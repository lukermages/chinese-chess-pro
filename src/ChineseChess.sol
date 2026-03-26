// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ChineseChess
 * @dev On-chain Xiangqi (Chinese Chess) with full move validation
 *      Board: 9 cols × 10 rows, stored as flat array to avoid Solidity nested array quirks
 *      Index: row * 9 + col
 */
contract ChineseChess {
    // ──────────────────────────── Constants ────────────────────────────
    uint8 constant COLS = 9;
    uint8 constant ROWS = 10;
    uint256 constant BOARD_SIZE = 90; // 9 * 10

    // ──────────────────────────── Types ────────────────────────────
    enum PieceType { Empty, King, Advisor, Elephant, Horse, Rook, Cannon, Pawn }
    enum Color { None, Red, Black }

    struct Piece {
        PieceType pType;
        Color color;
    }

    struct Game {
        address red;
        address black;
        Piece[90] board; // flat: board[row * 9 + col]
        Color turn;
        Color winner;
        bool finished;
        uint256 moveCount;
    }

    // ──────────────────────────── Storage ────────────────────────────
    mapping(uint256 => Game) public games;
    uint256 public nextGameId;

    // ──────────────────────────── Events ────────────────────────────
    event GameCreated(uint256 indexed gameId, address indexed red);
    event GameJoined(uint256 indexed gameId, address indexed black);
    event MoveMade(uint256 indexed gameId, address indexed player, uint8 fromCol, uint8 fromRow, uint8 toCol, uint8 toRow);
    event GameEnded(uint256 indexed gameId, Color winner);

    // ──────────────────────────── Errors ────────────────────────────
    error NotYourTurn();
    error GameFull();
    error GameNotWaiting();
    error GameAlreadyFinished();
    error InvalidPosition();
    error NoPieceAtSource();
    error NotYourPiece();
    error IllegalMove();
    error CannotCaptureKing();

    // ──────────────────────────── Helpers ────────────────────────────
    function _idx(uint8 row, uint8 col) internal pure returns (uint256) {
        return uint256(row) * 9 + uint256(col);
    }

    function _getPiece(Piece[90] storage board, uint8 row, uint8 col) internal view returns (PieceType, Color) {
        Piece storage p = board[_idx(row, col)];
        return (p.pType, p.color);
    }

    function _setPiece(Piece[90] storage board, uint8 row, uint8 col, PieceType pt, Color c) internal {
        board[_idx(row, col)] = Piece({pType: pt, color: c});
    }

    function _validPos(uint8 col, uint8 row) internal pure returns (bool) {
        return col < COLS && row < ROWS;
    }

    // ──────────────────────────── Public ────────────────────────────
    function createGame() external returns (uint256 gameId) {
        gameId = nextGameId++;
        Game storage g = games[gameId];
        g.red = msg.sender;
        g.turn = Color.Red;
        _initBoard(g.board);
        emit GameCreated(gameId, msg.sender);
    }

    function joinGame(uint256 gameId) external {
        Game storage g = games[gameId];
        if (g.finished) revert GameAlreadyFinished();
        if (g.black != address(0)) revert GameFull();
        g.black = msg.sender;
        emit GameJoined(gameId, msg.sender);
    }

    function makeMove(
        uint256 gameId,
        uint8 fromCol, uint8 fromRow,
        uint8 toCol, uint8 toRow
    ) external {
        Game storage g = games[gameId];
        if (g.finished) revert GameAlreadyFinished();
        if (g.black == address(0)) revert GameNotWaiting();

        Color moverColor = _playerColor(g, msg.sender);
        if (moverColor == Color.None) revert NotYourTurn();
        if (moverColor != g.turn) revert NotYourTurn();

        if (!_validPos(fromCol, fromRow) || !_validPos(toCol, toRow)) revert InvalidPosition();

        (PieceType srcType, Color srcColor) = _getPiece(g.board, fromRow, fromCol);
        (PieceType dstType, Color dstColor) = _getPiece(g.board, toRow, toCol);

        if (srcType == PieceType.Empty) revert NoPieceAtSource();
        if (srcColor != moverColor) revert NotYourPiece();
        if (dstColor == moverColor) revert IllegalMove();
        if (dstType == PieceType.King) revert CannotCaptureKing();

        // Inline move validation (no memory copies)
        if (!_isValidMove(g.board, fromCol, fromRow, toCol, toRow, srcType, srcColor)) revert IllegalMove();

        // Check king safety after move (simulate on storage, restore if invalid)
        // Save destination
        PieceType savedDstType = dstType;
        Color savedDstColor = dstColor;
        // Make temporary move on storage
        _setPiece(g.board, toRow, toCol, srcType, srcColor);
        _setPiece(g.board, fromRow, fromCol, PieceType.Empty, Color.None);
        bool inCheck = _isKingInCheck(g.board, moverColor);
        // Restore
        _setPiece(g.board, fromRow, fromCol, srcType, srcColor);
        _setPiece(g.board, toRow, toCol, savedDstType, savedDstColor);

        if (inCheck) revert IllegalMove();

        // Execute move
        _setPiece(g.board, toRow, toCol, srcType, srcColor);
        _setPiece(g.board, fromRow, fromCol, PieceType.Empty, Color.None);
        g.moveCount++;

        // Check for checkmate
        Color opponent = moverColor == Color.Red ? Color.Black : Color.Red;
        if (_isCheckmate(g.board, opponent)) {
            g.finished = true;
            g.winner = moverColor;
            emit GameEnded(gameId, moverColor);
        } else {
            g.turn = opponent;
        }

        emit MoveMade(gameId, msg.sender, fromCol, fromRow, toCol, toRow);
    }

    function getPiece(uint256 gameId, uint8 row, uint8 col) external view returns (PieceType, Color) {
        return _getPiece(games[gameId].board, row, col);
    }

    function getGame(uint256 gameId) external view returns (
        address red, address black, Color turn, Color winner, bool finished, uint256 moveCount
    ) {
        Game storage g = games[gameId];
        return (g.red, g.black, g.turn, g.winner, g.finished, g.moveCount);
    }

    // ──────────────────────────── Board Init ────────────────────────────
    function _initBoard(Piece[90] storage board) internal {
        // Red back rank (row 0)
        _setPiece(board, 0, 0, PieceType.Rook, Color.Red);
        _setPiece(board, 0, 1, PieceType.Horse, Color.Red);
        _setPiece(board, 0, 2, PieceType.Elephant, Color.Red);
        _setPiece(board, 0, 3, PieceType.Advisor, Color.Red);
        _setPiece(board, 0, 4, PieceType.King, Color.Red);
        _setPiece(board, 0, 5, PieceType.Advisor, Color.Red);
        _setPiece(board, 0, 6, PieceType.Elephant, Color.Red);
        _setPiece(board, 0, 7, PieceType.Horse, Color.Red);
        _setPiece(board, 0, 8, PieceType.Rook, Color.Red);
        // Red cannons (row 2)
        _setPiece(board, 2, 1, PieceType.Cannon, Color.Red);
        _setPiece(board, 2, 7, PieceType.Cannon, Color.Red);
        // Red pawns (row 3)
        _setPiece(board, 3, 0, PieceType.Pawn, Color.Red);
        _setPiece(board, 3, 2, PieceType.Pawn, Color.Red);
        _setPiece(board, 3, 4, PieceType.Pawn, Color.Red);
        _setPiece(board, 3, 6, PieceType.Pawn, Color.Red);
        _setPiece(board, 3, 8, PieceType.Pawn, Color.Red);

        // Black back rank (row 9)
        _setPiece(board, 9, 0, PieceType.Rook, Color.Black);
        _setPiece(board, 9, 1, PieceType.Horse, Color.Black);
        _setPiece(board, 9, 2, PieceType.Elephant, Color.Black);
        _setPiece(board, 9, 3, PieceType.Advisor, Color.Black);
        _setPiece(board, 9, 4, PieceType.King, Color.Black);
        _setPiece(board, 9, 5, PieceType.Advisor, Color.Black);
        _setPiece(board, 9, 6, PieceType.Elephant, Color.Black);
        _setPiece(board, 9, 7, PieceType.Horse, Color.Black);
        _setPiece(board, 9, 8, PieceType.Rook, Color.Black);
        // Black cannons (row 7)
        _setPiece(board, 7, 1, PieceType.Cannon, Color.Black);
        _setPiece(board, 7, 7, PieceType.Cannon, Color.Black);
        // Black pawns (row 6)
        _setPiece(board, 6, 0, PieceType.Pawn, Color.Black);
        _setPiece(board, 6, 2, PieceType.Pawn, Color.Black);
        _setPiece(board, 6, 4, PieceType.Pawn, Color.Black);
        _setPiece(board, 6, 6, PieceType.Pawn, Color.Black);
        _setPiece(board, 6, 8, PieceType.Pawn, Color.Black);
    }

    // ──────────────────────────── Move Validation (storage-based) ────────────────────────────
    function _isValidMove(
        Piece[90] storage board,
        uint8 fc, uint8 fr, uint8 tc, uint8 tr,
        PieceType pt, Color color
    ) internal view returns (bool) {
        if (fc == tc && fr == tr) return false;
        int8 dc = int8(tc) - int8(fc);
        int8 dr = int8(tr) - int8(fr);

        if (pt == PieceType.King) return _kingMove(fr, tc, tr, color, dc, dr);
        if (pt == PieceType.Advisor) return _advisorMove(tc, tr, color, dc, dr);
        if (pt == PieceType.Elephant) return _elephantMove(board, fc, fr, tc, tr, color, dc, dr);
        if (pt == PieceType.Horse) return _horseMove(board, fc, fr, tc, tr, dc, dr);
        if (pt == PieceType.Rook) return _rookMove(board, fc, fr, tc, tr);
        if (pt == PieceType.Cannon) return _cannonMove(board, fc, fr, tc, tr);
        if (pt == PieceType.Pawn) return _pawnMove(fr, tc, tr, color, dc, dr);
        return false;
    }

    function _kingMove(uint8 fr, uint8 tc, uint8 tr, Color color, int8 dc, int8 dr) internal pure returns (bool) {
        if (tc < 3 || tc > 5) return false;
        if (color == Color.Red && tr > 2) return false;
        if (color == Color.Black && tr < 7) return false;
        return (dc == 0 && (dr == 1 || dr == -1)) || (dr == 0 && (dc == 1 || dc == -1));
    }

    function _advisorMove(uint8 tc, uint8 tr, Color color, int8 dc, int8 dr) internal pure returns (bool) {
        if (tc < 3 || tc > 5) return false;
        if (color == Color.Red && tr > 2) return false;
        if (color == Color.Black && tr < 7) return false;
        return (dc == 1 || dc == -1) && (dr == 1 || dr == -1);
    }

    function _elephantMove(
        Piece[90] storage board, uint8 fc, uint8 fr, uint8 tc, uint8 tr,
        Color color, int8 dc, int8 dr
    ) internal view returns (bool) {
        if (color == Color.Red && tr > 4) return false;
        if (color == Color.Black && tr < 5) return false;
        if (!((dc == 2 || dc == -2) && (dr == 2 || dr == -2))) return false;
        uint8 eyeCol = uint8(int8(fc) + dc / 2);
        uint8 eyeRow = uint8(int8(fr) + dr / 2);
        (PieceType eyeType,) = _getPiece(board, eyeRow, eyeCol);
        return eyeType == PieceType.Empty;
    }

    function _horseMove(
        Piece[90] storage board, uint8 fc, uint8 fr, uint8 tc, uint8 tr,
        int8 dc, int8 dr
    ) internal view returns (bool) {
        int8 adc = dc < 0 ? -dc : dc;
        int8 adr = dr < 0 ? -dr : dr;
        if (!((adc == 1 && adr == 2) || (adc == 2 && adr == 1))) return false;
        uint8 blockCol;
        uint8 blockRow;
        if (adc == 2) {
            blockCol = uint8(int8(fc) + dc / 2);
            blockRow = fr;
        } else {
            blockCol = fc;
            blockRow = uint8(int8(fr) + dr / 2);
        }
        (PieceType blockType,) = _getPiece(board, blockRow, blockCol);
        return blockType == PieceType.Empty;
    }

    function _rookMove(Piece[90] storage board, uint8 fc, uint8 fr, uint8 tc, uint8 tr) internal view returns (bool) {
        if (fc != tc && fr != tr) return false;
        return _countBetween(board, fc, fr, tc, tr) == 0;
    }

    function _cannonMove(Piece[90] storage board, uint8 fc, uint8 fr, uint8 tc, uint8 tr) internal view returns (bool) {
        if (fc != tc && fr != tr) return false;
        uint256 between = _countBetween(board, fc, fr, tc, tr);
        (PieceType dstType,) = _getPiece(board, tr, tc);
        if (dstType != PieceType.Empty) return between == 1;
        return between == 0;
    }

    function _pawnMove(uint8 fr, uint8 tc, uint8 tr, Color color, int8 dc, int8 dr) internal pure returns (bool) {
        int8 adc = dc < 0 ? -dc : dc;
        int8 adr = dr < 0 ? -dr : dr;
        bool crossedRiver = (color == Color.Red && fr > 4) || (color == Color.Black && fr < 5);
        if (crossedRiver) {
            if (adc + adr != 1) return false;
            if (color == Color.Red && dr == -1) return false;
            if (color == Color.Black && dr == 1) return false;
            return true;
        } else {
            if (adc != 0 || adr != 1) return false;
            if (color == Color.Red && dr != 1) return false;
            if (color == Color.Black && dr != -1) return false;
            return true;
        }
    }

    function _countBetween(Piece[90] storage board, uint8 fc, uint8 fr, uint8 tc, uint8 tr) internal view returns (uint256) {
        uint256 count = 0;
        if (fc == tc) {
            uint8 minR = fr < tr ? fr : tr;
            uint8 maxR = fr > tr ? fr : tr;
            for (uint8 r = minR + 1; r < maxR; r++) {
                (PieceType pt,) = _getPiece(board, r, fc);
                if (pt != PieceType.Empty) count++;
            }
        } else {
            uint8 minC = fc < tc ? fc : tc;
            uint8 maxC = fc > tc ? fc : tc;
            for (uint8 c = minC + 1; c < maxC; c++) {
                (PieceType pt,) = _getPiece(board, fr, c);
                if (pt != PieceType.Empty) count++;
            }
        }
        return count;
    }

    // ──────────────────────────── King Safety ────────────────────────────
    function _playerColor(Game storage g, address player) internal view returns (Color) {
        if (player == g.red) return Color.Red;
        if (player == g.black) return Color.Black;
        return Color.None;
    }

    function _findKing(Piece[90] storage board, Color color) internal view returns (uint8 col, uint8 row) {
        for (uint8 r = 0; r < ROWS; r++) {
            for (uint8 c = 0; c < COLS; c++) {
                (PieceType pt, Color pc) = _getPiece(board, r, c);
                if (pt == PieceType.King && pc == color) {
                    return (c, r);
                }
            }
        }
    }

    function _isKingInCheck(Piece[90] storage board, Color color) internal view returns (bool) {
        (uint8 kingCol, uint8 kingRow) = _findKing(board, color);
        Color opp = color == Color.Red ? Color.Black : Color.Red;
        for (uint8 r = 0; r < ROWS; r++) {
            for (uint8 c = 0; c < COLS; c++) {
                (PieceType pt, Color pc) = _getPiece(board, r, c);
                if (pc == opp) {
                    if (_isValidMove(board, c, r, kingCol, kingRow, pt, opp)) {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    function _isCheckmate(Piece[90] storage board, Color color) internal returns (bool) {
        if (!_isKingInCheck(board, color)) return false;
        // Only check pieces of the defending color (max 16 pieces)
        // For each piece, try all reachable squares (max 90)
        // This reduces worst case from 90*90=8100 to 16*90=1440 checks
        for (uint8 fr = 0; fr < ROWS; fr++) {
            for (uint8 fc = 0; fc < COLS; fc++) {
                (PieceType srcType, Color srcColor) = _getPiece(board, fr, fc);
                if (srcColor != color) continue;
                for (uint8 tr = 0; tr < ROWS; tr++) {
                    for (uint8 tc = 0; tc < COLS; tc++) {
                        if (fc == tc && fr == tr) continue;
                        (PieceType dstType, Color dstColor) = _getPiece(board, tr, tc);
                        if (dstColor == color) continue;
                        if (dstType == PieceType.King) continue;
                        if (!_isValidMove(board, fc, fr, tc, tr, srcType, color)) continue;
                        // Simulate move on storage
                        _setPiece(board, tr, tc, srcType, color);
                        _setPiece(board, fr, fc, PieceType.Empty, Color.None);
                        bool stillInCheck = _isKingInCheck(board, color);
                        // Restore
                        _setPiece(board, fr, fc, srcType, color);
                        _setPiece(board, tr, tc, dstType, dstColor);
                        if (!stillInCheck) return false;
                    }
                }
            }
        }
        return true;
    }
}

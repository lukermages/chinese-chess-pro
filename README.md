# 🀄 Chinese Chess (象棋) On-Chain

**The first fully on-chain Chinese Chess (Xiangqi) smart contract.**

7 piece types · Complete move validation · Check/checkmate detection · Built with [Foundry](https://book.getfoundry.sh/)

## Features

- ♜ **Full board setup** (9×10 standard Xiangqi board)
- ♞ **All 7 piece types**: 車(Rook) 馬(Horse) 象/相(Elephant) 士/仕(Advisor) 将/帅(King) 炮(Cannon) 兵/卒(Pawn)
- ⚔️ **Player vs Player** with alternating turns
- 🏯 **Palace rules**: King and Advisor must stay in the palace (3×3)
- 🌊 **River rules**: Elephant can't cross river, Pawn gains sideways movement after crossing
- 🚫 **Flying General**: Kings can't face each other with no pieces between
- 🛡️ **Can't capture King**: Must checkmate, not capture
- ♟️ **Full move validation** with blocking detection (Horse leg, Elephant eye)
- 📦 **Pure Solidity** — 100% on-chain, no backend

## Quick Start

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Clone and build
git clone https://github.com/lukermages/chinese-chess-pro
cd chinese-chess-pro
forge build

# Run tests
forge test -vvv
```

## Contract Usage

```solidity
// Create a game (you are Red, moves first)
uint256 gameId = chess.createGame();

// Join as Black
chess.joinGame(gameId);

// Make a move: pawn from (col=0, row=3) to (col=0, row=4)
chess.makeMove(gameId, 0, 3, 0, 4);

// Check game status
(address red, address black, Color turn, Color winner, bool finished, uint256 moves) = chess.getGame(gameId);

// Get a piece at position
(PieceType pt, Color c) = chess.getPiece(gameId, row, col);
```

## Board Layout

```
     Black (top, rows 5-9)
  0   1   2   3   4   5   6   7   8
9 車  馬  象  士  将  士  象  馬  車
8
7    炮              炮
6 兵     兵     兵     兵     兵
  =========== 河界 ===========
5
4 兵     兵     兵     兵     兵
3
2    炮              炮
1
0 車  馬  相  仕  帅  仕  相  馬  車
     Red (bottom, rows 0-4)
```

## Piece Movement Rules

| Piece | Move Pattern | Constraints |
|-------|-------------|-------------|
| 将/帅 (King) | 1 step orthogonal | Must stay in 3×3 palace |
| 士/仕 (Advisor) | 1 step diagonal | Must stay in 3×3 palace |
| 象/相 (Elephant) | 2 steps diagonal | Can't cross river; blocked by "eye" |
| 馬 (Horse) | L-shape (1+2) | Blocked by adjacent piece ("leg") |
| 車 (Rook) | Any distance orthogonal | Blocked by any piece |
| 炮 (Cannon) | Any distance orthogonal | Jumps exactly 1 piece to capture |
| 兵/卒 (Pawn) | 1 step forward | After crossing river: + sideways |

## Gas Costs

| Function | Avg Gas | Notes |
|----------|---------|-------|
| createGame | ~850K | Sets up 32 pieces |
| makeMove | ~630K | Includes checkmate detection |
| joinGame | ~49K | Simple state update |

## Testing

```bash
# All tests
forge test -vvv

# Gas report
forge test --gas-report

# Specific test
forge test --match-test testRookCapture -vvv
```

13 tests covering:
- Game creation and joining
- Initial board verification
- All piece movement types (Pawn, Cannon, Horse, Rook)
- Error cases (wrong turn, empty square, capture king)
- Rook capture mechanics

## Architecture

The contract uses a **flat `Piece[90]` array** instead of nested `Piece[9][10]` to avoid Solidity's nested memory array quirks. Board positions use `_idx(row, col) = row * 9 + col`.

All move validation functions read directly from storage via `_getPiece()`, avoiding memory copies that can cause issues with complex nested types.

## Future Work

- [ ] Gas optimization (assembly, uint256 trick)
- [ ] Betting/wagering system
- [ ] Game replay/history
- [ ] NFT integration (mint game as NFT)
- [ ] Frontend (React + Canvas)
- [ ] AI opponent
- [ ] Tournament system

## License

MIT

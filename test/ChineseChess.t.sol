// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ChineseChess} from "../src/ChineseChess.sol";

contract ChineseChessTest is Test {
    ChineseChess game;
    uint256 gameId;
    address red = address(0xA11CE);
    address black = address(0xB0B);

    function setUp() public {
        game = new ChineseChess();
        vm.prank(red);
        gameId = game.createGame();
        vm.prank(black);
        game.joinGame(gameId);
    }

    function testCreateGame() public view {
        (address r, address b, ChineseChess.Color turn, ChineseChess.Color winner, bool finished, uint256 moves) = game.getGame(gameId);
        assertEq(r, red);
        assertEq(b, black);
        assertEq(uint8(turn), uint8(ChineseChess.Color.Red));
        assertFalse(finished);
        assertEq(moves, 0);
    }

    function testInitialBoard() public {
        (ChineseChess.PieceType pt, ChineseChess.Color c) = game.getPiece(gameId, 0, 4);
        assertEq(uint8(pt), uint8(ChineseChess.PieceType.King));
        assertEq(uint8(c), uint8(ChineseChess.Color.Red));

        (ChineseChess.PieceType pt2, ChineseChess.Color c2) = game.getPiece(gameId, 9, 4);
        assertEq(uint8(pt2), uint8(ChineseChess.PieceType.King));
        assertEq(uint8(c2), uint8(ChineseChess.Color.Black));

        (ChineseChess.PieceType pt3, ChineseChess.Color c3) = game.getPiece(gameId, 0, 0);
        assertEq(uint8(pt3), uint8(ChineseChess.PieceType.Rook));
        assertEq(uint8(c3), uint8(ChineseChess.Color.Red));
    }

    function testPawnMove() public {
        vm.prank(red);
        game.makeMove(gameId, 0, 3, 0, 4);

        (ChineseChess.PieceType pt, ChineseChess.Color c) = game.getPiece(gameId, 4, 0);
        assertEq(uint8(pt), uint8(ChineseChess.PieceType.Pawn));
        assertEq(uint8(c), uint8(ChineseChess.Color.Red));
    }

    function testCannonMove() public {
        vm.prank(red);
        game.makeMove(gameId, 1, 2, 1, 4);

        (ChineseChess.PieceType pt, ChineseChess.Color c) = game.getPiece(gameId, 4, 1);
        assertEq(uint8(pt), uint8(ChineseChess.PieceType.Cannon));
        assertEq(uint8(c), uint8(ChineseChess.Color.Red));
    }

    function testHorseMove() public {
        vm.prank(red);
        game.makeMove(gameId, 0, 3, 0, 4);
        vm.prank(black);
        game.makeMove(gameId, 0, 6, 0, 5);
        vm.prank(red);
        game.makeMove(gameId, 1, 0, 0, 2);

        (ChineseChess.PieceType pt, ChineseChess.Color c) = game.getPiece(gameId, 2, 0);
        assertEq(uint8(pt), uint8(ChineseChess.PieceType.Horse));
        assertEq(uint8(c), uint8(ChineseChess.Color.Red));
    }

    function testCannotMoveOnOpponentTurn() public {
        vm.prank(black);
        vm.expectRevert(ChineseChess.NotYourTurn.selector);
        game.makeMove(gameId, 0, 6, 0, 5);
    }

    function testCannotMoveEmptySquare() public {
        vm.prank(red);
        vm.expectRevert(ChineseChess.NoPieceAtSource.selector);
        game.makeMove(gameId, 4, 4, 4, 5);
    }

    function testCannotCaptureKing() public {
        vm.prank(red);
        vm.expectRevert(ChineseChess.CannotCaptureKing.selector);
        game.makeMove(gameId, 0, 0, 4, 9);
    }

    function testRookCapture() public {
        // Check rook at (0,0)
        (ChineseChess.PieceType pt, ChineseChess.Color c) = game.getPiece(gameId, 0, 0);
        assertEq(uint8(pt), uint8(ChineseChess.PieceType.Rook));

        // Try simple rook move (0,0)→(0,1)
        vm.prank(red);
        game.makeMove(gameId, 0, 0, 0, 1);

        (ChineseChess.PieceType pt2, ChineseChess.Color c2) = game.getPiece(gameId, 1, 0);
        assertEq(uint8(pt2), uint8(ChineseChess.PieceType.Rook));
        assertEq(uint8(c2), uint8(ChineseChess.Color.Red));
    }
}

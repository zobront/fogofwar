// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract GoldRush {

    struct Player {
        address addr;
        bytes32 lastCommitment;
        uint8 pendingMove;
        uint8 score;
        mapping(uint8 => bool) goldUsed;
    }

    struct Game {
        uint96 pot;
        uint64 timeout;
        uint64 nextTurn;
        uint8 middle;
        bool gameOver;
        Player p1;
        Player p2;
    }

    mapping(uint => Game) games;
    uint nextGame;

    function offerGame(uint64 _timeout) public payable {
        Game storage g = games[nextGame++];
        g.pot = uint64(msg.value * 2);
        g.p1.addr = msg.sender;
        g.timeout = _timeout;
    }

    function acceptGame(uint gameId) public payable {
        Game storage g = games[gameId];
        require(g.p2.addr == address(0));
        require(msg.value * 2 == g.pot);
        g.p2.addr = msg.sender;
        g.nextTurn = uint64(block.timestamp) + g.timeout;
    }

    function commitToTurn(uint gameId, bytes32 commitment) public {
        Game storage g = games[gameId];
        require(!games[gameId].gameOver);
        require(g.p1.lastCommitment == bytes32(0));
        require(g.p2.lastCommitment == bytes32(0));

        (Player storage player,) = _getPlayerAndOpponent(g);
        player.lastCommitment = commitment;
    }

    function makeMove(uint gameId, uint8 move) public {
        Game storage g = games[gameId];
        require(!games[gameId].gameOver);
        require(move <= 6 && move > 0);

        (Player storage player, Player storage opponent) = _getPlayerAndOpponent(g);
        require(player.lastCommitment == bytes32(0));
        require(opponent.lastCommitment != bytes32(0));

        require(player.goldUsed[move] == false);
        player.goldUsed[move] = true;
        player.pendingMove = move;
    }

    function revealCommitment(uint gameId, uint turn) public {
        Game storage g = games[gameId];
        require(!games[gameId].gameOver);

        (Player storage player, Player storage opponent) = _getPlayerAndOpponent(g);

        require(player.lastCommitment != bytes32(0));
        require(opponent.pendingMove != 0);

        require(player.lastCommitment == keccak256(abi.encodePacked(turn)));
        uint8 move = uint8(turn % 6);
        require(move != 0);
        require(player.goldUsed[move] == false);
        player.goldUsed[move] = true;

        if (move > opponent.pendingMove) {
            player.score += (move + opponent.pendingMove + g.middle);
            g.middle = 0;
        } else if (move < opponent.pendingMove) {
            opponent.score += (move + opponent.pendingMove + g.middle);
            g.middle = 0;
        } else {
            g.middle += (move + opponent.pendingMove);
        }
        opponent.pendingMove = 0;
        player.lastCommitment = bytes32(0);
    }

    function endGame(uint gameId) public {
        Game storage g = games[gameId];
        require(!games[gameId].gameOver);
        require(g.nextTurn < block.timestamp);

        if (g.p1.score > g.p2.score) {
            payable(g.p1.addr).transfer(g.pot);
        } else if (g.p1.score < g.p2.score) {
            payable(g.p2.addr).transfer(g.pot);
        } else {
            payable(g.p1.addr).transfer(g.pot / 2);
            payable(g.p2.addr).transfer(g.pot / 2);
        }
        g.gameOver = true;
    }

    function stealPot(uint gameId, bool p1, uint8 unusedGold) public {
        Game storage g = games[gameId];
        require(!games[gameId].gameOver);
        require(g.nextTurn < block.timestamp);
        Player storage slowPoke = p1 ? g.p1 : g.p2;
        Player storage otherPlayer = p1 ? g.p2 : g.p1;

        require(slowPoke.goldUsed[unusedGold] == false);
        require(slowPoke.lastCommitment == bytes32(0));
        require(slowPoke.pendingMove == 0);

        payable(otherPlayer.addr).transfer(g.pot);
        g.gameOver = true;
    }

    function _getPlayerAndOpponent(Game storage g) internal view returns (Player storage, Player storage) {
        if (msg.sender == g.p1.addr) {
            return (g.p1, g.p2);
        } else if (msg.sender == g.p2.addr) {
            return (g.p2, g.p1);
        } else {
            revert();
        }
    }

}

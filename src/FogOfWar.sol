// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { ELO } from "./ELO.sol";
import { UltraVerifier as MoveVerifier } from "../circuits/move/contract/plonk_vk.sol";
import { UltraVerifier as EndVerifier } from "../circuits/end/contract/plonk_vk.sol";
import "solady/utils/MerkleProofLib.sol";

contract FogOfWar is ELO {
    struct Agent {
        address addr;
        bytes32 secretCommitment;
        bytes32 lastMoveCommitment;
        bytes32[] nullifiers;
        mapping(bytes32 => bool) nullifiersUsed;
    }

    struct Soldier {
        address addr;
        uint8[] moves;
        mapping(uint8 => bool) cardsUsed;
    }

    struct Game {
        Agent agent;
        Soldier soldier;
        uint64 timeout;
        uint64 nextTurnDeadline;
        bool soldierTurn;
    }

    struct GameDetails {
        uint64 timeout;
        uint64 nextTurnDeadline;
        bool soldierTurn;
        address agent;
        bytes32[] agentNullifiers;
        bytes32 agentSecretCommitment;
        bytes32 agentLastMoveCommitment;
        address soldier;
        uint8[] soldierMoves;
    }

    enum TurnResult {
        Tie,
        AgentWon,
        SoldierWon
    }

    function getGameDetails(uint gameId) public view returns (GameDetails memory details) {
        Game storage g = games[gameId];

        details.timeout = g.timeout;
        details.nextTurnDeadline = g.nextTurnDeadline;
        details.soldierTurn = g.soldierTurn;
        details.agent = g.agent.addr;
        details.agentNullifiers = g.agent.nullifiers;
        details.agentSecretCommitment = g.agent.secretCommitment;
        details.agentLastMoveCommitment = g.agent.lastMoveCommitment;
        details.soldier = g.soldier.addr;
        details.soldierMoves = g.soldier.moves;
    }

    mapping(uint => Game) games;
    uint nextGame;
    bytes32 root;
    address owner;
    MoveVerifier moveVerifier;
    EndVerifier endVerifier;

    constructor( MoveVerifier _moveVerifier, EndVerifier _endVerifier) {
        owner = msg.sender;
        moveVerifier = _moveVerifier;
        endVerifier = _endVerifier;
    }

    ///////////////////////////////
    ///// REGISTER AN ACCOUNT /////
    ///////////////////////////////

    function register() public payable {
        require(msg.value == 0.01 ether);
        require(rankings[msg.sender] == 0);
        rankings[msg.sender] = 1000e18;
    }

    function registerWithProof(bytes32[] memory proof) public {
        require(MerkleProofLib.verify(proof, root, keccak256(abi.encodePacked(msg.sender))));
        require(rankings[msg.sender] == 0);
        rankings[msg.sender] = 1000e18;
    }

    ///////////////////////////////
    ////// OFFER A NEW GAME ///////
    ///////////////////////////////

    function offerGameAsAgent(uint64 _timeout, bytes32 _secretCommitment) public returns (uint gameId) {
        require(rankings[msg.sender] > 0, "register before playing");
        gameId = nextGame++;
        Game storage g = games[gameId];
        g.agent.addr = msg.sender;
        g.agent.secretCommitment = _secretCommitment;
        g.timeout = _timeout;
    }

    function offerGameAsSoldier(uint64 _timeout) public returns (uint gameId) {
        require(rankings[msg.sender] > 0, "register before playing");
        gameId = nextGame++;
        Game storage g = games[gameId];
        g.soldier.addr = msg.sender;
        g.timeout = _timeout;
    }

    function acceptGame(uint gameId, bytes32 _secretCommitment) public payable {
        require(rankings[msg.sender] > 0, "register before playing");
        Game storage g = games[gameId];
        if (_secretCommitment == bytes32(0)) {
            require(g.soldier.addr == address(0));
            require(g.agent.addr != address(0));
            g.soldier.addr = msg.sender;
        } else {
            require(g.soldier.addr != address(0));
            require(g.agent.addr == address(0));
            g.agent.addr = msg.sender;
            g.agent.secretCommitment = _secretCommitment;
        }
        g.nextTurnDeadline = uint64(block.timestamp) + g.timeout;
    }

    ///////////////////////////////
    ////////// GAME FLOW //////////
    ///////////////////////////////

    // only used if agent proposed game, soldier accepted
    function commitToFirstMove(uint gameId, bytes32 firstMoveCommitment) public {
        Game storage g = games[gameId];
        require(g.agent.addr == msg.sender);

        require(g.agent.lastMoveCommitment == bytes32(0));
        g.agent.lastMoveCommitment = firstMoveCommitment;

        g.nextTurnDeadline = uint64(block.timestamp) + g.timeout;
        g.soldierTurn = true;
    }

    function soldierMove(uint gameId, uint8 move) public {
        Game storage g = games[gameId];
        require(move <= 6 && move > 0);
        require(g.soldier.addr == msg.sender);
        require(g.soldier.cardsUsed[move] == false);
        require(g.soldierTurn);

        g.soldier.moves.push(move);
        g.soldier.cardsUsed[move] = true;
        g.soldierTurn = false;
        g.nextTurnDeadline = uint64(block.timestamp) + g.timeout;
    }

    function agentMove(uint gameId, bytes memory proof, bytes32 nullifier, TurnResult turnResult, bytes32 nextMoveCommitment) public {
        Game storage g = games[gameId];
        require(g.agent.addr == msg.sender);

        require(!g.agent.nullifiersUsed[nullifier]);
        g.agent.nullifiersUsed[nullifier] = true;
        g.agent.nullifiers.push(nullifier);

        require(!g.soldierTurn);
        if (g.agent.nullifiers.length < 6) {
            g.soldierTurn = true;
        }

        bytes32[] memory publicInputs = new bytes32[](5);
        publicInputs[0] = g.agent.secretCommitment;
        publicInputs[1] = g.agent.lastMoveCommitment;
        publicInputs[2] = bytes32(uint(g.soldier.moves[g.soldier.moves.length - 1]));
        publicInputs[3] = bytes32(uint(turnResult));
        publicInputs[4] = nullifier;

        require(moveVerifier.verify(proof, publicInputs), "proof failed");

        g.nextTurnDeadline = uint64(block.timestamp) + g.timeout;
        g.agent.lastMoveCommitment = nextMoveCommitment;
    }

    function endGame(uint gameId, bytes memory proof, uint8 agentScore, uint8 soldierScore) public {
        Game storage g = games[gameId];
        require(g.soldier.moves.length == 6);
        require(!g.soldierTurn);

        bytes32[] memory publicInputs = new bytes32[](15);
        publicInputs[0] = g.agent.secretCommitment;
        for (uint i; i < 6; i++) {
            publicInputs[1 + i] = g.agent.nullifiers[i];
            publicInputs[7 + i] = bytes32(uint(g.soldier.moves[i]));
        }
        publicInputs[13] = bytes32(uint(agentScore));
        publicInputs[14] = bytes32(uint(soldierScore));

        require(endVerifier.verify(proof, publicInputs), "proof failed");

        if (agentScore > soldierScore) {
            _updateRankings(g.agent.addr, g.soldier.addr, true);
        } else if (soldierScore > agentScore) {
            _updateRankings(g.soldier.addr, g.agent.addr, false);
        }
        // todo: should add updates in the case of a tie, since that should benefit soldier

        g.nextTurnDeadline = 0;
    }

    function stealGame(uint gameId) public {
        Game storage g = games[gameId];
        require(g.nextTurnDeadline > 0 && g.nextTurnDeadline < block.timestamp);

        if (g.soldierTurn) {
            _updateRankings(g.agent.addr, g.soldier.addr, true);
        } else {
            _updateRankings(g.soldier.addr, g.agent.addr, false);
        }

        g.nextTurnDeadline = 0;
    }

    /// OWNER ONLY //

    function updateMerkleRoot(bytes32 newRoot) public {
        require(msg.sender == owner);
        root = newRoot;
    }


    /// MOCKS FOR TESTING //

    function mockUpdateRankings(address winner, address loser, bool agentWon) public {
        _updateRankings(winner, loser, agentWon);
    }

}

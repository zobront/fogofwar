// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../src/FogOfWar.sol";
import "forge-std/Test.sol";
import { UltraVerifier as MoveVerifier } from "../circuits/move/contract/plonk_vk.sol";
import { UltraVerifier as EndVerifier } from "../circuits/end/contract/plonk_vk.sol";

contract FogOfWarE2E is Test {
    FogOfWar game;
    address agent = makeAddr("agent");
    address soldier = makeAddr("soldier");

    bytes32 SECRET_COMMITMENT = 0x08040e93139b1bb9070578e3c53bc39c37a68825066601c9d31f6d58b2cb001f;

    // must be ordered alphabetically for decoding to work
    struct DecodedJSONProofData {
        bytes32 move_commitment;
        bytes32 nullifier;
        bytes32 secret_hash;
    }

    struct ProofData {
        bytes proof;
        bytes32 move_commitment;
        bytes32 nullifier;
    }

    function testFogOfWarE2E() public {
        MoveVerifier moveVerifier = new MoveVerifier();
        EndVerifier endVerifier = new EndVerifier();
        game = new FogOfWar(moveVerifier, endVerifier);
        _registerBothPlayers();

        // Collect the data for all the moves
        // 1.json = 331 (1) vs 6
        // 2.json = 1268 (2) vs 1
        // 3.json = 1269 (3) vs 2
        // 4.json = 556 (4) vs 3
        // 5.json = 2597 (5) vs 4
        // 6.json = 354 (6) vs 5
        ProofData[] memory moves = new ProofData[](6);
        moves[0] = _getProofData("./circuits/move/proofs/1.proof", "./circuits/move/verifiers/1.json");
        moves[1] = _getProofData("./circuits/move/proofs/2.proof", "./circuits/move/verifiers/2.json");
        moves[2] = _getProofData("./circuits/move/proofs/3.proof", "./circuits/move/verifiers/3.json");
        moves[3] = _getProofData("./circuits/move/proofs/4.proof", "./circuits/move/verifiers/4.json");
        moves[4] = _getProofData("./circuits/move/proofs/5.proof", "./circuits/move/verifiers/5.json");
        moves[5] = _getProofData("./circuits/move/proofs/6.proof", "./circuits/move/verifiers/6.json");

        // Move 0: Offer Game As Soldier with 1 second timeout
        vm.prank(soldier);
        uint gameId = game.offerGameAsSoldier(1);

        // Move 0: Accept Game as Agent
        vm.prank(agent);
        game.acceptGame(gameId, SECRET_COMMITMENT);

        // Move 1A: Accept Game as Agent & make first move:
        // - Card: 1 (331)
        vm.prank(agent);
        game.commitToFirstMove(gameId, moves[0].move_commitment);

        // Move 1B: Soldier Move 1
        // - Card: 6
        vm.prank(soldier);
        game.soldierMove(gameId, 6);
        uint numSoldierMoves = game.getGameDetails(gameId).soldierMoves.length;
        assert(numSoldierMoves == 1);
        assert(game.getGameDetails(gameId).soldierMoves[numSoldierMoves - 1] == 6);
        assert(!game.getGameDetails(gameId).soldierTurn);

        // Move 1C/2A: Agent Move 2
        // - Card: 2 (1268)
        // - Soldier's View After: Soldier = [6], Agent = [a card under 6]
        vm.prank(agent);
        game.agentMove(gameId, moves[0].proof, moves[0].nullifier, FogOfWar.TurnResult.SoldierWon, moves[1].move_commitment);

        // Move 2B: Soldier Move 2
        // - Card: 1
        vm.prank(soldier);
        game.soldierMove(gameId, 1);

        // Move 2C/3A: Agent Move 3
        // - Card: 3 (1269)
        // - Soldier's View After: Soldier = [6, 1], Agent = [a card under 6, a card over 1])
        vm.prank(agent);
        game.agentMove(gameId, moves[1].proof, moves[1].nullifier, FogOfWar.TurnResult.AgentWon, moves[2].move_commitment);

        // Move 3B: Soldier Move 3
        // - Card: 2
        vm.prank(soldier);
        game.soldierMove(gameId, 2);

        // Move 3C/4A: Agent Move 4
        // - Card: 4 (556)
        // - Soldier's View After: Soldier = [6, 1, 2], Agent = [a card under 6, a card over 1, a card over 2])
        vm.prank(agent);
        game.agentMove(gameId, moves[2].proof, moves[2].nullifier, FogOfWar.TurnResult.AgentWon, moves[3].move_commitment);

        // Move 4B: Soldier Move 4
        // - Card: 3
        vm.prank(soldier);
        game.soldierMove(gameId, 3);

        // Move 4C/5A: Agent Move 5
        // - Card: 5 (2597)
        // - Soldier's View After: Soldier = [6, 1, 2, 3], Agent = [a card under 6, a card over 1, a card over 2, a card over 3])
        vm.prank(agent);
        game.agentMove(gameId, moves[3].proof, moves[3].nullifier, FogOfWar.TurnResult.AgentWon, moves[4].move_commitment);

        // Move 5B: Soldier Move 5
        // - Card: 4
        vm.prank(soldier);
        game.soldierMove(gameId, 4);

        // Move 5C/6A: Agent Move 6
        // - Card: 6 (354)
        // - Soldier's View After: Soldier = [6, 1, 2, 3, 4], Agent = [a card under 6, a card over 1, a card over 2, a card over 3, a card over 4])
        vm.prank(agent);
        game.agentMove(gameId, moves[4].proof, moves[4].nullifier, FogOfWar.TurnResult.AgentWon, moves[5].move_commitment);

        // Move 6B: Soldier Move 6
        // - Card: 5
        vm.prank(soldier);
        game.soldierMove(gameId, 5);

        // Move 6C: Agent Move 7
        vm.prank(agent);
        game.agentMove(gameId, moves[5].proof, moves[5].nullifier, FogOfWar.TurnResult.AgentWon, 0);

        // Agent Can Now End the Game
        bytes memory end_proof = _getProof("./circuits/end/proofs/p.proof");
        uint startingAgentRank = game.rankings(agent);
        uint startingSoldierRank = game.rankings(soldier);
        game.endGame(gameId, end_proof, 35, 7);
        assert(game.rankings(agent) > startingAgentRank);
        assert(game.rankings(soldier) < startingSoldierRank);
    }

    function _registerBothPlayers() internal {
        vm.deal(agent, 0.01 ether);
        vm.prank(agent);
        game.register{value: 0.01 ether}();

        vm.deal(soldier, 0.01 ether);
        vm.prank(soldier);
        game.register{value: 0.01 ether}();

        assert(game.rankings(agent) == 1000e18);
        assert(game.rankings(soldier) == 1000e18);
    }

    function _getProofData(string memory proof_filepath, string memory verifier_filepath)
        internal view returns (ProofData memory) {
        bytes memory proof = _getProof(proof_filepath);

        string memory json = vm.readFile(verifier_filepath);
        bytes memory values = vm.parseJson(json);
        DecodedJSONProofData memory decoded = abi.decode(values, (DecodedJSONProofData));

        return ProofData({
            proof: proof,
            move_commitment: decoded.move_commitment,
            nullifier: decoded.nullifier
        });
    }

    function _getProof(string memory filepath) internal view returns (bytes memory proof) {
        string memory proofString = vm.readLine(filepath);
        proof = vm.parseBytes(proofString);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { UltraVerifier as MoveVerifier } from "../circuits/move/contract/plonk_vk.sol";
import { UltraVerifier as EndVerifier } from "../circuits/end/contract/plonk_vk.sol";
import "./FogOfWar.t.sol";

contract TestVerifier is Test {
    function testMoveVerifier() public {
        MoveVerifier verifier = new MoveVerifier();

        FogOfWarE2E.ProofData memory proofdata = _getProofData("./circuits/move/proofs/1.proof", "./circuits/move/verifiers/1.json");

        bytes32[] memory publicInputs = new bytes32[](5);
        publicInputs[0] = 0x08040e93139b1bb9070578e3c53bc39c37a68825066601c9d31f6d58b2cb001f;
        publicInputs[1] = proofdata.move_commitment;
        uint op_move = 6;
        publicInputs[2] = bytes32(op_move);
        uint output = 2;
        publicInputs[3] = bytes32(output);
        publicInputs[4] = proofdata.nullifier;

        assert(verifier.verify(proofdata.proof, publicInputs));
    }

    function testEndVerifier() public {
        EndVerifier verifier = new EndVerifier();

        string memory proofString = vm.readLine("./circuits/end/proofs/p.proof");
        bytes memory proof = vm.parseBytes(proofString);

        bytes32[] memory publicInputs = new bytes32[](15);
        publicInputs[0] = 0x08040e93139b1bb9070578e3c53bc39c37a68825066601c9d31f6d58b2cb001f;
        publicInputs[1] = 0x222857ceb3707d30ffe34b9dd8c842d293419d8a400835e475acd6d11eb36e35;
        publicInputs[2] = 0x1b696e7a26ad5e14ae06724481b75ae72831171d9e6618917341c3700ec7e8b5;
        publicInputs[3] = 0x0742e8c285bb1893710e67686ed23aef58792fcd3a62290c7944a64f38f4f78a;
        publicInputs[4] = 0x11e8f70a498f932ab9fd9005beefb4ff68ef12d5eef632b8155f3702bf3b0113;
        publicInputs[5] = 0x2685e5bc482073a6fab26cdf6827dc70d712043168c12c3d9f3fcd596cda2fa8;
        publicInputs[6] = 0x18fc65b96ab05d4d8066bdd275cbc4c3c0246b6972872c23660cab8901754232;
        for (uint i; i < 7; i++) {
            uint j = i;
            if (i == 0) j = 6;
            publicInputs[7 + i] = bytes32(j);
        }
        publicInputs[13] = 0x0000000000000000000000000000000000000000000000000000000000000023;
        publicInputs[14] = 0x0000000000000000000000000000000000000000000000000000000000000007;

        assert(verifier.verify(proof, publicInputs));
    }

    function _getProofData(string memory proof_filepath, string memory verifier_filepath)
        internal view returns (FogOfWarE2E.ProofData memory) {
        string memory proofString = vm.readLine(proof_filepath);
        bytes memory proof = vm.parseBytes(proofString);

        string memory json = vm.readFile(verifier_filepath);
        bytes memory values = vm.parseJson(json);
        FogOfWarE2E.DecodedJSONProofData memory decoded = abi.decode(values, (FogOfWarE2E.DecodedJSONProofData));

        return FogOfWarE2E.ProofData({
            proof: proof,
            move_commitment: decoded.move_commitment,
            nullifier: decoded.nullifier
        });
    }
}

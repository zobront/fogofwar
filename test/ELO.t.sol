// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/FogOfWar.sol";
import "solady/utils/FixedPointMathLib.sol";
import { UltraVerifier as MoveVerifier } from "../circuits/move/contract/plonk_vk.sol";
import { UltraVerifier as EndVerifier } from "../circuits/end/contract/plonk_vk.sol";

contract ELOTest is Test {
    FogOfWar elo;
    address p1 = makeAddr("p1");
    address p2 = makeAddr("p2");

    function setUp() public {
        elo = new FogOfWar(MoveVerifier(address(0)), EndVerifier(address(0)));

        elo.setRanking(p1, 1600e18);
        elo.setRanking(p2, 1200e18);
    }

    function testGetExpectedScores(uint p1Score) public {
        p1Score = bound(p1Score, 401, 3000);
        uint p2Score = p1Score - 400;

        uint p1Prob = elo.getExpectedScore(p1Score * 1e18, p2Score * 1e18);
        uint inferredP2Prob = 1e18 - p1Prob;

        assert(_areWithinX(p1Prob / 10, inferredP2Prob, 1));
    }

    function testHighAgentBeatsLowSoldier() public {
        uint highBefore = elo.rankings(p1);
        uint lowBefore = elo.rankings(p2);

        elo.mockUpdateRankings(p1, p2, true);

        uint highAfter = elo.rankings(p1);
        uint lowAfter = elo.rankings(p2);

        // ranking is 400 higher, handicap is 400, so should be 99%
        // therefore, should update by 0.01 * 32 = 0.32e18
        assert(_areWithinX(highAfter, highBefore + 0.32e18, 0.01e18));
        assert(_areWithinX(lowAfter, lowBefore - 0.32e18, 0.01e18));
    }

    function testHighSoldierBeatsLowAgent() public {
        uint highBefore = elo.rankings(p1);
        uint lowBefore = elo.rankings(p2);

        elo.mockUpdateRankings(p1, p2, false);

        uint highAfter = elo.rankings(p1);
        uint lowAfter = elo.rankings(p2);

        // ranking is 400 higher, handicap is 400, so should be 50%
        // therefore, should update by 0.5 * 32 = 16e18
        assert(_areWithinX(highAfter, highBefore + 16e18, 0.01e18));
        assert(_areWithinX(lowAfter, lowBefore - 16e18, 0.01e18));
    }

    function testLowAgentBeatsHighSoldier() public {
        uint highBefore = elo.rankings(p1);
        uint lowBefore = elo.rankings(p2);

        elo.mockUpdateRankings(p2, p1, true);

        uint highAfter = elo.rankings(p1);
        uint lowAfter = elo.rankings(p2);

        // ranking is 400 higher, handicap is 400, so should be 50%
        // therefore, should update by 0.5 * 32 = 16e18
        assert(_areWithinX(highAfter, highBefore - 16e18, 0.01e18));
        assert(_areWithinX(lowAfter, lowBefore + 16e18, 0.01e18));
    }

    function testLowSoldierBeatsHighAgent() public {
        uint highBefore = elo.rankings(p1);
        uint lowBefore = elo.rankings(p2);

        elo.mockUpdateRankings(p2, p1, false);

        uint highAfter = elo.rankings(p1);
        uint lowAfter = elo.rankings(p2);

        // ranking is 400 higher, handicap is 400, so should be 1%
        // therefore, should update by 0.99 * 32 = 31.68e18
        assert(_areWithinX(highAfter, highBefore - 31.68e18, 0.01e18));
        assert(_areWithinX(lowAfter, lowBefore + 31.68e18, 0.01e18));
    }

    function _areWithinX(uint a, uint b, uint x) internal pure returns (bool) {
        return a >= b - x && a <= b + x;
    }
}

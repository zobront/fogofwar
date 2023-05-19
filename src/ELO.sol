// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "solady/utils/FixedPointMathLib.sol";
import "forge-std/Test.sol";

contract ELO is Test {
    using FixedPointMathLib for uint;

    mapping(address => uint) public rankings;
    uint constant WAD = 1e18;
    uint public UPDATE_MULTILPLIER = 32 * WAD;
    uint public AGENT_HANDICAP = 400 * WAD;

    // to abstract this, make this virtual and implement in FoW.sol
    // make final param bytes memory data that can be used
    // and encode the agentWon in there in the implementation
    function _updateRankings(address winner, address loser, bool agentWon) internal {
        uint winnerRanking = rankings[winner];
        uint loserRanking = rankings[loser];

        winnerRanking = agentWon ? winnerRanking + AGENT_HANDICAP : winnerRanking - AGENT_HANDICAP;

        uint winnerExpectedScore = getExpectedScore(winnerRanking, loserRanking);
        uint update = UPDATE_MULTILPLIER.mulWad(WAD - winnerExpectedScore);

        rankings[winner] += update;
        if (loserRanking > update) {
            rankings[loser] -= update;
        } else {
            rankings[loser] = 0;
        }
    }

    function getExpectedScore(uint playerRanking, uint opponentRanking) public pure returns (uint) {
        uint expA = playerRanking.divWad(400 * WAD);
        uint expB = opponentRanking.divWad(400 * WAD);

        uint qa = uint(FixedPointMathLib.powWad(int(10 * WAD), int(expA)));
        uint qb = uint(FixedPointMathLib.powWad(int(10 * WAD), int(expB)));

        return FixedPointMathLib.divWad(qa, qa + qb); // between (0, WAD)
    }

    // remove this or making it onlyOwner when done with testing
    function setRanking(address player, uint ranking) external {
        rankings[player] = ranking;
    }
}

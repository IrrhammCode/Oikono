// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./agents/core/IGameStateReader.sol";

contract MockGame is IGameStateReader {
    function getGameState() external pure returns (
        uint256 totalPlayers,
        uint256 activePlayers,
        uint256 totalEntities,
        uint256[] memory globalStats
    ) {
        return (1000, 500, 200, new uint256[](0));
    }

    function getBalanceMetrics() external pure returns (
        uint256 winRate,
        uint256 averageSessionLength,
        uint256[] memory classDistribution,
        uint256 averageLevel
    ) {
        return (9500, 120, new uint256[](0), 50);
    }

    function getEconomyState() external pure returns (
        uint256 circulatingSupply,
        uint256 totalSupply,
        uint256 totalBurned,
        uint256 velocity,
        uint256 avgRewardPerPlayer
    ) {
        return (8000000, 10000000, 1500, 50000, 100);
    }

    function getPlayerState(address player) external pure returns (
        uint256 level,
        uint256 xp,
        bytes memory position,
        uint256[] memory stats
    ) {
        return (10, 5000, "0x00", new uint256[](0));
    }

    function getRecentEvents(uint256 count) external pure returns (
        bytes[] memory events
    ) {
        return new bytes[](0);
    }

    function triggerAgent(address agent, uint256 gameId, string calldata actionType, bytes calldata data) external {
        (bool success, bytes memory returnData) = agent.call(abi.encodeWithSignature("requestAction(uint256,string,bytes)", gameId, actionType, data));
        if (!success) {
            if (returnData.length > 0) {
                assembly {
                    let returndata_size := mload(returnData)
                    revert(add(32, returnData), returndata_size)
                }
            } else {
                revert("Agent call failed with no reason");
            }
        }
    }
}

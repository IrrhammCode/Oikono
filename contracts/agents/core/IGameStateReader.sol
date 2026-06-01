// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title IGameStateReader
 * @notice Standard interface for OIKONO agent to read game state on-demand
 * @dev Unlike IGameDescriptor (static metadata), this reads LIVE game state.
 *      The agent calls these to build context before making decisions.
 *
 *      Any game implementing this gives the agent full visibility.
 *      Games that don't implement this can still work via events only.
 */
interface IGameStateReader {

    /**
     * @notice Get the current state of a specific player
     * @param player Address of the player
     * @return level Player's current level
     * @return xp Player's current XP
     * @return position Player's position (encoded, game-specific)
     * @return stats Additional stats as key-value pairs
     */
    function getPlayerState(address player) external view returns (
        uint256 level,
        uint256 xp,
        bytes memory position,
        uint256[] memory stats
    );

    /**
     * @notice Get global game state
     * @return totalPlayers Total registered players
     * @return activePlayers Players active in last epoch
     * @return totalEntities Total spawned entities
     * @return globalStats Global stats (total battles, total rewards, etc.)
     */
    function getGameState() external view returns (
        uint256 totalPlayers,
        uint256 activePlayers,
        uint256 totalEntities,
        uint256[] memory globalStats
    );

    /**
     * @notice Get economy state
     * @return circulatingSupply Current circulating token supply
     * @return totalSupply Total token supply
     * @return totalBurned Total tokens burned
     * @return velocity Token transfers in last epoch
     * @return avgRewardPerPlayer Average rewards per active player
     */
    function getEconomyState() external view returns (
        uint256 circulatingSupply,
        uint256 totalSupply,
        uint256 totalBurned,
        uint256 velocity,
        uint256 avgRewardPerPlayer
    );

    /**
     * @notice Get balance/combat metrics
     * @return winRate Overall win rate (basis points)
     * @return avgBattleDuration Average battle duration in blocks
     * @return difficultyDistribution Difficulty distribution histogram
     * @return playerRetention Player retention rate (basis points)
     */
    function getBalanceMetrics() external view returns (
        uint256 winRate,
        uint256 avgBattleDuration,
        uint256[] memory difficultyDistribution,
        uint256 playerRetention
    );

    /**
     * @notice Get recent events for context building
     * @param count Number of recent events to return
     * @return events Array of encoded event data
     */
    function getRecentEvents(uint256 count) external view returns (
        bytes[] memory events
    );
}

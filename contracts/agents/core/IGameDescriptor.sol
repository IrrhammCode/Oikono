// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title IGameDescriptor
 * @notice Standard interface for games to describe themselves to OIKONO Agent
 * @dev Any game that implements this interface can be auto-detected and
 *      intelligently managed by the OIKONO agent without manual configuration.
 *
 *      The agent reads this descriptor to understand:
 *      - What kind of game this is
 *      - What entities exist and their schemas
 *      - What the economy looks like
 *      - What events the game emits
 *      - What the game's goals/metrics are
 */
interface IGameDescriptor {

    // ============ Game Identity ============

    /**
     * @notice Get the game's basic identity
     * @return name Game name
     * @return version Game version string
     * @return gameType Type of game (rpg, strategy, card, puzzle, racing, social)
     */
    function getGameIdentity() external view returns (
        string memory name,
        string memory version,
        string memory gameType
    );

    // ============ Entity Schema ============

    /**
     * @notice Get the types of entities this game has
     * @return entityTypes Array of entity type names (e.g., ["enemy", "npc", "item", "card"])
     * @return entitySchemas Array of JSON schemas for each entity type
     *
     * Example return:
     * entityTypes: ["enemy", "boss"]
     * entitySchemas: [
     *   '{"name":"string","power":"uint256(40-100)","element":"fire|ice|shadow"}',
     *   '{"name":"string","power":"uint256(80-100)","phases":"uint256(1-3)"}'
     * ]
     */
    function getEntitySchema() external view returns (
        string[] memory entityTypes,
        string[] memory entitySchemas
    );

    // ============ Economy Schema ============

    /**
     * @notice Get the game's economy configuration
     * @return hasToken Whether the game has its own token
     * @return tokenAddress Address of the game's ERC-20 token (if any)
     * @return currencies Array of in-game currency names
     * @return sinks Array of token sink descriptions (where tokens are burned/spent)
     * @return sources Array of token source descriptions (where tokens are earned)
     */
    function getEconomySchema() external view returns (
        bool hasToken,
        address tokenAddress,
        string[] memory currencies,
        string[] memory sinks,
        string[] memory sources
    );

    // ============ Metrics Schema ============

    /**
     * @notice What metrics the game tracks for balancing
     * @return metricNames Array of metric names (e.g., ["win_rate", "avg_session_time"])
     * @return metricTargets Array of target values (basis points where applicable)
     * @return metricCurrent Array of current values
     */
    function getMetricsSchema() external view returns (
        string[] memory metricNames,
        uint256[] memory metricTargets,
        uint256[] memory metricCurrent
    );

    // ============ Event Schema ============

    /**
     * @notice Get the events this game emits that the agent should react to
     * @return eventSignatures Array of keccak256 event signatures
     * @return eventNames Array of human-readable event names
     * @return eventActions Array of suggested agent actions per event
     *
     * eventActions values: "spawn", "balance", "economy", "narrative", "ignore"
     */
    function getEventSchema() external view returns (
        bytes32[] memory eventSignatures,
        string[] memory eventNames,
        string[] memory eventActions
    );

    // ============ Goals ============

    /**
     * @notice What the game is trying to optimize
     * @return goals Array of goal descriptions
     * @return goalWeights Importance of each goal (basis points, sum = 10000)
     *
     * Example:
     * goals: ["player_retention", "token_stability", "fun_factor"]
     * goalWeights: [4000, 3000, 3000]
     */
    function getGoals() external view returns (
        string[] memory goals,
        uint256[] memory goalWeights
    );

    // ============ Agent Permissions ============

    /**
     * @notice What actions the agent is allowed to take
     * @return canSpawn Whether agent can spawn entities
     * @return canAdjustEconomy Whether agent can adjust economy params
     * @return canGenerateNarrative Whether agent can generate quests/dialogue
     * @return canAdjustDifficulty Whether agent can adjust difficulty
     * @return maxAdjustmentPerEpoch Max % change per epoch (basis points)
     */
    function getAgentPermissions() external view returns (
        bool canSpawn,
        bool canAdjustEconomy,
        bool canGenerateNarrative,
        bool canAdjustDifficulty,
        uint256 maxAdjustmentPerEpoch
    );
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title AgentTypes
 * @notice Common types and interfaces for OIKONO Agent Kit
 * @dev Shared data structures used across all agent contracts
 */
library AgentTypes {
    // Agent action types
    enum ActionType {
        SPAWN,          // Generate entity (enemy, NPC, item)
        MODIFY_STATE,   // Modify game state
        ECONOMIC,       // Economy adjustment
        NARRATIVE,      // Quest/dialogue generation
        BALANCE,        // Difficulty balancing
        CUSTOM          // Custom plugin action
    }

    // Request status
    enum RequestStatus {
        PENDING,
        PROCESSING,
        COMPLETED,
        FAILED
    }

    // Agent configuration
    struct AgentConfig {
        uint256 agentId;
        string name;
        string description;
        ActionType[] supportedActions;
        address pluginAddress;
        uint256 maxDailyExecutions;
        uint256 minDeposit;
        bool isActive;
    }

    // Action request
    struct ActionRequest {
        uint256 requestId;
        address requester;
        ActionType actionType;
        bytes params;
        uint256 deposit;
        uint256 timestamp;
        RequestStatus status;
    }

    // Action result
    struct ActionResult {
        uint256 requestId;
        bool success;
        bytes data;
        string errorMessage;
        uint256 executionTime;
    }

    // Game event data (for reactivity)
    struct GameEvent {
        address emitter;
        string eventName;
        address player;
        bytes data;
        uint256 blockNumber;
        uint256 timestamp;
    }

    // Agent execution context
    struct ExecutionContext {
        address player;
        uint256 playerLevel;
        uint256 playerXP;
        uint256 gameState;    // Hash of current game state
        bytes extraData;      // Game-specific extra data
    }

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../core/AgentTypes.sol";
import "../core/IAgentPlugin.sol";

/**
 * @title BalancePlugin
 * @notice Universal plugin for AI-driven game balance
 * @dev Auto-balances difficulty, rewards, drop rates based on player behavior
 *      Works for any game with measurable difficulty metrics
 *
 * @dev Plugin for OIKONO Agent Kit
 */
contract BalancePlugin is Ownable, IAgentPlugin {
    using AgentTypes for AgentTypes.ExecutionContext;

    // ============ Types ============
    struct BalanceConfig {
        uint256 targetWinRate;          // Target win rate (basis points, 6500 = 65%)
        uint256 targetCompletionTime;   // Target avg completion time (seconds)
        uint256 difficultyFloor;        // Minimum difficulty (1-100)
        uint256 difficultyCeiling;      // Maximum difficulty (1-100)
        uint256 adjustmentInterval;     // Epochs between adjustments
    }

    struct BalanceMetrics {
        uint256 totalBattles;
        uint256 totalWins;
        uint256 avgCompletionTime;
        uint256 currentDifficulty;
        uint256 playerCount;
        uint256 lastUpdate;
    }

    struct DifficultyCurve {
        uint256 baseDifficulty;
        uint256 scalingFactor;   // Basis points per player level
        uint256 zoneMultiplier;  // Zone-based multiplier
        bool adaptiveScaling;    // Adjust based on win rate
    }

    // State
    mapping(address => BalanceConfig) public gameConfigs;
    mapping(address => BalanceMetrics) public gameMetrics;
    mapping(address => DifficultyCurve) public difficultyCurves;
    mapping(address => uint256[]) public epochMetrics;

    // ============ Events ============
    event BalanceConfigured(address indexed game, uint256 targetWinRate);
    event DifficultyAdjusted(
        address indexed game,
        uint256 oldDifficulty,
        uint256 newDifficulty,
        string reason
    );
    event MetricsRecorded(address indexed game, uint256 winRate, uint256 playerCount);

    constructor() Ownable(msg.sender) {}

    // ============ Configuration ============

    /**
     * @notice Configure balance settings for a game
     */
    function configureGame(
        uint256 targetWinRate,
        uint256 difficultyFloor,
        uint256 difficultyCeiling
    ) external {
        require(gameConfigs[msg.sender].targetWinRate == 0, "Already configured");

        gameConfigs[msg.sender] = BalanceConfig({
            targetWinRate: targetWinRate,
            targetCompletionTime: 300,    // 5 minutes default
            difficultyFloor: difficultyFloor,
            difficultyCeiling: difficultyCeiling,
            adjustmentInterval: 10        // Every 10 epochs
        });

        difficultyCurves[msg.sender] = DifficultyCurve({
            baseDifficulty: 50,
            scalingFactor: 500,           // +5% per level
            zoneMultiplier: 10000,        // 1.0x base
            adaptiveScaling: true
        });

        emit BalanceConfigured(msg.sender, targetWinRate);
    }

    /**
     * @notice Update difficulty curve
     */
    function updateDifficultyCurve(
        uint256 baseDifficulty,
        uint256 scalingFactor,
        bool adaptiveScaling
    ) external {
        require(msg.sender == owner() || difficultyCurves[msg.sender].baseDifficulty > 0, "Not authorized");

        difficultyCurves[msg.sender] = DifficultyCurve({
            baseDifficulty: baseDifficulty,
            scalingFactor: scalingFactor,
            zoneMultiplier: difficultyCurves[msg.sender].zoneMultiplier,
            adaptiveScaling: adaptiveScaling
        });
    }

    // ============ Plugin Interface ============

    /**
     * @notice Build LLM prompt for balance analysis
     */
    function getPrompt(
        AgentTypes.ActionType actionType,
        bytes calldata params,
        AgentTypes.ExecutionContext calldata context
    ) external view override returns (string memory) {
        (uint256 winRate, uint256 avgTime, uint256 playerCount) =
            abi.decode(params, (uint256, uint256, uint256));

        BalanceConfig storage config = gameConfigs[msg.sender];

        return string(abi.encodePacked(
            "Analyze game balance. Current win rate: ", _toString(winRate / 100), "%",
            " (target: ", _toString(config.targetWinRate / 100), "%).",
            " Avg completion: ", _toString(avgTime), "s (target: ", _toString(config.targetCompletionTime), "s).",
            " Active players: ", _toString(playerCount), ".",
            " Recommend difficulty adjustment (", _toString(config.difficultyFloor), "-", _toString(config.difficultyCeiling), ").",
            " Return JSON: {\"difficulty\":...,\"reason\":\"...\",\"rewardMultiplier\":...}"
        ));
    }

    /**
     * @notice Execute balance adjustment
     */
    function execute(
        AgentTypes.ActionType actionType,
        bytes calldata params,
        AgentTypes.ExecutionContext calldata context
    ) external override returns (bytes memory) {
        BalanceConfig storage config = gameConfigs[msg.sender];
        require(config.targetWinRate > 0, "Not configured");

        // Parse metrics
        (uint256 winRate, uint256 avgTime, uint256 playerCount) =
            abi.decode(params, (uint256, uint256, uint256));

        // Update metrics
        BalanceMetrics storage metrics = gameMetrics[msg.sender];
        metrics.avgCompletionTime = avgTime;
        metrics.playerCount = playerCount;
        metrics.lastUpdate = block.timestamp;

        // Calculate new difficulty
        DifficultyCurve storage curve = difficultyCurves[msg.sender];
        uint256 oldDifficulty = curve.baseDifficulty;
        uint256 newDifficulty = oldDifficulty;

        if (curve.adaptiveScaling) {
            newDifficulty = _calculateAdaptiveDifficulty(msg.sender, winRate, avgTime);
        } else {
            newDifficulty = _calculateStaticDifficulty(context.playerLevel, curve);
        }

        // Apply bounds
        if (newDifficulty < config.difficultyFloor) newDifficulty = config.difficultyFloor;
        if (newDifficulty > config.difficultyCeiling) newDifficulty = config.difficultyCeiling;

        // Update curve base
        curve.baseDifficulty = newDifficulty;

        string memory reason;
        if (winRate > config.targetWinRate + 500) {
            reason = "Win rate too high - increasing difficulty";
        } else if (winRate < config.targetWinRate - 500) {
            reason = "Win rate too low - decreasing difficulty";
        } else if (avgTime > config.targetCompletionTime * 12 / 10) {
            reason = "Completion time too long - decreasing difficulty";
        } else {
            reason = "Within target range - minor adjustment";
        }

        emit DifficultyAdjusted(msg.sender, oldDifficulty, newDifficulty, reason);
        emit MetricsRecorded(msg.sender, winRate, playerCount);

        return abi.encode(newDifficulty, oldDifficulty, reason);
    }

    /**
     * @notice Parse AI response
     */
    function parseResponse(
        bytes calldata aiResponse
    ) external pure override returns (bytes memory) {
        return aiResponse;
    }

    // ============ Difficulty Calculations ============

    function _calculateAdaptiveDifficulty(
        address game,
        uint256 winRate,
        uint256 avgTime
    ) internal view returns (uint256) {
        BalanceConfig storage config = gameConfigs[game];
        DifficultyCurve storage curve = difficultyCurves[game];
        uint256 base = curve.baseDifficulty;

        // Adjust based on win rate deviation from target
        int256 winRateDiff = int256(winRate) - int256(config.targetWinRate);

        // Higher win rate → increase difficulty
        // Each 5% deviation = 1 difficulty point
        int256 adjustment = winRateDiff / 500;

        // Also consider completion time
        if (avgTime > config.targetCompletionTime) {
            adjustment -= 1;  // Too slow → easier
        } else if (avgTime < config.targetCompletionTime * 7 / 10) {
            adjustment += 1;  // Too fast → harder
        }

        int256 newDifficulty = int256(base) + adjustment;
        if (newDifficulty < 1) return 1;
        return uint256(newDifficulty);
    }

    function _calculateStaticDifficulty(
        uint256 playerLevel,
        DifficultyCurve storage curve
    ) internal view returns (uint256) {
        uint256 scaled = curve.baseDifficulty + (playerLevel * curve.scalingFactor / 10000);
        return scaled * curve.zoneMultiplier / 10000;
    }

    // ============ View Functions ============

    function getDifficulty(address game) external view returns (uint256) {
        return difficultyCurves[game].baseDifficulty;
    }

    function getMetrics(address game) external view returns (
        uint256 totalBattles,
        uint256 totalWins,
        uint256 winRate,
        uint256 avgCompletionTime,
        uint256 playerCount
    ) {
        BalanceMetrics storage m = gameMetrics[game];
        winRate = m.totalBattles > 0 ? (m.totalWins * 10000) / m.totalBattles : 0;
        return (m.totalBattles, m.totalWins, winRate, m.avgCompletionTime, m.playerCount);
    }

    /**
     * @notice Calculate difficulty for a specific player
     */
    function calculatePlayerDifficulty(
        address game,
        uint256 playerLevel,
        uint256 zone
    ) external view returns (uint256) {
        DifficultyCurve storage curve = difficultyCurves[game];
        uint256 base = _calculateStaticDifficulty(playerLevel, curve);
        return (base * zone) / 10;  // Zone 1-10 scales difficulty
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title GameKnowledgeBase
 * @notice Cross-game knowledge sharing for OIKONO Agent
 * @dev Stores aggregated knowledge from all games the agent manages.
 *      When a new game registers, the agent can bootstrap it with
 *      knowledge learned from similar games.
 *
 *      Example: If the agent has managed 10 RPG games and learned that
 *      65% win rate is optimal, a new RPG game gets that knowledge
 *      immediately — no cold start.
 */
contract GameKnowledgeBase is Ownable {

    // ============ Types ============

    struct GameTypeKnowledge {
        uint256 gameCount;              // How many games of this type
        uint256 optimalWinRate;         // Learned optimal (bps)
        uint256 optimalSessionTime;     // Learned optimal (seconds)
        uint256 optimalRewardRate;      // Learned optimal (bps)
        uint256 churnThreshold;         // When players start leaving (bps)
        uint256 difficultySweetSpot;    // Best difficulty level (1-100)
        uint256 lastUpdated;
        uint256 confidence;             // How reliable this knowledge is
    }

    struct EntityTemplate {
        string name;
        string gameType;
        uint256 minPower;
        uint256 maxPower;
        string[] attributes;
        uint256 successRate;            // How well this entity works
        uint256 usageCount;
    }

    struct EconomyTemplate {
        string gameType;
        uint256 burnRate;
        uint256 rewardMultiplier;
        uint256 emissionRate;
        uint256 successRate;
        uint256 usageCount;
    }

    // ============ State ============

    // Knowledge per game type
    mapping(string => GameTypeKnowledge) public typeKnowledge;

    // Entity templates (what works for each game type)
    mapping(string => EntityTemplate[]) public entityTemplates;

    // Economy templates
    mapping(string => EconomyTemplate[]) public economyTemplates;

    // Game type registry
    string[] public registeredTypes;
    mapping(string => bool) public typeRegistered;

    // Stats
    uint256 public totalGamesManaged;
    uint256 public totalKnowledgeUpdates;

    // ============ Events ============

    event TypeRegistered(string gameType, uint256 initialConfidence);
    event KnowledgeUpdated(string gameType, string field, uint256 oldValue, uint256 newValue);
    event EntityTemplateAdded(string gameType, string entityName, uint256 successRate);
    event EconomyTemplateAdded(string gameType, uint256 burnRate, uint256 rewardMult);
    event BootstrapGenerated(string gameType, uint256 recommendations);

    // ============ Constructor ============

    constructor(address initialOwner) Ownable(initialOwner) {
        // Bootstrap with common game type knowledge
        _bootstrapDefaults();
    }

    // ============ Bootstrap ============

    /**
     * @notice Bootstrap with default knowledge for common game types
     */
    function _bootstrapDefaults() internal {
        // RPG defaults (from industry data)
        _registerType("rpg", GameTypeKnowledge({
            gameCount: 0,
            optimalWinRate: 6500,        // 65% — challenging but fair
            optimalSessionTime: 1800,    // 30 minutes
            optimalRewardRate: 5000,     // 50% of effort rewarded
            churnThreshold: 3000,        // Churn if win rate < 30%
            difficultySweetSpot: 55,
            lastUpdated: block.timestamp,
            confidence: 7000             // Moderate confidence from industry data
        }));

        // Strategy defaults
        _registerType("strategy", GameTypeKnowledge({
            gameCount: 0,
            optimalWinRate: 5500,        // 55% — more competitive
            optimalSessionTime: 2400,    // 40 minutes
            optimalRewardRate: 4000,     // 40% — more grindy
            churnThreshold: 2500,        // More forgiving
            difficultySweetSpot: 60,
            lastUpdated: block.timestamp,
            confidence: 6000
        }));

        // Card game defaults
        _registerType("card", GameTypeKnowledge({
            gameCount: 0,
            optimalWinRate: 5000,        // 50% — pure skill
            optimalSessionTime: 900,     // 15 minutes
            optimalRewardRate: 6000,     // 60% — generous
            churnThreshold: 3500,
            difficultySweetSpot: 50,
            lastUpdated: block.timestamp,
            confidence: 6500
        }));

        // Default entity templates for RPG
        _addEntityTemplate("rpg", EntityTemplate({
            name: "Shadow Wraith",
            gameType: "rpg",
            minPower: 40,
            maxPower: 80,
            attributes: _toArray6("fire", "ice", "shadow", "lightning", "void", "earth"),
            successRate: 7500,
            usageCount: 0
        }));

        _addEntityTemplate("rpg", EntityTemplate({
            name: "Crimson Basilisk",
            gameType: "rpg",
            minPower: 60,
            maxPower: 100,
            attributes: _toArray6("fire", "poison", "shadow", "lightning", "void", "earth"),
            successRate: 6000,
            usageCount: 0
        }));
    }

    // ============ Knowledge Management ============

    /**
     * @notice Update knowledge based on game performance
     * @dev Called by OikonoAgent when it learns something new
     */
    function updateKnowledge(
        string calldata gameType,
        string calldata field,
        uint256 newValue
    ) external {
        GameTypeKnowledge storage kb = typeKnowledge[gameType];
        require(kb.confidence > 0, "Unknown game type");

        uint256 oldValue;

        if (keccak256(bytes(field)) == keccak256(bytes("winRate"))) {
            oldValue = kb.optimalWinRate;
            // Weighted average: old * 0.8 + new * 0.2
            kb.optimalWinRate = (oldValue * 8000 + newValue * 2000) / 10000;
        } else if (keccak256(bytes(field)) == keccak256(bytes("sessionTime"))) {
            oldValue = kb.optimalSessionTime;
            kb.optimalSessionTime = (oldValue * 8000 + newValue * 2000) / 10000;
        } else if (keccak256(bytes(field)) == keccak256(bytes("rewardRate"))) {
            oldValue = kb.optimalRewardRate;
            kb.optimalRewardRate = (oldValue * 8000 + newValue * 2000) / 10000;
        } else if (keccak256(bytes(field)) == keccak256(bytes("difficulty"))) {
            oldValue = kb.difficultySweetSpot;
            kb.difficultySweetSpot = (oldValue * 8000 + newValue * 2000) / 10000;
        }

        kb.lastUpdated = block.timestamp;

        // Increase confidence with more data
        if (kb.confidence < 9500) {
            kb.confidence += 100;
        }

        totalKnowledgeUpdates++;
        emit KnowledgeUpdated(gameType, field, oldValue, newValue);
    }

    /**
     * @notice Record a new game of this type
     */
    function recordGame(string calldata gameType) external {
        GameTypeKnowledge storage kb = typeKnowledge[gameType];
        require(kb.confidence > 0, "Unknown game type");
        kb.gameCount++;
        totalGamesManaged++;
    }

    // ============ Bootstrap for New Games ============

    /**
     * @notice Generate bootstrap recommendations for a new game
     * @dev Returns the learned optimal settings for this game type
     */
    function getBootstrap(string calldata gameType) external view returns (
        uint256 recommendedWinRate,
        uint256 recommendedDifficulty,
        uint256 recommendedBurnRate,
        uint256 recommendedRewardMult,
        uint256 confidence
    ) {
        GameTypeKnowledge storage kb = typeKnowledge[gameType];

        if (kb.confidence == 0) {
            // Unknown type — return safe defaults
            return (6500, 50, 4000, 10000, 0);
        }

        return (
            kb.optimalWinRate,
            kb.difficultySweetSpot,
            kb.optimalRewardRate,
            10000, // Default 1.0x multiplier
            kb.confidence
        );
    }

    /**
     * @notice Get entity templates for a game type
     */
    function getEntityTemplates(string calldata gameType) external view returns (
        EntityTemplate[] memory
    ) {
        return entityTemplates[gameType];
    }

    /**
     * @notice Get the best entity template for a given player level
     */
    function getBestEntityTemplate(
        string calldata gameType,
        uint256 playerLevel
    ) external view returns (
        string memory name,
        uint256 minPower,
        uint256 maxPower,
        string[] memory attributes
    ) {
        EntityTemplate[] storage templates = entityTemplates[gameType];
        require(templates.length > 0, "No templates");

        // Find template with highest success rate that matches level
        uint256 bestIdx = 0;
        uint256 bestScore = 0;

        for (uint256 i = 0; i < templates.length; i++) {
            uint256 levelScaledMax = templates[i].maxPower;
            if (playerLevel * 3 + 40 <= levelScaledMax) {
                if (templates[i].successRate > bestScore) {
                    bestScore = templates[i].successRate;
                    bestIdx = i;
                }
            }
        }

        EntityTemplate storage best = templates[bestIdx];
        return (best.name, best.minPower, best.maxPower, best.attributes);
    }

    // ============ Registration ============

    function _registerType(string memory gameType, GameTypeKnowledge memory kb) internal {
        typeKnowledge[gameType] = kb;
        if (!typeRegistered[gameType]) {
            registeredTypes.push(gameType);
            typeRegistered[gameType] = true;
        }
        emit TypeRegistered(gameType, kb.confidence);
    }

    function _addEntityTemplate(string memory gameType, EntityTemplate memory template) internal {
        entityTemplates[gameType].push(template);
        emit EntityTemplateAdded(gameType, template.name, template.successRate);
    }

    // ============ View Functions ============

    function getRegisteredTypes() external view returns (string[] memory) {
        return registeredTypes;
    }

    function getTypeKnowledge(string calldata gameType) external view returns (
        uint256 gameCount,
        uint256 optimalWinRate,
        uint256 optimalSessionTime,
        uint256 difficultySweetSpot,
        uint256 confidence
    ) {
        GameTypeKnowledge storage kb = typeKnowledge[gameType];
        return (
            kb.gameCount,
            kb.optimalWinRate,
            kb.optimalSessionTime,
            kb.difficultySweetSpot,
            kb.confidence
        );
    }

    // ============ Helpers ============

    function _toArray6(
        string memory a, string memory b, string memory c,
        string memory d, string memory e, string memory f
    ) internal pure returns (string[] memory) {
        string[] memory arr = new string[](6);
        arr[0] = a; arr[1] = b; arr[2] = c;
        arr[3] = d; arr[4] = e; arr[5] = f;
        return arr;
    }
}

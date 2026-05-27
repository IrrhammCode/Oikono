// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../core/AgentTypes.sol";
import "../core/IAgentPlugin.sol";

/**
 * @title SpawnPlugin
 * @notice Universal plugin for spawning game entities (enemies, NPCs, items)
 * @dev Configurable for any game type:
 *      - RPG: Spawn enemies with stats
 *      - Card Game: Generate cards
 *      - Strategy: Create units
 *      - Puzzle: Generate challenges
 *
 * @dev Plugin for OIKONO Agent Kit - plug into any game
 */
contract SpawnPlugin is Ownable, IAgentPlugin {
    using AgentTypes for AgentTypes.ExecutionContext;

    // ============ Configuration ============
    struct SpawnConfig {
        string entityType;        // "enemy", "npc", "item", "card", "unit"
        string[12] namePool;      // Pool of possible names
        uint256 minPower;         // Minimum power/stat value
        uint256 maxPower;         // Maximum power/stat value
        string[6] attributePool;  // Attributes (elements, types, etc.)
        bool scaleWithPlayer;     // Scale with player level
        uint256 baseScaleRate;    // Base scaling rate (basis points)
    }

    // Game-specific configs
    mapping(address => SpawnConfig) public gameConfigs;

    // Entity registry (for querying)
    struct SpawnedEntity {
        address game;
        address spawner;
        string entityType;
        string name;
        string attribute;
        uint256 power;
        uint256 timestamp;
        bytes metadata;
    }

    mapping(uint256 => SpawnedEntity) public entities;
    uint256 public totalSpawned;

    // ============ Events ============
    event ConfigUpdated(address indexed game, string entityType);
    event EntitySpawned(
        uint256 indexed entityId,
        address indexed game,
        address indexed spawner,
        string name,
        uint256 power
    );

    // ============ Name Pools ============
    string[12] public defaultEnemyNames = [
        "Shadow Wraith", "Crimson Basilisk", "Void Sentinel",
        "Nether Drake", "Phantom Knight", "Storm Colossus",
        "Obsidian Golem", "Spectral Warden", "Frost Lich",
        "Ember Wyrm", "Dark Harbinger", "Chaos Oracle"
    ];

    string[6] public defaultAttributes = [
        "fire", "ice", "shadow", "lightning", "void", "earth"
    ];

    string[6] public defaultCardTypes = [
        "attack", "defense", "spell", "trap", "buff", "debuff"
    ];

    constructor() Ownable(msg.sender) {}

    // ============ Configuration ============

    /**
     * @notice Configure spawn settings for a game
     * @dev Game developers customize this for their game type
     */
    function configureGame(
        address game,
        string calldata entityType,
        string[12] calldata namePool,
        uint256 minPower,
        uint256 maxPower,
        string[6] calldata attributePool,
        bool scaleWithPlayer,
        uint256 baseScaleRate
    ) external {
        require(msg.sender == game || msg.sender == owner(), "Not authorized");

        gameConfigs[game] = SpawnConfig({
            entityType: entityType,
            namePool: namePool,
            minPower: minPower,
            maxPower: maxPower,
            attributePool: attributePool,
            scaleWithPlayer: scaleWithPlayer,
            baseScaleRate: baseScaleRate
        });

        emit ConfigUpdated(game, entityType);
    }

    /**
     * @notice Quick configure for common game types
     */
    function quickConfigure(
        address game,
        string calldata gameType  // "rpg", "card", "strategy"
    ) external {
        string[12] memory names;
        string[6] memory attrs;
        uint256 minP;
        uint256 maxP;

        if (keccak256(bytes(gameType)) == keccak256(bytes("rpg"))) {
            names = defaultEnemyNames;
            attrs = defaultAttributes;
            minP = 40;
            maxP = 100;
        } else if (keccak256(bytes(gameType)) == keccak256(bytes("card"))) {
            names = ["Attack Card", "Defense Card", "Magic Card", "Trap Card",
                     "Heal Card", "Buff Card", "Debuff Card", "Summon Card",
                     "Counter Card", "Ultimate Card", "Rare Card", "Epic Card"];
            attrs = defaultCardTypes;
            minP = 1;
            maxP = 10;
        } else {
            names = defaultEnemyNames;
            attrs = defaultAttributes;
            minP = 1;
            maxP = 100;
        }

        gameConfigs[game] = SpawnConfig({
            entityType: gameType,
            namePool: names,
            minPower: minP,
            maxPower: maxP,
            attributePool: attrs,
            scaleWithPlayer: true,
            baseScaleRate: 10000 // 1.0x base
        });

        emit ConfigUpdated(game, gameType);
    }

    // ============ Plugin Interface ============

    /**
     * @notice Build LLM prompt for entity generation
     * @dev Called by AgentRuntime to generate prompt
     */
    function getPrompt(
        AgentTypes.ActionType actionType,
        bytes calldata params,
        AgentTypes.ExecutionContext calldata context
    ) external pure override returns (string memory) {
        // Parse params: player coordinates, zone, etc.
        (uint256 x, uint256 y, uint256 zone) = abi.decode(params, (uint256, uint256, uint256));

        return string(abi.encodePacked(
            "Generate a game entity for player at level ", _toString(context.playerLevel),
            " with ", _toString(context.playerXP), " XP,",
            " at position (", _toString(x), ", ", _toString(y), ") in zone ", _toString(zone), ".",
            " Return JSON: {\"name\":\"...\",\"class\":\"...\",\"element\":\"...\",",
            "\"power\":40-100,\"threat_level\":1-10}"
        ));
    }

    /**
     * @notice Execute spawn action
     * @dev Called by AgentRuntime after LLM consensus
     */
    function execute(
        AgentTypes.ActionType actionType,
        bytes calldata params,
        AgentTypes.ExecutionContext calldata context
    ) external override returns (bytes memory) {
        SpawnConfig storage config = gameConfigs[msg.sender];
        require(bytes(config.entityType).length > 0, "Game not configured");

        // Parse params
        (uint256 x, uint256 y, uint256 zone) = abi.decode(params, (uint256, uint256, uint256));

        // Generate deterministic entity
        bytes32 seed = keccak256(abi.encodePacked(
            blockhash(block.number - 1),
            msg.sender,
            context.player,
            x, y, zone,
            totalSpawned
        ));

        uint256 seedNum = uint256(seed);

        // Select from pools
        string memory name = config.namePool[seedNum % 12];
        string memory attribute = config.attributePool[(seedNum / 12) % 6];

        // Calculate power
        uint256 basePower = config.minPower + (seedNum % (config.maxPower - config.minPower + 1));

        // Scale with player level if configured
        if (config.scaleWithPlayer) {
            uint256 scaleFactor = config.baseScaleRate + (context.playerLevel * 500);
            basePower = (basePower * scaleFactor) / 10000;
            if (basePower > config.maxPower) basePower = config.maxPower;
            if (basePower < config.minPower) basePower = config.minPower;
        }

        // Store entity
        uint256 entityId = totalSpawned++;
        entities[entityId] = SpawnedEntity({
            game: msg.sender,
            spawner: context.player,
            entityType: config.entityType,
            name: name,
            attribute: attribute,
            power: basePower,
            timestamp: block.timestamp,
            metadata: params
        });

        emit EntitySpawned(entityId, msg.sender, context.player, name, basePower);

        return abi.encode(entityId, name, attribute, basePower);
    }

    /**
     * @notice Parse AI response into entity data
     * @dev Converts LLM JSON output to structured data
     */
    function parseResponse(
        bytes calldata aiResponse
    ) external pure override returns (bytes memory) {
        // In production: parse JSON response
        // For now: return as-is
        return aiResponse;
    }

    // ============ View Functions ============

    /**
     * @notice Get spawned entity details
     */
    function getEntity(uint256 entityId) external view returns (
        address game,
        address spawner,
        string memory entityType,
        string memory name,
        string memory attribute,
        uint256 power,
        uint256 timestamp
    ) {
        SpawnedEntity memory e = entities[entityId];
        return (e.game, e.spawner, e.entityType, e.name, e.attribute, e.power, e.timestamp);
    }

    /**
     * @notice Get total entities spawned for a game
     */
    function getGameStats(address game) external view returns (uint256 total) {
        // In production: track per-game stats
        return totalSpawned;
    }

    // ============ Helper ============

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

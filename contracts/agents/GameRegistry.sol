// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./OikonoAgent.sol";
import "./AgentMemory.sol";
import "./GameKnowledgeBase.sol";

/**
 * @title GameRegistry
 * @notice Central registry for games using Oikono Agent
 * @dev Flexible registration - any game type, custom config, metadata
 */
contract GameRegistry is Ownable {

    // ============ Types ============

    struct Game {
        uint256 gameId;
        address gameAddress;
        address owner;
        string name;
        string gameType;
        string description;
        string metadata;            // JSON string for extra data (website, tags, etc)
        bool isActive;
        bool isVerified;
        uint256 registeredAt;
        uint256 lastActivity;
        uint256 totalEvents;
        uint256 totalActions;
    }

    struct AgentConfig {
        bool canSpawn;              // Allow agent to spawn entities
        bool canAdjustEconomy;      // Allow agent to adjust economy
        bool canGenerateNarrative;  // Allow agent to generate narrative
        bool canAdjustDifficulty;   // Allow agent to adjust difficulty
        uint256 maxChangePerEpoch;  // Max % change per epoch (0-10000 bps)
        uint256 epochLength;        // Blocks per epoch
    }

    struct GameStats {
        uint256 totalPlayers;
        uint256 activePlayers;
        uint256 winRate;
        uint256 economyHealth;
        uint256 agentDecisions;
        uint256 agentSuccessRate;
    }

    // ============ State ============

    mapping(uint256 => Game) public games;
    mapping(uint256 => AgentConfig) public gameConfigs;
    mapping(uint256 => GameStats) public gameStats;
    mapping(address => uint256) public gameByAddress;
    mapping(address => uint256[]) public gamesByOwner;
    uint256 public nextGameId;

    // Track game types (any string allowed)
    mapping(string => uint256) public gameTypeCount;
    string[] public registeredGameTypes;

    // ============ Events ============

    event GameRegistered(
        uint256 indexed gameId,
        address indexed gameAddress,
        address indexed owner,
        string name,
        string gameType
    );

    event GameActivated(uint256 indexed gameId);
    event GameDeactivated(uint256 indexed gameId);
    event GameVerified(uint256 indexed gameId);
    event GameConfigUpdated(uint256 indexed gameId);
    event GameMetadataUpdated(uint256 indexed gameId);

    // ============ Constructor ============

    constructor(
        address _agent,
        address _agentMemory,
        address _knowledgeBase
    ) Ownable(msg.sender) {}

    // ============ Registration ============

    /**
     * @notice Register a new game - FLEXIBLE
     * @param name Game name
     * @param gameType Any type: "rpg", "fps", "moba", "puzzle", etc.
     * @param description Short description
     * @param gameAddress Address of game contract (zero for off-chain)
     * @param metadata JSON string: {"website":"...","tags":["tag1","tag2"]}
     * @param config Agent configuration for this game
     */
    function registerGame(
        string calldata name,
        string calldata gameType,
        string calldata description,
        address gameAddress,
        string calldata metadata,
        AgentConfig calldata config
    ) external returns (uint256 gameId) {
        require(bytes(name).length > 0, "Name required");
        require(bytes(gameType).length > 0, "Type required");

        if (gameAddress != address(0)) {
            require(gameByAddress[gameAddress] == 0, "Already registered");
        }

        gameId = nextGameId++;

        games[gameId] = Game({
            gameId: gameId,
            gameAddress: gameAddress,
            owner: msg.sender,
            name: name,
            gameType: gameType,
            description: description,
            metadata: metadata,
            isActive: true,
            isVerified: false,
            registeredAt: block.timestamp,
            lastActivity: block.timestamp,
            totalEvents: 0,
            totalActions: 0
        });

        gameConfigs[gameId] = config;

        if (gameAddress != address(0)) {
            gameByAddress[gameAddress] = gameId;
        }

        gamesByOwner[msg.sender].push(gameId);

        // Track game type
        if (gameTypeCount[gameType] == 0) {
            registeredGameTypes.push(gameType);
        }
        gameTypeCount[gameType]++;

        // Try to record in knowledge base
        try GameKnowledgeBase(_getKnowledgeBase()).recordGame(gameType) {} catch {}

        emit GameRegistered(gameId, gameAddress, msg.sender, name, gameType);
    }

    /**
     * @notice Simplified registration (uses default config)
     */
    function registerGameSimple(
        string calldata name,
        string calldata gameType,
        string calldata description,
        address gameAddress
    ) external returns (uint256 gameId) {
        AgentConfig memory defaultConfig = AgentConfig({
            canSpawn: true,
            canAdjustEconomy: true,
            canGenerateNarrative: true,
            canAdjustDifficulty: true,
            maxChangePerEpoch: 2000,  // 20%
            epochLength: 1000
        });

        // Direct implementation (avoid external call to this.registerGame)
        require(bytes(name).length > 0, "Name required");
        require(bytes(gameType).length > 0, "Type required");

        if (gameAddress != address(0)) {
            require(gameByAddress[gameAddress] == 0, "Already registered");
        }

        gameId = nextGameId++;

        games[gameId] = Game({
            gameId: gameId,
            gameAddress: gameAddress,
            owner: msg.sender,
            name: name,
            gameType: gameType,
            description: description,
            metadata: "",
            isActive: true,
            isVerified: false,
            registeredAt: block.timestamp,
            lastActivity: block.timestamp,
            totalEvents: 0,
            totalActions: 0
        });

        gameConfigs[gameId] = defaultConfig;

        if (gameAddress != address(0)) {
            gameByAddress[gameAddress] = gameId;
        }

        gamesByOwner[msg.sender].push(gameId);

        // Track game type
        if (gameTypeCount[gameType] == 0) {
            registeredGameTypes.push(gameType);
        }
        gameTypeCount[gameType]++;

        emit GameRegistered(gameId, gameAddress, msg.sender, name, gameType);
    }

    // ============ Game Management ============

    function deactivateGame(uint256 gameId) external {
        require(games[gameId].owner == msg.sender, "Not owner");
        games[gameId].isActive = false;
        emit GameDeactivated(gameId);
    }

    function activateGame(uint256 gameId) external {
        require(games[gameId].owner == msg.sender, "Not owner");
        games[gameId].isActive = true;
        emit GameActivated(gameId);
    }

    function updateGame(
        uint256 gameId,
        string calldata description,
        string calldata metadata,
        address newGameAddress
    ) external {
        require(games[gameId].owner == msg.sender, "Not owner");

        if (bytes(description).length > 0) {
            games[gameId].description = description;
        }

        if (bytes(metadata).length > 0) {
            games[gameId].metadata = metadata;
            emit GameMetadataUpdated(gameId);
        }

        if (newGameAddress != address(0)) {
            if (games[gameId].gameAddress != address(0)) {
                delete gameByAddress[games[gameId].gameAddress];
            }
            games[gameId].gameAddress = newGameAddress;
            gameByAddress[newGameAddress] = gameId;
        }
    }

    /**
     * @notice Update agent configuration for game
     */
    function updateConfig(uint256 gameId, AgentConfig calldata config) external {
        require(games[gameId].owner == msg.sender, "Not owner");
        require(config.maxChangePerEpoch <= 10000, "Max change too high");

        gameConfigs[gameId] = config;
        emit GameConfigUpdated(gameId);
    }

    // ============ Activity Tracking ============

    function recordEvent(uint256 gameId) external {
        require(games[gameId].isActive, "Game not active");
        games[gameId].totalEvents++;
        games[gameId].lastActivity = block.timestamp;
    }

    function recordAction(uint256 gameId, bool success) external {
        require(games[gameId].isActive, "Game not active");
        games[gameId].totalActions++;
        games[gameId].lastActivity = block.timestamp;
    }

    function updateStats(
        uint256 gameId,
        uint256 totalPlayers,
        uint256 activePlayers,
        uint256 winRate,
        uint256 economyHealth
    ) external {
        gameStats[gameId] = GameStats({
            totalPlayers: totalPlayers,
            activePlayers: activePlayers,
            winRate: winRate,
            economyHealth: economyHealth,
            agentDecisions: gameStats[gameId].agentDecisions,
            agentSuccessRate: gameStats[gameId].agentSuccessRate
        });
    }

    // ============ Verification ============

    function verifyGame(uint256 gameId) external onlyOwner {
        require(games[gameId].gameAddress != address(0), "No game address");
        games[gameId].isVerified = true;
        emit GameVerified(gameId);
    }

    // ============ View Functions ============

    function getGame(uint256 gameId) external view returns (
        address gameAddress,
        address owner,
        string memory name,
        string memory gameType,
        string memory description,
        string memory metadata,
        bool isActive,
        bool isVerified,
        uint256 totalEvents,
        uint256 totalActions
    ) {
        Game storage g = games[gameId];
        return (
            g.gameAddress,
            g.owner,
            g.name,
            g.gameType,
            g.description,
            g.metadata,
            g.isActive,
            g.isVerified,
            g.totalEvents,
            g.totalActions
        );
    }

    function getConfig(uint256 gameId) external view returns (AgentConfig memory) {
        return gameConfigs[gameId];
    }

    function getStats(uint256 gameId) external view returns (GameStats memory) {
        return gameStats[gameId];
    }

    function getGamesByOwner(address owner) external view returns (uint256[] memory) {
        return gamesByOwner[owner];
    }

    function getTotalGames() external view returns (uint256) {
        return nextGameId;
    }

    function getGameTypeCount() external view returns (uint256) {
        return registeredGameTypes.length;
    }

    function isGameTypeRegistered(string calldata gameType) external view returns (bool) {
        return gameTypeCount[gameType] > 0;
    }

    // ============ Internal ============

    function _getKnowledgeBase() internal view returns (address) {
        // This would need to be set in constructor or via admin
        return address(0); // Placeholder
    }
}

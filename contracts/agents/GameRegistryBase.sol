// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title GameRegistryBase
 * @notice Core game registration and management
 * @dev Minimal contract for game registration
 */
contract GameRegistryBase is Ownable {

    // ============ Types ============

    struct Game {
        uint256 gameId;
        address owner;
        string name;
        string gameType;
        string description;
        string metadata;
        bool isActive;
        bool isVerified;
        uint256 registeredAt;
        uint256 lastActivity;
        uint256 totalEvents;
        uint256 totalActions;
    }

    struct AgentConfig {
        bool canSpawn;
        bool canAdjustEconomy;
        bool canGenerateNarrative;
        bool canAdjustDifficulty;
        uint256 maxChangePerEpoch;
        uint256 epochLength;
    }

    // ============ State ============

    mapping(uint256 => Game) public games;
    mapping(uint256 => AgentConfig) public gameConfigs;
    mapping(address => uint256) public gameByAddress;
    mapping(address => uint256[]) public gamesByOwner;
    uint256 public nextGameId;

    mapping(string => uint256) public gameTypeCount;
    string[] public registeredGameTypes;

    // ============ Events ============

    event GameRegistered(
        uint256 indexed gameId,
        address indexed owner,
        string name,
        string gameType
    );

    event GameActivated(uint256 indexed gameId);
    event GameDeactivated(uint256 indexed gameId);
    event GameVerified(uint256 indexed gameId);
    event GameUpdated(uint256 indexed gameId);
    event GameConfigUpdated(uint256 indexed gameId);

    // ============ Constructor ============

    constructor(address initialOwner) Ownable(initialOwner) {}

    // ============ Registration ============

    /**
     * @notice Register a new game
     */
    function registerGame(
        string calldata name,
        string calldata gameType,
        string calldata description,
        string calldata metadata
    ) external returns (uint256 gameId) {
        require(bytes(name).length > 0, "Name required");
        require(bytes(gameType).length > 0, "Type required");

        gameId = nextGameId++;

        games[gameId] = Game({
            gameId: gameId,
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

        gameConfigs[gameId] = AgentConfig({
            canSpawn: true,
            canAdjustEconomy: true,
            canGenerateNarrative: true,
            canAdjustDifficulty: true,
            maxChangePerEpoch: 2000,
            epochLength: 1000
        });

        gamesByOwner[msg.sender].push(gameId);

        if (gameTypeCount[gameType] == 0) {
            registeredGameTypes.push(gameType);
        }
        gameTypeCount[gameType]++;

        emit GameRegistered(gameId, msg.sender, name, gameType);
    }

    /**
     * @notice Register a game on behalf of another user (for proxy contracts)
     */
    function registerGameFor(
        address ownerAddr,
        string calldata name,
        string calldata gameType,
        string calldata description,
        string calldata metadata
    ) external returns (uint256 gameId) {
        require(bytes(name).length > 0, "Name required");
        require(bytes(gameType).length > 0, "Type required");

        gameId = nextGameId++;

        games[gameId] = Game({
            gameId: gameId,
            owner: ownerAddr,
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

        gameConfigs[gameId] = AgentConfig({
            canSpawn: true,
            canAdjustEconomy: true,
            canGenerateNarrative: true,
            canAdjustDifficulty: true,
            maxChangePerEpoch: 2000,
            epochLength: 1000
        });

        gamesByOwner[ownerAddr].push(gameId);

        if (gameTypeCount[gameType] == 0) {
            registeredGameTypes.push(gameType);
        }
        gameTypeCount[gameType]++;

        emit GameRegistered(gameId, ownerAddr, name, gameType);
    }

    // ============ Management ============

    function deactivateGame(uint256 gameId) external {
        require(games[gameId].owner == msg.sender, "Not owner");
        games[gameId].isActive = false;
        emit GameDeactivated(gameId);
    }

    function deactivateGameFor(uint256 gameId, address caller) external {
        require(games[gameId].owner == caller, "Not owner");
        games[gameId].isActive = false;
        emit GameDeactivated(gameId);
    }

    function activateGame(uint256 gameId) external {
        require(games[gameId].owner == msg.sender, "Not owner");
        games[gameId].isActive = true;
        emit GameActivated(gameId);
    }

    function activateGameFor(uint256 gameId, address caller) external {
        require(games[gameId].owner == caller, "Not owner");
        games[gameId].isActive = true;
        emit GameActivated(gameId);
    }

    function updateGame(
        uint256 gameId,
        string calldata description,
        string calldata metadata
    ) external {
        require(games[gameId].owner == msg.sender, "Not owner");
        if (bytes(description).length > 0) {
            games[gameId].description = description;
        }
        if (bytes(metadata).length > 0) {
            games[gameId].metadata = metadata;
        }
        emit GameUpdated(gameId);
    }

    function updateGameFor(
        uint256 gameId,
        address caller,
        string calldata description,
        string calldata metadata
    ) external {
        require(games[gameId].owner == caller, "Not owner");
        if (bytes(description).length > 0) {
            games[gameId].description = description;
        }
        if (bytes(metadata).length > 0) {
            games[gameId].metadata = metadata;
        }
        emit GameUpdated(gameId);
    }

    function updateConfig(uint256 gameId, AgentConfig calldata config) external {
        require(games[gameId].owner == msg.sender, "Not owner");
        require(config.maxChangePerEpoch <= 10000, "Max change too high");
        gameConfigs[gameId] = config;
        emit GameConfigUpdated(gameId);
    }

    function updateConfigFor(uint256 gameId, address caller, AgentConfig calldata config) external {
        require(games[gameId].owner == caller, "Not owner");
        require(config.maxChangePerEpoch <= 10000, "Max change too high");
        gameConfigs[gameId] = config;
        emit GameConfigUpdated(gameId);
    }

    function verifyGame(uint256 gameId) external onlyOwner {
        games[gameId].isVerified = true;
        emit GameVerified(gameId);
    }

    // ============ Activity Tracking ============

    function recordEvent(uint256 gameId) external {
        require(games[gameId].isActive, "Game not active");
        games[gameId].totalEvents++;
        games[gameId].lastActivity = block.timestamp;
    }

    function recordAction(uint256 gameId) external {
        require(games[gameId].isActive, "Game not active");
        games[gameId].totalActions++;
        games[gameId].lastActivity = block.timestamp;
    }

    // ============ View Functions ============

    function getGame(uint256 gameId) external view returns (
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

    function getGamesByOwner(address owner) external view returns (uint256[] memory) {
        return gamesByOwner[owner];
    }

    function getTotalGames() external view returns (uint256) {
        return nextGameId;
    }

    function getRegisteredGameTypes() external view returns (string[] memory) {
        return registeredGameTypes;
    }
}

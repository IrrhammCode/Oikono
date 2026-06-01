// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./GameRegistryBase.sol";
import "./GameContractManager.sol";
import "./GameTypeManager.sol";

/**
 * @title GameRegistryV2
 * @notice Unified interface for game registration
 * @dev Delegates to specialized contracts for reduced size
 */
contract GameRegistryV2 is Ownable {

    // ============ State ============

    GameRegistryBase public base;
    GameContractManager public contractManager;
    GameTypeManager public typeManager;

    // ============ Events ============

    event GameRegistered(uint256 indexed gameId, address indexed owner, string name, string gameType);
    event ContractAdded(uint256 indexed gameId, address indexed contractAddress, string role);
    event TemplateApplied(uint256 indexed gameId, string templateName);

    // ============ Constructor ============

    constructor(
        address _base,
        address _contractManager,
        address _typeManager,
        address initialOwner
    ) Ownable(initialOwner) {
        base = GameRegistryBase(_base);
        contractManager = GameContractManager(_contractManager);
        typeManager = GameTypeManager(_typeManager);
    }

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
        gameId = base.registerGameFor(msg.sender, name, gameType, description, metadata);
        emit GameRegistered(gameId, msg.sender, name, gameType);
    }

    // ============ Contract Management ============

    /**
     * @notice Add a contract to game
     */
    function addContract(
        uint256 gameId,
        address contractAddress,
        string calldata role,
        bytes32[] calldata eventHashes
    ) external {
        contractManager.addContractFor(gameId, msg.sender, contractAddress, role, eventHashes);
        emit ContractAdded(gameId, contractAddress, role);
    }

    /**
     * @notice Remove a contract from game
     */
    function removeContract(uint256 gameId, address contractAddress) external {
        contractManager.removeContractFor(gameId, msg.sender, contractAddress);
    }

    /**
     * @notice Update contract role
     */
    function updateContractRole(
        uint256 gameId,
        address contractAddress,
        string calldata newRole
    ) external {
        contractManager.updateContractRole(gameId, contractAddress, newRole);
    }

    // ============ Template Management ============

    /**
     * @notice Apply game type template
     */
    function applyTemplate(uint256 gameId, string calldata typeName) external {
        typeManager.applyTemplateFor(gameId, msg.sender, typeName);
        emit TemplateApplied(gameId, typeName);
    }

    // ============ Game Management ============

    function deactivateGame(uint256 gameId) external {
        base.deactivateGameFor(gameId, msg.sender);
    }

    function activateGame(uint256 gameId) external {
        base.activateGameFor(gameId, msg.sender);
    }

    function updateGame(
        uint256 gameId,
        string calldata description,
        string calldata metadata
    ) external {
        base.updateGameFor(gameId, msg.sender, description, metadata);
    }

    function updateConfig(uint256 gameId, GameRegistryBase.AgentConfig calldata config) external {
        base.updateConfigFor(gameId, msg.sender, config);
    }

    function verifyGame(uint256 gameId) external {
        base.verifyGame(gameId);
    }

    // ============ Activity Tracking ============

    function recordEvent(uint256 gameId) external {
        base.recordEvent(gameId);
    }

    function recordAction(uint256 gameId) external {
        base.recordAction(gameId);
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
        return base.getGame(gameId);
    }

    function getGameContracts(uint256 gameId) external view returns (
        address[] memory addresses,
        string[] memory roles,
        bool[] memory active
    ) {
        return contractManager.getGameContracts(gameId);
    }

    function getContractByRole(uint256 gameId, string calldata role) external view returns (address) {
        return contractManager.getContractByRole(gameId, role);
    }

    function getGamesByOwner(address owner) external view returns (uint256[] memory) {
        return base.getGamesByOwner(owner);
    }

    function getTotalGames() external view returns (uint256) {
        return base.getTotalGames();
    }

    function getRegisteredGameTypes() external view returns (string[] memory) {
        return typeManager.getRegisteredTypes();
    }

    function getGameTypeConfig(string calldata typeName) external view returns (
        string memory description,
        uint256 metricCount,
        uint256 ruleCount
    ) {
        return typeManager.getGameTypeConfig(typeName);
    }
}

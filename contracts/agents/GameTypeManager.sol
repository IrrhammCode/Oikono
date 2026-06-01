// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./GameRegistryBase.sol";
import "./MetricsRegistry.sol";
import "./PatternDetector.sol";
import "./GameTypeTemplatesLib.sol";

/**
 * @title GameTypeManager
 * @notice Manages game type templates and applies them to games
 * @dev Handles template registration and application
 */
contract GameTypeManager is Ownable {

    // ============ Types ============

    struct GameTypeConfig {
        string typeName;
        string description;
        GameTypeTemplatesLib.MetricTemplate[] metrics;
        GameTypeTemplatesLib.RuleTemplate[] rules;
    }

    // ============ State ============

    GameRegistryBase public registry;
    MetricsRegistry public metricsRegistry;
    PatternDetector public patternDetector;

    mapping(string => GameTypeConfig) public gameTypeConfigs;
    string[] public registeredGameTypes;

    // ============ Events ============

    event TemplateApplied(uint256 indexed gameId, string templateName);
    event GameTypeRegistered(string typeName, string description);

    // ============ Constructor ============

    constructor(
        address _registry,
        address _metricsRegistry,
        address _patternDetector,
        address initialOwner
    ) Ownable(initialOwner) {
        registry = GameRegistryBase(_registry);
        metricsRegistry = MetricsRegistry(_metricsRegistry);
        patternDetector = PatternDetector(_patternDetector);

        _registerDefaultGameTypes();
    }

    // ============ Template Application ============

    /**
     * @notice Apply game type template to a game
     */
    function applyTemplate(uint256 gameId, string calldata typeName) external {
        (address gameOwner, , , , , , , , ) = registry.getGame(gameId);
        require(gameOwner == msg.sender, "Not game owner");
        _applyTemplate(gameId, typeName);
    }

    /**
     * @notice Apply template on behalf of another user
     */
    function applyTemplateFor(uint256 gameId, address caller, string calldata typeName) external {
        (address gameOwner, , , , , , , , ) = registry.getGame(gameId);
        require(gameOwner == caller, "Not game owner");
        _applyTemplate(gameId, typeName);
    }

    /**
     * @notice Internal template application
     */
    function _applyTemplate(uint256 gameId, string calldata typeName) internal {
        GameTypeConfig storage config = gameTypeConfigs[typeName];
        require(bytes(config.typeName).length > 0, "Template not found");

        // Apply metrics
        for (uint256 i = 0; i < config.metrics.length; i++) {
            GameTypeTemplatesLib.MetricTemplate storage m = config.metrics[i];

            metricsRegistry.defineMetric(
                gameId,
                m.name,
                m.dataType,
                m.source,
                m.healthyMin,
                m.healthyMax,
                m.isHigherBetter
            );
        }

        // Apply detection rules
        for (uint256 i = 0; i < config.rules.length; i++) {
            GameTypeTemplatesLib.RuleTemplate storage r = config.rules[i];
            patternDetector.addRule(
                gameId,
                r.ruleType,
                r.metricName,
                r.threshold,
                r.period
            );
        }

        emit TemplateApplied(gameId, typeName);
    }

    // ============ Registration ============

    /**
     * @notice Register a custom game type
     */
    function registerGameType(
        string calldata typeName,
        string calldata description,
        GameTypeTemplatesLib.MetricTemplate[] calldata metrics,
        GameTypeTemplatesLib.RuleTemplate[] calldata rules
    ) external onlyOwner {
        gameTypeConfigs[typeName] = GameTypeConfig({
            typeName: typeName,
            description: description,
            metrics: metrics,
            rules: rules
        });
        registeredGameTypes.push(typeName);
        emit GameTypeRegistered(typeName, description);
    }

    // ============ View Functions ============

    function getRegisteredTypes() external view returns (string[] memory) {
        return registeredGameTypes;
    }

    function getGameTypeConfig(string calldata typeName) external view returns (
        string memory description,
        uint256 metricCount,
        uint256 ruleCount
    ) {
        GameTypeConfig storage config = gameTypeConfigs[typeName];
        return (config.description, config.metrics.length, config.rules.length);
    }

    function getMetricTemplates(string calldata typeName) external view returns (
        GameTypeTemplatesLib.MetricTemplate[] memory
    ) {
        return gameTypeConfigs[typeName].metrics;
    }

    function getRuleTemplates(string calldata typeName) external view returns (
        GameTypeTemplatesLib.RuleTemplate[] memory
    ) {
        return gameTypeConfigs[typeName].rules;
    }

    // ============ Internal ============

    function _registerDefaultGameTypes() internal {
        _registerGameType("rpg", "Role-Playing Games", GameTypeTemplatesLib.rpgMetrics(), GameTypeTemplatesLib.rpgRules());
        _registerGameType("card", "Card Games (TCG/CCG)", GameTypeTemplatesLib.cardMetrics(), GameTypeTemplatesLib.cardRules());
        _registerGameType("strategy", "Strategy Games (4X, RTS)", GameTypeTemplatesLib.strategyMetrics(), GameTypeTemplatesLib.strategyRules());
        _registerGameType("pvp", "PvP Games (Fighting, Battle Royale)", GameTypeTemplatesLib.pvpMetrics(), GameTypeTemplatesLib.pvpRules());
        _registerGameType("simulation", "Simulation Games (Tycoon, City Builder)", GameTypeTemplatesLib.simulationMetrics(), GameTypeTemplatesLib.simulationRules());
        _registerGameType("puzzle", "Puzzle Games", GameTypeTemplatesLib.puzzleMetrics(), GameTypeTemplatesLib.puzzleRules());
        _registerGameType("racing", "Racing Games", GameTypeTemplatesLib.racingMetrics(), GameTypeTemplatesLib.racingRules());
        _registerGameType("idle", "Idle/Clicker Games", GameTypeTemplatesLib.idleMetrics(), GameTypeTemplatesLib.idleRules());
        _registerGameType("sandbox", "Sandbox Games (UGC)", GameTypeTemplatesLib.sandboxMetrics(), GameTypeTemplatesLib.sandboxRules());
        _registerGameType("defi", "DeFi/GameFi Games", GameTypeTemplatesLib.defiMetrics(), GameTypeTemplatesLib.defiRules());
    }

    function _registerGameType(
        string memory typeName,
        string memory description,
        GameTypeTemplatesLib.MetricTemplate[] memory metrics,
        GameTypeTemplatesLib.RuleTemplate[] memory rules
    ) internal {
        gameTypeConfigs[typeName] = GameTypeConfig({
            typeName: typeName,
            description: description,
            metrics: metrics,
            rules: rules
        });
        registeredGameTypes.push(typeName);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./MetricsRegistry.sol";
import "./PatternDetector.sol";

/**
 * @title GameTypeTemplates
 * @notice Pre-defined templates for different Web3 game types
 * @dev Provides starting point for developers, fully customizable
 */
contract GameTypeTemplates is Ownable {

    // ============ Types ============

    struct MetricTemplate {
        string name;
        string dataType;
        string source;
        uint256 healthyMin;
        uint256 healthyMax;
        bool isHigherBetter;
    }

    struct RuleTemplate {
        string ruleType;
        string metricName;
        uint256 threshold;
        uint256 period;
    }

    struct GameTypeConfig {
        string typeName;
        string description;
        MetricTemplate[] metrics;
        RuleTemplate[] rules;
    }

    // ============ State ============

    MetricsRegistry public metricsRegistry;
    PatternDetector public patternDetector;

    // Game type configs
    mapping(string => GameTypeConfig) public configs;
    string[] public registeredTypes;

    // ============ Events ============

    event GameTypeRegistered(string typeName, string description);

    // ============ Constructor ============

    constructor(
        address _metricsRegistry,
        address _patternDetector,
        address initialOwner
    ) Ownable(initialOwner) {
        metricsRegistry = MetricsRegistry(_metricsRegistry);
        patternDetector = PatternDetector(_patternDetector);

        // Register default game types
        _registerRPG();
        _registerCardGame();
        _registerStrategy();
        _registerPvP();
        _registerSimulation();
        _registerPuzzle();
        _registerRacing();
        _registerIdle();
        _registerSandbox();
        _registerDeFi();
    }

    // ============ Template Application ============

    /**
     * @notice Apply template to a game
     * @param gameId Game ID
     * @param typeName Game type (e.g., "rpg", "card")
     */
    function applyTemplate(uint256 gameId, string calldata typeName) external {
        GameTypeConfig storage config = configs[typeName];
        require(bytes(config.typeName).length > 0, "Template not found");

        // Apply metric definitions
        for (uint256 i = 0; i < config.metrics.length; i++) {
            MetricTemplate storage m = config.metrics[i];
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
            RuleTemplate storage r = config.rules[i];
            patternDetector.addRule(
                gameId,
                r.ruleType,
                r.metricName,
                r.threshold,
                r.period
            );
        }
    }

    // ============ Template Registration ============

    /**
     * @notice Register a custom game type template
     */
    function registerGameType(
        string calldata typeName,
        string calldata description,
        MetricTemplate[] calldata metrics,
        RuleTemplate[] calldata rules
    ) external onlyOwner {
        configs[typeName] = GameTypeConfig({
            typeName: typeName,
            description: description,
            metrics: metrics,
            rules: rules
        });

        registeredTypes.push(typeName);
        emit GameTypeRegistered(typeName, description);
    }

    // ============ Default Templates ============

    function _registerRPG() internal {
        MetricTemplate[] memory metrics = new MetricTemplate[](10);
        metrics[0] = MetricTemplate("win_rate", "bps", "on_chain", 4000, 7000, false);
        metrics[1] = MetricTemplate("token_velocity", "uint256", "on_chain", 0, 50000, false);
        metrics[2] = MetricTemplate("retention_d7", "bps", "off_chain", 3000, 6000, true);
        metrics[3] = MetricTemplate("gold_inflation", "bps", "calculated", 0, 1000, false);
        metrics[4] = MetricTemplate("avg_session_length", "duration", "off_chain", 900, 3600, true);
        metrics[5] = MetricTemplate("level_up_rate", "uint256", "on_chain", 1, 5, true);
        metrics[6] = MetricTemplate("quest_completion", "bps", "on_chain", 3000, 7000, true);
        metrics[7] = MetricTemplate("item_drop_rate", "bps", "on_chain", 500, 2000, true);
        metrics[8] = MetricTemplate("pvp_participation", "bps", "on_chain", 2000, 5000, true);
        metrics[9] = MetricTemplate("daily_active_users", "uint256", "off_chain", 100, 0, true);

        RuleTemplate[] memory rules = new RuleTemplate[](4);
        rules[0] = RuleTemplate("spike", "win_rate", 2000, 1);
        rules[1] = RuleTemplate("drop", "retention_d7", 1500, 1);
        rules[2] = RuleTemplate("trend_up", "token_velocity", 5000, 7);
        rules[3] = RuleTemplate("trend_up", "gold_inflation", 3000, 7);

        configs["rpg"] = GameTypeConfig({
            typeName: "rpg",
            description: "Role-Playing Games with character progression, quests, and economy",
            metrics: metrics,
            rules: rules
        });

        registeredTypes.push("rpg");
    }

    function _registerCardGame() internal {
        MetricTemplate[] memory metrics = new MetricTemplate[](8);
        metrics[0] = MetricTemplate("collection_rate", "bps", "on_chain", 2000, 5000, true);
        metrics[1] = MetricTemplate("meta_dominance", "bps", "on_chain", 0, 3500, false);
        metrics[2] = MetricTemplate("pack_ev", "bps", "on_chain", 8000, 12000, true);
        metrics[3] = MetricTemplate("card_price_avg", "uint256", "on_chain", 0, 0, false);
        metrics[4] = MetricTemplate("match_duration", "duration", "on_chain", 300, 900, false);
        metrics[5] = MetricTemplate("retention_d7", "bps", "off_chain", 3000, 6000, true);
        metrics[6] = MetricTemplate("daily_matches", "uint256", "on_chain", 3, 20, true);
        metrics[7] = MetricTemplate("deck_diversity", "bps", "on_chain", 5000, 8000, true);

        RuleTemplate[] memory rules = new RuleTemplate[](3);
        rules[0] = RuleTemplate("spike", "meta_dominance", 1000, 1);
        rules[1] = RuleTemplate("drop", "pack_ev", 2000, 1);
        rules[2] = RuleTemplate("trend_down", "retention_d7", 1500, 7);

        configs["card"] = GameTypeConfig({
            typeName: "card",
            description: "Card games (TCG/CCG) with collection, deck building, and matches",
            metrics: metrics,
            rules: rules
        });

        registeredTypes.push("card");
    }

    function _registerStrategy() internal {
        MetricTemplate[] memory metrics = new MetricTemplate[](8);
        metrics[0] = MetricTemplate("resource_balance", "bps", "calculated", 4000, 6000, true);
        metrics[1] = MetricTemplate("build_time_avg", "duration", "on_chain", 60, 600, false);
        metrics[2] = MetricTemplate("unit_win_rate", "bps", "on_chain", 4500, 5500, false);
        metrics[3] = MetricTemplate("territory_control", "bps", "on_chain", 2000, 5000, true);
        metrics[4] = MetricTemplate("alliance_participation", "bps", "on_chain", 3000, 6000, true);
        metrics[5] = MetricTemplate("match_duration", "duration", "on_chain", 600, 1800, false);
        metrics[6] = MetricTemplate("retention_d7", "bps", "off_chain", 2500, 5000, true);
        metrics[7] = MetricTemplate("resource_inflation", "bps", "calculated", 0, 1500, false);

        RuleTemplate[] memory rules = new RuleTemplate[](3);
        rules[0] = RuleTemplate("trend_up", "resource_inflation", 3000, 7);
        rules[1] = RuleTemplate("spike", "unit_win_rate", 1500, 1);
        rules[2] = RuleTemplate("drop", "alliance_participation", 2000, 1);

        configs["strategy"] = GameTypeConfig({
            typeName: "strategy",
            description: "Strategy games (4X, RTS, Tower Defense) with resources and territory",
            metrics: metrics,
            rules: rules
        });

        registeredTypes.push("strategy");
    }

    function _registerPvP() internal {
        MetricTemplate[] memory metrics = new MetricTemplate[](7);
        metrics[0] = MetricTemplate("win_rate_distribution", "bps", "on_chain", 4000, 6000, false);
        metrics[1] = MetricTemplate("kd_ratio", "uint256", "on_chain", 50, 200, true);
        metrics[2] = MetricTemplate("match_duration", "duration", "on_chain", 300, 900, false);
        metrics[3] = MetricTemplate("queue_time", "duration", "off_chain", 10, 120, false);
        metrics[4] = MetricTemplate("character_usage", "bps", "on_chain", 500, 2000, false);
        metrics[5] = MetricTemplate("retention_d7", "bps", "off_chain", 3000, 6000, true);
        metrics[6] = MetricTemplate("rank_distribution", "bps", "on_chain", 3000, 5000, true);

        RuleTemplate[] memory rules = new RuleTemplate[](3);
        rules[0] = RuleTemplate("trend_up", "queue_time", 5000, 7);
        rules[1] = RuleTemplate("spike", "character_usage", 3000, 1);
        rules[2] = RuleTemplate("drop", "retention_d7", 1500, 1);

        configs["pvp"] = GameTypeConfig({
            typeName: "pvp",
            description: "PvP games (Fighting, Battle Royale, MOBA) with matchmaking",
            metrics: metrics,
            rules: rules
        });

        registeredTypes.push("pvp");
    }

    function _registerSimulation() internal {
        MetricTemplate[] memory metrics = new MetricTemplate[](6);
        metrics[0] = MetricTemplate("resource_production", "uint256", "on_chain", 100, 10000, true);
        metrics[1] = MetricTemplate("trade_volume", "uint256", "on_chain", 1000, 100000, true);
        metrics[2] = MetricTemplate("land_utilization", "bps", "on_chain", 3000, 7000, true);
        metrics[3] = MetricTemplate("creator_earnings", "uint256", "on_chain", 100, 10000, true);
        metrics[4] = MetricTemplate("visitor_count", "uint256", "off_chain", 50, 5000, true);
        metrics[5] = MetricTemplate("retention_d7", "bps", "off_chain", 2500, 5000, true);

        RuleTemplate[] memory rules = new RuleTemplate[](2);
        rules[0] = RuleTemplate("drop", "trade_volume", 3000, 7);
        rules[1] = RuleTemplate("drop", "visitor_count", 4000, 7);

        configs["simulation"] = GameTypeConfig({
            typeName: "simulation",
            description: "Simulation games (Tycoon, City Builder) with building and trading",
            metrics: metrics,
            rules: rules
        });

        registeredTypes.push("simulation");
    }

    function _registerPuzzle() internal {
        MetricTemplate[] memory metrics = new MetricTemplate[](5);
        metrics[0] = MetricTemplate("level_completion", "bps", "on_chain", 5000, 8000, true);
        metrics[1] = MetricTemplate("move_efficiency", "bps", "on_chain", 3000, 7000, true);
        metrics[2] = MetricTemplate("streak_length", "uint256", "on_chain", 3, 50, true);
        metrics[3] = MetricTemplate("lives_purchased", "uint256", "on_chain", 0, 10, false);
        metrics[4] = MetricTemplate("retention_d7", "bps", "off_chain", 3000, 6000, true);

        RuleTemplate[] memory rules = new RuleTemplate[](2);
        rules[0] = RuleTemplate("drop", "level_completion", 2000, 1);
        rules[1] = RuleTemplate("trend_up", "lives_purchased", 5000, 7);

        configs["puzzle"] = GameTypeConfig({
            typeName: "puzzle",
            description: "Puzzle games (Match-3, Logic) with levels and power-ups",
            metrics: metrics,
            rules: rules
        });

        registeredTypes.push("puzzle");
    }

    function _registerRacing() internal {
        MetricTemplate[] memory metrics = new MetricTemplate[](5);
        metrics[0] = MetricTemplate("win_rate", "bps", "on_chain", 4000, 6000, false);
        metrics[1] = MetricTemplate("lap_time_avg", "duration", "on_chain", 60, 300, false);
        metrics[2] = MetricTemplate("vehicle_upgrades", "uint256", "on_chain", 1, 20, true);
        metrics[3] = MetricTemplate("tournament_participation", "bps", "on_chain", 2000, 5000, true);
        metrics[4] = MetricTemplate("retention_d7", "bps", "off_chain", 2500, 5000, true);

        RuleTemplate[] memory rules = new RuleTemplate[](2);
        rules[0] = RuleTemplate("spike", "win_rate", 2000, 1);
        rules[1] = RuleTemplate("drop", "tournament_participation", 3000, 1);

        configs["racing"] = GameTypeConfig({
            typeName: "racing",
            description: "Racing games with vehicles, tracks, and tournaments",
            metrics: metrics,
            rules: rules
        });

        registeredTypes.push("racing");
    }

    function _registerIdle() internal {
        MetricTemplate[] memory metrics = new MetricTemplate[](5);
        metrics[0] = MetricTemplate("income_per_hour", "uint256", "on_chain", 10, 10000, true);
        metrics[1] = MetricTemplate("upgrade_frequency", "uint256", "on_chain", 1, 50, true);
        metrics[2] = MetricTemplate("session_length", "duration", "off_chain", 60, 600, true);
        metrics[3] = MetricTemplate("return_frequency", "uint256", "off_chain", 1, 10, true);
        metrics[4] = MetricTemplate("retention_d7", "bps", "off_chain", 2000, 4000, true);

        RuleTemplate[] memory rules = new RuleTemplate[](2);
        rules[0] = RuleTemplate("trend_up", "income_per_hour", 10000, 7);
        rules[1] = RuleTemplate("drop", "return_frequency", 3000, 7);

        configs["idle"] = GameTypeConfig({
            typeName: "idle",
            description: "Idle/Clicker games with auto-progression and upgrades",
            metrics: metrics,
            rules: rules
        });

        registeredTypes.push("idle");
    }

    function _registerSandbox() internal {
        MetricTemplate[] memory metrics = new MetricTemplate[](6);
        metrics[0] = MetricTemplate("content_creation", "uint256", "on_chain", 1, 100, true);
        metrics[1] = MetricTemplate("user_engagement", "bps", "off_chain", 3000, 7000, true);
        metrics[2] = MetricTemplate("land_utilization", "bps", "on_chain", 2000, 6000, true);
        metrics[3] = MetricTemplate("creator_earnings", "uint256", "on_chain", 100, 10000, true);
        metrics[4] = MetricTemplate("platform_fees", "bps", "on_chain", 200, 1000, false);
        metrics[5] = MetricTemplate("retention_d7", "bps", "off_chain", 2000, 5000, true);

        RuleTemplate[] memory rules = new RuleTemplate[](2);
        rules[0] = RuleTemplate("drop", "content_creation", 3000, 7);
        rules[1] = RuleTemplate("drop", "creator_earnings", 4000, 7);

        configs["sandbox"] = GameTypeConfig({
            typeName: "sandbox",
            description: "Sandbox games (UGC-focused) with user-generated content",
            metrics: metrics,
            rules: rules
        });

        registeredTypes.push("sandbox");
    }

    function _registerDeFi() internal {
        MetricTemplate[] memory metrics = new MetricTemplate[](6);
        metrics[0] = MetricTemplate("apy", "bps", "on_chain", 500, 50000, true);
        metrics[1] = MetricTemplate("tvl", "uint256", "on_chain", 10000, 0, true);
        metrics[2] = MetricTemplate("token_price", "uint256", "on_chain", 0, 0, true);
        metrics[3] = MetricTemplate("liquidity_depth", "uint256", "on_chain", 10000, 0, true);
        metrics[4] = MetricTemplate("deposit_withdraw_ratio", "bps", "on_chain", 8000, 12000, true);
        metrics[5] = MetricTemplate("retention_d7", "bps", "off_chain", 2000, 5000, true);

        RuleTemplate[] memory rules = new RuleTemplate[](3);
        rules[0] = RuleTemplate("drop", "tvl", 2000, 1);
        rules[1] = RuleTemplate("drop", "liquidity_depth", 3000, 1);
        rules[2] = RuleTemplate("trend_down", "deposit_withdraw_ratio", 2000, 7);

        configs["defi"] = GameTypeConfig({
            typeName: "defi",
            description: "DeFi/GameFi games with yield farming and token economics",
            metrics: metrics,
            rules: rules
        });

        registeredTypes.push("defi");
    }

    // ============ View Functions ============

    /**
     * @notice Get all registered game types
     */
    function getRegisteredTypes() external view returns (string[] memory) {
        return registeredTypes;
    }

    /**
     * @notice Get game type config
     */
    function getConfig(string calldata typeName) external view returns (
        string memory description,
        uint256 metricCount,
        uint256 ruleCount
    ) {
        GameTypeConfig storage config = configs[typeName];
        return (
            config.description,
            config.metrics.length,
            config.rules.length
        );
    }

    /**
     * @notice Get metric templates for a game type
     */
    function getMetricTemplates(string calldata typeName) external view returns (MetricTemplate[] memory) {
        return configs[typeName].metrics;
    }

    /**
     * @notice Get rule templates for a game type
     */
    function getRuleTemplates(string calldata typeName) external view returns (RuleTemplate[] memory) {
        return configs[typeName].rules;
    }
}

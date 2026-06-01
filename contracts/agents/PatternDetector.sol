// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./MetricsRegistry.sol";

/**
 * @title PatternDetector
 * @notice Detects patterns, anomalies, and trends in game metrics
 * @dev Data-driven approach: find patterns in data, not based on formulas
 */
contract PatternDetector is Ownable {

    // ============ Types ============

    struct Pattern {
        uint256 patternId;
        uint256 gameId;
        string patternType;     // "anomaly", "trend", "divergence", "correlation"
        string metricName;      // Primary metric
        string metricName2;     // Secondary metric (for divergence/correlation)
        string description;     // Human-readable description
        uint256 severity;       // 1-10
        uint256 confidence;     // 0-10000 (basis points)
        uint256 detectedAt;
        bool isActive;
        bytes data;             // Additional pattern data
    }

    struct DetectionRule {
        string ruleType;        // "spike", "drop", "trend_up", "trend_down", "divergence"
        string metricName;
        uint256 threshold;      // Threshold value (in bps for percentage)
        uint256 period;         // Time period or number of values
        bool isActive;
    }

    // ============ State ============

    MetricsRegistry public metricsRegistry;

    // Patterns per game
    mapping(uint256 => Pattern[]) public gamePatterns;
    mapping(uint256 => uint256) public patternCount;

    // Detection rules per game
    mapping(uint256 => DetectionRule[]) public detectionRules;
    mapping(uint256 => uint256) public ruleCount;

    // Game owner mapping
    mapping(uint256 => address) public gameOwners;

    // ============ Events ============

    event PatternDetected(
        uint256 indexed gameId,
        uint256 indexed patternId,
        string patternType,
        string description,
        uint256 severity
    );

    event RuleAdded(
        uint256 indexed gameId,
        uint256 indexed ruleId,
        string ruleType,
        string metricName
    );

    // ============ Constructor ============

    constructor(address _metricsRegistry, address initialOwner) Ownable(initialOwner) {
        metricsRegistry = MetricsRegistry(_metricsRegistry);
    }

    // ============ Rule Management ============

    /**
     * @notice Add a detection rule
     */
    // Authorized callers
    mapping(address => bool) public authorizedCallers;

    function setAuthorizedCaller(address caller, bool authorized) external onlyOwner {
        authorizedCallers[caller] = authorized;
    }

    function addRule(
        uint256 gameId,
        string calldata ruleType,
        string calldata metricName,
        uint256 threshold,
        uint256 period
    ) external {
        require(
            gameOwners[gameId] == msg.sender ||
            msg.sender == owner() ||
            authorizedCallers[msg.sender],
            "Not game owner"
        );

        uint256 ruleId = ruleCount[gameId]++;

        detectionRules[gameId].push(DetectionRule({
            ruleType: ruleType,
            metricName: metricName,
            threshold: threshold,
            period: period,
            isActive: true
        }));

        emit RuleAdded(gameId, ruleId, ruleType, metricName);
    }

    /**
     * @notice Add default rules for a game type
     */
    function addDefaultRules(uint256 gameId, string calldata gameType) external {
        require(
            gameOwners[gameId] == msg.sender || msg.sender == owner(),
            "Not game owner"
        );

        if (keccak256(bytes(gameType)) == keccak256(bytes("rpg"))) {
            _addRPGRules(gameId);
        } else if (keccak256(bytes(gameType)) == keccak256(bytes("card"))) {
            _addCardGameRules(gameId);
        } else if (keccak256(bytes(gameType)) == keccak256(bytes("strategy"))) {
            _addStrategyRules(gameId);
        } else if (keccak256(bytes(gameType)) == keccak256(bytes("pvp"))) {
            _addPvPRules(gameId);
        }
    }

    // ============ Pattern Detection ============

    /**
     * @notice Detect patterns for a game
     * @dev Can be called manually or via automation
     */
    function detectPatterns(uint256 gameId) external {
        require(gameOwners[gameId] == msg.sender || msg.sender == owner(), "Not authorized");

        // Check all rules
        DetectionRule[] storage rules = detectionRules[gameId];
        for (uint256 i = 0; i < rules.length; i++) {
            if (rules[i].isActive) {
                _checkRule(gameId, i, rules[i]);
            }
        }

        // Check for anomalies (even without rules)
        _detectAnomalies(gameId);

        // Check for trends
        _detectTrends(gameId);
    }

    // ============ Internal Detection Logic ============

    function _checkRule(uint256 gameId, uint256 ruleIdx, DetectionRule storage rule) internal {
        if (keccak256(bytes(rule.ruleType)) == keccak256(bytes("spike"))) {
            _checkSpike(gameId, rule.metricName, rule.threshold);
        } else if (keccak256(bytes(rule.ruleType)) == keccak256(bytes("drop"))) {
            _checkDrop(gameId, rule.metricName, rule.threshold);
        } else if (keccak256(bytes(rule.ruleType)) == keccak256(bytes("trend_up"))) {
            _checkTrendUp(gameId, rule.metricName, rule.threshold, rule.period);
        } else if (keccak256(bytes(rule.ruleType)) == keccak256(bytes("trend_down"))) {
            _checkTrendDown(gameId, rule.metricName, rule.threshold, rule.period);
        }
    }

    function _checkSpike(uint256 gameId, string memory metricName, uint256 threshold) internal {
        int256 change = metricsRegistry.getChange(gameId, metricName);
        if (change > int256(threshold)) {
            _createPattern(
                gameId,
                "anomaly",
                metricName,
                "",
                string(abi.encodePacked(
                    metricName, " spiked ", _toString(uint256(change) / 100), "%"
                )),
                7,
                8000 // 80% confidence
            );
        }
    }

    function _checkDrop(uint256 gameId, string memory metricName, uint256 threshold) internal {
        int256 change = metricsRegistry.getChange(gameId, metricName);
        if (change < -int256(threshold)) {
            _createPattern(
                gameId,
                "anomaly",
                metricName,
                "",
                string(abi.encodePacked(
                    metricName, " dropped ", _toString(uint256(-change) / 100), "%"
                )),
                8,
                8000
            );
        }
    }

    function _checkTrendUp(
        uint256 gameId,
        string memory metricName,
        uint256 threshold,
        uint256 period
    ) internal {
        // Check if metric is consistently increasing
        MetricsRegistry.MetricValue[] memory history = metricsRegistry.getHistory(
            gameId, metricName, period
        );

        if (history.length < 3) return;

        bool isIncreasing = true;
        for (uint256 i = 1; i < history.length; i++) {
            if (history[i].value <= history[i - 1].value) {
                isIncreasing = false;
                break;
            }
        }

        if (isIncreasing) {
            uint256 totalChange = (history[history.length - 1].value - history[0].value) * 10000 / history[0].value;
            if (totalChange > threshold) {
                _createPattern(
                    gameId,
                    "trend",
                    metricName,
                    "",
                    string(abi.encodePacked(
                        metricName, " trending up ", _toString(totalChange / 100), "% over ", _toString(period), " periods"
                    )),
                    5,
                    7000
                );
            }
        }
    }

    function _checkTrendDown(
        uint256 gameId,
        string memory metricName,
        uint256 threshold,
        uint256 period
    ) internal {
        MetricsRegistry.MetricValue[] memory history = metricsRegistry.getHistory(
            gameId, metricName, period
        );

        if (history.length < 3) return;

        bool isDecreasing = true;
        for (uint256 i = 1; i < history.length; i++) {
            if (history[i].value >= history[i - 1].value) {
                isDecreasing = false;
                break;
            }
        }

        if (isDecreasing) {
            uint256 totalChange = (history[0].value - history[history.length - 1].value) * 10000 / history[0].value;
            if (totalChange > threshold) {
                _createPattern(
                    gameId,
                    "trend",
                    metricName,
                    "",
                    string(abi.encodePacked(
                        metricName, " trending down ", _toString(totalChange / 100), "% over ", _toString(period), " periods"
                    )),
                    6,
                    7000
                );
            }
        }
    }

    function _detectAnomalies(uint256 gameId) internal {
        // Check if any metric is outside healthy range
        string[] memory names = metricsRegistry.getMetricNames(gameId);
        for (uint256 i = 0; i < names.length; i++) {
            if (!metricsRegistry.isHealthy(gameId, names[i])) {
                _createPattern(
                    gameId,
                    "anomaly",
                    names[i],
                    "",
                    string(abi.encodePacked(names[i], " outside healthy range")),
                    6,
                    9000
                );
            }
        }
    }

    function _detectTrends(uint256 gameId) internal {
        // Check for divergence between metrics
        // Example: win_rate going up while retention going down
        string[] memory names = metricsRegistry.getMetricNames(gameId);

        for (uint256 i = 0; i < names.length; i++) {
            for (uint256 j = i + 1; j < names.length; j++) {
                int256 change1 = metricsRegistry.getChange(gameId, names[i]);
                int256 change2 = metricsRegistry.getChange(gameId, names[j]);

                // Check for divergence (one going up, other going down)
                if ((change1 > 1000 && change2 < -1000) || (change1 < -1000 && change2 > 1000)) {
                    _createPattern(
                        gameId,
                        "divergence",
                        names[i],
                        names[j],
                        string(abi.encodePacked(
                            names[i], " and ", names[j], " moving in opposite directions"
                        )),
                        7,
                        7500
                    );
                }
            }
        }
    }

    // ============ Pattern Creation ============

    function _createPattern(
        uint256 gameId,
        string memory patternType,
        string memory metricName,
        string memory metricName2,
        string memory description,
        uint256 severity,
        uint256 confidence
    ) internal {
        uint256 patternId = patternCount[gameId]++;

        gamePatterns[gameId].push(Pattern({
            patternId: patternId,
            gameId: gameId,
            patternType: patternType,
            metricName: metricName,
            metricName2: metricName2,
            description: description,
            severity: severity,
            confidence: confidence,
            detectedAt: block.timestamp,
            isActive: true,
            data: ""
        }));

        emit PatternDetected(gameId, patternId, patternType, description, severity);
    }

    // ============ Default Rules ============

    function _addRPGRules(uint256 gameId) internal {
        // Win rate spikes
        detectionRules[gameId].push(DetectionRule({
            ruleType: "spike",
            metricName: "win_rate",
            threshold: 2000, // 20% change
            period: 1,
            isActive: true
        }));
        ruleCount[gameId]++;

        // Retention drops
        detectionRules[gameId].push(DetectionRule({
            ruleType: "drop",
            metricName: "retention_d7",
            threshold: 1500, // 15% change
            period: 1,
            isActive: true
        }));
        ruleCount[gameId]++;

        // Token velocity trend
        detectionRules[gameId].push(DetectionRule({
            ruleType: "trend_up",
            metricName: "token_velocity",
            threshold: 5000, // 50% over period
            period: 7,
            isActive: true
        }));
        ruleCount[gameId]++;

        // Gold inflation trend
        detectionRules[gameId].push(DetectionRule({
            ruleType: "trend_up",
            metricName: "gold_inflation",
            threshold: 3000, // 30% over period
            period: 7,
            isActive: true
        }));
        ruleCount[gameId]++;
    }

    function _addCardGameRules(uint256 gameId) internal {
        // Meta dominance
        detectionRules[gameId].push(DetectionRule({
            ruleType: "spike",
            metricName: "meta_dominance",
            threshold: 1000, // 10% change
            period: 1,
            isActive: true
        }));
        ruleCount[gameId]++;

        // Pack EV drops
        detectionRules[gameId].push(DetectionRule({
            ruleType: "drop",
            metricName: "pack_ev",
            threshold: 2000, // 20% change
            period: 1,
            isActive: true
        }));
        ruleCount[gameId]++;
    }

    function _addStrategyRules(uint256 gameId) internal {
        // Resource inflation
        detectionRules[gameId].push(DetectionRule({
            ruleType: "trend_up",
            metricName: "resource_inflation",
            threshold: 3000, // 30% over period
            period: 7,
            isActive: true
        }));
        ruleCount[gameId]++;
    }

    function _addPvPRules(uint256 gameId) internal {
        // Queue time increases
        detectionRules[gameId].push(DetectionRule({
            ruleType: "trend_up",
            metricName: "queue_time",
            threshold: 5000, // 50% over period
            period: 7,
            isActive: true
        }));
        ruleCount[gameId]++;
    }

    // ============ View Functions ============

    /**
     * @notice Get all active patterns for a game
     */
    function getActivePatterns(uint256 gameId) external view returns (Pattern[] memory) {
        Pattern[] storage patterns = gamePatterns[gameId];
        uint256 activeCount = 0;

        for (uint256 i = 0; i < patterns.length; i++) {
            if (patterns[i].isActive) {
                activeCount++;
            }
        }

        Pattern[] memory result = new Pattern[](activeCount);
        uint256 idx = 0;
        for (uint256 i = 0; i < patterns.length; i++) {
            if (patterns[i].isActive) {
                result[idx++] = patterns[i];
            }
        }
        return result;
    }

    /**
     * @notice Get pattern by ID
     */
    function getPattern(uint256 gameId, uint256 patternId) external view returns (Pattern memory) {
        return gamePatterns[gameId][patternId];
    }

    /**
     * @notice Get pattern count
     */
    function getPatternCount(uint256 gameId) external view returns (uint256) {
        return patternCount[gameId];
    }

    // ============ Internal Helpers ============

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) { digits++; temp /= 10; }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    // ============ Admin ============

    /**
     * @notice Set game owner
     */
    function setGameOwner(uint256 gameId, address owner) external onlyOwner {
        gameOwners[gameId] = owner;
    }

    /**
     * @notice Deactivate a pattern
     */
    function deactivatePattern(uint256 gameId, uint256 patternId) external {
        require(gameOwners[gameId] == msg.sender, "Not game owner");
        gamePatterns[gameId][patternId].isActive = false;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MetricsRegistry
 * @notice Flexible metrics storage for Web3 game economies
 * @dev Data-driven approach: store metrics, detect patterns, learn from outcomes
 *
 *      Key insight: No universal formulas exist. Each game is unique.
 *      System tracks all metrics and learns what matters.
 */
contract MetricsRegistry is Ownable {

    // ============ Types ============

    struct MetricDefinition {
        string name;            // "win_rate", "token_velocity", "retention_d7"
        string dataType;        // "uint256", "bps", "percentage", "duration"
        string source;          // "on_chain", "off_chain", "manual", "calculated"
        uint256 healthyMin;     // Minimum healthy value (0 = no min)
        uint256 healthyMax;     // Maximum healthy value (0 = no max)
        bool isHigherBetter;    // true = higher is better
        bool isActive;
    }

    struct MetricValue {
        uint256 value;
        uint256 timestamp;
        uint256 blockNumber;
    }

    struct MetricStats {
        uint256 latest;
        uint256 min;
        uint256 max;
        uint256 avg;
        uint256 count;
        uint256 lastUpdated;
    }

    // ============ State ============

    // Metric definitions per game
    mapping(uint256 => mapping(string => MetricDefinition)) public metricDefs;
    mapping(uint256 => string[]) public metricNames;
    mapping(uint256 => uint256) public metricCount;

    // Metric values per game (stores last 100 values per metric)
    mapping(uint256 => mapping(string => MetricValue[])) public metricHistory;
    mapping(uint256 => mapping(string => MetricStats)) public metricStats;

    // Game owner mapping
    mapping(uint256 => address) public gameOwners;

    // Constants
    uint256 public constant MAX_HISTORY = 100;

    // ============ Events ============

    event MetricDefined(
        uint256 indexed gameId,
        string metricName,
        string dataType,
        string source
    );

    event MetricRecorded(
        uint256 indexed gameId,
        string metricName,
        uint256 value,
        uint256 timestamp
    );

    // ============ Constructor ============

    constructor(address initialOwner) Ownable(initialOwner) {}

    // ============ Metric Definition ============

    // Authorized callers (e.g., GameTypeManager)
    mapping(address => bool) public authorizedCallers;

    /**
     * @notice Authorize a caller to define metrics
     */
    function setAuthorizedCaller(address caller, bool authorized) external onlyOwner {
        authorizedCallers[caller] = authorized;
    }

    /**
     * @notice Define a new metric for a game
     */
    function defineMetric(
        uint256 gameId,
        string calldata name,
        string calldata dataType,
        string calldata source,
        uint256 healthyMin,
        uint256 healthyMax,
        bool isHigherBetter
    ) external {
        require(
            gameOwners[gameId] == msg.sender ||
            msg.sender == owner() ||
            authorizedCallers[msg.sender],
            "Not game owner"
        );
        _defineMetric(gameId, name, dataType, source, healthyMin, healthyMax, isHigherBetter);
    }

    /**
     * @notice Internal: Define a new metric for a game
     */
    function _defineMetric(
        uint256 gameId,
        string memory name,
        string memory dataType,
        string memory source,
        uint256 healthyMin,
        uint256 healthyMax,
        bool isHigherBetter
    ) internal {
        require(bytes(name).length > 0, "Name required");
        require(bytes(dataType).length > 0, "Data type required");

        metricDefs[gameId][name] = MetricDefinition({
            name: name,
            dataType: dataType,
            source: source,
            healthyMin: healthyMin,
            healthyMax: healthyMax,
            isHigherBetter: isHigherBetter,
            isActive: true
        });

        metricNames[gameId].push(name);
        metricCount[gameId]++;

        emit MetricDefined(gameId, name, dataType, source);
    }

    /**
     * @notice Define multiple metrics at once
     */
    function defineMetrics(
        uint256 gameId,
        string[] calldata names,
        string[] calldata dataTypes,
        string[] calldata sources,
        uint256[] calldata healthyMins,
        uint256[] calldata healthyMaxs,
        bool[] calldata isHigherBetters
    ) external {
        require(names.length == dataTypes.length, "Length mismatch");
        require(names.length == sources.length, "Length mismatch");

        for (uint256 i = 0; i < names.length; i++) {
            _defineMetric(
                gameId,
                names[i],
                dataTypes[i],
                sources[i],
                healthyMins[i],
                healthyMaxs[i],
                isHigherBetters[i]
            );
        }
    }

    // ============ Metric Recording ============

    /**
     * @notice Record a metric value
     * @param gameId Game ID
     * @param name Metric name
     * @param value Metric value
     */
    function recordMetric(
        uint256 gameId,
        string calldata name,
        uint256 value
    ) external {
        require(metricDefs[gameId][name].isActive, "Metric not defined");

        MetricValue memory newValue = MetricValue({
            value: value,
            timestamp: block.timestamp,
            blockNumber: block.number
        });

        // Add to history (with rotation)
        MetricValue[] storage history = metricHistory[gameId][name];
        if (history.length >= MAX_HISTORY) {
            // Rotate: remove oldest
            for (uint256 i = 0; i < history.length - 1; i++) {
                history[i] = history[i + 1];
            }
            history[history.length - 1] = newValue;
        } else {
            history.push(newValue);
        }

        // Update stats
        _updateStats(gameId, name, value);

        emit MetricRecorded(gameId, name, value, block.timestamp);
    }

    /**
     * @notice Record multiple metrics at once
     */
    function recordMetrics(
        uint256 gameId,
        string[] calldata names,
        uint256[] calldata values
    ) external {
        require(names.length == values.length, "Length mismatch");

        for (uint256 i = 0; i < names.length; i++) {
            this.recordMetric(gameId, names[i], values[i]);
        }
    }

    // ============ Internal Functions ============

    function _updateStats(
        uint256 gameId,
        string memory name,
        uint256 value
    ) internal {
        MetricStats storage stats = metricStats[gameId][name];

        stats.latest = value;
        stats.lastUpdated = block.timestamp;
        stats.count++;

        if (value < stats.min || stats.min == 0) {
            stats.min = value;
        }
        if (value > stats.max) {
            stats.max = value;
        }

        // Calculate running average
        if (stats.count == 1) {
            stats.avg = value;
        } else {
            stats.avg = ((stats.avg * (stats.count - 1)) + value) / stats.count;
        }
    }

    // ============ View Functions ============

    /**
     * @notice Get latest metric value
     */
    function getLatest(uint256 gameId, string calldata name) external view returns (uint256) {
        return metricStats[gameId][name].latest;
    }

    /**
     * @notice Get metric statistics
     */
    function getStats(uint256 gameId, string calldata name) external view returns (
        uint256 latest,
        uint256 min,
        uint256 max,
        uint256 avg,
        uint256 count,
        uint256 lastUpdated
    ) {
        MetricStats storage stats = metricStats[gameId][name];
        return (
            stats.latest,
            stats.min,
            stats.max,
            stats.avg,
            stats.count,
            stats.lastUpdated
        );
    }

    /**
     * @notice Get metric history
     */
    function getHistory(
        uint256 gameId,
        string calldata name,
        uint256 count
    ) external view returns (MetricValue[] memory) {
        MetricValue[] storage history = metricHistory[gameId][name];
        uint256 len = history.length;
        uint256 start = len > count ? len - count : 0;
        uint256 resultCount = len - start;

        MetricValue[] memory result = new MetricValue[](resultCount);
        for (uint256 i = 0; i < resultCount; i++) {
            result[i] = history[start + i];
        }
        return result;
    }

    /**
     * @notice Get all metric names for a game
     */
    function getMetricNames(uint256 gameId) external view returns (string[] memory) {
        return metricNames[gameId];
    }

    /**
     * @notice Get metric definition
     */
    function getMetricDef(uint256 gameId, string calldata name) external view returns (
        string memory dataType,
        string memory source,
        uint256 healthyMin,
        uint256 healthyMax,
        bool isHigherBetter,
        bool isActive
    ) {
        MetricDefinition storage def = metricDefs[gameId][name];
        return (
            def.dataType,
            def.source,
            def.healthyMin,
            def.healthyMax,
            def.isHigherBetter,
            def.isActive
        );
    }

    /**
     * @notice Check if metric is within healthy range
     */
    function isHealthy(uint256 gameId, string calldata name) external view returns (bool) {
        MetricDefinition storage def = metricDefs[gameId][name];
        uint256 latest = metricStats[gameId][name].latest;

        if (def.healthyMin > 0 && latest < def.healthyMin) {
            return false;
        }
        if (def.healthyMax > 0 && latest > def.healthyMax) {
            return false;
        }
        return true;
    }

    /**
     * @notice Calculate change percentage from previous value
     */
    function getChange(uint256 gameId, string calldata name) external view returns (int256) {
        MetricValue[] storage history = metricHistory[gameId][name];
        if (history.length < 2) {
            return 0;
        }

        uint256 current = history[history.length - 1].value;
        uint256 previous = history[history.length - 2].value;

        if (previous == 0) {
            return 0;
        }

        if (current >= previous) {
            return int256((current - previous) * 10000 / previous);
        } else {
            return -int256((previous - current) * 10000 / previous);
        }
    }

    /**
     * @notice Calculate moving average over last N values
     */
    function getMovingAverage(uint256 gameId, string calldata name, uint256 period) external view returns (uint256) {
        MetricValue[] storage history = metricHistory[gameId][name];
        if (history.length == 0) {
            return 0;
        }

        uint256 len = history.length;
        uint256 start = len > period ? len - period : 0;
        uint256 sum = 0;
        uint256 count = 0;

        for (uint256 i = start; i < len; i++) {
            sum += history[i].value;
            count++;
        }

        return count > 0 ? sum / count : 0;
    }

    // ============ Admin ============

    /**
     * @notice Set game owner
     */
    function setGameOwner(uint256 gameId, address owner) external onlyOwner {
        gameOwners[gameId] = owner;
    }

    /**
     * @notice Deactivate a metric
     */
    function deactivateMetric(uint256 gameId, string calldata name) external {
        require(gameOwners[gameId] == msg.sender, "Not game owner");
        metricDefs[gameId][name].isActive = false;
    }
}

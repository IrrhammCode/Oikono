// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./PatternDetector.sol";
import "./MetricsRegistry.sol";

/**
 * @title SuggestionEngine
 * @notice Generates suggestions based on detected patterns
 * @dev Learns from outcomes to improve future suggestions
 */
contract SuggestionEngine is Ownable {

    // ============ Types ============

    struct Suggestion {
        uint256 suggestionId;
        uint256 gameId;
        uint256 patternId;      // Related pattern
        string category;        // "economy", "balance", "content", "retention"
        string priority;        // "critical", "high", "medium", "low"
        string description;     // Human-readable description
        string action;          // Specific action to take
        uint256 confidence;     // 0-10000 (basis points)
        uint256 expectedImpact; // 0-10000 (basis points)
        bool implemented;
        uint256 implementedAt;
        bytes outcomeData;      // What happened after implementation
    }

    struct Outcome {
        uint256 suggestionId;
        bool success;
        uint256 impact;         // Measured impact (0-10000)
        string notes;           // Developer notes
        uint256 recordedAt;
    }

    struct SuggestionTemplate {
        string patternType;     // Pattern type this applies to
        string category;
        string priority;
        string descriptionTemplate;
        string actionTemplate;
        uint256 baseConfidence;
    }

    // ============ State ============

    PatternDetector public patternDetector;
    MetricsRegistry public metricsRegistry;

    // Suggestions per game
    mapping(uint256 => Suggestion[]) public gameSuggestions;
    mapping(uint256 => uint256) public suggestionCount;

    // Outcomes per suggestion
    mapping(uint256 => Outcome[]) public suggestionOutcomes;

    // Suggestion templates
    SuggestionTemplate[] public templates;

    // Learning: track success rates per pattern type
    mapping(string => uint256) public patternSuccessCount;
    mapping(string => uint256) public patternTotalCount;

    // Game owner mapping
    mapping(uint256 => address) public gameOwners;

    // ============ Events ============

    event SuggestionCreated(
        uint256 indexed gameId,
        uint256 indexed suggestionId,
        string category,
        string priority,
        string description
    );

    event SuggestionImplemented(
        uint256 indexed gameId,
        uint256 indexed suggestionId,
        uint256 implementedAt
    );

    event OutcomeRecorded(
        uint256 indexed suggestionId,
        bool success,
        uint256 impact
    );

    // ============ Constructor ============

    constructor(
        address _patternDetector,
        address _metricsRegistry,
        address initialOwner
    ) Ownable(initialOwner) {
        patternDetector = PatternDetector(_patternDetector);
        metricsRegistry = MetricsRegistry(_metricsRegistry);

        // Initialize default templates
        _initTemplates();
    }

    // ============ Suggestion Generation ============

    /**
     * @notice Generate suggestions based on current patterns
     */
    function generateSuggestions(uint256 gameId) external {
        require(
            gameOwners[gameId] == msg.sender || msg.sender == owner(),
            "Not authorized"
        );

        // Get active patterns
        PatternDetector.Pattern[] memory patterns = patternDetector.getActivePatterns(gameId);

        for (uint256 i = 0; i < patterns.length; i++) {
            _generateFromPattern(gameId, patterns[i]);
        }
    }

    /**
     * @notice Generate suggestion from a specific pattern
     */
    function _generateFromPattern(uint256 gameId, PatternDetector.Pattern memory pattern) internal {
        // Find matching template
        for (uint256 i = 0; i < templates.length; i++) {
            if (keccak256(bytes(templates[i].patternType)) == keccak256(bytes(pattern.patternType))) {
                // Calculate confidence based on historical success
                uint256 adjustedConfidence = _adjustConfidence(
                    pattern.patternType,
                    templates[i].baseConfidence
                );

                // Create suggestion
                uint256 suggestionId = suggestionCount[gameId]++;

                gameSuggestions[gameId].push(Suggestion({
                    suggestionId: suggestionId,
                    gameId: gameId,
                    patternId: pattern.patternId,
                    category: templates[i].category,
                    priority: templates[i].priority,
                    description: _buildDescription(templates[i].descriptionTemplate, pattern),
                    action: _buildAction(templates[i].actionTemplate, pattern),
                    confidence: adjustedConfidence,
                    expectedImpact: _estimateImpact(pattern),
                    implemented: false,
                    implementedAt: 0,
                    outcomeData: ""
                }));

                emit SuggestionCreated(
                    gameId,
                    suggestionId,
                    templates[i].category,
                    templates[i].priority,
                    _buildDescription(templates[i].descriptionTemplate, pattern)
                );
            }
        }
    }

    // ============ Outcome Tracking ============

    /**
     * @notice Mark a suggestion as implemented
     */
    function markImplemented(uint256 gameId, uint256 suggestionId) external {
        require(gameOwners[gameId] == msg.sender, "Not game owner");

        Suggestion storage suggestion = gameSuggestions[gameId][suggestionId];
        require(!suggestion.implemented, "Already implemented");

        suggestion.implemented = true;
        suggestion.implementedAt = block.timestamp;

        emit SuggestionImplemented(gameId, suggestionId, block.timestamp);
    }

    /**
     * @notice Record outcome of an implemented suggestion
     */
    function recordOutcome(
        uint256 gameId,
        uint256 suggestionId,
        bool success,
        uint256 impact,
        string calldata notes
    ) external {
        require(gameOwners[gameId] == msg.sender, "Not game owner");

        Suggestion storage suggestion = gameSuggestions[gameId][suggestionId];
        require(suggestion.implemented, "Not implemented");
        require(suggestion.outcomeData.length == 0, "Outcome already recorded");

        // Store outcome
        suggestionOutcomes[suggestionId].push(Outcome({
            suggestionId: suggestionId,
            success: success,
            impact: impact,
            notes: notes,
            recordedAt: block.timestamp
        }));

        // Update suggestion
        suggestion.outcomeData = abi.encode(success, impact, notes);

        // Update learning stats
        patternTotalCount[suggestion.category]++;
        if (success) {
            patternSuccessCount[suggestion.category]++;
        }

        emit OutcomeRecorded(suggestionId, success, impact);
    }

    // ============ Learning Functions ============

    /**
     * @notice Adjust confidence based on historical success
     */
    function _adjustConfidence(
        string memory patternType,
        uint256 baseConfidence
    ) internal view returns (uint256) {
        uint256 total = patternTotalCount[patternType];
        if (total == 0) {
            return baseConfidence;
        }

        uint256 successRate = (patternSuccessCount[patternType] * 10000) / total;

        // Adjust confidence: if success rate is high, increase confidence
        // If success rate is low, decrease confidence
        if (successRate > 7000) {
            // High success rate: increase confidence by up to 20%
            return baseConfidence + (baseConfidence * 2000 / 10000);
        } else if (successRate < 3000) {
            // Low success rate: decrease confidence by up to 30%
            return baseConfidence - (baseConfidence * 3000 / 10000);
        }

        return baseConfidence;
    }

    /**
     * @notice Estimate impact based on pattern severity
     */
    function _estimateImpact(PatternDetector.Pattern memory pattern) internal pure returns (uint256) {
        // Higher severity = higher expected impact
        return pattern.severity * 1000; // 1-10 → 1000-10000
    }

    // ============ Template Functions ============

    function _initTemplates() internal {
        // Anomaly templates
        templates.push(SuggestionTemplate({
            patternType: "anomaly",
            category: "economy",
            priority: "high",
            descriptionTemplate: "Detected anomaly in {metric}: {description}",
            actionTemplate: "Investigate {metric} and consider adjusting related parameters",
            baseConfidence: 7000
        }));

        // Trend templates
        templates.push(SuggestionTemplate({
            patternType: "trend",
            category: "balance",
            priority: "medium",
            descriptionTemplate: "Trend detected in {metric}: {description}",
            actionTemplate: "Monitor trend and consider intervention if it continues",
            baseConfidence: 6000
        }));

        // Divergence templates
        templates.push(SuggestionTemplate({
            patternType: "divergence",
            category: "balance",
            priority: "high",
            descriptionTemplate: "Metrics moving in opposite directions: {description}",
            actionTemplate: "Analyze relationship between metrics and adjust game balance",
            baseConfidence: 7500
        }));
    }

    /**
     * @notice Build description from template
     */
    function _buildDescription(
        string memory template,
        PatternDetector.Pattern memory pattern
    ) internal pure returns (string memory) {
        // Simplified: just use pattern description
        return pattern.description;
    }

    /**
     * @notice Build action from template
     */
    function _buildAction(
        string memory template,
        PatternDetector.Pattern memory pattern
    ) internal pure returns (string memory) {
        // Simplified: just use template
        return template;
    }

    // ============ View Functions ============

    /**
     * @notice Get all suggestions for a game
     */
    function getSuggestions(uint256 gameId) external view returns (Suggestion[] memory) {
        return gameSuggestions[gameId];
    }

    /**
     * @notice Get active (non-implemented) suggestions
     */
    function getActiveSuggestions(uint256 gameId) external view returns (Suggestion[] memory) {
        Suggestion[] storage suggestions = gameSuggestions[gameId];
        uint256 activeCount = 0;

        for (uint256 i = 0; i < suggestions.length; i++) {
            if (!suggestions[i].implemented) {
                activeCount++;
            }
        }

        Suggestion[] memory result = new Suggestion[](activeCount);
        uint256 idx = 0;
        for (uint256 i = 0; i < suggestions.length; i++) {
            if (!suggestions[i].implemented) {
                result[idx++] = suggestions[i];
            }
        }
        return result;
    }

    /**
     * @notice Get suggestion by ID
     */
    function getSuggestion(uint256 gameId, uint256 suggestionId) external view returns (Suggestion memory) {
        return gameSuggestions[gameId][suggestionId];
    }

    /**
     * @notice Get outcomes for a suggestion
     */
    function getOutcomes(uint256 suggestionId) external view returns (Outcome[] memory) {
        return suggestionOutcomes[suggestionId];
    }

    /**
     * @notice Get success rate for a category
     */
    function getSuccessRate(string calldata category) external view returns (uint256) {
        uint256 total = patternTotalCount[category];
        if (total == 0) return 0;
        return (patternSuccessCount[category] * 10000) / total;
    }

    /**
     * @notice Get suggestion count
     */
    function getSuggestionCount(uint256 gameId) external view returns (uint256) {
        return suggestionCount[gameId];
    }

    // ============ Admin ============

    /**
     * @notice Set game owner
     */
    function setGameOwner(uint256 gameId, address owner) external onlyOwner {
        gameOwners[gameId] = owner;
    }

    /**
     * @notice Add custom template
     */
    function addTemplate(
        string calldata patternType,
        string calldata category,
        string calldata priority,
        string calldata descriptionTemplate,
        string calldata actionTemplate,
        uint256 baseConfidence
    ) external onlyOwner {
        templates.push(SuggestionTemplate({
            patternType: patternType,
            category: category,
            priority: priority,
            descriptionTemplate: descriptionTemplate,
            actionTemplate: actionTemplate,
            baseConfidence: baseConfidence
        }));
    }
}

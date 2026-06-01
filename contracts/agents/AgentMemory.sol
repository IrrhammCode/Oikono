// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AgentMemory
 * @notice On-chain learning memory for OIKONO AI Agent
 * @dev Stores decision history, outcomes, and learned patterns per game.
 *      The agent uses this to:
 *      - Learn from past decisions (what worked, what didn't)
 *      - Build game-specific knowledge over time
 *      - Share patterns across similar games
 *      - Improve decision quality autonomously
 *
 *      This is the "brain" that makes OIKONO smarter over time.
 */
contract AgentMemory is Ownable {

    // ============ Types ============

    struct Decision {
        address game;
        address player;
        string decisionType;    // "spawn", "economy", "balance", "narrative"
        bytes inputData;        // Context when decision was made
        bool success;           // Did the decision achieve its goal?
        bytes outputData;       // What the agent did
        uint256 timestamp;
        uint256 blockNumber;
    }

    struct GameStats {
        uint256 totalDecisions;
        uint256 successfulDecisions;
        uint256 failedDecisions;
        uint256 lastDecisionBlock;
        uint256 averageConfidence;
    }

    struct LearnedPattern {
        string patternType;     // "high_win_rate", "low_velocity", "player_churn", etc.
        bytes patternData;      // Encoded pattern specifics
        uint256 confidence;     // 0-10000 (basis points)
        uint256 occurrences;    // How many times this pattern was observed
        uint256 lastSeen;
        bool isActive;
    }

    struct GameKnowledge {
        string gameType;
        uint256 optimalWinRate;      // Learned optimal win rate (bps)
        uint256 optimalVelocity;     // Learned optimal token velocity
        uint256 difficultyCurve;     // Learned difficulty scaling factor
        uint256 rewardCurve;         // Learned reward scaling factor
        uint256 lastUpdated;
    }

    // ============ State ============

    // Per-game decision history
    mapping(address => Decision[]) public gameDecisions;
    mapping(address => GameStats) public gameStats;

    // Per-game learned patterns
    mapping(address => LearnedPattern[]) public gamePatterns;
    mapping(address => mapping(bytes32 => uint256)) public patternIndex; // pattern hash → index

    // Cross-game knowledge base
    mapping(string => GameKnowledge) public knowledgeBase; // gameType → knowledge

    // Global stats
    uint256 public totalMemories;
    uint256 public totalPatterns;
    uint256 public totalGames;

    // Memory limits
    uint256 public constant MAX_DECISIONS_PER_GAME = 1000;
    uint256 public constant MAX_PATTERNS_PER_GAME = 50;

    // ============ Events ============

    event DecisionRecorded(
        address indexed game,
        string decisionType,
        bool success
    );
    event PatternLearned(
        address indexed game,
        string patternType,
        uint256 confidence
    );
    event KnowledgeUpdated(
        string gameType,
        string field,
        uint256 newValue
    );
    event MemoryConsolidated(
        address indexed game,
        uint256 decisionsAnalyzed,
        uint256 patternsFound
    );

    // ============ Constructor ============

    constructor(address initialOwner) Ownable(initialOwner) {}

    // ============ Decision Recording ============

    /**
     * @notice Record a decision and its outcome
     * @dev Called by OikonoAgent after each autonomous action
     */
    function recordDecision(
        address game,
        address player,
        string calldata decisionType,
        bytes calldata inputData,
        bool success,
        bytes calldata outputData
    ) external {
        Decision memory decision = Decision({
            game: game,
            player: player,
            decisionType: decisionType,
            inputData: inputData,
            success: success,
            outputData: outputData,
            timestamp: block.timestamp,
            blockNumber: block.number
        });

        // Store decision (with rotation if limit reached)
        if (gameDecisions[game].length >= MAX_DECISIONS_PER_GAME) {
            // Rotate: remove oldest, add newest
            for (uint256 i = 0; i < MAX_DECISIONS_PER_GAME - 1; i++) {
                gameDecisions[game][i] = gameDecisions[game][i + 1];
            }
            gameDecisions[game][MAX_DECISIONS_PER_GAME - 1] = decision;
        } else {
            gameDecisions[game].push(decision);
        }

        // Update stats
        GameStats storage stats = gameStats[game];
        stats.totalDecisions++;
        if (success) {
            stats.successfulDecisions++;
        } else {
            stats.failedDecisions++;
        }
        stats.lastDecisionBlock = block.number;

        totalMemories++;

        emit DecisionRecorded(game, decisionType, success);

        // Auto-learn patterns every 10 decisions
        if (stats.totalDecisions % 10 == 0) {
            _analyzeAndLearn(game);
        }
    }

    // ============ Pattern Learning ============

    /**
     * @notice Analyze recent decisions and learn patterns
     * @dev Automatically called after every 10 decisions
     *      Identifies patterns like:
     *      - "spawn_challenging" works better when win rate > 70%
     *      - Players churn when difficulty spikes > 20%
     *      - Economy stabilizes when burn rate matches velocity
     */
    function _analyzeAndLearn(address game) internal {
        GameStats storage stats = gameStats[game];
        Decision[] storage decisions = gameDecisions[game];

        if (decisions.length < 5) return; // Need minimum data

        // Analyze last 10 decisions
        uint256 startIdx = decisions.length > 10 ? decisions.length - 10 : 0;

        // Analyze decisions by type and learn patterns
        for (uint256 i = startIdx; i < decisions.length; i++) {
            Decision storage d = decisions[i];
            bytes32 typeHash = keccak256(bytes(d.decisionType));
            _recordPatternObservation(game, typeHash, d.success);
        }

        // Consolidate patterns
        _consolidatePatterns(game);

        emit MemoryConsolidated(
            game,
            decisions.length - startIdx,
            gamePatterns[game].length
        );
    }

    /**
     * @notice Record a pattern observation
     */
    function _recordPatternObservation(
        address game,
        bytes32 typeHash,
        bool success
    ) internal {
        uint256 idx = patternIndex[game][typeHash];

        if (idx == 0 && gamePatterns[game].length == 0) {
            // New pattern
            LearnedPattern memory pattern = LearnedPattern({
                patternType: _typeHashToString(typeHash),
                patternData: abi.encode(typeHash),
                confidence: success ? 6000 : 4000,
                occurrences: 1,
                lastSeen: block.timestamp,
                isActive: true
            });

            if (gamePatterns[game].length < MAX_PATTERNS_PER_GAME) {
                gamePatterns[game].push(pattern);
                patternIndex[game][typeHash] = gamePatterns[game].length;
                totalPatterns++;
            }
        } else {
            // Update existing pattern
            uint256 patternIdx = idx > 0 ? idx - 1 : 0;
            LearnedPattern storage pattern = gamePatterns[game][patternIdx];

            pattern.occurrences++;

            // Update confidence based on success/failure
            if (success) {
                pattern.confidence = pattern.confidence + ((10000 - pattern.confidence) / 10);
            } else {
                pattern.confidence = pattern.confidence - (pattern.confidence / 10);
            }

            pattern.lastSeen = block.timestamp;

            emit PatternLearned(game, pattern.patternType, pattern.confidence);
        }
    }

    /**
     * @notice Consolidate patterns into actionable knowledge
     */
    function _consolidatePatterns(address game) internal {
        LearnedPattern[] storage patterns = gamePatterns[game];
        GameStats storage stats = gameStats[game];

        // Calculate overall success rate
        uint256 successRate = stats.totalDecisions > 0
            ? (stats.successfulDecisions * 10000) / stats.totalDecisions
            : 5000;

        // Find high-confidence patterns
        for (uint256 i = 0; i < patterns.length; i++) {
            LearnedPattern storage p = patterns[i];

            if (p.confidence > 8000 && p.occurrences >= 3) {
                // High confidence pattern — update knowledge base
                string memory gameType = gameTypes[game];

                if (bytes(gameType).length > 0) {
                    _updateKnowledge(gameType, p.patternType, p.confidence);
                }
            }
        }
    }

    // ============ Knowledge Base ============

    /**
     * @notice Update cross-game knowledge
     */
    function _updateKnowledge(
        string memory gameType,
        string memory patternType,
        uint256 confidence
    ) internal {
        GameKnowledge storage kb = knowledgeBase[gameType];

        if (bytes(kb.gameType).length == 0) {
            kb.gameType = gameType;
            totalGames++;
        }

        // Update relevant knowledge field
        if (keccak256(bytes(patternType)) == keccak256(bytes("spawn"))) {
            kb.difficultyCurve = confidence;
        } else if (keccak256(bytes(patternType)) == keccak256(bytes("economy"))) {
            kb.rewardCurve = confidence;
        } else if (keccak256(bytes(patternType)) == keccak256(bytes("balance"))) {
            kb.optimalWinRate = confidence;
        }

        kb.lastUpdated = block.timestamp;

        emit KnowledgeUpdated(gameType, patternType, confidence);
    }

    // ============ Query Functions ============

    /**
     * @notice Get a specific memory (decision)
     */
    function getMemory(address game, uint256 index) external view returns (
        address player,
        string memory decisionType,
        bytes memory inputData,
        bool success,
        bytes memory outputData
    ) {
        Decision storage d = gameDecisions[game][index];
        return (d.player, d.decisionType, d.inputData, d.success, d.outputData);
    }

    /**
     * @notice Get game stats
     */
    function getGameStats(address game) external view returns (
        uint256 totalDecisions,
        uint256 successfulDecisions,
        uint256 failedDecisions,
        uint256 successRate
    ) {
        GameStats storage stats = gameStats[game];
        uint256 rate = stats.totalDecisions > 0
            ? (stats.successfulDecisions * 10000) / stats.totalDecisions
            : 0;
        return (
            stats.totalDecisions,
            stats.successfulDecisions,
            stats.failedDecisions,
            rate
        );
    }

    /**
     * @notice Get learned patterns for a game
     */
    function getPatterns(address game) external view returns (
        string[] memory patternTypes,
        uint256[] memory confidences,
        uint256[] memory occurrences
    ) {
        LearnedPattern[] storage patterns = gamePatterns[game];
        uint256 len = patterns.length;

        patternTypes = new string[](len);
        confidences = new uint256[](len);
        occurrences = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            patternTypes[i] = patterns[i].patternType;
            confidences[i] = patterns[i].confidence;
            occurrences[i] = patterns[i].occurrences;
        }
    }

    /**
     * @notice Get cross-game knowledge
     */
    function getKnowledge(string calldata gameType) external view returns (
        uint256 optimalWinRate,
        uint256 optimalVelocity,
        uint256 difficultyCurve,
        uint256 rewardCurve,
        uint256 lastUpdated
    ) {
        GameKnowledge storage kb = knowledgeBase[gameType];
        return (
            kb.optimalWinRate,
            kb.optimalVelocity,
            kb.difficultyCurve,
            kb.rewardCurve,
            kb.lastUpdated
        );
    }

    /**
     * @notice Get the last N decisions for a game
     */
    function getRecentDecisions(address game, uint256 count) external view returns (
        Decision[] memory
    ) {
        Decision[] storage decisions = gameDecisions[game];
        uint256 len = decisions.length;
        uint256 startIdx = len > count ? len - count : 0;
        uint256 resultCount = len - startIdx;

        Decision[] memory result = new Decision[](resultCount);
        for (uint256 i = 0; i < resultCount; i++) {
            result[i] = decisions[startIdx + i];
        }
        return result;
    }

    // ============ Admin ============

    /**
     * @notice Manually set knowledge (for bootstrapping)
     */
    function setKnowledge(
        string calldata gameType,
        uint256 optimalWinRate,
        uint256 optimalVelocity,
        uint256 difficultyCurve,
        uint256 rewardCurve
    ) external onlyOwner {
        knowledgeBase[gameType] = GameKnowledge({
            gameType: gameType,
            optimalWinRate: optimalWinRate,
            optimalVelocity: optimalVelocity,
            difficultyCurve: difficultyCurve,
            rewardCurve: rewardCurve,
            lastUpdated: block.timestamp
        });
        totalGames++;
    }

    // ============ Helpers ============

    // Store game type for each game (needed for knowledge lookup)
    mapping(address => string) internal gameContexts_gameType;

    struct GameContextRef {
        string gameType;
    }

    // We need access to game contexts from OikonoAgent
    // In production, this would be via a shared registry
    // For now, store game type when recording decisions
    mapping(address => string) public gameTypes;

    function setGameType(address game, string calldata gameType) external onlyOwner {
        gameTypes[game] = gameType;
    }

    function _typeHashToString(bytes32 hash) internal pure returns (string memory) {
        if (hash == keccak256(bytes("spawn"))) return "spawn";
        if (hash == keccak256(bytes("economy"))) return "economy";
        if (hash == keccak256(bytes("balance"))) return "balance";
        if (hash == keccak256(bytes("narrative"))) return "narrative";
        return "unknown";
    }
}

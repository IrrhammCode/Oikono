// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./core/AgentTypes.sol";
import "./core/IGameDescriptor.sol";
import "./core/IGameStateReader.sol";
import "./core/IAgentPlugin.sol";
import "./core/AgentRuntime.sol";
import "./AgentMemory.sol";
import "./GameKnowledgeBase.sol";

/**
 * @title ICircuitBreaker
 * @notice Interface for CircuitBreaker contract
 */
interface ICircuitBreaker {
    function paused() external view returns (bool);
    function voteToPause() external;
    function emergencyPause() external;
}

/**
 * @title IGameRegistry
 * @notice Interface for GameRegistry
 */
interface IGameRegistry {
    function games(uint256 gameId) external view returns (
        uint256 gameId_, address gameAddress, address owner,
        string memory name, string memory gameType, string memory description,
        bool isActive, bool isVerified, uint256 registeredAt,
        uint256 lastActivity, uint256 totalEvents, uint256 totalActions
    );
    function gameByAddress(address gameAddress) external view returns (uint256);
    function recordEvent(uint256 gameId) external;
    function recordAction(uint256 gameId, bool success) external;
    function isGameTypeSupported(string calldata gameType) external view returns (bool);
}

/**
 * @title OikonoAgent
 * @notice The BRAIN of OIKONO — autonomous AI agent for all Web3 games
 * @dev This is the contract games call to get intelligent, autonomous behavior.
 *
 *      Flow:
 *      1. Game registers in GameRegistry
 *      2. Game emits events or calls requestAction()
 *      3. Agent reads game state (IGameStateReader)
 *      4. Agent reads its memory (AgentMemory — learned patterns)
 *      5. Agent builds rich context from all data
 *      6. Agent calls Somnia LLM Inference with context
 *      7. LLM response parsed → agent executes appropriate plugin
 *      8. Result stored in memory for future learning
 *
 *      Developers just register their game. Agent handles everything.
 */
contract OikonoAgent is Ownable {

    // ============ Somnia Constants ============
    address public constant SOMNIA_PLATFORM = address(0x401);
    address public constant REACTIVITY_PRECOMPILE = address(0x100);
    address public constant AGENT_REQUESTER = address(0x200);
    uint256 public constant LLM_INFERENCE_AGENT_ID = 12847293847561029384;

    // ============ Dependencies ============
    AgentRuntime public runtime;
    AgentMemory public memory_;
    GameKnowledgeBase public knowledgeBase;
    address public circuitBreaker;
    IGameRegistry public gameRegistry;

    // LLM Mode: true = use Somnia LLM Agent, false = use rule-based fallback
    bool public useLLMAgent;

    // ============ Game Context Cache ============
    struct GameContext {
        address gameAddress;
        string gameType;
        string[] goals;
        uint256[] goalWeights;
        bool canSpawn;
        bool canAdjustEconomy;
        bool canGenerateNarrative;
        bool canAdjustDifficulty;
        uint256 lastAnalysisBlock;
        uint256 analysisCount;
    }

    mapping(address => GameContext) public gameContexts;

    // ============ Pending LLM Requests ============
    struct PendingDecision {
        address game;
        address player;
        string decisionType; // "spawn", "economy", "balance", "narrative"
        bytes contextData;
        bytes gameState;
        bytes memoryData;
        uint256 timestamp;
        bool processed;
    }

    mapping(uint256 => PendingDecision) public pendingDecisions;
    uint256 public nextDecisionId;

    // ============ Stats ============
    uint256 public totalDecisions;
    uint256 public totalLLMCalls;
    uint256 public totalAutoActions;

    // ============ Events ============
    event DecisionRequested(
        uint256 indexed decisionId,
        address indexed game,
        string decisionType,
        string promptSummary
    );
    event DecisionExecuted(
        uint256 indexed decisionId,
        address indexed game,
        string action,
        bool success
    );
    event AgentActionTaken(
        address indexed game,
        string actionType,
        string description
    );
    event ContextBuilt(
        address indexed game,
        uint256 stateSize,
        uint256 memorySize
    );

    // ============ Modifiers ============

    modifier whenSystemActive() {
        require(circuitBreaker == address(0) || !ICircuitBreaker(circuitBreaker).paused(), "System paused by circuit breaker");
        _;
    }

    // ============ Constructor ============

    constructor(
        address _runtime,
        address _memory,
        address _knowledgeBase,
        address _circuitBreaker
    ) Ownable(msg.sender) {
        runtime = AgentRuntime(_runtime);
        memory_ = AgentMemory(_memory);
        knowledgeBase = GameKnowledgeBase(_knowledgeBase);
        circuitBreaker = _circuitBreaker;
    }

    /**
     * @notice Toggle LLM Agent mode
     * @param _useLLM true = use Somnia LLM Agent, false = use rule-based fallback
     */
    function setLLMMode(bool _useLLM) external onlyOwner {
        useLLMAgent = _useLLM;
    }

    /**
     * @notice Set GameRegistry reference
     */
    function setGameRegistry(address _registry) external onlyOwner {
        gameRegistry = IGameRegistry(_registry);
    }

    // ============ Game Action Request ============

    /**
     * @notice Games call this to request agent action
     * @param gameId Game ID in registry
     * @param actionType Type of action: "spawn", "economy", "balance", "narrative"
     * @param gameData Encoded game state data
     */
    function requestAction(
        uint256 gameId,
        string calldata actionType,
        bytes calldata gameData
    ) external whenSystemActive returns (uint256 decisionId) {
        // Verify game is registered and active
        require(address(gameRegistry) != address(0), "Registry not set");
        (, address gameAddress, , , , , bool isActive, , , , , ) = gameRegistry.games(gameId);
        require(isActive, "Game not active");
        require(gameAddress == msg.sender || gameRegistry.gameByAddress(msg.sender) == gameId, "Not authorized");

        // Build context
        bytes memory contextData = abi.encode(gameId, block.number, block.timestamp, gameData);

        // Read memories (use empty topics for manual requests)
        bytes32[] memory emptyTopics = new bytes32[](0);
        bytes memory memoryData = _readRelevantMemories(gameAddress, emptyTopics);

        // Store decision
        decisionId = nextDecisionId++;
        pendingDecisions[decisionId] = PendingDecision({
            game: gameAddress,
            player: address(0),
            decisionType: actionType,
            contextData: contextData,
            gameState: gameData,
            memoryData: memoryData,
            timestamp: block.timestamp,
            processed: false
        });

        // Build prompt
        string memory prompt = _buildLLMPrompt(gameAddress, actionType, contextData, gameData, memoryData);

        emit DecisionRequested(decisionId, gameAddress, actionType, _truncate(prompt, 100));

        // Execute decision
        _executeDecision(decisionId, gameAddress, actionType, contextData, gameData);

        // Record in registry
        try gameRegistry.recordEvent(gameId) {} catch {}

        totalDecisions++;
    }

    /**
     * @notice Report action outcome (for learning)
     * @param decisionId Decision ID from requestAction
     * @param success Whether the action succeeded
     * @param resultData Encoded result data
     */
    function reportOutcome(
        uint256 decisionId,
        bool success,
        bytes calldata resultData
    ) external whenSystemActive {
        PendingDecision storage decision = pendingDecisions[decisionId];
        require(!decision.processed, "Already processed");

        // Record in memory for learning
        memory_.recordDecision(
            decision.game,
            decision.player,
            decision.decisionType,
            decision.contextData,
            success,
            resultData
        );

        decision.processed = true;

        // Record in registry
        uint256 gameId = gameRegistry.gameByAddress(decision.game);
        if (gameId > 0) {
            try gameRegistry.recordAction(gameId, success) {} catch {}
        }

        totalAutoActions++;
    }

    // ============ Autonomous Event Handler ============

    /**
     * @notice Handle on-chain events from Somnia validators
     * @dev This is the main entry point for autonomous behavior.
     *      When a game event fires, the agent:
     *      1. Reads full game state
     *      2. Reads relevant memories
     *      3. Builds context
     *      4. Decides what to do
     *      5. Does it
     *      6. Learns from the result
     */
    function _onEvent(
        address emitter,
        bytes32[] calldata topics,
        bytes calldata data
    ) external {
        // Only Somnia validators
        require(
            msg.sender == address(0x100) || msg.sender == REACTIVITY_PRECOMPILE,
            "Only Somnia validators"
        );

        // Get or build game context
        GameContext storage ctx = gameContexts[emitter];
        if (ctx.gameAddress == address(0)) {
            // First time seeing this game — try to auto-discover
            _discoverGame(emitter);
            ctx = gameContexts[emitter];
        }

        // Build full context for decision
        bytes memory contextData = _buildContext(emitter, topics, data);

        // Read game state if available
        bytes memory gameState = new bytes(0);
        if (ctx.gameAddress != address(0)) {
            gameState = _readGameState(emitter);
        }

        // Read relevant memories
        bytes memory memoryData = _readRelevantMemories(emitter, topics);

        // Determine what kind of decision this is
        string memory decisionType = _determineDecisionType(topics, data, ctx);

        // Store pending decision
        uint256 decisionId = nextDecisionId++;
        pendingDecisions[decisionId] = PendingDecision({
            game: emitter,
            player: _extractPlayerFromData(data),
            decisionType: decisionType,
            contextData: contextData,
            gameState: gameState,
            memoryData: memoryData,
            timestamp: block.timestamp,
            processed: false
        });

        // Build LLM prompt with full context
        string memory prompt = _buildLLMPrompt(emitter, decisionType, contextData, gameState, memoryData);

        emit DecisionRequested(decisionId, emitter, decisionType, _truncate(prompt, 100));

        if (useLLMAgent) {
            // Production: Call Somnia LLM Agent
            bytes memory payload = abi.encodeWithSelector(
                ILLMAgent.inferString.selector,
                prompt,
                "chainOfThought"
            );
            uint256 deposit = IAgentRequester(AGENT_REQUESTER).getRequestDeposit(LLM_INFERENCE_AGENT_ID);
            IAgentRequester(AGENT_REQUESTER).createRequest{value: deposit}(
                LLM_INFERENCE_AGENT_ID,
                payload,
                this.handleLLMResponse.selector
            );
            totalLLMCalls++;
        } else {
            // Fallback: Execute rule-based decision
            _executeDecision(decisionId, emitter, decisionType, contextData, gameState);
        }

        totalDecisions++;
        ctx.lastAnalysisBlock = block.number;
        ctx.analysisCount++;
    }

    // ============ Game Discovery ============

    /**
     * @notice Discover a game's capabilities via IGameDescriptor
     */
    function _discoverGame(address gameAddress) internal {
        try IGameDescriptor(gameAddress).getGameIdentity() returns (
            string memory name,
            string memory /* version */,
            string memory gameType
        ) {
            (bool canSpawn, bool canAdjustEconomy, bool canGenerateNarrative,
             bool canAdjustDifficulty, ) = IGameDescriptor(gameAddress).getAgentPermissions();

            (string[] memory goals, uint256[] memory goalWeights) = IGameDescriptor(gameAddress).getGoals();

            gameContexts[gameAddress] = GameContext({
                gameAddress: gameAddress,
                gameType: gameType,
                goals: goals,
                goalWeights: goalWeights,
                canSpawn: canSpawn,
                canAdjustEconomy: canAdjustEconomy,
                canGenerateNarrative: canGenerateNarrative,
                canAdjustDifficulty: canAdjustDifficulty,
                lastAnalysisBlock: 0,
                analysisCount: 0
            });

            // Bootstrap from KnowledgeBase
            try knowledgeBase.recordGame(gameType) {} catch {}
        } catch {
            // Game doesn't implement IGameDescriptor — use defaults
            gameContexts[gameAddress] = GameContext({
                gameAddress: gameAddress,
                gameType: "unknown",
                goals: new string[](0),
                goalWeights: new uint256[](0),
                canSpawn: true,
                canAdjustEconomy: false,
                canGenerateNarrative: false,
                canAdjustDifficulty: false,
                lastAnalysisBlock: 0,
                analysisCount: 0
            });
        }
    }

    // ============ Context Building ============

    /**
     * @notice Build rich context from event data
     */
    function _buildContext(
        address game,
        bytes32[] calldata topics,
        bytes calldata data
    ) internal view returns (bytes memory) {
        return abi.encode(
            game,
            block.number,
            block.timestamp,
            topics,
            data
        );
    }

    /**
     * @notice Read game state via IGameStateReader
     */
    function _readGameState(address game) internal returns (bytes memory) {
        try IGameStateReader(game).getGameState() returns (
            uint256 totalPlayers,
            uint256 activePlayers,
            uint256 totalEntities,
            uint256[] memory globalStats
        ) {
            emit ContextBuilt(game, 0, 0);
            return abi.encode(totalPlayers, activePlayers, totalEntities, globalStats);
        } catch {
            return new bytes(0);
        }
    }

    /**
     * @notice Read relevant memories from AgentMemory
     */
    function _readRelevantMemories(
        address game,
        bytes32[] memory /* topics */
    ) internal view returns (bytes memory) {
        // Query memory for this game's past decisions
        (uint256 totalMemories, , , ) = memory_.getGameStats(game);

        if (totalMemories == 0) {
            return new bytes(0);
        }

        // Get last 5 memories for context
        uint256 startIdx = totalMemories > 5 ? totalMemories - 5 : 0;
        bytes[] memory recentMemories = new bytes[](totalMemories - startIdx);

        for (uint256 i = startIdx; i < totalMemories; i++) {
            (, , bytes memory data, bool memSuccess, ) = memory_.getMemory(game, i);
            recentMemories[i - startIdx] = abi.encode(data, memSuccess);
        }

        return abi.encode(recentMemories);
    }

    // ============ Decision Making ============

    /**
     * @notice Determine what kind of decision the agent should make
     */
    function _determineDecisionType(
        bytes32[] calldata topics,
        bytes calldata data,
        GameContext storage ctx
    ) internal view returns (string memory) {
        // Analyze topics/data to determine action type
        if (topics.length > 0) {
            bytes32 sig = topics[0];

            // PlayerMoved → spawn
            if (sig == keccak256("PlayerMoved(address,uint256,uint256,uint256,uint256)")) {
                if (ctx.canSpawn) return "spawn";
            }

            // BattleEnded → balance check
            if (sig == keccak256("BattleEnded(address,uint256,bool,uint256,uint256)")) {
                if (ctx.canAdjustDifficulty) return "balance";
            }

            // Transfer/swap → economy check
            if (sig == keccak256("Transfer(address,address,uint256)")) {
                if (ctx.canAdjustEconomy) return "economy";
            }
        }

        // Default: analyze game state
        return "analyze";
    }

    /**
     * @notice Build the LLM prompt with full context
     * @dev Requests pipe-separated response for gas-efficient on-chain parsing
     */
    function _buildLLMPrompt(
        address game,
        string memory decisionType,
        bytes memory contextData,
        bytes memory gameState,
        bytes memory memoryData
    ) internal view returns (string memory) {
        GameContext storage ctx = gameContexts[game];

        return string(abi.encodePacked(
            "You are OIKONO, an autonomous AI agent managing a Web3 game.\n",
            "Game: ", ctx.gameType, ". Decision type: ", decisionType, ".\n",
            "Context size: ", _toString(contextData.length), " bytes. ",
            "State size: ", _toString(gameState.length), " bytes. ",
            "Memory entries: ", _toString(memoryData.length > 0 ? 1 : 0), ".\n",
            "Analyze and recommend an action.\n\n",
            "RESPONSE FORMAT - Return ONLY pipe-separated values:\n",
            "success|action|confidence|reasoning\n\n",
            "Fields:\n",
            "- success: true or false\n",
            "- action: spawn_balanced|spawn_challenging|spawn_easy|increase_difficulty|decrease_difficulty|maintain_difficulty|trigger_deflation|stimulate_economy|maintain_economy|no_action\n",
            "- confidence: 0 to 100\n",
            "- reasoning: Brief explanation (no pipes)\n\n",
            "Example: true|spawn_balanced|85|Player at moderate level, balanced challenge needed"
        ));
    }

    /**
     * @notice Execute the decision (rule-based fallback when LLM unavailable)
     */
    function _executeDecision(
        uint256 decisionId,
        address game,
        string memory decisionType,
        bytes memory contextData,
        bytes memory /* gameState */
    ) internal {
        PendingDecision storage decision = pendingDecisions[decisionId];
        decision.processed = true;

        bool success = false;
        string memory action = "";

        if (keccak256(bytes(decisionType)) == keccak256(bytes("spawn"))) {
            (success, action) = _executeSpawnDecision(game, contextData);
        } else if (keccak256(bytes(decisionType)) == keccak256(bytes("balance"))) {
            (success, action) = _executeBalanceDecision(game, contextData);
        } else if (keccak256(bytes(decisionType)) == keccak256(bytes("economy"))) {
            (success, action) = _executeEconomyDecision(game, contextData);
        } else {
            action = "analyzed";
            success = true;
        }

        // Store in memory for learning
        memory_.recordDecision(
            game,
            decision.player,
            decisionType,
            contextData,
            success,
            abi.encode(action)
        );

        emit DecisionExecuted(decisionId, game, action, success);
        emit AgentActionTaken(game, decisionType, action);

        totalAutoActions++;
    }

    /**
     * @notice Spawn decision — uses game context to generate appropriate entity
     */
    function _executeSpawnDecision(
        address game,
        bytes memory contextData
    ) internal returns (bool success, string memory action) {
        // Decode context to get player info
        (, uint256 blockNum, , , bytes memory data) = abi.decode(contextData, (
            address, uint256, uint256, bytes32[], bytes
        ));

        // Use memory to learn what works
        (uint256 totalDecisions_, uint256 successCount, , ) = memory_.getGameStats(game);
        uint256 historicalSuccessRate = totalDecisions_ > 0
            ? (successCount * 10000) / totalDecisions_
            : 5000;

        // Get knowledge base bootstrap for this game type
        string memory gameType = gameContexts[game].gameType;
        uint256 kbWinRate = 5000;
        try knowledgeBase.getBootstrap(gameType) returns (
            uint256 recommendedWinRate, uint256, uint256, uint256, uint256
        ) {
            kbWinRate = recommendedWinRate;
        } catch {}

        // Adjust behavior based on history + knowledge
        string memory adjustedAction;
        if (historicalSuccessRate > 7000 || kbWinRate > 7000) {
            adjustedAction = "spawn_challenging";
        } else if (historicalSuccessRate < 3000) {
            adjustedAction = "spawn_easy";
        } else {
            adjustedAction = "spawn_balanced";
        }

        return (true, adjustedAction);
    }

    /**
     * @notice Balance decision — adjust difficulty based on metrics
     */
    function _executeBalanceDecision(
        address game,
        bytes memory /* contextData */
    ) internal returns (bool success, string memory action) {
        // Read balance metrics if available
        try IGameStateReader(game).getBalanceMetrics() returns (
            uint256 winRate,
            uint256,
            uint256[] memory,
            uint256
        ) {
            if (winRate > 7000) {
                return (true, "increase_difficulty");
            } else if (winRate < 4000) {
                return (true, "decrease_difficulty");
            } else {
                return (true, "maintain_difficulty");
            }
        } catch {
            return (true, "no_action");
        }
    }

    /**
     * @notice Economy decision — adjust economy based on metrics
     */
    function _executeEconomyDecision(
        address game,
        bytes memory /* contextData */
    ) internal returns (bool success, string memory action) {
        try IGameStateReader(game).getEconomyState() returns (
            uint256 circSupply,
            uint256 totalSupply,
            uint256,
            uint256 velocity,
            uint256
        ) {
            uint256 circRatio = totalSupply > 0 ? (circSupply * 10000) / totalSupply : 5000;

            if (circRatio > 7000 && velocity > 30000) {
                return (true, "trigger_deflation");
            } else if (circRatio < 3000) {
                return (true, "stimulate_economy");
            } else {
                return (true, "maintain_economy");
            }
        } catch {
            return (true, "no_action");
        }
    }

    // ============ LLM Callback (Production) ============

    /**
     * @notice Handle LLM response from Somnia Inference
     * @dev Parses pipe-separated response and executes the recommended action
     *      Format: success|action|confidence|reasoning
     */
    function handleLLMResponse(
        uint256 decisionId,
        bytes calldata responseData
    ) external {
        require(msg.sender == SOMNIA_PLATFORM, "Not Somnia Platform");

        PendingDecision storage decision = pendingDecisions[decisionId];
        require(!decision.processed, "Already processed");

        // Decode pipe-separated response
        string memory response = abi.decode(responseData, (string));

        // Parse the response
        (bool success, string memory action, uint256 confidence, string memory reasoning) =
            _parseLLMResponse(response);

        decision.processed = true;

        bool executed = false;

        if (success && confidence >= 50) {
            // Execute the LLM-recommended action
            if (_startsWith(action, "spawn")) {
                (executed, ) = _executeSpawnDecision(decision.game, decision.contextData);
            } else if (_startsWith(action, "increase_difficulty") || _startsWith(action, "decrease_difficulty") || _startsWith(action, "maintain_difficulty")) {
                (executed, ) = _executeBalanceDecision(decision.game, decision.contextData);
            } else if (_startsWith(action, "trigger_deflation") || _startsWith(action, "stimulate_economy") || _startsWith(action, "maintain_economy")) {
                (executed, ) = _executeEconomyDecision(decision.game, decision.contextData);
            } else {
                executed = true; // no_action
            }
        } else {
            // Low confidence or parse failure — use rule-based fallback
            _executeDecision(decisionId, decision.game, decision.decisionType, decision.contextData, decision.gameState);
            executed = true;
        }

        // Record in memory for learning
        memory_.recordDecision(
            decision.game,
            decision.player,
            decision.decisionType,
            decision.contextData,
            executed,
            abi.encode(action, confidence)
        );

        emit DecisionExecuted(decisionId, decision.game, action, executed);
        emit AgentActionTaken(decision.game, decision.decisionType, action);

        totalLLMCalls++;
        totalAutoActions++;
    }

    /**
     * @notice Parse pipe-separated LLM response
     * @dev Format: success|action|confidence|reasoning
     */
    function _parseLLMResponse(
        string memory response
    ) internal pure returns (
        bool success,
        string memory action,
        uint256 confidence,
        string memory reasoning
    ) {
        bytes memory data = bytes(response);

        // Default values
        success = false;
        action = "no_action";
        confidence = 0;
        reasoning = "";

        // Find pipe positions
        uint256[] memory pipes = new uint256[](3);
        uint256 pipeCount = 0;

        for (uint256 i = 0; i < data.length && pipeCount < 3; i++) {
            if (data[i] == '|') {
                pipes[pipeCount] = i;
                pipeCount++;
            }
        }

        // Need at least 3 pipes for 4 fields
        if (pipeCount < 3) {
            return (false, "no_action", 0, "Invalid response format");
        }

        // Parse success (field 1)
        success = _parseBool(data, 0, pipes[0]);

        // Parse action (field 2)
        action = _parseString(data, pipes[0] + 1, pipes[1]);

        // Parse confidence (field 3)
        confidence = _parseUint(data, pipes[1] + 1, pipes[2]);

        // Parse reasoning (field 4 - rest of string)
        reasoning = _parseString(data, pipes[2] + 1, data.length);

        return (success, action, confidence, reasoning);
    }

    function _parseBool(bytes memory data, uint256 start, uint256 end) internal pure returns (bool) {
        if (end - start == 4) {
            return data[start] == 't' && data[start+1] == 'r' && data[start+2] == 'u' && data[start+3] == 'e';
        }
        return false;
    }

    function _parseString(bytes memory data, uint256 start, uint256 end) internal pure returns (string memory) {
        uint256 len = end - start;
        bytes memory result = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            result[i] = data[start + i];
        }
        return string(result);
    }

    function _parseUint(bytes memory data, uint256 start, uint256 end) internal pure returns (uint256) {
        uint256 result = 0;
        for (uint256 i = start; i < end; i++) {
            if (data[i] >= '0' && data[i] <= '9') {
                result = result * 10 + uint256(uint8(data[i]) - 48);
            }
        }
        return result;
    }

    function _startsWith(string memory s, string memory prefix) internal pure returns (bool) {
        bytes memory sBytes = bytes(s);
        bytes memory pBytes = bytes(prefix);
        if (sBytes.length < pBytes.length) return false;
        for (uint256 i = 0; i < pBytes.length; i++) {
            if (sBytes[i] != pBytes[i]) return false;
        }
        return true;
    }

    // ============ View Functions ============

    function getGameContext(address game) external view returns (
        string memory gameType,
        bool canSpawn,
        bool canAdjustEconomy,
        bool canGenerateNarrative,
        bool canAdjustDifficulty,
        uint256 analysisCount
    ) {
        GameContext storage ctx = gameContexts[game];
        return (
            ctx.gameType,
            ctx.canSpawn,
            ctx.canAdjustEconomy,
            ctx.canGenerateNarrative,
            ctx.canAdjustDifficulty,
            ctx.analysisCount
        );
    }

    function getStats() external view returns (
        uint256 decisions,
        uint256 llmCalls,
        uint256 autoActions
    ) {
        return (totalDecisions, totalLLMCalls, totalAutoActions);
    }

    // ============ Helpers ============

    function _extractPlayerFromData(bytes calldata data) internal pure returns (address) {
        if (data.length >= 32) {
            return address(uint160(uint256(bytes32(data[:32]))));
        }
        return address(0);
    }

    function _truncate(string memory s, uint256 maxLength) internal pure returns (string memory) {
        if (bytes(s).length <= maxLength) return s;
        bytes memory truncated = new bytes(maxLength);
        for (uint256 i = 0; i < maxLength; i++) {
            truncated[i] = bytes(s)[i];
        }
        return string(truncated);
    }

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

    function setCircuitBreaker(address _cb) external onlyOwner {
        circuitBreaker = _cb;
    }
}

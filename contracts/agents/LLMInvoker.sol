// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./AgentMemory.sol";
import "./GameKnowledgeBase.sol";

/**
 * @title IAgentRequester
 * @notice Interface for Somnia Agent Requester
 */
interface IAgentRequester {
    function createRequest(
        uint256 agentId,
        bytes calldata payload,
        bytes4 callbackSelector
    ) external payable returns (uint256 requestId);

    function getRequestDeposit(uint256 agentId) external view returns (uint256);
}

/**
 * @title ILLMAgent
 * @notice Interface for Somnia LLM Agent
 */
interface ILLMAgent {
    function inferString(
        string calldata prompt,
        string calldata chainOfThought
    ) external view returns (bytes memory);
}

/**
 * @title LLMInvoker
 * @notice Handles Somnia LLM Inference for game economy decisions
 * @dev Uses ABI-encoded responses instead of JSON (per deep research recommendation)
 *
 *      Architecture:
 *      1. Build prompt with context
 *      2. Request ABI-encoded response from LLM
 *      3. Decode response directly (no JSON parsing)
 *      4. Apply safety bounds
 *      5. Record in memory for learning
 */
contract LLMInvoker is Ownable {

    // ============ Somnia Constants ============
    address public constant SOMNIA_PLATFORM = address(0x401);
    address public constant AGENT_REQUESTER = address(0x200);
    uint256 public constant LLM_INFERENCE_AGENT_ID = 12847293847561029384;

    // ============ Dependencies ============
    AgentMemory public memory_;
    GameKnowledgeBase public knowledgeBase;

    // ============ State ============
    struct LLMRequest {
        uint256 requestId;
        address game;
        string decisionType;
        bytes contextData;
        uint256 timestamp;
        bool processed;
    }

    mapping(uint256 => LLMRequest) public requests;
    uint256 public nextRequestId;

    // Safety bounds
    int256 public constant MAX_REWARD_CHANGE = 2000;  // ±20%
    int256 public constant MAX_BURN_CHANGE = 2000;    // ±20%
    int256 public constant MAX_MINT_CHANGE = 3000;    // ±30%
    int256 public constant MAX_POWER_CHANGE = 2000;   // ±20%
    int256 public constant MAX_ENTRY_CHANGE = 2000;   // ±20%

    // ============ Events ============

    event LLMRequestSent(
        uint256 indexed requestId,
        address indexed game,
        string decisionType,
        string promptSummary
    );

    event LLMResponseReceived(
        uint256 indexed requestId,
        address indexed game,
        string action,
        bool success
    );

    event LLMError(
        uint256 indexed requestId,
        string error
    );

    // ============ Constructor ============

    constructor(
        address _memory,
        address _knowledgeBase
    ) Ownable(msg.sender) {
        memory_ = AgentMemory(_memory);
        knowledgeBase = GameKnowledgeBase(_knowledgeBase);
    }

    // ============ LLM Invocation ============

    /**
     * @notice Invoke LLM for game economy decision
     * @param game Game address
     * @param decisionType Type of decision: "spawn", "economy", "balance", "narrative"
     * @param contextData Encoded context data
     * @param gameState Current game state
     * @return requestId Request ID for tracking
     */
    function invokeLLM(
        address game,
        string calldata decisionType,
        bytes calldata contextData,
        bytes calldata gameState
    ) external payable returns (uint256 requestId) {
        requestId = nextRequestId++;

        // Store request
        requests[requestId] = LLMRequest({
            requestId: requestId,
            game: game,
            decisionType: decisionType,
            contextData: contextData,
            timestamp: block.timestamp,
            processed: false
        });

        // Build prompt
        string memory prompt = _buildPrompt(game, decisionType, contextData, gameState);

        // Invoke LLM
        bytes memory payload = abi.encodeWithSelector(
            ILLMAgent.inferString.selector,
            prompt,
            "Analyze the game economy data and provide actionable recommendations. Return JSON format."
        );

        uint256 deposit = IAgentRequester(AGENT_REQUESTER).getRequestDeposit(LLM_INFERENCE_AGENT_ID);

        IAgentRequester(AGENT_REQUESTER).createRequest{value: deposit}(
            LLM_INFERENCE_AGENT_ID,
            payload,
            this.handleLLMResponse.selector
        );

        emit LLMRequestSent(requestId, game, decisionType, _truncate(prompt, 100));
    }

    // ============ Response Handling ============

    /**
     * @notice Handle LLM response from Somnia
     * @param requestId Request ID
     * @param responseData Encoded response data
     * @dev Parses pipe-separated values (gas-efficient alternative to JSON)
     */
    function handleLLMResponse(
        uint256 requestId,
        bytes calldata responseData
    ) external {
        require(msg.sender == SOMNIA_PLATFORM, "Not Somnia Platform");

        LLMRequest storage request = requests[requestId];
        require(!request.processed, "Already processed");

        request.processed = true;

        // Decode response as pipe-separated string
        string memory response = abi.decode(responseData, (string));

        // Parse pipe-separated response
        (bool success, string memory action, int256 rewardMult, int256 burnRate,
         int256 mintCost, int256 powerScale, int256 entryFee, string memory reasoning) =
            _parsePipeResponse(response);

        if (success) {
            // Apply safety bounds
            rewardMult = _clamp(rewardMult, -MAX_REWARD_CHANGE, MAX_REWARD_CHANGE);
            burnRate = _clamp(burnRate, -MAX_BURN_CHANGE, MAX_BURN_CHANGE);
            mintCost = _clamp(mintCost, -MAX_MINT_CHANGE, MAX_MINT_CHANGE);
            powerScale = _clamp(powerScale, -MAX_POWER_CHANGE, MAX_POWER_CHANGE);
            entryFee = _clamp(entryFee, -MAX_ENTRY_CHANGE, MAX_ENTRY_CHANGE);

            // Store in memory for learning
            memory_.recordDecision(
                request.game,
                address(0),
                request.decisionType,
                request.contextData,
                true,
                abi.encode(action, rewardMult, burnRate, mintCost, powerScale, entryFee)
            );

            emit LLMResponseReceived(requestId, request.game, action, true);
        } else {
            emit LLMError(requestId, "Failed to parse LLM response");
        }
    }

    // ============ Prompt Engineering ============

    /**
     * @notice Build LLM prompt with context
     * @dev Requests ABI-encoded response for gas-efficient on-chain parsing
     */
    function _buildPrompt(
        address game,
        string memory decisionType,
        bytes memory contextData,
        bytes memory gameState
    ) internal view returns (string memory) {
        // Get memory context
        (uint256 totalDecisions, uint256 successfulDecisions, , uint256 successRate) =
            memory_.getGameStats(game);

        return string(abi.encodePacked(
            "You are OIKONO, an autonomous AI agent managing a Web3 game economy.\n\n",
            "TASK: Analyze the following game data and provide actionable recommendations.\n\n",
            "GAME: ", _addressToString(game), "\n",
            "DECISION TYPE: ", decisionType, "\n",
            "CONTEXT SIZE: ", _toString(contextData.length), " bytes\n",
            "STATE SIZE: ", _toString(gameState.length), " bytes\n\n",
            "HISTORY:\n",
            "- Total decisions: ", _toString(totalDecisions), "\n",
            "- Successful: ", _toString(successfulDecisions), "\n",
            "- Success rate: ", _toString(successRate / 100), "%\n\n",
            "RESPONSE FORMAT (ABI-encoded):\n",
            "Return the following values separated by pipes (|):\n",
            "success|action|rewardMultiplier|burnRate|mintCost|powerScale|entryFee|reasoning\n\n",
            "Example: true|increase_rewards|5|-3|0|10|-5|Win rate too high\n\n",
            "CONSTRAINTS:\n",
            "- success: true or false\n",
            "- action: increase_rewards|decrease_rewards|increase_burn|decrease_burn|increase_difficulty|decrease_difficulty|spawn_entity|no_action\n",
            "- rewardMultiplier: -20 to +20\n",
            "- burnRate: -20 to +20\n",
            "- mintCost: -30 to +30\n",
            "- powerScale: -20 to +20\n",
            "- entryFee: -20 to +20\n",
            "- reasoning: Brief explanation (no pipes)\n\n",
            "IMPORTANT: Return ONLY the pipe-separated values. No other text."
        ));
    }

    // ============ Pipe-Separated Parsing ============

    /**
     * @notice Parse pipe-separated LLM response
     * @dev Gas-efficient alternative to JSON parsing
     *      Format: success|action|rewardMult|burnRate|mintCost|powerScale|entryFee|reasoning
     */
    function _parsePipeResponse(
        string memory response
    ) internal pure returns (
        bool success,
        string memory action,
        int256 rewardMult,
        int256 burnRate,
        int256 mintCost,
        int256 powerScale,
        int256 entryFee,
        string memory reasoning
    ) {
        bytes memory data = bytes(response);

        // Default values
        success = false;
        action = "no_action";
        rewardMult = 0;
        burnRate = 0;
        mintCost = 0;
        powerScale = 0;
        entryFee = 0;
        reasoning = "";

        // Find pipe positions
        uint256[] memory pipes = new uint256[](7);
        uint256 pipeCount = 0;

        for (uint256 i = 0; i < data.length && pipeCount < 7; i++) {
            if (data[i] == '|') {
                pipes[pipeCount] = i;
                pipeCount++;
            }
        }

        // Need at least 7 pipes for 8 fields
        if (pipeCount < 7) {
            return (false, "no_action", 0, 0, 0, 0, 0, "Invalid response format");
        }

        // Parse success (field 1)
        success = _parseBool(data, 0, pipes[0]);

        // Parse action (field 2)
        action = _parseString(data, pipes[0] + 1, pipes[1]);

        // Parse numeric fields (fields 3-7)
        rewardMult = _parseInt(data, pipes[1] + 1, pipes[2]);
        burnRate = _parseInt(data, pipes[2] + 1, pipes[3]);
        mintCost = _parseInt(data, pipes[3] + 1, pipes[4]);
        powerScale = _parseInt(data, pipes[4] + 1, pipes[5]);
        entryFee = _parseInt(data, pipes[5] + 1, pipes[6]);

        // Parse reasoning (field 8 - rest of string)
        reasoning = _parseString(data, pipes[6] + 1, data.length);

        return (success, action, rewardMult, burnRate, mintCost, powerScale, entryFee, reasoning);
    }

    /**
     * @notice Parse boolean from bytes
     */
    function _parseBool(bytes memory data, uint256 start, uint256 end) internal pure returns (bool) {
        if (end - start == 4) {
            // "true"
            return data[start] == 't' && data[start+1] == 'r' && data[start+2] == 'u' && data[start+3] == 'e';
        }
        return false;
    }

    /**
     * @notice Parse string from bytes
     */
    function _parseString(bytes memory data, uint256 start, uint256 end) internal pure returns (string memory) {
        uint256 len = end - start;
        bytes memory result = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            result[i] = data[start + i];
        }
        return string(result);
    }

    /**
     * @notice Parse integer from bytes
     */
    function _parseInt(bytes memory data, uint256 start, uint256 end) internal pure returns (int256) {
        bool negative = false;
        int256 result = 0;

        for (uint256 i = start; i < end; i++) {
            if (data[i] == '-') {
                negative = true;
            } else if (data[i] >= '0' && data[i] <= '9') {
                result = result * 10 + int256(uint256(uint8(data[i]) - 48));
            }
        }

        return negative ? -result : result;
    }

    // ============ Helper Functions ============

    function _clamp(int256 value, int256 min, int256 max) internal pure returns (int256) {
        if (value < min) return min;
        if (value > max) return max;
        return value;
    }

    function _addressToString(address addr) internal pure returns (string memory) {
        uint256 value = uint256(uint160(addr));
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(42);
        str[0] = '0';
        str[1] = 'x';
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8((value >> (156 - i * 8)) & 0xf0) >> 4];
            str[3 + i * 2] = alphabet[uint8((value >> (152 - i * 8)) & 0x0f)];
        }
        return string(str);
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

    function _truncate(string memory s, uint256 maxLength) internal pure returns (string memory) {
        if (bytes(s).length <= maxLength) return s;
        bytes memory truncated = new bytes(maxLength);
        for (uint256 i = 0; i < maxLength; i++) {
            truncated[i] = bytes(s)[i];
        }
        return string(truncated);
    }

    // ============ Admin ============

    function setMemory(address _memory) external onlyOwner {
        memory_ = AgentMemory(_memory);
    }

    function setKnowledgeBase(address _knowledgeBase) external onlyOwner {
        knowledgeBase = GameKnowledgeBase(_knowledgeBase);
    }
}

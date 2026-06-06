// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./PlayerRegistry.sol";
import "./EnemyNFT.sol";
import "../utils/AntiSybil.sol";
import "../utils/CircuitBreaker.sol";

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
 * @title ISomniaEventHandler
 * @notice Interface for Somnia's reactivity precompile (0x0100)
 */
interface ISomniaEventHandler {
    function createSoliditySubscription(
        bytes32 eventSignature,
        address emitterAddress,
        address handlerAddress
    ) external payable;
}

/**
 * @title GameMaster
 * @notice Autonomous AI Game Master using Somnia's On-Chain Reactivity + LLM Inference
 * @dev Reacts to PlayerMoved events, generates enemies via AI, mints NFTs
 *
 * This is the core OIKONO contract - the "Only on Somnia" feature:
 * - On-Chain Reactivity: _onEvent catches PlayerMoved in same block
 * - LLM Inference: Qwen3-30B generates enemy profiles deterministically
 * - Dynamic NFT Minting: EnemyNFT created with AI-generated metadata
 *
 * Flow:
 * PlayerMoved event → _onEvent → compose prompt → LLM Agent → callback → mint NFT
 */
contract GameMaster is Ownable {
    // Somnia Platform Address (for callback verification)
    address public constant SOMNIA_PLATFORM = address(0x401);

    // Somnia Agent IDs (Testnet)
    uint256 public constant LLM_INFERENCE_AGENT_ID = 12847293847561029384;

    // Somnia Reactivity Precompile
    address public constant REACTIVITY_PRECOMPILE = address(0x100);
    address public constant AGENT_REQUESTER = address(0x200);

    // Dependencies
    PlayerRegistry public playerRegistry;
    EnemyNFT public enemyNFT;
    AntiSybil public antiSybil;
    CircuitBreaker public circuitBreaker;

    // LLM Mode: true = use Somnia LLM Agent, false = use deterministic fallback
    bool public useLLMAgent;

    // Request tracking
    struct PendingRequest {
        address player;
        uint256 x;
        uint256 y;
        uint256 xp;
        uint256 level;
        bool processed;
    }

    mapping(uint256 => PendingRequest) public pendingRequests;
    uint256 public nextRequestId;

    // Statistics
    uint256 public totalEnemiesGenerated;
    uint256 public totalLLMCalls;
    uint256 public totalSubscriptions;

    // Events
    event LLMRequestSent(
        uint256 indexed requestId,
        address indexed player,
        string prompt
    );
    event LLMResponseReceived(
        uint256 indexed requestId,
        string enemyData
    );
    event EnemyGenerated(
        address indexed player,
        uint256 indexed tokenId,
        string name,
        string enemyClass,
        uint256 power
    );
    event SubscriptionCreated(
        bytes32 eventSig,
        address emitter,
        address handler
    );
    event SubscriptionRegistered(uint256 deposit);

    constructor(
        address _playerRegistry,
        address _enemyNFT,
        address _antiSybil,
        address _circuitBreaker
    ) Ownable(msg.sender) {
        playerRegistry = PlayerRegistry(_playerRegistry);
        enemyNFT = EnemyNFT(_enemyNFT);
        antiSybil = AntiSybil(_antiSybil);
        circuitBreaker = CircuitBreaker(_circuitBreaker);
    }

    // ============ Modifiers ============

    modifier whenSystemActive() {
        require(!circuitBreaker.paused(), "System paused by circuit breaker");
        _;
    }

    /**
     * @notice Toggle LLM Agent mode
     * @param _useLLM true = use Somnia LLM Agent, false = use deterministic fallback
     */
    function setLLMMode(bool _useLLM) external onlyOwner {
        useLLMAgent = _useLLM;
    }

    /**
     * @notice Set CircuitBreaker reference
     */
    function setCircuitBreaker(address _circuitBreaker) external onlyOwner {
        circuitBreaker = CircuitBreaker(_circuitBreaker);
    }

    // ========================================
    // SOMNIA REACTIVITY INTEGRATION
    // ========================================

    /**
     * @notice Subscribe to PlayerMoved events via Somnia Reactivity
     * @dev Must be called after deployment to activate on-chain reactivity
     * @param eventSig keccak256("PlayerMoved(address,uint256,uint256,uint256,uint256)")
     */
    function subscribeToPlayerMoved(bytes32 eventSig) external payable onlyOwner {
        ISomniaEventHandler(REACTIVITY_PRECOMPILE).createSoliditySubscription{value: msg.value}(
            eventSig,
            address(playerRegistry), // Emitter contract
            address(this)           // This contract handles the event
        );

        totalSubscriptions++;
        emit SubscriptionCreated(eventSig, address(playerRegistry), address(this));
        emit SubscriptionRegistered(msg.value);
    }

    /**
     * @notice Register subscription using SDK-generated parameters (alternative method)
     * @dev This function can be called off-chain via SDK createSoliditySubscription
     */
    function registerSubscription(
        bytes32 eventSignature,
        address emitterAddress,
        uint256 deposit
    ) external payable onlyOwner {
        require(msg.value >= deposit, "Insufficient deposit");

        ISomniaEventHandler(REACTIVITY_PRECOMPILE).createSoliditySubscription{value: deposit}(
            eventSignature,
            emitterAddress,
            address(this)
        );

        totalSubscriptions++;
    }

    // ========================================
    // SOMNIA REACTIVITY HANDLER (_onEvent)
    // ========================================

    /**
     * @notice Reactive handler - called automatically by Somnia validators when PlayerMoved fires
     * @dev This is the core of OIKONO's "Agent-First Design"
     *      Executes in the SAME BLOCK as the PlayerMoved event
     *      No mempool exposure, MEV-resistant
     *
     * @param emitter Address of the contract that emitted the event
     * @param topics Encoded event topics (signature hash + indexed params)
     * @param data Non-indexed event data
     */
    function _onEvent(
        address emitter,
        bytes32[] calldata topics,
        bytes calldata data
    ) external whenSystemActive {
        // Only Somnia validators can call this
        require(msg.sender == address(0x100) || msg.sender == REACTIVITY_PRECOMPILE,
            "Only Somnia validators");

        // Decode PlayerMoved event data
        // event PlayerMoved(address indexed player, uint256 x, uint256 y, uint256 xp, uint256 level)
        (address player, uint256 x, uint256 y, uint256 xp, uint256 level) =
            abi.decode(data, (address, uint256, uint256, uint256, uint256));

        // Generate enemy for this player
        _generateEnemy(player, x, y, xp, level);
    }

    /**
     * @notice Manually trigger enemy generation (for testing/fallback)
     * @dev Can be called by player directly or by admin
     */
    function triggerEnemyGeneration(address player) external whenSystemActive {
        require(
            msg.sender == player || msg.sender == owner(),
            "Not authorized"
        );
        require(playerRegistry.playerExists(player), "Player not registered");

        (uint256 x, uint256 y, uint256 xp, uint256 level, , , , ) =
            playerRegistry.getPlayer(player);

        _generateEnemy(player, x, y, xp, level);
    }

    // ========================================
    // LLM INFERENCE INTEGRATION
    // ========================================

    /**
     * @notice Generate enemy using Somnia LLM Inference Agent
     * @dev This is a simplified version - in production, uses Somnia's async callback
     *
     * For async flow with callback:
     * 1. Call IAgentRequester.createRequest with prompt
     * 2. Wait for subcommittee consensus
     * 3. Handle callback in handleAIResponse
     *
     * This implementation uses a deterministic on-chain generation as fallback
     * when Somnia Agent is not available (e.g., local testing)
     */
    function _generateEnemy(
        address player,
        uint256 x,
        uint256 y,
        uint256 xp,
        uint256 level
    ) internal {
        // Compose prompt for LLM
        string memory prompt = _buildPrompt(player, x, y, xp, level);

        if (useLLMAgent) {
            // Production: Use Somnia LLM Agent
            bytes memory payload = abi.encodeWithSelector(
                ILLMAgent.inferString.selector,
                prompt,
                "chainOfThought"
            );
            uint256 deposit = IAgentRequester(AGENT_REQUESTER).getRequestDeposit(LLM_INFERENCE_AGENT_ID);
            uint256 requestId = IAgentRequester(AGENT_REQUESTER).createRequest{value: deposit}(
                LLM_INFERENCE_AGENT_ID,
                payload,
                this.handleAIResponse.selector
            );
            pendingRequests[requestId] = PendingRequest(player, x, y, xp, level, false);
            totalLLMCalls++;

            emit LLMRequestSent(requestId, player, prompt);
        } else {
            // Fallback: Use deterministic on-chain generation
            _generateEnemyDeterministic(player, x, y, xp, level, prompt);
            emit LLMRequestSent(nextRequestId++, player, prompt);
        }
    }

    /**
     * @notice Build LLM prompt from player state
     */
    function _buildPrompt(
        address player,
        uint256 x,
        uint256 y,
        uint256 xp,
        uint256 level
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(
            "Player ", _shortAddress(player),
            " at position (", _toString(x), ", ", _toString(y), ")",
            " with ", _toString(xp), " XP and Level ", _toString(level),
            ". Generate a challenging enemy NPC.",
            "\n\nRESPONSE FORMAT - Return ONLY pipe-separated values:\n",
            "name|class|element|power|threat_level\n\n",
            "Fields:\n",
            "- name: Creative enemy name (no pipes)\n",
            "- class: assassin|tank|mage|berserker|healer|ranger\n",
            "- element: fire|ice|shadow|lightning|void|earth\n",
            "- power: 40 to 100\n",
            "- threat_level: 1 to 10\n\n",
            "Example: Shadow Wraith|assassin|shadow|75|7"
        ));
    }

    /**
     * @notice Deterministic enemy generation (deterministic based on seed)
     * @dev Uses blockhash + player address for deterministic randomness
     */
    function _generateEnemyDeterministic(
        address player,
        uint256 x,
        uint256 y,
        uint256 xp,
        uint256 level,
        string memory prompt
    ) internal {
        // Generate deterministic seed
        bytes32 seed = keccak256(abi.encodePacked(
            blockhash(block.number - 1),
            player,
            x, y, xp, level,
            totalEnemiesGenerated
        ));

        // Parse deterministic values from seed
        uint256 seedNum = uint256(seed);

        // Enemy names pool
        string[12] memory names = [
            "Shadow Wraith", "Crimson Basilisk", "Void Sentinel",
            "Nether Drake", "Phantom Knight", "Storm Colossus",
            "Obsidian Golem", "Spectral Warden", "Frost Lich",
            "Ember Wyrm", "Dark Harbinger", "Chaos Oracle"
        ];

        string[6] memory classes = [
            "assassin", "tank", "mage", "berserker", "healer", "ranger"
        ];

        string[6] memory elements = [
            "fire", "ice", "shadow", "lightning", "void", "earth"
        ];

        // Select from pools using seed
        string memory enemyName = names[seedNum % 12];
        string memory enemyClass = classes[(seedNum / 12) % 6];
        string memory element = elements[(seedNum / 72) % 6];

        // Calculate power based on player level (scaled challenge)
        uint256 basePower = 40 + (level * 2); // Level 1: 42, Level 10: 60, Level 30: 100
        int256 variance = int256(seedNum % 21) - 10; // -10 to +10
        int256 powerInt = int256(basePower) + variance;
        if (powerInt < 40) powerInt = 40;
        if (powerInt > 100) powerInt = 100;
        uint256 power = uint256(powerInt);

        uint256 threatLevel = 1 + ((power - 40) * 9) / 60;
        if (threatLevel < 1) threatLevel = 1;
        if (threatLevel > 10) threatLevel = 10;

        // Create metadata URI (on-chain JSON)
        string memory metadataURI = string(abi.encodePacked(
            "data:application/json,{\"name\":\"", enemyName,
            "\",\"class\":\"", enemyClass,
            "\",\"element\":\"", element,
            "\",\"power\":", _toString(power),
            ",\"threat_level\":", _toString(threatLevel),
            ",\"creator\":\"", _shortAddress(player), "\"}"
        ));

        // Mint EnemyNFT
        uint256 tokenId = enemyNFT.mintFromAI(
            player,
            enemyName,
            enemyClass,
            element,
            power,
            threatLevel,
            metadataURI
        );

        totalEnemiesGenerated++;

        emit EnemyGenerated(player, tokenId, enemyName, enemyClass, power);
    }

    /**
     * @notice Callback handler for Somnia LLM Inference response
     * @dev Parses pipe-separated response and mints enemy NFT
     *      Format: name|class|element|power|threat_level
     *      Verify msg.sender is Somnia Platform
     */
    function handleAIResponse(
        uint256 requestId,
        bytes calldata responseData
    ) external {
        // Verify sender is Somnia Platform
        require(msg.sender == SOMNIA_PLATFORM, "Unauthorized: Not Somnia Platform");

        PendingRequest storage request = pendingRequests[requestId];
        require(!request.processed, "Request already processed");
        require(request.player != address(0), "Request not found");

        request.processed = true;

        // Decode AI response (pipe-separated string)
        string memory aiResponse = abi.decode(responseData, (string));

        // Parse pipe-separated response: name|class|element|power|threat_level
        (string memory name, string memory enemyClass, string memory element,
         uint256 power, uint256 threatLevel) = _parseEnemyResponse(aiResponse);

        // Validate parsed values
        if (power < 40 || power > 100 || bytes(name).length == 0) {
            // Fallback to deterministic generation if parsing fails
            _generateEnemyDeterministic(
                request.player,
                request.x,
                request.y,
                request.xp,
                request.level,
                aiResponse
            );
        } else {
            // Use LLM-generated enemy
            if (threatLevel < 1) threatLevel = 1;
            if (threatLevel > 10) threatLevel = 10;

            // Create metadata URI
            string memory metadataURI = string(abi.encodePacked(
                "data:application/json,{\"name\":\"", name,
                "\",\"class\":\"", enemyClass,
                "\",\"element\":\"", element,
                "\",\"power\":", _toString(power),
                ",\"threat_level\":", _toString(threatLevel),
                ",\"creator\":\"", _shortAddress(request.player), "\",\"source\":\"llm\"}"
            ));

            // Mint EnemyNFT with LLM-generated data
            uint256 tokenId = enemyNFT.mintFromAI(
                request.player,
                name,
                enemyClass,
                element,
                power,
                threatLevel,
                metadataURI
            );

            totalEnemiesGenerated++;
            emit EnemyGenerated(request.player, tokenId, name, enemyClass, power);
        }

        emit LLMResponseReceived(requestId, aiResponse);
    }

    /**
     * @notice Parse pipe-separated LLM response for enemy generation
     * @dev Format: name|class|element|power|threat_level
     */
    function _parseEnemyResponse(
        string memory response
    ) internal pure returns (
        string memory name,
        string memory enemyClass,
        string memory element,
        uint256 power,
        uint256 threatLevel
    ) {
        bytes memory data = bytes(response);

        // Default values
        name = "";
        enemyClass = "assassin";
        element = "fire";
        power = 50;
        threatLevel = 5;

        // Find pipe positions
        uint256[] memory pipes = new uint256[](4);
        uint256 pipeCount = 0;

        for (uint256 i = 0; i < data.length && pipeCount < 4; i++) {
            if (data[i] == '|') {
                pipes[pipeCount] = i;
                pipeCount++;
            }
        }

        // Need at least 4 pipes for 5 fields
        if (pipeCount < 4) {
            return (name, enemyClass, element, power, threatLevel);
        }

        // Parse fields
        name = _extractString(data, 0, pipes[0]);
        enemyClass = _extractString(data, pipes[0] + 1, pipes[1]);
        element = _extractString(data, pipes[1] + 1, pipes[2]);
        power = _extractUint(data, pipes[2] + 1, pipes[3]);
        threatLevel = _extractUint(data, pipes[3] + 1, data.length);

        return (name, enemyClass, element, power, threatLevel);
    }

    function _extractString(bytes memory data, uint256 start, uint256 end) internal pure returns (string memory) {
        uint256 len = end - start;
        bytes memory result = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            result[i] = data[start + i];
        }
        return string(result);
    }

    function _extractUint(bytes memory data, uint256 start, uint256 end) internal pure returns (uint256) {
        uint256 result = 0;
        for (uint256 i = start; i < end; i++) {
            if (data[i] >= '0' && data[i] <= '9') {
                result = result * 10 + uint256(uint8(data[i]) - 48);
            }
        }
        return result;
    }

    // ========================================
    // HELPER FUNCTIONS
    // ========================================

    function _shortAddress(address addr) internal pure returns (string memory) {
        bytes memory b = abi.encodePacked(
            "0x",
            _toHex(uint256(uint160(addr)) >> 100, 4),
            "..",
            _toHex(uint256(uint160(addr)), 4)
        );
        return string(b);
    }

    function _toHex(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory hexBytes = new bytes(length);
        bytes16 alphabet = "0123456789abcdef";
        for (uint256 i = 0; i < length; i++) {
            hexBytes[length - 1 - i] = alphabet[value & 0xf];
            value >>= 4;
        }
        return string(hexBytes);
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    // ========================================
    // STATS & VIEW FUNCTIONS
    // ========================================

    function getStats() external view returns (
        uint256 totalEnemies,
        uint256 totalLLM,
        uint256 subscriptions
    ) {
        return (totalEnemiesGenerated, totalLLMCalls, totalSubscriptions);
    }
}

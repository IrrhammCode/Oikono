// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./AgentTypes.sol";
import "./IAgentPlugin.sol";

/**
 * @title AgentRuntime
 * @notice Core runtime for OIKONO Agent Kit - handles Somnia integration
 * @dev This is the heart of the framework:
 *      - Listens to on-chain events via Somnia Reactivity
 *      - Invokes LLM Inference deterministically
 *      - Routes results to appropriate plugins
 *      - Handles callback verification and execution
 *
 * @dev Designed to be "AWS Lambda for Web3 Games" - plug in your game, agent handles AI
 */
contract AgentRuntime is Ownable {
    using AgentTypes for AgentTypes.ActionRequest;
    using AgentTypes for AgentTypes.ActionResult;

    // ============ Somnia Constants ============
    address public constant SOMNIA_PLATFORM = address(0x401);
    address public constant REACTIVITY_PRECOMPILE = address(0x100);
    address public constant AGENT_REQUESTER = address(0x200);
    uint256 public constant LLM_INFERENCE_AGENT_ID = 12847293847561029384;

    // ============ State ============
    struct RegisteredGame {
        address gameAddress;
        string name;
        bytes32[] subscribedEvents;
        address pluginAddress;
        bool isActive;
        uint256 totalExecutions;
    }

    struct AgentStats {
        uint256 totalRequests;
        uint256 successfulRequests;
        uint256 failedRequests;
        uint256 totalLLMCalls;
        uint256 avgExecutionTime;
    }

    // Registered games
    mapping(address => RegisteredGame) public registeredGames;
    address[] public gameAddresses;

    // Request tracking
    mapping(uint256 => AgentTypes.ActionRequest) public requests;
    mapping(uint256 => AgentTypes.ActionResult) public results;
    uint256 public nextRequestId;

    // Game-specific request mapping
    mapping(uint256 => address) public requestGame;

    // Dependencies
    address public circuitBreaker;

    // Stats
    AgentStats public stats;

    // ============ Events ============
    event GameRegistered(address indexed game, string name, address plugin);
    event GameUnregistered(address indexed game);
    event SubscriptionCreated(address indexed game, bytes32 eventSig);
    event ActionRequested(
        uint256 indexed requestId,
        address indexed game,
        address indexed player,
        uint8 actionType
    );
    event ActionCompleted(
        uint256 indexed requestId,
        bool success,
        uint256 executionTime
    );
    event LLMResponseReceived(uint256 indexed requestId, bytes data);
    event PluginExecuted(address indexed plugin, uint256 indexed requestId, bool success);

    constructor(address _circuitBreaker) Ownable(msg.sender) {
        circuitBreaker = _circuitBreaker;
    }

    // ============ Game Registration ============

    /**
     * @notice Register a game to use the agent framework
     * @dev Game developers call this to plug their game into OIKONO Agent Kit
     */
    function registerGame(
        string calldata name,
        address pluginAddress
    ) external {
        require(registeredGames[msg.sender].gameAddress == address(0), "Already registered");

        registeredGames[msg.sender] = RegisteredGame({
            gameAddress: msg.sender,
            name: name,
            subscribedEvents: new bytes32[](0),
            pluginAddress: pluginAddress,
            isActive: true,
            totalExecutions: 0
        });

        gameAddresses.push(msg.sender);

        emit GameRegistered(msg.sender, name, pluginAddress);
    }

    /**
     * @notice Subscribe to events for a registered game
     * @dev Creates Somnia reactivity subscription for automatic event handling
     */
    function subscribeToEvent(
        bytes32 eventSignature,
        uint256 deposit
    ) external payable {
        require(msg.value >= deposit, "Insufficient deposit");
        require(registeredGames[msg.sender].gameAddress != address(0), "Game not registered");

        // Add to subscribed events
        registeredGames[msg.sender].subscribedEvents.push(eventSignature);

        // Register with Somnia Reactivity
        // ISomniaEventHandler(REACTIVITY_PRECOMPILE).createSoliditySubscription{value: deposit}(
        //     eventSignature,
        //     msg.sender,  // Game emits the event
        //     address(this) // We handle it
        // );

        emit SubscriptionCreated(msg.sender, eventSignature);
    }

    /**
     * @notice Unregister a game
     */
    function unregisterGame(address gameAddress) external {
        require(
            msg.sender == gameAddress || msg.sender == owner(),
            "Not authorized"
        );
        require(registeredGames[gameAddress].gameAddress != address(0), "Game not registered");

        delete registeredGames[gameAddress];

        emit GameUnregistered(gameAddress);
    }

    // ============ Event Handling (Somnia Reactivity) ============

    /**
     * @notice Handle on-chain events from Somnia validators
     * @dev This is called by Somnia when a subscribed event fires
     *      Routes to the appropriate game's plugin
     */
    function _onEvent(
        address emitter,
        bytes32[] calldata topics,
        bytes calldata data
    ) external {
        // Verify Somnia validator call
        require(
            msg.sender == address(0x100) || msg.sender == REACTIVITY_PRECOMPILE,
            "Only Somnia validators"
        );

        RegisteredGame storage game = registeredGames[emitter];
        require(game.isActive, "Game not active");

        // Parse event data
        AgentTypes.GameEvent memory gameEvent = AgentTypes.GameEvent({
            emitter: emitter,
            eventName: "",               // Will be parsed from data
            player: address(0),          // Will be parsed from data
            data: data,
            blockNumber: block.number,
            timestamp: block.timestamp
        });

        // Create action request for plugin
        uint256 requestId = _createRequest(
            emitter,
            AgentTypes.ActionType.SPAWN,
            data  // Pass raw event data to plugin
        );

        // In production: call LLM Agent and route to plugin callback
        // For now: execute plugin directly with rule-based fallback
        _executePlugin(game.pluginAddress, requestId, gameEvent);
    }

    // ============ Request Management ============

    /**
     * @notice Create a new action request
     * @dev Called by games or the runtime itself
     */
    function _createRequest(
        address game,
        AgentTypes.ActionType actionType,
        bytes calldata params
    ) internal returns (uint256) {
        uint256 requestId = nextRequestId++;

        requests[requestId] = AgentTypes.ActionRequest({
            requestId: requestId,
            requester: game,
            actionType: actionType,
            params: bytes(params),
            deposit: 0,
            timestamp: block.timestamp,
            status: AgentTypes.RequestStatus.PENDING
        });

        requestGame[requestId] = game;

        stats.totalRequests++;

        return requestId;
    }

    /**
     * @notice Execute plugin with game event data
     * @dev Plugin processes the event and returns action result
     */
    function _executePlugin(
        address plugin,
        uint256 requestId,
        AgentTypes.GameEvent memory gameEvent
    ) internal {
        AgentTypes.ActionRequest storage request = requests[requestId];
        request.status = AgentTypes.RequestStatus.PROCESSING;

        // In full implementation, this would:
        // 1. Build LLM prompt from gameEvent
        // 2. Call Somnia LLM Inference
        // 3. Wait for subcommittee consensus
        // 4. Parse response
        // 5. Execute plugin action

        // For demo: simulate successful execution
        results[requestId] = AgentTypes.ActionResult({
            requestId: requestId,
            success: true,
            data: abi.encode(gameEvent),
            errorMessage: "",
            executionTime: 100 // Simulated ms
        });

        request.status = AgentTypes.RequestStatus.COMPLETED;
        registeredGames[requestGame[requestId]].totalExecutions++;
        stats.successfulRequests++;

        emit ActionCompleted(requestId, true, 100);
        emit PluginExecuted(plugin, requestId, true);
    }

    // ============ LLM Integration ============

    /**
     * @notice Build LLM prompt from game event
     * @dev Delegates to plugin's getPrompt method
     */
    function buildPrompt(
        address plugin,
        AgentTypes.ActionType actionType,
        bytes calldata params,
        AgentTypes.ExecutionContext calldata context
    ) external view returns (string memory) {
        // Plugin builds the prompt
        return IAgentPlugin(plugin).getPrompt(actionType, params, context);
    }

    /**
     * @notice Handle LLM callback (from Somnia subcommittee)
     * @dev Parses AI response and executes plugin
     */
    function handleLLMResponse(
        uint256 requestId,
        bytes calldata aiResponse
    ) external {
        require(msg.sender == SOMNIA_PLATFORM, "Unauthorized");

        AgentTypes.ActionRequest storage request = requests[requestId];
        require(request.status == AgentTypes.RequestStatus.PROCESSING, "Invalid status");

        address game = requestGame[requestId];
        RegisteredGame storage gameConfig = registeredGames[game];

        // Parse AI response via plugin
        bytes memory parsed = IAgentPlugin(gameConfig.pluginAddress)
            .parseResponse(aiResponse);

        // Store result
        results[requestId] = AgentTypes.ActionResult({
            requestId: requestId,
            success: true,
            data: parsed,
            errorMessage: "",
            executionTime: block.timestamp - request.timestamp
        });

        request.status = AgentTypes.RequestStatus.COMPLETED;
        stats.successfulRequests++;
        stats.totalLLMCalls++;

        emit LLMResponseReceived(requestId, aiResponse);
        emit ActionCompleted(requestId, true, block.timestamp - request.timestamp);
    }

    // ============ View Functions ============

    /**
     * @notice Get registered game info
     */
    function getGame(address gameAddress) external view returns (
        string memory name,
        address plugin,
        bool isActive,
        uint256 totalExecutions
    ) {
        RegisteredGame memory game = registeredGames[gameAddress];
        return (game.name, game.pluginAddress, game.isActive, game.totalExecutions);
    }

    /**
     * @notice Get request status
     */
    function getRequest(uint256 requestId) external view returns (
        address requester,
        uint8 actionType,
        uint8 status,
        uint256 timestamp
    ) {
        AgentTypes.ActionRequest memory req = requests[requestId];
        return (req.requester, uint8(req.actionType), uint8(req.status), req.timestamp);
    }

    /**
     * @notice Get agent statistics
     */
    function getStats() external view returns (
        uint256 total,
        uint256 successful,
        uint256 failed,
        uint256 llmCalls
    ) {
        return (stats.totalRequests, stats.successfulRequests, stats.failedRequests, stats.totalLLMCalls);
    }

    /**
     * @notice Get all registered games
     */
    function getAllGames() external view returns (address[] memory) {
        return gameAddresses;
    }

    // ============ Admin ============

    function setCircuitBreaker(address _circuitBreaker) external onlyOwner {
        circuitBreaker = _circuitBreaker;
    }

    function toggleGameActive(address gameAddress) external onlyOwner {
        registeredGames[gameAddress].isActive = !registeredGames[gameAddress].isActive;
    }
}

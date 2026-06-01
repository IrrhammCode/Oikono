// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./core/AgentTypes.sol";
import "./core/IAgentPlugin.sol";
import "./plugins/SpawnPlugin.sol";
import "./plugins/EconomyPlugin.sol";
import "./plugins/NarrativePlugin.sol";
import "./plugins/BalancePlugin.sol";

/**
 * @title GameReactor
 * @notice Universal AI integration for Web3 games
 *
 * This is the ONLY contract game developers need to import.
 * It wraps all OIKONO Agent Kit complexity into a simple interface.
 *
 * Features:
 * - Automatic Somnia reactivity integration
 * - Plugin-based AI capabilities (spawn, economy, narrative, balance)
 * - Configurable rules per game type
 * - Minimal gas overhead with lazy initialization
 *
 * Usage (3 steps):
 * 1. Import and inherit GameReactor
 * 2. Configure plugins in constructor
 * 3. Emit events when game actions happen
 */
contract GameReactor is Ownable {
    using AgentTypes for AgentTypes.ExecutionContext;

    // ============ Enums ============
    enum GameType {
        RPG,        // Role-playing: enemies, quests, leveling
        STRATEGY,   // Resource management, units, economy
        CARD,       // Card generation, deck balancing
        PUZZLE,     // Challenge generation, difficulty
        RACING,     // Opponent AI, track generation
        SOCIAL,     // NPC dialogue, world events
        CUSTOM      // Custom plugin-based
    }

    enum AgentPlugin {
        SPAWN,      // Entity generation
        ECONOMY,    // Tokenomics & supply
        NARRATIVE,  // Quests & dialogue
        BALANCE,    // Difficulty scaling
        CUSTOM      // Custom plugin
    }

    enum EventType {
        PLAYER_ACTION,      // Player did something
        GAME_STATE,         // Game state changed
        ECONOMY,            // Economy event
        SOCIAL,             // Social/guild event
        CUSTOM              // Custom event
    }

    // ============ Structs ============
    struct Player {
        address wallet;
        uint256 level;
        uint256 xp;
        uint256 joinedAt;
        uint256 lastActionAt;
        bool exists;
    }

    struct GameConfig {
        string name;
        GameType gameType;
        address token;
        uint256 targetWinRate;      // Basis points (6500 = 65%)
        uint256 epochLength;        // Blocks between economy adjustments
        uint256 dailyRewardCap;     // Max rewards per player per day
        bool autoBalance;           // Auto-adjust difficulty
        bool autoEconomy;           // Auto-adjust tokenomics
    }

    struct PluginState {
        bool enabled;
        address pluginAddress;
        uint256 executions;
        uint256 lastExecution;
    }

    // ============ State ============
    GameConfig public config;
    mapping(address => Player) public players;
    mapping(AgentPlugin => PluginState) public plugins;
    address[] public registeredPlayers;

    // Plugin instances (lazily created)
    SpawnPlugin public spawnPlugin;
    EconomyPlugin public economyPlugin;
    NarrativePlugin public narrativePlugin;
    BalancePlugin public balancePlugin;

    // Somnia addresses (constants)
    address internal constant SOMNIA_PLATFORM = address(0x401);
    address internal constant REACTIVITY_PRECOMPILE = address(0x100);

    // Stats
    uint256 public totalEvents;
    uint256 public totalActions;
    uint256 public totalPlayers;

    // ============ Events (Standardized for Game Reactions) ============
    event GameInitialized(string name, GameType gameType);
    event PluginEnabled(AgentPlugin plugin, address pluginAddress);
    event PluginDisabled(AgentPlugin plugin);
    event PlayerRegistered(address indexed player);
    event PlayerUpdated(address indexed player, uint256 level, uint256 xp);
    event AgentActionTriggered(EventType eventType, AgentPlugin plugin, bytes data);
    event AgentActionResult(AgentPlugin plugin, bool success, bytes result);
    event ConfigUpdated(GameConfig newConfig);

    // ============ Constructor ============

    /**
     * @notice Initialize GameReactor
     * @param gameName Your game's name
     * @param _gameType Type of game (RPG, STRATEGY, CARD, etc.)
     */
    constructor(string memory gameName, GameType _gameType) Ownable(msg.sender) {
        config = GameConfig({
            name: gameName,
            gameType: _gameType,
            token: address(0),
            targetWinRate: 6500,     // 65%
            epochLength: 1000,
            dailyRewardCap: 2000 * 1e18,
            autoBalance: true,
            autoEconomy: false
        });

        emit GameInitialized(gameName, _gameType);
    }

    // ============ Plugin Management ============

    /**
     * @notice Enable an AI plugin for your game
     * @param plugin The plugin to enable
     */
    function enablePlugin(AgentPlugin plugin) public onlyOwner {
        if (!plugins[plugin].enabled) {
            address pluginAddress = _getOrCreatePlugin(plugin);
            plugins[plugin] = PluginState({
                enabled: true,
                pluginAddress: pluginAddress,
                executions: 0,
                lastExecution: 0
            });
            emit PluginEnabled(plugin, pluginAddress);
        }
    }

    /**
     * @notice Disable an AI plugin
     */
    function disablePlugin(AgentPlugin plugin) public onlyOwner {
        plugins[plugin].enabled = false;
        emit PluginDisabled(plugin);
    }

    /**
     * @notice Get or create plugin instance
     */
    function _getOrCreatePlugin(AgentPlugin plugin) internal returns (address) {
        if (plugin == AgentPlugin.SPAWN) {
            if (address(spawnPlugin) == address(0)) {
                spawnPlugin = new SpawnPlugin();
            }
            return address(spawnPlugin);
        } else if (plugin == AgentPlugin.ECONOMY) {
            if (address(economyPlugin) == address(0)) {
                economyPlugin = new EconomyPlugin();
            }
            return address(economyPlugin);
        } else if (plugin == AgentPlugin.NARRATIVE) {
            if (address(narrativePlugin) == address(0)) {
                narrativePlugin = new NarrativePlugin();
            }
            return address(narrativePlugin);
        } else if (plugin == AgentPlugin.BALANCE) {
            if (address(balancePlugin) == address(0)) {
                balancePlugin = new BalancePlugin();
            }
            return address(balancePlugin);
        }
        return address(0);
    }

    // ============ Player Management ============

    /**
     * @notice Register a new player (call this in your game's register function)
     */
    function registerPlayer(address player) internal {
        require(!players[player].exists, "Already registered");

        players[player] = Player({
            wallet: player,
            level: 1,
            xp: 0,
            joinedAt: block.timestamp,
            lastActionAt: block.timestamp,
            exists: true
        });

        registeredPlayers.push(player);
        totalPlayers++;

        emit PlayerRegistered(player);
    }

    /**
     * @notice Update player state (call this when player levels up, gains XP, etc.)
     */
    function updatePlayer(address player, uint256 newLevel, uint256 newXp) internal {
        require(players[player].exists, "Player not registered");

        players[player].level = newLevel;
        players[player].xp = newXp;
        players[player].lastActionAt = block.timestamp;

        emit PlayerUpdated(player, newLevel, newXp);
    }

    /**
     * @notice Get player info
     */
    function getPlayer(address player) external view returns (
        uint256 level,
        uint256 xp,
        uint256 joinedAt,
        bool exists
    ) {
        Player storage p = players[player];
        return (p.level, p.xp, p.joinedAt, p.exists);
    }

    // ============ Event Handling (Somnia Reactivity) ============

    /**
     * @notice Handle on-chain events from Somnia validators
     * @dev This is called automatically by Somnia when subscribed events fire
     */
    function _onEvent(
        address emitter,
        bytes32[] calldata topics,
        bytes calldata data
    ) external {
        // Verify Somnia validator
        require(
            msg.sender == address(0x100) || msg.sender == REACTIVITY_PRECOMPILE,
            "Only Somnia validators"
        );

        totalEvents++;

        // Parse event type and route to appropriate plugin
        EventType eventType = _determineEventType(topics, data);
        AgentPlugin targetPlugin = _routeToPlugin(eventType);

        if (targetPlugin != AgentPlugin.CUSTOM || plugins[AgentPlugin.CUSTOM].enabled) {
            _executePlugin(targetPlugin, emitter, topics, data);
        }
    }

    /**
     * @notice Manually trigger agent action (for testing or explicit calls)
     */
    function triggerAction(
        AgentPlugin plugin,
        bytes calldata params
    ) external onlyOwner returns (bytes memory) {
        require(plugins[plugin].enabled, "Plugin not enabled");

        AgentTypes.ExecutionContext memory context = _buildContext(msg.sender);
        IAgentPlugin pluginContract = IAgentPlugin(plugins[plugin].pluginAddress);

        bytes memory result = pluginContract.execute(
            AgentTypes.ActionType.SPAWN,
            params,
            context
        );

        plugins[plugin].executions++;
        plugins[plugin].lastExecution = block.timestamp;
        totalActions++;

        emit AgentActionResult(plugin, true, result);

        return result;
    }

    // ============ Internal Functions ============

    function _determineEventType(bytes32[] calldata topics, bytes calldata /* data */) internal pure returns (EventType) {
        if (topics.length == 0) return EventType.PLAYER_ACTION;

        bytes32 sig = topics[0];

        // PlayerMoved, PlayerRegistered → PLAYER_ACTION
        if (sig == keccak256("PlayerMoved(address,uint256,uint256,uint256,uint256)") ||
            sig == keccak256("PlayerRegistered(address,uint256,uint256)")) {
            return EventType.PLAYER_ACTION;
        }

        // Transfer, Approval → ECONOMY
        if (sig == keccak256("Transfer(address,address,uint256)") ||
            sig == keccak256("Approval(address,address,uint256)")) {
            return EventType.ECONOMY;
        }

        // BattleEnded, EnemyGenerated → GAME_STATE
        if (sig == keccak256("BattleEnded(address,uint256,bool,uint256,uint256)") ||
            sig == keccak256("EnemyGenerated(address,uint256,string,string,uint256)")) {
            return EventType.GAME_STATE;
        }

        return EventType.PLAYER_ACTION;
    }

    function _routeToPlugin(EventType eventType) internal view returns (AgentPlugin) {
        if (eventType == EventType.PLAYER_ACTION && plugins[AgentPlugin.SPAWN].enabled) {
            return AgentPlugin.SPAWN;
        } else if (eventType == EventType.ECONOMY && plugins[AgentPlugin.ECONOMY].enabled) {
            return AgentPlugin.ECONOMY;
        }
        return AgentPlugin.SPAWN; // Default
    }

    function _executePlugin(
        AgentPlugin pluginType,
        address emitter,
        bytes32[] calldata topics,
        bytes calldata data
    ) internal {
        AgentTypes.ExecutionContext memory context = _buildContext(emitter);

        address pluginAddr = plugins[pluginType].pluginAddress;
        IAgentPlugin pluginContract = IAgentPlugin(pluginAddr);

        // Build params from event data
        bytes memory params = _buildParams(emitter, topics, data);

        // Execute plugin
        bytes memory result = pluginContract.execute(
            AgentTypes.ActionType.SPAWN,
            params,
            context
        );

        plugins[pluginType].executions++;
        plugins[pluginType].lastExecution = block.timestamp;
        totalActions++;

        emit AgentActionResult(pluginType, true, result);
    }

    function _buildContext(address player) internal view returns (AgentTypes.ExecutionContext memory) {
        Player storage p = players[player];
        return AgentTypes.ExecutionContext({
            player: player,
            playerLevel: p.exists ? p.level : 1,
            playerXP: p.exists ? p.xp : 0,
            gameState: 0,
            extraData: ""
        });
    }

    function _buildParams(address emitter, bytes32[] calldata topics, bytes calldata data) internal view returns (bytes memory) {
        // Default: pass emitter address and block number
        return abi.encode(emitter, block.number);
    }

    // ============ Configuration ============

    /**
     * @notice Update game configuration
     */
    function updateConfig(GameConfig calldata newConfig) external onlyOwner {
        require(bytes(newConfig.name).length > 0, "Name required");
        config = newConfig;
        emit ConfigUpdated(newConfig);
    }

    /**
     * @notice Set token address for economy features
     */
    function setToken(address token) external onlyOwner {
        config.token = token;
    }

    /**
     * @notice Configure spawn plugin for this game
     */
    function configureSpawn(
        string[12] memory names,
        uint256 minPower,
        uint256 maxPower,
        string[6] memory attributes
    ) public onlyOwner {
        require(plugins[AgentPlugin.SPAWN].enabled, "Spawn not enabled");
        spawnPlugin.configureGame(
            address(this),
            _gameTypeToString(),
            names,
            minPower,
            maxPower,
            attributes,
            true,
            10000
        );
    }

    /**
     * @notice Configure economy plugin
     */
    function configureEconomy(
        uint256 targetWinRate,
        uint256 epochLength
    ) public onlyOwner {
        require(plugins[AgentPlugin.ECONOMY].enabled, "Economy not enabled");
        economyPlugin.configureGame(config.token, address(0), epochLength, targetWinRate);
    }

    /**
     * @notice Configure balance plugin
     */
    function configureBalance(
        uint256 targetWinRate,
        uint256 diffFloor,
        uint256 diffCeiling
    ) public onlyOwner {
        require(plugins[AgentPlugin.BALANCE].enabled, "Balance not enabled");
        balancePlugin.configureGame(targetWinRate, diffFloor, diffCeiling);
    }

    function _gameTypeToString() internal view returns (string memory) {
        if (config.gameType == GameType.RPG) return "rpg";
        if (config.gameType == GameType.STRATEGY) return "strategy";
        if (config.gameType == GameType.CARD) return "card";
        if (config.gameType == GameType.PUZZLE) return "puzzle";
        if (config.gameType == GameType.RACING) return "racing";
        if (config.gameType == GameType.SOCIAL) return "social";
        return "custom";
    }

    // ============ View Functions ============

    /**
     * @notice Get game info
     */
    function getGameInfo() public view returns (
        string memory name,
        GameType gameType,
        uint256 totalPlayers_,
        uint256 totalEvents_,
        uint256 totalActions_
    ) {
        return (config.name, config.gameType, totalPlayers, totalEvents, totalActions);
    }

    /**
     * @notice Check if plugin is enabled
     */
    function isPluginEnabled(AgentPlugin plugin) public view returns (bool) {
        return plugins[plugin].enabled;
    }

    /**
     * @notice Get plugin stats
     */
    function getPluginStats(AgentPlugin plugin) public view returns (
        bool enabled,
        address pluginAddr,
        uint256 executions,
        uint256 lastExecution
    ) {
        PluginState storage ps = plugins[plugin];
        return (ps.enabled, ps.pluginAddress, ps.executions, ps.lastExecution);
    }

    // ============ Admin ============

    function transferGameOwnership(address newOwner) external onlyOwner {
        _transferOwnership(newOwner);
    }

    receive() external payable {}
}

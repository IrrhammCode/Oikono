// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../agents/GameReactor.sol";
import "../agents/core/IGameDescriptor.sol";
import "../agents/core/IGameStateReader.sol";

/**
 * @title SimpleRPG
 * @notice Example: Game that implements IGameDescriptor for auto-registration
 * @dev This game describes itself to the OIKONO agent via IGameDescriptor.
 *      The agent reads the descriptor and auto-configures everything.
 *
 *      Flow:
 *      1. Game deployed
 *      2. Game calls agent.autoRegisterGame(address(this))
 *      3. Agent reads getGameIdentity(), getEntitySchema(), etc.
 *      4. Agent auto-selects plugins, auto-configures, auto-subscribes
 *      5. Game emits events → Agent reacts intelligently
 *
 *      Game developer writes GAME LOGIC only.
 *      Agent handles everything else.
 */
contract SimpleRPG is GameReactor, IGameDescriptor, IGameStateReader {

    // ============ Game State ============
    struct Enemy {
        uint256 id;
        string name;
        uint256 hp;
        uint256 power;
        bool exists;
    }

    mapping(uint256 => Enemy) public enemies;
    uint256 public nextEnemyId;
    uint256 public activeEnemies;

    mapping(address => uint256) public playerKills;
    mapping(address => uint256) public playerGold;

    // Battle stats for IGameStateReader
    uint256 public totalBattlesGlobal;
    uint256 public totalWinsGlobal;
    uint256 public totalRewardsDistributed;

    // Recent events storage for IGameStateReader
    bytes[] public recentEvents;
    uint256 public constant MAX_RECENT_EVENTS = 50;

    // ============ Events ============
    event PlayerMoved(address indexed player, uint256 x, uint256 y, uint256 xp);
    event EnemySpawned(uint256 indexed enemyId, string name, uint256 power, address spawnedBy);
    event EnemyDefeated(uint256 indexed enemyId, address indexed killer, uint256 goldReward);
    event PlayerLeveledUp(address indexed player, uint256 newLevel);
    event BattleEnded(address indexed player, uint256 indexed enemyId, bool won, uint256 reward, uint256 xp);

    // ============ Constructor ============

    constructor() GameReactor("SimpleRPG", GameType.RPG) {
        enablePlugin(AgentPlugin.SPAWN);
        enablePlugin(AgentPlugin.BALANCE);
        enablePlugin(AgentPlugin.NARRATIVE);

        string[12] memory names = [
            "Goblin", "Skeleton", "Wolf", "Slime",
            "Orc", "Troll", "Wraith", "Dragon",
            "Demon", "Golem", "Phoenix", "Hydra"
        ];
        string[6] memory attrs = ["fire", "ice", "earth", "lightning", "shadow", "holy"];
        configureSpawn(names, 10, 100, attrs);
        configureBalance(6000, 1, 100);
    }

    // ============ IGameDescriptor Implementation ============

    function getGameIdentity() external pure override returns (
        string memory name,
        string memory version,
        string memory gameType
    ) {
        return ("SimpleRPG", "1.0.0", "rpg");
    }

    function getEntitySchema() external pure override returns (
        string[] memory entityTypes,
        string[] memory entitySchemas
    ) {
        entityTypes = new string[](1);
        entityTypes[0] = "enemy";

        entitySchemas = new string[](1);
        entitySchemas[0] = '{"name":"string","power":"uint256(10-100)","hp":"uint256","type":"goblin|skeleton|wolf|slime|orc|troll|wraith|dragon|demon|golem|phoenix|hydra"}';
    }

    function getEconomySchema() external pure override returns (
        bool hasToken,
        address tokenAddress,
        string[] memory currencies,
        string[] memory sinks,
        string[] memory sources
    ) {
        hasToken = false;
        tokenAddress = address(0);

        currencies = new string[](1);
        currencies[0] = "gold";

        sinks = new string[](1);
        sinks[0] = "enemy_spawn_cost";

        sources = new string[](2);
        sources[0] = "battle_reward";
        sources[1] = "exploration_reward";
    }

    function getMetricsSchema() external view override returns (
        string[] memory metricNames,
        uint256[] memory metricTargets,
        uint256[] memory metricCurrent
    ) {
        metricNames = new string[](3);
        metricNames[0] = "win_rate";
        metricNames[1] = "avg_power";
        metricNames[2] = "active_enemies";

        metricTargets = new uint256[](3);
        metricCurrent = new uint256[](3);

        uint256 winRate = totalBattlesGlobal > 0
            ? (totalWinsGlobal * 10000) / totalBattlesGlobal
            : 5000;

        metricTargets[0] = 6000; // Target 60% win rate
        metricTargets[1] = 50;   // Target avg power 50
        metricTargets[2] = 10;   // Target 10 active enemies

        metricCurrent[0] = winRate;
        metricCurrent[1] = _getAverageEnemyPower();
        metricCurrent[2] = activeEnemies;
    }

    function getEventSchema() external pure override returns (
        bytes32[] memory eventSignatures,
        string[] memory eventNames,
        string[] memory eventActions
    ) {
        eventSignatures = new bytes32[](3);
        eventNames = new string[](3);
        eventActions = new string[](3);

        eventSignatures[0] = keccak256("PlayerMoved(address,uint256,uint256,uint256)");
        eventNames[0] = "PlayerMoved";
        eventActions[0] = "spawn";

        eventSignatures[1] = keccak256("BattleEnded(address,uint256,bool,uint256,uint256)");
        eventNames[1] = "BattleEnded";
        eventActions[1] = "balance";

        eventSignatures[2] = keccak256("PlayerLeveledUp(address,uint256)");
        eventNames[2] = "PlayerLeveledUp";
        eventActions[2] = "spawn";
    }

    function getGoals() external pure override returns (
        string[] memory goals,
        uint256[] memory goalWeights
    ) {
        goals = new string[](3);
        goals[0] = "player_retention";
        goals[1] = "fun_factor";
        goals[2] = "token_stability";

        goalWeights = new uint256[](3);
        goalWeights[0] = 4000; // 40%
        goalWeights[1] = 4000; // 40%
        goalWeights[2] = 2000; // 20%
    }

    function getAgentPermissions() external pure override returns (
        bool canSpawn,
        bool canAdjustEconomy,
        bool canGenerateNarrative,
        bool canAdjustDifficulty,
        uint256 maxAdjustmentPerEpoch
    ) {
        return (true, false, true, true, 2000); // Max 20% change per epoch
    }

    // ============ IGameStateReader Implementation ============

    function getPlayerState(address player) external view override returns (
        uint256 level,
        uint256 xp,
        bytes memory position,
        uint256[] memory stats
    ) {
        Player storage p = players[player];
        level = p.level;
        xp = p.xp;
        position = abi.encode(p.xp, p.level); // Simplified

        stats = new uint256[](3);
        stats[0] = playerKills[player];
        stats[1] = playerGold[player];
        stats[2] = p.lastActionAt;
    }

    function getGameState() external view override returns (
        uint256 totalPlayersCount,
        uint256 activePlayersCount,
        uint256 totalEntities,
        uint256[] memory globalStats
    ) {
        totalPlayersCount = totalPlayers;
        activePlayersCount = totalPlayers; // Simplified
        totalEntities = activeEnemies;

        globalStats = new uint256[](4);
        globalStats[0] = totalBattlesGlobal;
        globalStats[1] = totalWinsGlobal;
        globalStats[2] = totalRewardsDistributed;
        globalStats[3] = nextEnemyId;
    }

    function getEconomyState() external pure override returns (
        uint256 circulatingSupply,
        uint256 totalSupply,
        uint256 totalBurned,
        uint256 velocity,
        uint256 avgRewardPerPlayer
    ) {
        // SimpleRPG has no token — return zeros
        return (0, 0, 0, 0, 0);
    }

    function getBalanceMetrics() external view override returns (
        uint256 winRate,
        uint256 avgBattleDuration,
        uint256[] memory difficultyDistribution,
        uint256 playerRetention
    ) {
        winRate = totalBattlesGlobal > 0
            ? (totalWinsGlobal * 10000) / totalBattlesGlobal
            : 5000;

        avgBattleDuration = 1; // 1 block

        difficultyDistribution = new uint256[](5);
        // Distribution: easy(1-20), medium(21-50), hard(51-80), extreme(81-100)
        difficultyDistribution[0] = 0; // placeholder
        difficultyDistribution[1] = 0;
        difficultyDistribution[2] = 0;
        difficultyDistribution[3] = 0;
        difficultyDistribution[4] = 0;

        playerRetention = 8000; // 80% (placeholder)
    }

    function getRecentEvents(uint256 count) external view override returns (
        bytes[] memory events
    ) {
        uint256 len = recentEvents.length;
        uint256 startIdx = len > count ? len - count : 0;
        uint256 resultCount = len - startIdx;

        events = new bytes[](resultCount);
        for (uint256 i = 0; i < resultCount; i++) {
            events[i] = recentEvents[startIdx + i];
        }
    }

    function _storeEvent(bytes memory eventData) internal {
        if (recentEvents.length >= MAX_RECENT_EVENTS) {
            // Rotate: remove oldest
            for (uint256 i = 0; i < MAX_RECENT_EVENTS - 1; i++) {
                recentEvents[i] = recentEvents[i + 1];
            }
            recentEvents[MAX_RECENT_EVENTS - 1] = eventData;
        } else {
            recentEvents.push(eventData);
        }
    }

    // ============ Core Game Functions ============

    function register() external {
        registerPlayer(msg.sender);
    }

    function move(uint256 x, uint256 y) external {
        require(players[msg.sender].exists, "Register first");

        Player storage player = players[msg.sender];
        uint256 newXp = player.xp + 10;
        uint256 newLevel = 1 + (newXp / 100);

        if (newLevel > player.level) {
            emit PlayerLeveledUp(msg.sender, newLevel);
        }

        updatePlayer(msg.sender, newLevel, newXp);
        emit PlayerMoved(msg.sender, x, y, newXp);

        // Store event for IGameStateReader
        _storeEvent(abi.encodePacked(
            abi.encode(msg.sender, x, y, newXp, newLevel)
        ));
    }

    function attackEnemy(uint256 enemyId) external {
        require(players[msg.sender].exists, "Register first");
        require(enemies[enemyId].exists, "Enemy not found");

        Enemy storage enemy = enemies[enemyId];
        Player storage player = players[msg.sender];

        uint256 playerPower = player.level * 10;
        bool won = playerPower >= enemy.power;

        uint256 reward = 0;
        uint256 xpGain = 0;

        if (won) {
            reward = enemy.power * 2;
            xpGain = enemy.power * 10;
            playerKills[msg.sender]++;
            playerGold[msg.sender] += reward;
            totalWinsGlobal++;
            totalRewardsDistributed += reward;

            delete enemies[enemyId];
            activeEnemies--;
        } else {
            uint256 xpLoss = player.xp / 20;
            if (xpLoss > player.xp) xpLoss = player.xp;
            player.xp -= xpLoss;
        }

        totalBattlesGlobal++;

        // Update player XP
        uint256 newXp = player.xp + xpGain;
        uint256 newLevel = 1 + (newXp / 100);
        if (newLevel > player.level) {
            emit PlayerLeveledUp(msg.sender, newLevel);
        }
        updatePlayer(msg.sender, newLevel, newXp);

        emit BattleEnded(msg.sender, enemyId, won, reward, xpGain);
        emit EnemyDefeated(enemyId, msg.sender, reward);

        // Store event for IGameStateReader
        _storeEvent(abi.encodePacked(
            abi.encode(msg.sender, enemyId, won, reward, xpGain)
        ));
    }

    // ============ Helpers ============

    function _getAverageEnemyPower() internal view returns (uint256) {
        if (activeEnemies == 0) return 0;
        uint256 totalPower = 0;
        uint256 count = 0;
        for (uint256 i = 0; i < nextEnemyId; i++) {
            if (enemies[i].exists) {
                totalPower += enemies[i].power;
                count++;
            }
        }
        return count > 0 ? totalPower / count : 0;
    }

    // ============ View Functions ============

    function getEnemy(uint256 enemyId) external view returns (
        string memory name, uint256 hp, uint256 power, bool exists
    ) {
        Enemy storage e = enemies[enemyId];
        return (e.name, e.hp, e.power, e.exists);
    }

    function getPlayerStats(address player) external view returns (
        uint256 kills, uint256 gold
    ) {
        return (playerKills[player], playerGold[player]);
    }
}

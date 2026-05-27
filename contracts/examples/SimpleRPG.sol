// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../agents/GameReactor.sol";

/**
 * @title SimpleRPG
 * @notice Example: How simple it is to integrate AI into a Web3 game
 *
 * @dev This entire game only needs:
 *      1. Import GameReactor
 *      2. Configure plugins in constructor
 *      3. Emit events when things happen
 *
 *      Agent handles: enemy spawning, economy, quests, difficulty — automatically!
 *
 * @dev TOTAL LINES OF CODE: ~50
 *      Without OIKONO Agent Kit: ~500+ lines
 */
contract SimpleRPG is GameReactor {

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

    // ============ Events ============
    event PlayerMoved(address indexed player, uint256 x, uint256 y, uint256 xp);
    event EnemySpawned(uint256 indexed enemyId, string name, uint256 power, address spawnedBy);
    event EnemyDefeated(uint256 indexed enemyId, address indexed killer, uint256 goldReward);
    event PlayerLeveledUp(address indexed player, uint256 newLevel);

    // ============ Constructor ============
    /**
     * @notice Create your RPG game with AI agents in ONE line of config!
     *
     * That's it. The agent will now:
     * - Auto-spawn enemies when players move
     * - Scale difficulty based on player level
     * - Generate quests with AI narrative
     * - Balance economy automatically
     */
    constructor() GameReactor("SimpleRPG", GameType.RPG) {
        // Enable the AI plugins we want
        enablePlugin(AgentPlugin.SPAWN);      // Auto-generate enemies
        enablePlugin(AgentPlugin.BALANCE);    // Auto-balance difficulty
        enablePlugin(AgentPlugin.NARRATIVE);  // Auto-generate quests

        // Configure spawn settings
        string[12] memory names = [
            "Goblin", "Skeleton", "Wolf", "Slime",
            "Orc", "Troll", "Wraith", "Dragon",
            "Demon", "Golem", "Phoenix", "Hydra"
        ];
        string[6] memory attrs = ["fire", "ice", "earth", "lightning", "shadow", "holy"];
        configureSpawn(names, 10, 100, attrs);

        // Configure balance
        configureBalance(6000, 1, 100); // 60% win rate target
    }

    // ============ Core Game Functions ============
    // These are the ONLY functions the game developer writes!

    /**
     * @notice Player registers to play
     * @dev Agent will auto-track this player for balancing
     */
    function register() external {
        registerPlayer(msg.sender);
    }

    /**
     * @notice Player moves in the game world
     * @dev Agent will auto-spawn enemies based on this event!
     */
    function move(uint256 x, uint256 y) external {
        require(players[msg.sender].exists, "Register first");

        // Update player XP (simple: 10 XP per move)
        Player storage player = players[msg.sender];
        uint256 newXp = player.xp + 10;
        uint256 newLevel = 1 + (newXp / 100);

        // Level up check
        if (newLevel > player.level) {
            emit PlayerLeveledUp(msg.sender, newLevel);
        }

        updatePlayer(msg.sender, newLevel, newXp);

        // Emit event — Agent reacts to this!
        emit PlayerMoved(msg.sender, x, y, newXp);

        // ⚡ Agent automatically:
        // 1. Spawns enemy with power scaled to player level
        // 2. Balances difficulty based on win rate
        // 3. May generate a quest
    }

    /**
     * @notice Player attacks an enemy
     * @dev Simple combat — agent manages enemy stats
     */
    function attackEnemy(uint256 enemyId) external {
        require(players[msg.sender].exists, "Register first");
        require(enemies[enemyId].exists, "Enemy not found");

        Enemy storage enemy = enemies[enemyId];
        Player storage player = players[msg.sender];

        // Simple combat: player level vs enemy power
        uint256 playerPower = player.level * 10;

        if (playerPower >= enemy.power) {
            // Player wins!
            uint256 goldReward = enemy.power * 2;
            playerKills[msg.sender]++;
            playerGold[msg.sender] += goldReward;

            delete enemies[enemyId];
            activeEnemies--;

            emit EnemyDefeated(enemyId, msg.sender, goldReward);
        } else {
            // Player loses — lose some XP
            uint256 xpLoss = player.xp / 20;
            if (xpLoss > player.xp) xpLoss = player.xp;
            player.xp -= xpLoss;
        }
    }

    // ============ Helper Functions ============

    /**
     * @notice Manually trigger enemy spawn (also happens automatically via Agent!)
     */
    function spawnEnemy(uint256 x, uint256 y) external returns (uint256) {
        // This can be called manually OR by the Agent automatically
        uint256 enemyId = nextEnemyId++;

        // Agent determines enemy stats based on player level
        Player storage player = players[msg.sender];
        uint256 power = 20 + (player.level * 5);

        enemies[enemyId] = Enemy({
            id: enemyId,
            name: "Wild Creature",
            hp: power * 10,
            power: power,
            exists: true
        });

        activeEnemies++;
        emit EnemySpawned(enemyId, "Wild Creature", power, msg.sender);

        return enemyId;
    }

    /**
     * @notice Get enemy info
     */
    function getEnemy(uint256 enemyId) external view returns (string memory name, uint256 hp, uint256 power, bool exists) {
        Enemy storage e = enemies[enemyId];
        return (e.name, e.hp, e.power, e.exists);
    }

    /**
     * @notice Get player stats
     */
    function getPlayerStats(address player) external view returns (uint256 kills, uint256 gold) {
        return (playerKills[player], playerGold[player]);
    }

    /**
     * @notice Get game stats (proves agent is working)
     */
    function getAgentStats() external view returns (
        string memory gameName,
        uint256 totalPlayers_,
        uint256 totalEvents_,
        uint256 totalActions_
    ) {
        (, , totalPlayers_, totalEvents_, totalActions_) = getGameInfo();
        return (config.name, totalPlayers_, totalEvents_, totalActions_);
    }
}

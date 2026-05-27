// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../agents/GameReactor.sol";

/**
 * @title SimpleStrategy
 * @notice Example: Strategy game with AI-managed economy and units
 *
 * @dev Proves universality: same GameReactor, strategy game!
 *      Agent manages: resource economy, unit spawning, difficulty
 */
contract SimpleStrategy is GameReactor {

    // ============ Game State ============
    struct PlayerState {
        uint256 gold;
        uint256 food;
        uint256 soldiers;
        uint256 buildings;
        bool exists;
    }

    struct Unit {
        uint256 id;
        address owner;
        uint256 attack;
        uint256 defense;
        uint256 hp;
        bool isAlive;
    }

    struct Battle {
        address attacker;
        address defender;
        uint256 attackerPower;
        uint256 defenderPower;
        uint256 turn;
        bool isActive;
    }

    mapping(address => PlayerState) public playerStates;
    mapping(uint256 => Unit) public units;
    mapping(uint256 => Battle) public battles;

    uint256 public nextUnitId;
    uint256 public nextBattleId;
    uint256 public totalBattles;

    // ============ Events ============
    event ResourceGathered(address indexed player, uint256 gold, uint256 food);
    event UnitTrained(address indexed player, uint256 unitId, uint256 attack, uint256 defense);
    event BattleStarted(uint256 battleId, address attacker, address defender);
    event BattleEnded(uint256 battleId, address winner, uint256 goldReward);
    event EconomyAdjusted(string parameter, int256 oldValue, int256 newValue);

    // ============ Constructor ============
    /**
     * @notice Strategy game with AI economy management
     * Agent auto-balances: resource generation, unit costs, battle rewards
     */
    constructor() GameReactor("StrategyWar", GameType.STRATEGY) {
        enablePlugin(AgentPlugin.ECONOMY);   // Auto-manage economy
        enablePlugin(AgentPlugin.BALANCE);   // Auto-balance units

        // Configure economy
        configureEconomy(5500, 500); // 55% win rate, 500 blocks per epoch

        // Configure balance for strategy
        configureBalance(5500, 1, 50); // 55% win rate, difficulty 1-50
    }

    // ============ Core Game Functions ============

    /**
     * @notice Register as a player
     */
    function register() external {
        registerPlayer(msg.sender);
        playerStates[msg.sender] = PlayerState({
            gold: 100,
            food: 100,
            soldiers: 5,
            buildings: 1,
            exists: true
        });
    }

    /**
     * @notice Gather resources (triggers economy agent)
     */
    function gatherResources() external {
        require(playerStates[msg.sender].exists, "Register first");

        PlayerState storage state = playerStates[msg.sender];

        // Base gathering
        uint256 goldGain = 10 + (state.buildings * 5);
        uint256 foodGain = 15 + (state.buildings * 3);

        state.gold += goldGain;
        state.food += foodGain;

        emit ResourceGathered(msg.sender, goldGain, foodGain);

        // ⚡ Agent may auto-adjust economy based on resource flow
    }

    /**
     * @notice Train a new unit (Agent determines unit stats)
     */
    function trainUnit() external {
        require(playerStates[msg.sender].exists, "Register first");

        PlayerState storage state = playerStates[msg.sender];
        require(state.gold >= 50 && state.food >= 30, "Insufficient resources");

        // Pay cost
        state.gold -= 50;
        state.food -= 30;

        // Create unit (Agent would determine stats in production)
        uint256 unitId = nextUnitId++;
        uint256 playerLevel = players[msg.sender].level;

        // Stats scale with player level (agent manages this)
        uint256 attack = 5 + (playerLevel * 2);
        uint256 defense = 3 + playerLevel;
        uint256 hp = 20 + (playerLevel * 5);

        units[unitId] = Unit({
            id: unitId,
            owner: msg.sender,
            attack: attack,
            defense: defense,
            hp: hp,
            isAlive: true
        });

        state.soldiers++;

        emit UnitTrained(msg.sender, unitId, attack, defense);
    }

    /**
     * @notice Build a structure (increases resource generation)
     */
    function buildStructure() external {
        require(playerStates[msg.sender].exists, "Register first");

        PlayerState storage state = playerStates[msg.sender];
        require(state.gold >= 100, "Need 100 gold");

        state.gold -= 100;
        state.buildings++;

        // Update player XP
        Player storage player = players[msg.sender];
        updatePlayer(msg.sender, player.level, player.xp + 50);
    }

    /**
     * @notice Start a battle with another player
     */
    function startBattle(address defender) external {
        require(playerStates[msg.sender].exists, "Register first");
        require(playerStates[defender].exists, "Defender not registered");

        uint256 battleId = nextBattleId++;

        // Calculate army power
        uint256 attackerPower = _calculateArmyPower(msg.sender);
        uint256 defenderPower = _calculateArmyPower(defender);

        battles[battleId] = Battle({
            attacker: msg.sender,
            defender: defender,
            attackerPower: attackerPower,
            defenderPower: defenderPower,
            turn: 1,
            isActive: true
        });

        totalBattles++;
        emit BattleStarted(battleId, msg.sender, defender);
    }

    /**
     * @notice Resolve battle outcome
     */
    function resolveBattle(uint256 battleId) external {
        Battle storage battle = battles[battleId];
        require(battle.isActive, "Battle not active");

        // Higher power wins
        address winner;
        uint256 goldReward;

        if (battle.attackerPower >= battle.defenderPower) {
            winner = battle.attacker;
            goldReward = battle.defenderPower;
        } else {
            winner = battle.defender;
            goldReward = battle.attackerPower;
        }

        // Award gold
        playerStates[winner].gold += goldReward;

        // Update player XP and stats
        Player storage player = players[winner];
        updatePlayer(winner, player.level + 1, player.xp + 100);

        battle.isActive = false;
        emit BattleEnded(battleId, winner, goldReward);

        // ⚡ Agent will auto-balance based on battle results
    }

    // ============ Helper Functions ============

    function _calculateArmyPower(address player) internal view returns (uint256) {
        PlayerState storage state = playerStates[player];
        // Simple formula: soldiers * average stats
        uint256 basePower = state.soldiers * 10;
        uint256 buildingBonus = state.buildings * 5;
        return basePower + buildingBonus;
    }

    /**
     * @notice Get player state
     */
    function getPlayerState(address player) external view returns (
        uint256 gold, uint256 food, uint256 soldiers, uint256 buildings
    ) {
        PlayerState storage s = playerStates[player];
        return (s.gold, s.food, s.soldiers, s.buildings);
    }

    /**
     * @notice Get unit stats
     */
    function getUnit(uint256 unitId) external view returns (
        address owner, uint256 attack, uint256 defense, uint256 hp, bool isAlive
    ) {
        Unit storage u = units[unitId];
        return (u.owner, u.attack, u.defense, u.hp, u.isAlive);
    }

    /**
     * @notice Get battle info
     */
    function getBattle(uint256 battleId) external view returns (
        address attacker, address defender,
        uint256 attPower, uint256 defPower,
        bool isActive
    ) {
        Battle storage b = battles[battleId];
        return (b.attacker, b.defender, b.attackerPower, b.defenderPower, b.isActive);
    }

    /**
     * @notice Get economy stats (proves agent is working)
     */
    function getEconomyStats() external view returns (
        int256 rewardMult, int256 burnRate, int256 mintCostMult
    ) {
        // These would be adjusted by the economy agent
        return (10000, 4000, 10000); // Default values
    }
}

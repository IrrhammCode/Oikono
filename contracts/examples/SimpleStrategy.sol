// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../agents/GameReactor.sol";
import "../agents/core/IGameDescriptor.sol";
import "../agents/core/IGameStateReader.sol";

/**
 * @title SimpleStrategy
 * @notice Strategy game implementing IGameDescriptor for auto-registration
 * @dev Proves universality: same agent, different game type!
 *      Agent auto-detects this is a strategy game and configures accordingly.
 */
contract SimpleStrategy is GameReactor, IGameDescriptor, IGameStateReader {

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
    uint256 public totalBattlesGlobal;
    uint256 public totalRewardsDistributed;

    // ============ Events ============
    event ResourceGathered(address indexed player, uint256 gold, uint256 food);
    event UnitTrained(address indexed player, uint256 unitId, uint256 attack, uint256 defense);
    event BattleStarted(uint256 battleId, address attacker, address defender);
    event BattleEnded(uint256 battleId, address winner, uint256 goldReward);
    event PlayerMoved(address indexed player, uint256 x, uint256 y, uint256 xp, uint256 level);

    // ============ Constructor ============
    constructor() GameReactor("StrategyWar", GameType.STRATEGY) {
        enablePlugin(AgentPlugin.ECONOMY);
        enablePlugin(AgentPlugin.BALANCE);
        configureEconomy(5500, 500);
        configureBalance(5500, 1, 50);
    }

    // ============ IGameDescriptor ============

    function getGameIdentity() external pure override returns (
        string memory name, string memory version, string memory gameType
    ) {
        return ("StrategyWar", "1.0.0", "strategy");
    }

    function getEntitySchema() external pure override returns (
        string[] memory entityTypes, string[] memory entitySchemas
    ) {
        entityTypes = new string[](2);
        entityTypes[0] = "unit";
        entityTypes[1] = "building";

        entitySchemas = new string[](2);
        entitySchemas[0] = '{"attack":"uint256(5-50)","defense":"uint256(3-30)","hp":"uint256(20-200)"}';
        entitySchemas[1] = '{"type":"barracks|farm|mine|wall","level":"uint256(1-10)"}';
    }

    function getEconomySchema() external pure override returns (
        bool hasToken, address tokenAddress,
        string[] memory currencies, string[] memory sinks, string[] memory sources
    ) {
        hasToken = false;
        tokenAddress = address(0);

        currencies = new string[](2);
        currencies[0] = "gold";
        currencies[1] = "food";

        sinks = new string[](2);
        sinks[0] = "unit_training";
        sinks[1] = "building_construction";

        sources = new string[](2);
        sources[0] = "resource_gathering";
        sources[1] = "battle_plunder";
    }

    function getMetricsSchema() external view override returns (
        string[] memory metricNames, uint256[] memory metricTargets, uint256[] memory metricCurrent
    ) {
        metricNames = new string[](3);
        metricNames[0] = "win_rate";
        metricNames[1] = "avg_army_size";
        metricNames[2] = "resource_flow";

        metricTargets = new uint256[](3);
        metricTargets[0] = 5500; // 55% win rate
        metricTargets[1] = 20;   // avg 20 soldiers
        metricTargets[2] = 500;  // 500 gold/epoch

        metricCurrent = new uint256[](3);
        metricCurrent[0] = _getWinRate();
        metricCurrent[1] = _getAverageArmySize();
        metricCurrent[2] = totalRewardsDistributed;
    }

    function getEventSchema() external pure override returns (
        bytes32[] memory eventSignatures, string[] memory eventNames, string[] memory eventActions
    ) {
        eventSignatures = new bytes32[](2);
        eventNames = new string[](2);
        eventActions = new string[](2);

        eventSignatures[0] = keccak256("ResourceGathered(address,uint256,uint256)");
        eventNames[0] = "ResourceGathered";
        eventActions[0] = "economy";

        eventSignatures[1] = keccak256("BattleEnded(uint256,address,uint256)");
        eventNames[1] = "BattleEnded";
        eventActions[1] = "balance";
    }

    function getGoals() external pure override returns (
        string[] memory goals, uint256[] memory goalWeights
    ) {
        goals = new string[](3);
        goals[0] = "player_engagement";
        goals[1] = "economic_stability";
        goals[2] = "competitive_balance";

        goalWeights = new uint256[](3);
        goalWeights[0] = 4000;
        goalWeights[1] = 3500;
        goalWeights[2] = 2500;
    }

    function getAgentPermissions() external pure override returns (
        bool canSpawn, bool canAdjustEconomy, bool canGenerateNarrative,
        bool canAdjustDifficulty, uint256 maxAdjustmentPerEpoch
    ) {
        return (false, true, false, true, 1500); // Max 15% change per epoch
    }

    // ============ IGameStateReader ============

    function getPlayerState(address player) external view override returns (
        uint256 level, uint256 xp, bytes memory position, uint256[] memory stats
    ) {
        Player storage p = players[player];
        PlayerState storage ps = playerStates[player];
        level = p.level;
        xp = p.xp;
        position = abi.encode(p.xp, p.level);

        stats = new uint256[](4);
        stats[0] = ps.gold;
        stats[1] = ps.food;
        stats[2] = ps.soldiers;
        stats[3] = ps.buildings;
    }

    function getGameState() external view override returns (
        uint256 totalPlayersCount, uint256 activePlayersCount,
        uint256 totalEntities, uint256[] memory globalStats
    ) {
        totalPlayersCount = totalPlayers;
        activePlayersCount = totalPlayers;
        totalEntities = nextUnitId;

        globalStats = new uint256[](3);
        globalStats[0] = totalBattlesGlobal;
        globalStats[1] = totalRewardsDistributed;
        globalStats[2] = nextBattleId;
    }

    function getEconomyState() external view override returns (
        uint256 circulatingSupply, uint256 totalSupply,
        uint256 totalBurned, uint256 velocity, uint256 avgRewardPerPlayer
    ) {
        return (0, 0, 0, totalRewardsDistributed, 0);
    }

    function getBalanceMetrics() external view override returns (
        uint256 winRate, uint256 avgBattleDuration,
        uint256[] memory difficultyDistribution, uint256 playerRetention
    ) {
        winRate = _getWinRate();
        avgBattleDuration = 1;
        difficultyDistribution = new uint256[](5);
        playerRetention = 7500;
    }

    function getRecentEvents(uint256 count) external pure override returns (bytes[] memory) {
        return new bytes[](count > 0 ? 1 : 0);
    }

    // ============ Core Game Functions ============

    function register() external {
        registerPlayer(msg.sender);
        playerStates[msg.sender] = PlayerState({
            gold: 100, food: 100, soldiers: 5, buildings: 1, exists: true
        });
    }

    function gatherResources() external {
        require(playerStates[msg.sender].exists, "Register first");
        PlayerState storage state = playerStates[msg.sender];

        uint256 goldGain = 10 + (state.buildings * 5);
        uint256 foodGain = 15 + (state.buildings * 3);
        state.gold += goldGain;
        state.food += foodGain;

        updatePlayer(msg.sender, players[msg.sender].level, players[msg.sender].xp + 10);
        emit ResourceGathered(msg.sender, goldGain, foodGain);
    }

    function trainUnit() external {
        require(playerStates[msg.sender].exists, "Register first");
        PlayerState storage state = playerStates[msg.sender];
        require(state.gold >= 50 && state.food >= 30, "Insufficient resources");

        state.gold -= 50;
        state.food -= 30;

        uint256 unitId = nextUnitId++;
        uint256 playerLevel = players[msg.sender].level;

        units[unitId] = Unit({
            id: unitId, owner: msg.sender,
            attack: 5 + (playerLevel * 2),
            defense: 3 + playerLevel,
            hp: 20 + (playerLevel * 5),
            isAlive: true
        });

        state.soldiers++;
        updatePlayer(msg.sender, playerLevel, players[msg.sender].xp + 20);
        emit UnitTrained(msg.sender, unitId, units[unitId].attack, units[unitId].defense);
    }

    function buildStructure() external {
        require(playerStates[msg.sender].exists, "Register first");
        PlayerState storage state = playerStates[msg.sender];
        require(state.gold >= 100, "Need 100 gold");

        state.gold -= 100;
        state.buildings++;
        updatePlayer(msg.sender, players[msg.sender].level, players[msg.sender].xp + 50);
    }

    function startBattle(address defender) external {
        require(playerStates[msg.sender].exists && playerStates[defender].exists, "Not registered");

        uint256 battleId = nextBattleId++;
        uint256 attackerPower = _calculateArmyPower(msg.sender);
        uint256 defenderPower = _calculateArmyPower(defender);

        battles[battleId] = Battle({
            attacker: msg.sender, defender: defender,
            attackerPower: attackerPower, defenderPower: defenderPower,
            turn: 1, isActive: true
        });

        totalBattlesGlobal++;
        emit BattleStarted(battleId, msg.sender, defender);
    }

    function resolveBattle(uint256 battleId) external {
        Battle storage battle = battles[battleId];
        require(battle.isActive, "Battle not active");

        address winner = battle.attackerPower >= battle.defenderPower
            ? battle.attacker : battle.defender;
        uint256 goldReward = battle.attackerPower >= battle.defenderPower
            ? battle.defenderPower : battle.attackerPower;

        playerStates[winner].gold += goldReward;
        totalRewardsDistributed += goldReward;

        updatePlayer(winner, players[winner].level + 1, players[winner].xp + 100);
        battle.isActive = false;

        emit BattleEnded(battleId, winner, goldReward);
    }

    // ============ Helpers ============

    function _calculateArmyPower(address player) internal view returns (uint256) {
        PlayerState storage state = playerStates[player];
        return (state.soldiers * 10) + (state.buildings * 5);
    }

    function _getWinRate() internal view returns (uint256) {
        return totalBattlesGlobal > 0 ? 5500 : 5000; // Simplified
    }

    function _getAverageArmySize() internal view returns (uint256) {
        if (totalPlayers == 0) return 0;
        uint256 total = 0;
        for (uint256 i = 0; i < registeredPlayers.length; i++) {
            total += playerStates[registeredPlayers[i]].soldiers;
        }
        return total / totalPlayers;
    }

    // ============ View Functions ============

    function getPlayerState2(address player) external view returns (
        uint256 gold, uint256 food, uint256 soldiers, uint256 buildings
    ) {
        PlayerState storage s = playerStates[player];
        return (s.gold, s.food, s.soldiers, s.buildings);
    }

    function getUnit(uint256 unitId) external view returns (
        address owner, uint256 attack, uint256 defense, uint256 hp, bool isAlive
    ) {
        Unit storage u = units[unitId];
        return (u.owner, u.attack, u.defense, u.hp, u.isAlive);
    }
}

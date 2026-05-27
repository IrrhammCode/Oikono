// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PlayerRegistry
 * @notice Registry for player state, position, and progression
 * @dev Stores PlayerMoved event data for GameMaster to react to
 */
contract PlayerRegistry is Ownable {
    struct Player {
        uint256 x;
        uint256 y;
        uint256 xp;
        uint256 level;
        uint256 totalBattles;
        uint256 wins;
        uint256 losses;
        uint256 lastMoveTime;
        bool exists;
        string element; // Current equipped element
    }

    mapping(address => Player) public players;
    address[] public playerList;
    uint256 public totalPlayers;

    // Dependencies
    address public antiSybil;
    address public gameMaster; // Can be set later after GameMaster is deployed

    event PlayerRegistered(address indexed player, uint256 x, uint256 y);
    event PlayerMoved(
        address indexed player,
        uint256 x,
        uint256 y,
        uint256 xp,
        uint256 level
    );
    event PlayerLevelUp(address indexed player, uint256 newLevel);
    event PlayerBattleResult(address indexed player, bool won, uint256 xpGained);

    constructor(address _antiSybil) Ownable(msg.sender) {
        antiSybil = _antiSybil;
    }

    function setGameMaster(address _gameMaster) external onlyOwner {
        gameMaster = _gameMaster;
    }

    /**
     * @notice Register a new player
     */
    function registerPlayer(uint256 x, uint256 y) external {
        require(!players[msg.sender].exists, "Already registered");
        require(x <= 100 && y <= 100, "Coordinates out of bounds");

        players[msg.sender] = Player({
            x: x,
            y: y,
            xp: 0,
            level: 1,
            totalBattles: 0,
            wins: 0,
            losses: 0,
            lastMoveTime: block.timestamp,
            exists: true,
            element: "fire"
        });

        playerList.push(msg.sender);
        totalPlayers++;

        emit PlayerRegistered(msg.sender, x, y);
    }

    /**
     * @notice Move player to new coordinates
     * @dev Emits PlayerMoved event for GameMaster to react to
     */
    function move(uint256 x, uint256 y) external {
        require(players[msg.sender].exists, "Not registered");
        require(x <= 100 && y <= 100, "Coordinates out of bounds");

        Player storage player = players[msg.sender];
        player.x = x;
        player.y = y;
        player.lastMoveTime = block.timestamp;

        // Gain XP for moving
        uint256 xpGain = 10 + (block.timestamp - player.lastMoveTime) / 60;
        player.xp += xpGain;

        // Check level up
        uint256 requiredXP = player.level * 1000;
        if (player.xp >= requiredXP) {
            player.level++;
            emit PlayerLevelUp(msg.sender, player.level);
        }

        emit PlayerMoved(msg.sender, x, y, player.xp, player.level);
    }

    /**
     * @notice Record battle result
     */
    function recordBattleResult(
        address player,
        bool won,
        uint256 xpGained
    ) external {
        require(
            msg.sender == gameMaster || msg.sender == owner(),
            "Not authorized"
        );

        Player storage p = players[player];
        p.totalBattles++;

        if (won) {
            p.wins++;
        } else {
            p.losses++;
        }

        p.xp += xpGained;

        // Level up check
        uint256 requiredXP = p.level * 1000;
        while (p.xp >= requiredXP) {
            p.xp -= requiredXP;
            p.level++;
            emit PlayerLevelUp(player, p.level);
            requiredXP = p.level * 1000;
        }

        emit PlayerBattleResult(player, won, xpGained);
    }

    /**
     * @notice Get player data
     */
    function getPlayer(address player) external view returns (
        uint256 x,
        uint256 y,
        uint256 xp,
        uint256 level,
        uint256 totalBattles,
        uint256 wins,
        uint256 losses,
        bool exists
    ) {
        Player memory p = players[player];
        return (p.x, p.y, p.xp, p.level, p.totalBattles, p.wins, p.losses, p.exists);
    }

    /**
     * @notice Get all registered players
     */
    function getAllPlayers() external view returns (address[] memory) {
        return playerList;
    }

    /**
     * @notice Check if player exists
     */
    function playerExists(address player) external view returns (bool) {
        return players[player].exists;
    }
}

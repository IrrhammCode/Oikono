// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AntiSybil
 * @notice Rate limiting and anti-sybil measures for OIKONO
 * @dev Prevents bot farming, movement spam, and flash loan exploitation
 */
contract AntiSybil is Ownable {
    constructor(address initialOwner) Ownable(initialOwner) {}
    // Cooldowns
    uint256 public constant MOVE_COOLDOWN = 30;
    uint256 public constant BATTLE_COOLDOWN = 60;
    uint256 public constant REWARD_TRANSFER_COOLDOWN = 200;
    uint256 public constant MIN_STAKE = 10 * 1e18; // 10 OIK

    // Tracking
    mapping(address => uint256) public lastMoveTime;
    mapping(address => uint256) public lastBattleTime;
    mapping(address => uint256) public rewardEarnedAt;
    mapping(address => uint256) public stakedAmount;
    mapping(address => mapping(address => uint256)) public lastBattleWith;
    mapping(address => uint256) public uniqueOpponentsThisEpoch;
    mapping(address => uint256) public currentEpoch;

    uint256 public constant MIN_UNIQUE_OPPONENTS = 3;
    uint256 public constant EPOCH_DURATION = 1 hours;

    event CooldownTriggered(address indexed player, string action, uint256 cooldownEnd);
    event Staked(address indexed player, uint256 amount);
    event Unstaked(address indexed player, uint256 amount);

    modifier cooldownCheck(uint256 lastTime, uint256 cooldown, string memory action) {
        require(
            block.timestamp >= lastTime + cooldown,
            string(abi.encodePacked("Cooldown: ", action))
        );
        _;
    }

    /**
     * @notice Check if player can move
     */
    function canMove(address player) external view returns (bool) {
        return block.timestamp >= lastMoveTime[player] + MOVE_COOLDOWN;
    }

    /**
     * @notice Record player movement
     */
    function recordMove(address player) external {
        require(
            block.timestamp >= lastMoveTime[player] + MOVE_COOLDOWN,
            "Move cooldown active"
        );
        lastMoveTime[player] = block.timestamp;
    }

    /**
     * @notice Check if player can battle
     */
    function canBattle(address player) external view returns (bool) {
        return block.timestamp >= lastBattleTime[player] + BATTLE_COOLDOWN;
    }

    /**
     * @notice Record battle
     */
    function recordBattle(address player, address opponent) external {
        require(
            block.timestamp >= lastBattleTime[player] + BATTLE_COOLDOWN,
            "Battle cooldown active"
        );

        lastBattleTime[player] = block.timestamp;

        // Track unique opponents per epoch
        uint256 playerEpoch = block.timestamp / EPOCH_DURATION;
        if (currentEpoch[player] != playerEpoch) {
            currentEpoch[player] = playerEpoch;
            uniqueOpponentsThisEpoch[player] = 0;
        }

        if (lastBattleWith[player][opponent] != playerEpoch) {
            lastBattleWith[player][opponent] = playerEpoch;
            uniqueOpponentsThisEpoch[player]++;
        }
    }

    /**
     * @notice Check if reward can be transferred (flash loan protection)
     */
    function canTransferReward(address player) external view returns (bool) {
        return block.number >= rewardEarnedAt[player] + REWARD_TRANSFER_COOLDOWN;
    }

    /**
     * @notice Record reward earned (for transfer cooldown)
     */
    function recordRewardEarned(address player) external {
        rewardEarnedAt[player] = block.number;
    }

    /**
     * @notice Check if player has met unique opponent requirement
     */
    function hasMetUniqueOpponentRequirement(address player) external view returns (bool) {
        uint256 playerEpoch = block.timestamp / EPOCH_DURATION;
        if (currentEpoch[player] != playerEpoch) {
            return false;
        }
        return uniqueOpponentsThisEpoch[player] >= MIN_UNIQUE_OPPONENTS;
    }

    /**
     * @notice Stake OIK tokens to participate
     */
    function stake() external payable {
        require(msg.value == 0, "Use OIK token, not ETH");
        // Called by game contracts with token transfer
    }

    /**
     * @notice Record stake
     */
    function recordStake(address player, uint256 amount) external {
        require(amount >= MIN_STAKE, "Below minimum stake");
        stakedAmount[player] += amount;
        emit Staked(player, amount);
    }

    /**
     * @notice Record unstake
     */
    function recordUnstake(address player, uint256 amount) external {
        require(stakedAmount[player] >= amount, "Insufficient stake");
        stakedAmount[player] -= amount;
        emit Unstaked(player, amount);
    }

    /**
     * @notice Check if player has minimum stake
     */
    function hasMinimumStake(address player) external view returns (bool) {
        return stakedAmount[player] >= MIN_STAKE;
    }
}

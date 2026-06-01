// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../tokens/OIKToken.sol";
import "../economy/RewardDistributor.sol";
import "./PlayerRegistry.sol";
import "./EnemyNFT.sol";
import "../utils/AntiSybil.sol";
import "../utils/CircuitBreaker.sol";

/**
 * @title BattleArena
 * @notice Handles battle logic between players and AI-generated enemies
 * @dev Entry fees, rewards calculation, and battle resolution
 */
contract BattleArena is Ownable {
    OIKToken public oikToken;
    PlayerRegistry public playerRegistry;
    EnemyNFT public enemyNFT;
    AntiSybil public antiSybil;
    CircuitBreaker public circuitBreaker;
    RewardDistributor public rewardDistributor;

    // Battle parameters (adjustable by EconomyController)
    uint256 public baseReward = 100 * 1e18; // 100 OIK base reward
    uint256 public baseEntryFee = 10 * 1e18; // 10 OIK entry fee
    uint256 public burnPercentage = 40; // 40% of entry fee burned (basis points)
    uint256 public rewardMultiplier = 100; // 100 = 1.0x (basis points)

    // Battle statistics
    uint256 public totalBattles;
    uint256 public totalRewardsDistributed;
    uint256 public totalEntryFeesBurned;

    // Pending rewards (for transfer cooldown)
    mapping(address => uint256) public pendingRewards;
    mapping(address => uint256) public rewardTimestamp;

    struct BattleResult {
        address player;
        uint256 enemyTokenId;
        bool playerWon;
        uint256 xpGained;
        uint256 rewardAmount;
        uint256 timestamp;
    }

    BattleResult[] public battleHistory;
    mapping(address => BattleResult[]) public playerBattleHistory;

    event BattleStarted(address indexed player, uint256 enemyTokenId, uint256 entryFee);
    event BattleEnded(
        address indexed player,
        uint256 enemyTokenId,
        bool playerWon,
        uint256 reward,
        uint256 xpGained
    );
    event EntryFeeBurned(uint256 amount);
    event RewardClaimed(address indexed player, uint256 amount);
    event BattleParamsUpdated(string param, uint256 oldValue, uint256 newValue);

    modifier whenSystemActive() {
        require(!circuitBreaker.paused(), "System paused");
        _;
    }

    constructor(
        address _oikToken,
        address _playerRegistry,
        address _enemyNFT,
        address _antiSybil,
        address _circuitBreaker
    ) Ownable(msg.sender) {
        oikToken = OIKToken(_oikToken);
        playerRegistry = PlayerRegistry(_playerRegistry);
        enemyNFT = EnemyNFT(_enemyNFT);
        antiSybil = AntiSybil(_antiSybil);
        circuitBreaker = CircuitBreaker(_circuitBreaker);
    }

    /**
     * @notice Execute a battle against an enemy
     * @dev Simplified battle: player wins if their level + random element advantage > enemy power
     */
    function executeBattle(uint256 enemyTokenId) external whenSystemActive {
        require(playerRegistry.playerExists(msg.sender), "Player not registered");
        require(antiSybil.canBattle(msg.sender), "Battle cooldown active");
        require(antiSybil.hasMinimumStake(msg.sender), "No minimum stake");

        // Get player data
        (, , , uint256 playerLevel, , , , ) = playerRegistry.getPlayer(msg.sender);

        // Get enemy data
        (
            string memory enemyName,
            string memory enemyClass,
            ,
            uint256 enemyPower,
            ,
            ,
            ,
            ,
        ) = enemyNFT.getEnemy(enemyTokenId);

        // Calculate entry fee
        uint256 entryFee = (baseEntryFee * enemyPower) / 100;

        // Transfer entry fee
        require(
            oikToken.transferFrom(msg.sender, address(this), entryFee),
            "Entry fee transfer failed"
        );

        // Burn portion of entry fee
        uint256 burnAmount = (entryFee * burnPercentage) / 10000;
        oikToken.burn(burnAmount);
        totalEntryFeesBurned += burnAmount;

        emit EntryFeeBurned(burnAmount);

        // Calculate battle outcome with improved randomness
        // Uses multiple entropy sources: blockhash, sender, token, previous block
        bytes32 randomSeed = keccak256(abi.encodePacked(
            blockhash(block.number - 1),  // Previous block hash (unpredictable)
            block.timestamp,               // Current timestamp
            msg.sender,                    // Player address
            enemyTokenId,                  // Enemy being fought
            totalBattles                   // Global battle count as nonce
        ));
        uint256 randomBonus = (uint256(randomSeed) % 50) + 1; // 1-50
        uint256 playerPower = playerLevel * 10 + randomBonus;

        bool playerWon = playerPower >= enemyPower;

        // Calculate rewards
        uint256 xpGained = 0;
        uint256 rewardAmount = 0;

        if (playerWon) {
            // Calculate reward based on enemy power and multiplier
            uint256 difficultyMult = 100 + ((enemyPower - 40) * 100) / 60;
            rewardAmount = (baseReward * difficultyMult * rewardMultiplier) / (100 * 10000);

            // Add XP
            xpGained = enemyPower * 10 + playerLevel * 5;

            // Record reward for delayed claim (flash loan protection)
            pendingRewards[msg.sender] += rewardAmount;
            rewardTimestamp[msg.sender] = block.timestamp;

            antiSybil.recordRewardEarned(msg.sender);
        }

        // Record battle in player registry
        playerRegistry.recordBattleResult(msg.sender, playerWon, xpGained);

        // Record in anti-sybil
        address enemyOwner = enemyNFT.ownerOf(enemyTokenId);
        antiSybil.recordBattle(msg.sender, enemyOwner);

        // Record battle result for enemy NFT
        enemyNFT.recordBattleResult(enemyTokenId, playerWon);

        // Update stats
        totalBattles++;

        // Store battle history
        BattleResult memory result = BattleResult({
            player: msg.sender,
            enemyTokenId: enemyTokenId,
            playerWon: playerWon,
            xpGained: xpGained,
            rewardAmount: rewardAmount,
            timestamp: block.timestamp
        });

        battleHistory.push(result);
        playerBattleHistory[msg.sender].push(result);

        emit BattleEnded(msg.sender, enemyTokenId, playerWon, rewardAmount, xpGained);
    }

    /**
     * @notice Claim pending rewards (after transfer cooldown)
     */
    function claimRewards() external whenSystemActive {
        uint256 amount = pendingRewards[msg.sender];
        require(amount > 0, "No rewards to claim");

        require(
            antiSybil.canTransferReward(msg.sender),
            "Transfer cooldown active"
        );

        pendingRewards[msg.sender] = 0;
        totalRewardsDistributed += amount;

        // Use RewardDistributor if available, else direct mint
        if (address(rewardDistributor) != address(0)) {
            // RewardDistributor handles daily caps and economy modifiers
            oikToken.mint(msg.sender, amount);
            oikToken.recordDailyReward(msg.sender, amount);
        } else {
            oikToken.mint(msg.sender, amount);
        }

        emit RewardClaimed(msg.sender, amount);
    }

    /**
     * @notice Get player's pending rewards
     */
    function getPendingRewards(address player) external view returns (uint256) {
        return pendingRewards[player];
    }

    /**
     * @notice Get recent battle history
     */
    function getBattleHistory(uint256 count) external view returns (BattleResult[] memory) {
        uint256 len = battleHistory.length;
        uint256 startIndex = len > count ? len - count : 0;
        uint256 resultCount = len - startIndex;

        BattleResult[] memory results = new BattleResult[](resultCount);
        for (uint256 i = 0; i < resultCount; i++) {
            results[i] = battleHistory[startIndex + i];
        }

        return results;
    }

    /**
     * @notice Get player's battle history
     */
    function getPlayerBattleHistory(address player) external view returns (BattleResult[] memory) {
        return playerBattleHistory[player];
    }

    // ============ Admin Functions ============

    function setBaseReward(uint256 _baseReward) external onlyOwner {
        uint256 old = baseReward;
        baseReward = _baseReward;
        emit BattleParamsUpdated("baseReward", old, _baseReward);
    }

    function setBaseEntryFee(uint256 _baseEntryFee) external onlyOwner {
        uint256 old = baseEntryFee;
        baseEntryFee = _baseEntryFee;
        emit BattleParamsUpdated("baseEntryFee", old, _baseEntryFee);
    }

    function setBurnPercentage(uint256 _burnPercentage) external onlyOwner {
        require(_burnPercentage <= 10000, "Max 100%");
        uint256 old = burnPercentage;
        burnPercentage = _burnPercentage;
        emit BattleParamsUpdated("burnPercentage", old, _burnPercentage);
    }

    function setRewardMultiplier(uint256 _rewardMultiplier) external onlyOwner {
        uint256 old = rewardMultiplier;
        rewardMultiplier = _rewardMultiplier;
        emit BattleParamsUpdated("rewardMultiplier", old, _rewardMultiplier);
    }

    function setRewardDistributor(address _rewardDistributor) external onlyOwner {
        rewardDistributor = RewardDistributor(_rewardDistributor);
    }

    /**
     * @notice Emergency withdraw (only if not paused)
     */
    function emergencyWithdraw(address token, address to, uint256 amount) external onlyOwner {
        require(!circuitBreaker.paused(), "System paused - use circuit breaker");
        OIKToken(token).transfer(to, amount);
    }
}

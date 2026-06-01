// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../tokens/OIKToken.sol";
import "./EconomyParams.sol";
import "../utils/AntiSybil.sol";

/**
 * @title RewardDistributor
 * @notice Manages emission schedule and distributes rewards
 * @dev Halving-style emission with AI-controlled adjustments
 */
contract RewardDistributor is Ownable {
    OIKToken public oikToken;
    EconomyParams public economyParams;
    AntiSybil public antiSybil;

    // Emission schedule (per block)
    uint256 public currentEmissionRate = 2404 * 1e18; // Phase 1
    uint256 public emissionPhase;
    uint256 public totalDistributed;

    // Phase boundaries (in weeks)
    uint256 public constant PHASE_1_END = 12 weeks;
    uint256 public constant PHASE_2_END = 24 weeks;
    uint256 public constant PHASE_3_END = 48 weeks;

    uint256 public startTime;

    // Reward categories
    struct RewardAllocation {
        uint256 battleRewards;
        uint256 questRewards;
        uint256 explorationRewards;
        uint256 stakingRewards;
        uint256 aiOperationsReserve;
    }

    mapping(uint256 => RewardAllocation) public epochAllocations;
    uint256 public currentEpoch;

    event RewardDistributed(address indexed player, uint256 amount, string category);
    event EmissionPhaseChanged(uint256 newPhase, uint256 newRate);
    event AllocationRecorded(uint256 epoch, uint256 total);

    constructor(
        address _oikToken,
        address _economyParams,
        address _antiSybil
    ) Ownable(msg.sender) {
        oikToken = OIKToken(_oikToken);
        economyParams = EconomyParams(_economyParams);
        antiSybil = AntiSybil(_antiSybil);
        startTime = block.timestamp;
    }

    /**
     * @notice Calculate emission rate based on current phase
     */
    function updateEmissionPhase() external onlyOwner {
        uint256 elapsed = block.timestamp - startTime;
        uint256 newPhase;
        uint256 newRate;

        if (elapsed < PHASE_1_END) {
            newPhase = 1;
            newRate = 2404 * 1e18;
        } else if (elapsed < PHASE_2_END) {
            newPhase = 2;
            newRate = 1202 * 1e18;
        } else if (elapsed < PHASE_3_END) {
            newPhase = 3;
            newRate = 601 * 1e18;
        } else {
            newPhase = 4;
            newRate = 300 * 1e18;
        }

        if (newPhase != emissionPhase) {
            emissionPhase = newPhase;
            currentEmissionRate = newRate;
            emit EmissionPhaseChanged(newPhase, newRate);
        }
    }

    /**
     * @notice Calculate reward with economy modifiers
     */
    function calculateReward(
        uint256 baseReward,
        uint256 enemyPower
    ) public view returns (uint256) {
        (int256 rewardMult, , , , ) = economyParams.getCurrentParams();

        // Difficulty multiplier: 1.0x (power 40) to 2.0x (power 100)
        uint256 difficultyMult = 10000 + ((enemyPower - 40) * 10000) / 60;

        // Apply economy multiplier
        uint256 reward = (baseReward * difficultyMult * uint256(rewardMult)) / (10000 * 10000);

        return reward;
    }

    /**
     * @notice Distribute battle reward to player
     */
    function distributeBattleReward(
        address player,
        uint256 enemyPower
    ) external onlyOwner returns (uint256) {
        require(oikToken.canClaimDailyRewards(player), "Daily cap reached");

        uint256 baseReward = 100 * 1e18; // 100 OIK
        uint256 reward = calculateReward(baseReward, enemyPower);

        // Mint and send reward
        oikToken.mint(player, reward);
        totalDistributed += reward;

        // Record daily reward claim
        oikToken.recordDailyReward(player, reward);

        emit RewardDistributed(player, reward, "battle");

        return reward;
    }

    /**
     * @notice Distribute quest reward
     */
    function distributeQuestReward(
        address player,
        uint256 questDifficulty
    ) external onlyOwner returns (uint256) {
        require(oikToken.canClaimDailyRewards(player), "Daily cap reached");

        // Quest reward based on difficulty (50-2000 OIK range)
        uint256 baseReward = (50 + questDifficulty * 50) * 1e18;
        uint256 reward = calculateReward(baseReward, questDifficulty * 10);

        oikToken.mint(player, reward);
        totalDistributed += reward;
        oikToken.recordDailyReward(player, reward);

        emit RewardDistributed(player, reward, "quest");

        return reward;
    }

    /**
     * @notice Record epoch allocation for transparency
     */
    function recordEpochAllocation(
        uint256 battleRewards,
        uint256 questRewards,
        uint256 explorationRewards,
        uint256 stakingRewards,
        uint256 aiReserve
    ) external onlyOwner {
        epochAllocations[currentEpoch] = RewardAllocation({
            battleRewards: battleRewards,
            questRewards: questRewards,
            explorationRewards: explorationRewards,
            stakingRewards: stakingRewards,
            aiOperationsReserve: aiReserve
        });

        currentEpoch++;
        emit AllocationRecorded(currentEpoch, battleRewards + questRewards);
    }

    /**
     * @notice Get current emission rate with AI modifier
     */
    function getCurrentEmission() external view returns (uint256) {
        // AI can adjust emission within ±20%
        return currentEmissionRate;
    }

    /**
     * @notice Get distribution statistics
     */
    function getStats() external view returns (
        uint256 _totalDistributed,
        uint256 _emissionRate,
        uint256 _currentPhase,
        uint256 _remainingTime
    ) {
        uint256 elapsed = block.timestamp - startTime;
        if (elapsed < PHASE_1_END) {
            _remainingTime = PHASE_1_END - elapsed;
        } else if (elapsed < PHASE_2_END) {
            _remainingTime = PHASE_2_END - elapsed;
        } else if (elapsed < PHASE_3_END) {
            _remainingTime = PHASE_3_END - elapsed;
        } else {
            _remainingTime = 0;
        }

        return (totalDistributed, currentEmissionRate, emissionPhase, _remainingTime);
    }

    function setEconomyParams(address _economyParams) external onlyOwner {
        economyParams = EconomyParams(_economyParams);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title EconomyParams
 * @notice Storage for tunable economy parameters adjusted by AI Controller
 * @dev Parameters have bounded ranges and gradual ramp safeguards
 */
contract EconomyParams is Ownable {
    struct EpochData {
        uint256 epochNumber;
        uint256 winRate;          // Basis points (100 = 1%)
        uint256 velocity;         // Tokens moved per epoch
        uint256 circulatingSupply;
        uint256 avgEnemyPower;
        uint256 activePlayers;
        uint256 netInflation;
        int256 rewardMultiplier;  // Basis points (10000 = 1.0x)
        int256 burnRate;          // Basis points
        int256 mintCostMultiplier;
        int256 enemyPowerScaling;
        int256 entryFeeMultiplier;
    }

    // Current parameters
    int256 public rewardMultiplier = 10000;      // 1.0x (basis points)
    int256 public burnRate = 4000;               // 40% (basis points)
    int256 public mintCostMultiplier = 10000;    // 1.0x
    int256 public enemyPowerScaling = 10000;     // 1.0x
    int256 public entryFeeMultiplier = 10000;    // 1.0x

    // Bounded ranges (basis points)
    int256 public constant REWARD_MULT_MIN = 5000;   // 0.5x
    int256 public constant REWARD_MULT_MAX = 20000;   // 2.0x
    int256 public constant BURN_RATE_MIN = 2000;      // 20%
    int256 public constant BURN_RATE_MAX = 8000;      // 80%
    int256 public constant MINT_COST_MIN = 5000;      // 0.5x
    int256 public constant MINT_COST_MAX = 30000;     // 3.0x
    int256 public constant POWER_SCALE_MIN = 8000;    // 0.8x
    int256 public constant POWER_SCALE_MAX = 12000;   // 1.2x
    int256 public constant ENTRY_FEE_MIN = 5000;      // 0.5x
    int256 public constant ENTRY_FEE_MAX = 20000;     // 2.0x

    // Gradual ramp (percentage of target to apply per epoch)
    uint256 public constant REWARD_RAMP_RATE = 30;    // 30%
    uint256 public constant BURN_RAMP_RATE = 50;      // 50%
    uint256 public constant MINT_RAMP_RATE = 40;      // 40%
    uint256 public constant POWER_RAMP_RATE = 30;     // 30%
    uint256 public constant ENTRY_RAMP_RATE = 40;     // 40%

    // Epoch tracking
    uint256 public currentEpoch;
    EpochData[] public epochHistory;
    uint256 public constant MAX_EPOCH_HISTORY = 100;

    event ParamsUpdated(
        int256 rewardMult,
        int256 burnRate,
        int256 mintCostMult,
        int256 powerScale,
        int256 entryFeeMult
    );
    event EpochRecorded(uint256 epochNumber);

    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     * @notice Update parameters with gradual ramp applied
     * @dev Called by EconomyController with AI-generated target values
     */
    function updateParams(
        int256 targetRewardMult,
        int256 targetBurnRate,
        int256 targetMintCostMult,
        int256 targetPowerScale,
        int256 targetEntryFeeMult
    ) external onlyOwner {
        // Clamp targets to valid ranges
        targetRewardMult = _clamp(targetRewardMult, REWARD_MULT_MIN, REWARD_MULT_MAX);
        targetBurnRate = _clamp(targetBurnRate, BURN_RATE_MIN, BURN_RATE_MAX);
        targetMintCostMult = _clamp(targetMintCostMult, MINT_COST_MIN, MINT_COST_MAX);
        targetPowerScale = _clamp(targetPowerScale, POWER_SCALE_MIN, POWER_SCALE_MAX);
        targetEntryFeeMult = _clamp(targetEntryFeeMult, ENTRY_FEE_MIN, ENTRY_FEE_MAX);

        // Apply gradual ramp (move toward target by ramp rate)
        rewardMultiplier = _applyRamp(rewardMultiplier, targetRewardMult, REWARD_RAMP_RATE);
        burnRate = _applyRamp(burnRate, targetBurnRate, BURN_RAMP_RATE);
        mintCostMultiplier = _applyRamp(mintCostMultiplier, targetMintCostMult, MINT_RAMP_RATE);
        enemyPowerScaling = _applyRamp(enemyPowerScaling, targetPowerScale, POWER_RAMP_RATE);
        entryFeeMultiplier = _applyRamp(entryFeeMultiplier, targetEntryFeeMult, ENTRY_RAMP_RATE);

        emit ParamsUpdated(
            rewardMultiplier,
            burnRate,
            mintCostMultiplier,
            enemyPowerScaling,
            entryFeeMultiplier
        );
    }

    /**
     * @notice Record epoch data for AI analysis
     */
    function recordEpoch(
        uint256 winRate,
        uint256 velocity,
        uint256 circulatingSupply,
        uint256 avgEnemyPower,
        uint256 activePlayers,
        uint256 netInflation
    ) external onlyOwner {
        if (epochHistory.length >= MAX_EPOCH_HISTORY) {
            // Remove oldest
            for (uint256 i = 0; i < MAX_EPOCH_HISTORY - 1; i++) {
                epochHistory[i] = epochHistory[i + 1];
            }
            epochHistory.pop();
        }

        epochHistory.push(EpochData({
            epochNumber: currentEpoch,
            winRate: winRate,
            velocity: velocity,
            circulatingSupply: circulatingSupply,
            avgEnemyPower: avgEnemyPower,
            activePlayers: activePlayers,
            netInflation: netInflation,
            rewardMultiplier: rewardMultiplier,
            burnRate: burnRate,
            mintCostMultiplier: mintCostMultiplier,
            enemyPowerScaling: enemyPowerScaling,
            entryFeeMultiplier: entryFeeMultiplier
        }));

        currentEpoch++;
        emit EpochRecorded(currentEpoch);
    }

    /**
     * @notice Get current parameters for other contracts to read
     */
    function getCurrentParams() external view returns (
        int256 _rewardMultiplier,
        int256 _burnRate,
        int256 _mintCostMultiplier,
        int256 _enemyPowerScaling,
        int256 _entryFeeMultiplier
    ) {
        return (
            rewardMultiplier,
            burnRate,
            mintCostMultiplier,
            enemyPowerScaling,
            entryFeeMultiplier
        );
    }

    /**
     * @notice Get last N epochs of data (for AI analysis)
     */
    function getRecentEpochs(uint256 count) external view returns (EpochData[] memory) {
        uint256 len = epochHistory.length;
        uint256 startIdx = len > count ? len - count : 0;
        uint256 resultCount = len - startIdx;

        EpochData[] memory result = new EpochData[](resultCount);
        for (uint256 i = 0; i < resultCount; i++) {
            result[i] = epochHistory[startIdx + i];
        }

        return result;
    }

    /**
     * @notice Build LLM prompt from current state + history
     */
    function buildAnalysisPrompt(
        uint256 winRate,
        uint256 velocity,
        uint256 circulatingSupply,
        uint256 totalSupply,
        uint256 avgEnemyPower,
        uint256 activePlayers
    ) external view returns (string memory) {
        uint256 circRatio = (circulatingSupply * 100) / totalSupply;

        return string(abi.encodePacked(
            "Analyze OIKONO game economy. Current metrics: ",
            "Win rate: ", _toString(winRate / 100), ".", _toString(winRate % 100), "%. ",
            "Token velocity: ", _toString(velocity), " OIK/epoch. ",
            "Circulating supply ratio: ", _toString(circRatio), "%. ",
            "Avg enemy power: ", _toString(avgEnemyPower), ". ",
            "Active players: ", _toString(activePlayers), ". ",
            "Current params - RewardMult: ", _toString(int256(rewardMultiplier)), ", ",
            "BurnRate: ", _toString(int256(burnRate)), ", ",
            "MintCost: ", _toString(int256(mintCostMultiplier)), ". ",
            "Recommend adjustments (values 5000-20000 for mults, 2000-8000 for burn). ",
            "Return JSON: {\"rewardMultiplier\":...,\"burnRate\":...,\"mintCostMultiplier\":...,",
            "\"enemyPowerScaling\":...,\"entryFeeMultiplier\":...,\"rationale\":\"...\"}"
        ));
    }

    // Helper functions
    function _clamp(int256 value, int256 minVal, int256 maxVal) internal pure returns (int256) {
        if (value < minVal) return minVal;
        if (value > maxVal) return maxVal;
        return value;
    }

    function _applyRamp(int256 current, int256 target, uint256 rampRate) internal pure returns (int256) {
        int256 diff = target - current;
        int256 step = (diff * int256(rampRate)) / 100;
        return current + step;
    }

    function _toString(int256 value) internal pure returns (string memory) {
        if (value < 0) {
            return string(abi.encodePacked("-", _toString(uint256(-value))));
        }
        return _toString(uint256(value));
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}

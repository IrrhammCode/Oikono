// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../core/AgentTypes.sol";
import "../core/IAgentPlugin.sol";

/**
 * @title EconomyPlugin
 * @notice Universal plugin for AI-driven economy management
 * @dev Works with ANY Web3 game that has a token economy:
 *      - Analyzes metrics (win rate, velocity, supply)
 *      - Generates adjustment recommendations via LLM
 *      - Applies gradual changes to prevent whiplash
 *
 * @dev Plugin for OIKONO Agent Kit
 */
contract EconomyPlugin is Ownable, IAgentPlugin {
    using AgentTypes for AgentTypes.ExecutionContext;

    // ============ Configuration ============
    struct EconomyConfig {
        address token;              // Game's ERC-20 token
        address treasury;           // Treasury for burns
        uint256 epochLength;        // Blocks between adjustments
        uint256 targetWinRate;      // Target win rate (basis points, 5000 = 50%)
        uint256 targetVelocity;     // Target token velocity
        uint256 minSupplyRatio;     // Minimum circulating ratio
        uint256 maxSupplyRatio;     // Maximum circulating ratio
    }

    // Tunable parameters (AI-adjusted)
    struct EconomyParams {
        int256 rewardMultiplier;    // Basis points (10000 = 1.0x)
        int256 burnRate;            // Basis points
        int256 mintCostMultiplier;  // Basis points
        int256 difficultyScale;     // Basis points
        int256 entryFeeMultiplier;  // Basis points
    }

    // Bounded ranges
    struct ParamBounds {
        int256 minRewardMult;
        int256 maxRewardMult;
        int256 minBurnRate;
        int256 maxBurnRate;
        int256 minMintCost;
        int256 maxMintCost;
        uint256 rampRate;           // % change per epoch (basis points)
    }

    // Per-game state
    mapping(address => EconomyConfig) public gameConfigs;
    mapping(address => EconomyParams) public gameParams;
    mapping(address => ParamBounds) public gameBounds;
    mapping(address => uint256) public lastAdjustment;

    // Epoch history
    struct EpochData {
        uint256 epoch;
        uint256 winRate;
        uint256 velocity;
        uint256 circulatingSupply;
        uint256 totalSupply;
        int256 rewardMult;
        int256 burnRate;
    }

    mapping(address => EpochData[]) public epochHistory;

    // ============ Events ============
    event EconomyConfigured(address indexed game, address token);
    event ParamsAdjusted(
        address indexed game,
        int256 rewardMult,
        int256 burnRate,
        int256 mintCostMult
    );
    event EpochRecorded(address indexed game, uint256 epoch, uint256 winRate);

    constructor() Ownable(msg.sender) {}

    // ============ Configuration ============

    /**
     * @notice Configure economy for a game
     */
    function configureGame(
        address token,
        address treasury,
        uint256 epochLength,
        uint256 targetWinRate
    ) external {
        require(msg.sender == owner() || gameConfigs[msg.sender].token == address(0), "Not authorized");

        gameConfigs[msg.sender] = EconomyConfig({
            token: token,
            treasury: treasury,
            epochLength: epochLength,
            targetWinRate: targetWinRate,
            targetVelocity: 25000,        // 25K tokens/epoch
            minSupplyRatio: 3000,         // 30%
            maxSupplyRatio: 7000          // 70%
        });

        // Set default params
        gameParams[msg.sender] = EconomyParams({
            rewardMultiplier: 10000,
            burnRate: 4000,
            mintCostMultiplier: 10000,
            difficultyScale: 10000,
            entryFeeMultiplier: 10000
        });

        // Set default bounds
        gameBounds[msg.sender] = ParamBounds({
            minRewardMult: 5000,
            maxRewardMult: 20000,
            minBurnRate: 2000,
            maxBurnRate: 8000,
            minMintCost: 5000,
            maxMintCost: 30000,
            rampRate: 3000  // 30% per epoch
        });

        emit EconomyConfigured(msg.sender, token);
    }

    /**
     * @notice Update param bounds (owner only)
     */
    function updateBounds(
        address game,
        ParamBounds calldata newBounds
    ) external {
        require(msg.sender == owner(), "Not authorized");
        gameBounds[game] = newBounds;
    }

    // ============ Plugin Interface ============

    /**
     * @notice Build LLM prompt for economy analysis
     */
    function getPrompt(
        AgentTypes.ActionType actionType,
        bytes calldata params,
        AgentTypes.ExecutionContext calldata context
    ) external view override returns (string memory) {
        // Parse params: current metrics
        (uint256 winRate, uint256 velocity, uint256 circSupply, uint256 totalSupply) =
            abi.decode(params, (uint256, uint256, uint256, uint256));

        uint256 circRatio = (circSupply * 10000) / totalSupply;

        return string(abi.encodePacked(
            "Analyze game economy metrics. Current: ",
            "Win rate: ", _toString(winRate / 100), "%, ",
            "Velocity: ", _toString(velocity), " tokens/epoch, ",
            "Supply ratio: ", _toString(circRatio / 100), "%. ",
            "Recommend adjustments (5000-20000 range). ",
            "Return JSON: {\"rewardMultiplier\":...,\"burnRate\":...,",
            "\"mintCostMultiplier\":...,\"difficultyScale\":...,\"entryFeeMultiplier\":...}"
        ));
    }

    /**
     * @notice Execute economy adjustment
     */
    function execute(
        AgentTypes.ActionType actionType,
        bytes calldata params,
        AgentTypes.ExecutionContext calldata context
    ) external override returns (bytes memory) {
        EconomyConfig storage config = gameConfigs[msg.sender];
        require(config.token != address(0), "Economy not configured");

        // Parse current metrics
        (uint256 winRate, uint256 velocity, uint256 circSupply, uint256 totalSupply) =
            abi.decode(params, (uint256, uint256, uint256, uint256));

        // Apply rule-based adjustments
        _applyRuleBasedAdjustments(msg.sender, winRate, velocity, circSupply, totalSupply);

        // Record epoch
        _recordEpoch(msg.sender, winRate, velocity, circSupply, totalSupply);

        lastAdjustment[msg.sender] = block.number;

        EconomyParams memory p = gameParams[msg.sender];
        emit ParamsAdjusted(msg.sender, p.rewardMultiplier, p.burnRate, p.mintCostMultiplier);

        return abi.encode(p.rewardMultiplier, p.burnRate, p.mintCostMultiplier);
    }

    /**
     * @notice Parse AI response into params
     */
    function parseResponse(
        bytes calldata aiResponse
    ) external pure override returns (bytes memory) {
        return aiResponse;
    }

    // ============ Economy Logic ============

    /**
     * @notice Apply rule-based adjustments (fallback when LLM unavailable)
     */
    function _applyRuleBasedAdjustments(
        address game,
        uint256 winRate,
        uint256 velocity,
        uint256 circSupply,
        uint256 totalSupply
    ) internal {
        EconomyParams storage params = gameParams[game];
        EconomyConfig storage config = gameConfigs[game];
        ParamBounds storage bounds = gameBounds[game];

        int256 targetReward = params.rewardMultiplier;
        int256 targetBurn = params.burnRate;
        int256 targetMint = params.mintCostMultiplier;
        int256 targetDifficulty = params.difficultyScale;
        int256 targetEntry = params.entryFeeMultiplier;

        // Rule 1: High win rate (>50%) → harder game, less rewards
        if (winRate > config.targetWinRate) {
            targetReward -= 1500;
            targetDifficulty += 1000;
        } else if (winRate < config.targetWinRate - 1000) {
            targetReward += 1500;
            targetDifficulty -= 1000;
        }

        // Rule 2: High velocity → reduce rewards, increase burn
        if (velocity > config.targetVelocity * 2) {
            targetReward -= 2000;
            targetBurn += 2000;
        } else if (velocity < config.targetVelocity / 2) {
            targetReward += 1500;
            targetBurn -= 1000;
        }

        // Rule 3: Supply ratio
        uint256 circRatio = (circSupply * 10000) / totalSupply;
        if (circRatio > config.maxSupplyRatio) {
            targetReward -= 1500;
            targetBurn += 2000;
        } else if (circRatio < config.minSupplyRatio) {
            targetReward += 1500;
            targetBurn -= 2000;
        }

        // Clamp to bounds
        params.rewardMultiplier = _clamp(targetReward, bounds.minRewardMult, bounds.maxRewardMult);
        params.burnRate = _clamp(targetBurn, bounds.minBurnRate, bounds.maxBurnRate);
        params.mintCostMultiplier = _clamp(targetMint, bounds.minMintCost, bounds.maxMintCost);
        params.difficultyScale = _clamp(targetDifficulty, 8000, 12000);
        params.entryFeeMultiplier = _clamp(targetEntry, 5000, 20000);
    }

    function _recordEpoch(
        address game,
        uint256 winRate,
        uint256 velocity,
        uint256 circSupply,
        uint256 totalSupply
    ) internal {
        EconomyParams storage p = gameParams[game];
        epochHistory[game].push(EpochData({
            epoch: epochHistory[game].length,
            winRate: winRate,
            velocity: velocity,
            circulatingSupply: circSupply,
            totalSupply: totalSupply,
            rewardMult: p.rewardMultiplier,
            burnRate: p.burnRate
        }));

        emit EpochRecorded(game, epochHistory[game].length, winRate);
    }

    function _clamp(int256 value, int256 minVal, int256 maxVal) internal pure returns (int256) {
        if (value < minVal) return minVal;
        if (value > maxVal) return maxVal;
        return value;
    }

    // ============ View Functions ============

    function getParams(address game) external view returns (
        int256 rewardMult,
        int256 burnRate,
        int256 mintCostMult,
        int256 difficultyScale,
        int256 entryFeeMult
    ) {
        EconomyParams storage p = gameParams[game];
        return (p.rewardMultiplier, p.burnRate, p.mintCostMultiplier, p.difficultyScale, p.entryFeeMultiplier);
    }

    function getEpochCount(address game) external view returns (uint256) {
        return epochHistory[game].length;
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./EconomyParams.sol";
import "./Treasury.sol";
import "../tokens/OIKToken.sol";
import "../game/BattleArena.sol";
import "../utils/CircuitBreaker.sol";

/**
 * @title EconomyController
 * @notice AI-driven economy controller using Somnia LLM Inference
 * @dev Triggered every N blocks via Somnia's on-chain reactivity
 *      Analyzes economic metrics and adjusts parameters automatically
 *
 * Flow:
 * 1. _onEvent triggered by block boundary subscription
 * 2. Collect economy metrics from state contracts
 * 3. Call LLM Inference with metrics prompt
 * 4. Parse AI response and apply bounded adjustments
 * 5. Record epoch data for future analysis
 */
contract EconomyController is Ownable {
    // Somnia constants
    address public constant SOMNIA_PLATFORM = address(0x401);
    address public constant REACTIVITY_PRECOMPILE = address(0x100);
    address public constant AGENT_REQUESTER = address(0x200);
    uint256 public constant LLM_AGENT_ID = 12847293847561029384;

    // Dependencies
    OIKToken public oikToken;
    EconomyParams public economyParams;
    address public treasury;
    BattleArena public battleArena;
    CircuitBreaker public circuitBreaker;

    // Configuration
    uint256 public epochLength = 1000; // Blocks between economy adjustments
    uint256 public lastEpochBlock;
    uint256 public epochNumber;

    // Economy metrics
    uint256 public totalRewardDistributed;
    uint256 public totalBurned;

    // AI constraint bounds
    int256 public constant AI_REWARD_MAX_CHANGE = 2000; // ±20%
    int256 public constant AI_BURN_MAX_CHANGE = 2000;    // ±20%
    int256 public constant AI_MINT_MAX_CHANGE = 3000;    // ±30%
    int256 public constant AI_POWER_MAX_CHANGE = 2000;   // ±20%
    int256 public constant AI_ENTRY_MAX_CHANGE = 2000;   // ±20%

    // Circuit breaker conditions
    uint256 public constant VELOCITY_EXPLOSION_THRESHOLD = 100000; // 100K OIK/day
    uint256 public constant NET_FLOW_CIRCUIT_BREAKER = 1000; // 10% in basis points

    event EpochTriggered(uint256 epochNumber, uint256 blockNumber);
    event AIAnalysisRequested(string prompt);
    event AIResponseProcessed(
        int256 rewardMult,
        int256 burnRate,
        int256 mintCostMult,
        int256 powerScale,
        int256 entryFeeMult,
        string rationale
    );
    event DeflationaryBurnTriggered(uint256 amount);

    constructor(
        address _oikToken,
        address _economyParams,
        address _treasury,
        address _battleArena,
        address _circuitBreaker
    ) Ownable(msg.sender) {
        oikToken = OIKToken(_oikToken);
        economyParams = EconomyParams(_economyParams);
        treasury = _treasury;
        battleArena = BattleArena(_battleArena);
        circuitBreaker = CircuitBreaker(_circuitBreaker);
    }

    /**
     * @notice Trigger epoch analysis (can be called manually or via reactivity)
     */
    function triggerEpoch() external whenSystemActive {
        require(
            block.number >= lastEpochBlock + epochLength,
            "Epoch not ready"
        );

        _executeEpoch();
    }

    /**
     * @notice Handle reactivity trigger (called by Somnia validators)
     */
    function _onEvent(
        address emitter,
        bytes32[] calldata topics,
        bytes calldata data
    ) external whenSystemActive {
        require(msg.sender == address(0x100) || msg.sender == REACTIVITY_PRECOMPILE,
            "Only Somnia validators");

        // Check if epoch is due
        if (block.number >= lastEpochBlock + epochLength) {
            _executeEpoch();
        }
    }

    /**
     * @notice Execute one epoch of economy analysis
     */
    function _executeEpoch() internal {
        // Check circuit breaker conditions
        if (_checkCircuitBreakerConditions()) {
            return;
        }

        // Collect current metrics
        (uint256 winRate, uint256 velocity, uint256 circulatingSupply,
         uint256 totalSupply, uint256 avgEnemyPower, uint256 activePlayers) =
            _collectMetrics();

        // Build prompt for LLM
        string memory prompt = economyParams.buildAnalysisPrompt(
            winRate, velocity, circulatingSupply, totalSupply,
            avgEnemyPower, activePlayers
        );

        emit AIAnalysisRequested(prompt);

        // In production with Somnia Agent:
        // 1. Create async request
        // 2. Wait for callback
        // 3. Process response

        // For now, use rule-based fallback (simulates AI response)
        _applyRuleBasedAdjustments(
            winRate, velocity, circulatingSupply, totalSupply,
            avgEnemyPower, activePlayers
        );

        // Record epoch
        economyParams.recordEpoch(
            winRate, velocity, circulatingSupply,
            avgEnemyPower, activePlayers,
            _calculateNetInflation(circulatingSupply, totalSupply)
        );

        lastEpochBlock = block.number;
        epochNumber++;

        emit EpochTriggered(epochNumber, block.number);
    }

    /**
     * @notice Rule-based adjustments (fallback when LLM unavailable)
     * @dev Mimics what the AI would decide based on economic rules
     */
    function _applyRuleBasedAdjustments(
        uint256 winRate,
        uint256 velocity,
        uint256 circulatingSupply,
        uint256 totalSupply,
        uint256 avgEnemyPower,
        uint256 activePlayers
    ) internal {
        (int256 currentRewardMult, int256 currentBurnRate,
         int256 currentMintCost, int256 currentPowerScale,
         int256 currentEntryFee) = economyParams.getCurrentParams();

        int256 targetRewardMult = currentRewardMult;
        int256 targetBurnRate = currentBurnRate;
        int256 targetMintCost = currentMintCost;
        int256 targetPowerScale = currentPowerScale;
        int256 targetEntryFee = currentEntryFee;

        // Rule 1: High win rate (>70%) → reduce rewards, increase difficulty
        if (winRate > 7000) { // 70%
            targetRewardMult -= 1500; // -15%
            targetPowerScale += 1000; // +10%
            targetMintCost += 500;    // +5%
        }
        // Rule 2: Low win rate (<40%) → increase rewards, decrease difficulty
        else if (winRate < 4000) {
            targetRewardMult += 1500;
            targetPowerScale -= 1000;
            targetEntryFee -= 500;
        }

        // Rule 3: High velocity (>50K) → reduce rewards, increase burn
        if (velocity > 50000) {
            targetRewardMult -= 2000;
            targetBurnRate += 2000;
        }
        // Rule 4: Low velocity (<10K) → increase rewards to stimulate
        else if (velocity < 10000 && velocity > 0) {
            targetRewardMult += 1500;
            targetBurnRate -= 1000;
        }

        // Rule 5: Low circulating supply (<30%) → inflate
        uint256 circRatio = (circulatingSupply * 10000) / totalSupply;
        if (circRatio < 3000) {
            targetRewardMult += 1500;
            targetBurnRate -= 2000;
        }
        // Rule 6: High circulating supply (>70%) → deflate
        else if (circRatio > 7000) {
            targetRewardMult -= 1500;
            targetBurnRate += 2000;
        }

        // Rule 7: Players dropping → boost economy
        uint256 medianPlayers = 100; // Simplified baseline
        if (activePlayers < medianPlayers / 2) {
            targetRewardMult += 2000;
            targetEntryFee -= 3000; // -30%
        }

        // Apply changes through EconomyParams (which applies gradual ramp)
        economyParams.updateParams(
            targetRewardMult,
            targetBurnRate,
            targetMintCost,
            targetPowerScale,
            targetEntryFee
        );

        // Trigger deflationary burn if needed
        if (circRatio > 6500 && velocity > 30000) {
            _triggerDeflationaryBurn(circulatingSupply);
        }

        emit AIResponseProcessed(
            targetRewardMult, targetBurnRate, targetMintCost,
            targetPowerScale, targetEntryFee,
            "Rule-based adjustment"
        );
    }

    /**
     * @notice Handle LLM callback (in production)
     */
    function handleAIResponse(
        uint256 requestId,
        bytes calldata responseData
    ) external {
        require(msg.sender == SOMNIA_PLATFORM, "Unauthorized");

        // Decode AI response
        string memory aiResponse = abi.decode(responseData, (string));

        // Parse JSON response (simplified - in production use proper parser)
        // Expected format: {"rewardMultiplier":..., "burnRate":..., ...}

        // For demo, apply rule-based
        _executeEpoch();
    }

    /**
     * @notice Trigger deflationary burn event
     */
    function _triggerDeflationaryBurn(uint256 circulatingSupply) internal {
        // Burn up to 1% of circulating supply
        uint256 burnAmount = circulatingSupply / 100;

        // Limit to treasury balance
        uint256 treasuryBalance = oikToken.balanceOf(address(treasury));
        if (burnAmount > treasuryBalance) {
            burnAmount = treasuryBalance;
        }

        if (burnAmount > 0) {
            // Call Treasury.executeBuyback via low-level call
            (bool success, ) = treasury.call(
                abi.encodeWithSignature("executeBuyback(uint256)", burnAmount)
            );
            require(success, "Treasury buyback failed");
            totalBurned += burnAmount;

            emit DeflationaryBurnTriggered(burnAmount);
        }
    }

    /**
     * @notice Check if circuit breaker should activate
     */
    function _checkCircuitBreakerConditions() internal view returns (bool) {
        // Check if system is paused
        if (circuitBreaker.paused()) {
            return true;
        }

        return false;
    }

    /**
     * @notice Collect economy metrics
     */
    function _collectMetrics() internal view returns (
        uint256 winRate,
        uint256 velocity,
        uint256 circulatingSupply,
        uint256 totalSupply,
        uint256 avgEnemyPower,
        uint256 activePlayers
    ) {
        totalSupply = oikToken.totalSupply();
        circulatingSupply = totalSupply - oikToken.balanceOf(address(treasury));

        // Simplified metrics (in production, query from game contracts)
        winRate = 6500; // 65%
        velocity = 25000;
        avgEnemyPower = 65;
        activePlayers = 150;
    }

    /**
     * @notice Calculate net inflation rate
     */
    function _calculateNetInflation(uint256 circulating, uint256 total) internal pure returns (uint256) {
        if (total == 0) return 0;
        return ((circulating * 10000) / total);
    }

    modifier whenSystemActive() {
        require(!circuitBreaker.paused(), "System paused");
        _;
    }

    // ============ Admin ============

    function setEpochLength(uint256 _epochLength) external onlyOwner {
        epochLength = _epochLength;
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    function setBattleArena(address _battleArena) external onlyOwner {
        battleArena = BattleArena(_battleArena);
    }

    function getEpochInfo() external view returns (
        uint256 _epochNumber,
        uint256 _lastEpochBlock,
        uint256 _epochLength,
        uint256 _nextEpochIn
    ) {
        _nextEpochIn = epochLength > block.number - lastEpochBlock
            ? epochLength - (block.number - lastEpochBlock)
            : 0;
        return (epochNumber, lastEpochBlock, epochLength, _nextEpochIn);
    }
}

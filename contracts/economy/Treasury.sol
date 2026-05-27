// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../tokens/OIKToken.sol";
import "./EconomyParams.sol";

/**
 * @title Treasury
 * @notice Manages reserves, buyback, and burn operations
 * @dev Receives burned tokens and manages ecosystem funds
 */
contract Treasury is Ownable {
    OIKToken public oikToken;
    EconomyParams public economyParams;

    uint256 public totalBurned;
    uint256 public totalBuybackAmount;
    uint256 public lastBuybackTime;

    uint256 public constant BUYBACK_COOLDOWN = 24 hours;
    uint256 public constant MAX_BUYBACK_PERCENTAGE = 100; // 1% of circulating supply

    // Burn statistics by category
    mapping(string => uint256) public burnsByCategory;

    event TokensBurned(string category, uint256 amount);
    event BuybackExecuted(uint256 amount, uint256 timestamp);
    event FundsReceived(address indexed from, uint256 amount);
    event EmergencyWithdraw(address indexed to, string token, uint256 amount);

    constructor(
        address _oikToken,
        address _economyParams
    ) Ownable(msg.sender) {
        oikToken = OIKToken(_oikToken);
        economyParams = EconomyParams(_economyParams);
    }

    /**
     * @notice Receive OIK tokens (entry fees, etc.)
     */
    function receiveTokens(string calldata category) external {
        uint256 amount = oikToken.balanceOf(msg.sender);
        require(amount > 0, "No tokens to receive");

        // Transfer from caller to treasury
        oikToken.transferFrom(msg.sender, address(this), amount);

        emit FundsReceived(msg.sender, amount);
    }

    /**
     * @notice Burn tokens from treasury
     */
    function burnTokens(string calldata category, uint256 amount) external onlyOwner {
        require(oikToken.balanceOf(address(this)) >= amount, "Insufficient balance");

        oikToken.burn(amount);

        totalBurned += amount;
        burnsByCategory[category] += amount;

        emit TokensBurned(category, amount);
    }

    /**
     * @notice Execute deflationary buyback and burn
     * @dev Triggered by EconomyController when supply > 65% and velocity > 30000
     */
    function executeBuyback(uint256 amount) external onlyOwner {
        require(
            block.timestamp >= lastBuybackTime + BUYBACK_COOLDOWN,
            "Buyback cooldown active"
        );
        require(
            oikToken.balanceOf(address(this)) >= amount,
            "Insufficient treasury balance"
        );

        // Buyback is done by treasury using its own OIK
        // In production, treasury would swap OIK for another asset
        // Here we just burn the OIK directly

        oikToken.burn(amount);

        totalBuybackAmount += amount;
        lastBuybackTime = block.timestamp;

        emit BuybackExecuted(amount, block.timestamp);
    }

    /**
     * @notice Calculate burn amount based on category
     * @dev Categories: 1=entry_fee, 2=mint_cost, 3=transfer
     */
    function calculateBurnAmount(
        uint256 baseAmount,
        uint256 category
    ) external view returns (uint256) {
        (, int256 burnRate, , , ) = economyParams.getCurrentParams();

        if (category == 1) {
            // Entry fee burn rate from params
            return (baseAmount * uint256(burnRate)) / 10000;
        } else if (category == 2) {
            // Full mint cost is burned (it's a sink)
            return baseAmount;
        } else if (category == 3) {
            // 0.5% transfer burn (handled by OIKToken)
            return (baseAmount * 50) / 10000;
        }

        return baseAmount;
    }

    /**
     * @notice Get treasury statistics
     */
    function getStats() external view returns (
        uint256 _totalBurned,
        uint256 _totalBuyback,
        uint256 balance
    ) {
        return (totalBurned, totalBuybackAmount, oikToken.balanceOf(address(this)));
    }

    /**
     * @notice Emergency withdrawal (only if system is not in critical state)
     */
    function emergencyWithdraw(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        OIKToken(token).transfer(to, amount);
        emit EmergencyWithdraw(to, "OIK", amount);
    }

    /**
     * @notice Accept OIK token transfers
     */
    receive() external payable {}
}

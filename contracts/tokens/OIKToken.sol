// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title OIKToken
 * @notice ERC-20 token for OIKONO game economy with 0.5% transfer burn tax
 * @dev Built for Somnia Agentic L1 (Chain ID: 5031/50312)
 */
contract OIKToken is ERC20, ERC20Burnable, Ownable {
    uint256 public constant MAX_SUPPLY = 1_500_000_000 * 1e18; // 1.5B OIK
    uint256 public constant TRANSFER_BURN_RATE = 50; // 0.5% (50 basis points)
    uint256 public constant BPS_BASE = 10_000;

    bool public transfersEnabled;
    uint256 public totalBurned;

    mapping(address => uint256) public dailyRewardsClaimed;
    mapping(address => uint256) public lastRewardDay;
    uint256 public constant DAILY_REWARD_CAP = 2000 * 1e18; // 2000 OIK per day per address

    event TransferBurn(address indexed from, uint256 amount);
    event TransfersEnabled();

    constructor(address initialOwner) ERC20("OIKONO", "OIK") Ownable(initialOwner) {
        // Mint initial supply (1B OIK)
        _mint(initialOwner, 1_000_000_000 * 1e18);
    }

    function enableTransfers() external onlyOwner {
        transfersEnabled = true;
        emit TransfersEnabled();
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override {
        // Skip burn tax for mint (from == address(0)) and burn (to == address(0))
        if (from != address(0) && to != address(0) && transfersEnabled) {
            uint256 burnAmount = (value * TRANSFER_BURN_RATE) / BPS_BASE;
            uint256 transferAmount = value - burnAmount;

            totalBurned += burnAmount;

            emit TransferBurn(from, burnAmount);

            // Send burn amount to address(0) (burn)
            super._update(from, address(0), burnAmount);
            // Send remaining amount to recipient
            super._update(from, to, transferAmount);
        } else {
            super._update(from, to, value);
        }
    }

    /**
     * @notice Check if address can claim daily rewards (anti-sybil)
     */
    function canClaimDailyRewards(address account) external view returns (bool) {
        uint256 today = block.timestamp / 1 days;
        if (lastRewardDay[account] < today) {
            return true;
        }
        return dailyRewardsClaimed[account] < DAILY_REWARD_CAP;
    }

    /**
     * @notice Record daily reward claim (called by game contracts)
     */
    function recordDailyReward(address account, uint256 amount) external onlyOwner {
        uint256 today = block.timestamp / 1 days;

        if (lastRewardDay[account] < today) {
            lastRewardDay[account] = today;
            dailyRewardsClaimed[account] = 0;
        }

        require(
            dailyRewardsClaimed[account] + amount <= DAILY_REWARD_CAP,
            "Daily reward cap exceeded"
        );

        dailyRewardsClaimed[account] += amount;
    }

    /**
     * @notice Mint new tokens (only owner, for emission)
     */
    function mint(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(to, amount);
    }
}

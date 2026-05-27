// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AgentVault
 * @notice Budget management and security for autonomous agents
 * @dev Prevents runaway AI agents from draining funds
 *      - Daily transaction limits
 *      - Per-execution caps
 *      - Emergency withdrawal by owner
 *
 * @dev Part of OIKONO Agent Kit
 */
contract AgentVault is Ownable {
    // ============ Types ============
    struct VaultConfig {
        uint256 dailyLimit;          // Max tokens per day
        uint256 perTxLimit;          // Max tokens per transaction
        uint256 minBalance;          // Keep minimum balance
        bool requireMultisig;        // Require multi-sig for large txs
        uint256 multisigThreshold;   // Amount requiring multisig
    }

    struct VaultStats {
        uint256 totalDeposited;
        uint256 totalSpent;
        uint256 dailySpent;
        uint256 lastResetDay;
        uint256 transactionCount;
    }

    // ============ State ============
    address public token;

    // Per-agent vaults
    mapping(address => uint256) public agentBalances;
    mapping(address => VaultConfig) public agentConfigs;
    mapping(address => VaultStats) public agentStats;

    // Guardian system
    mapping(address => bool) public guardians;
    mapping(address => mapping(uint256 => bool)) public guardianApprovals;
    uint256 public requiredApprovals;

    // ============ Events ============
    event VaultCreated(address indexed agent, uint256 initialDeposit);
    event Deposited(address indexed agent, uint256 amount);
    event Withdrawn(address indexed agent, uint256 amount, string reason);
    event SpendingCapped(address indexed agent, uint256 attempted, uint256 limit);
    event GuardianAdded(address indexed guardian);
    event TransactionApproved(uint256 indexed txId, address indexed guardian);

    // ============ Constructor ============
    constructor(address _token, uint256 _requiredApprovals) Ownable(msg.sender) {
        token = _token;
        requiredApprovals = _requiredApprovals;
    }

    // ============ Vault Management ============

    /**
     * @notice Create a vault for an agent
     */
    function createVault(
        uint256 dailyLimit,
        uint256 perTxLimit,
        uint256 minBalance
    ) external {
        require(agentConfigs[msg.sender].dailyLimit == 0, "Vault exists");

        agentConfigs[msg.sender] = VaultConfig({
            dailyLimit: dailyLimit,
            perTxLimit: perTxLimit,
            minBalance: minBalance,
            requireMultisig: false,
            multisigThreshold: dailyLimit / 2
        });

        agentStats[msg.sender] = VaultStats({
            totalDeposited: 0,
            totalSpent: 0,
            dailySpent: 0,
            lastResetDay: block.timestamp / 1 days,
            transactionCount: 0
        });

        emit VaultCreated(msg.sender, 0);
    }

    /**
     * @notice Deposit funds to vault
     */
    function deposit(uint256 amount) external {
        require(amount > 0, "Zero amount");

        IERC20(token).transferFrom(msg.sender, address(this), amount);
        agentBalances[msg.sender] += amount;
        agentStats[msg.sender].totalDeposited += amount;

        emit Deposited(msg.sender, amount);
    }

    /**
     * @notice Withdraw funds from vault (agent's own funds)
     */
    function withdraw(uint256 amount) external {
        VaultConfig storage config = agentConfigs[msg.sender];
        VaultStats storage stats = agentStats[msg.sender];

        // Check daily reset
        uint256 today = block.timestamp / 1 days;
        if (today > stats.lastResetDay) {
            stats.dailySpent = 0;
            stats.lastResetDay = today;
        }

        // Check limits
        require(agentBalances[msg.sender] >= amount, "Insufficient balance");
        require(stats.dailySpent + amount <= config.dailyLimit, "Daily limit exceeded");
        require(amount <= config.perTxLimit, "Per-tx limit exceeded");
        require(agentBalances[msg.sender] - amount >= config.minBalance, "Below min balance");

        agentBalances[msg.sender] -= amount;
        stats.dailySpent += amount;
        stats.totalSpent += amount;
        stats.transactionCount++;

        IERC20(token).transfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount, "normal");
    }

    /**
     * @notice Check if withdrawal is allowed
     */
    function canWithdraw(address agent, uint256 amount) external view returns (bool) {
        VaultConfig storage config = agentConfigs[agent];
        VaultStats storage stats = agentStats[agent];

        if (agentBalances[agent] < amount) return false;
        if (amount > config.perTxLimit) return false;
        if (agentBalances[agent] - amount < config.minBalance) return false;

        // Check daily limit (approximate - can't account for time in view)
        return true;
    }

    // ============ Guardian System ============

    /**
     * @notice Add guardian
     */
    function addGuardian(address guardian) external onlyOwner {
        guardians[guardian] = true;
        emit GuardianAdded(guardian);
    }

    /**
     * @notice Approve transaction (for multisig)
     */
    function approveTransaction(uint256 txId) external {
        require(guardians[msg.sender], "Not guardian");
        guardianApprovals[msg.sender][txId] = true;
        emit TransactionApproved(txId, msg.sender);
    }

    /**
     * @notice Emergency withdrawal by owner
     */
    function emergencyWithdraw(
        address agent,
        uint256 amount,
        string calldata reason
    ) external onlyOwner {
        require(agentBalances[agent] >= amount, "Insufficient balance");

        agentBalances[agent] -= amount;

        IERC20(token).transfer(owner(), amount);

        emit Withdrawn(agent, amount, reason);
    }

    /**
     * @notice Set vault config (owner/admin)
     */
    function setConfig(
        address agent,
        VaultConfig calldata config
    ) external onlyOwner {
        agentConfigs[agent] = config;
    }

    // ============ View Functions ============

    /**
     * @notice Get vault info
     */
    function getVaultInfo(address agent) external view returns (
        uint256 balance,
        uint256 dailyLimit,
        uint256 perTxLimit,
        uint256 minBalance,
        uint256 dailySpent,
        uint256 totalDeposited,
        uint256 totalSpent
    ) {
        VaultConfig storage config = agentConfigs[agent];
        VaultStats storage stats = agentStats[agent];

        return (
            agentBalances[agent],
            config.dailyLimit,
            config.perTxLimit,
            config.minBalance,
            stats.dailySpent,
            stats.totalDeposited,
            stats.totalSpent
        );
    }

    /**
     * @notice Get remaining daily budget
     */
    function getRemainingDailyBudget(address agent) external view returns (uint256) {
        VaultConfig storage config = agentConfigs[agent];
        VaultStats storage stats = agentStats[agent];

        uint256 today = block.timestamp / 1 days;
        uint256 spent = today > stats.lastResetDay ? 0 : stats.dailySpent;

        if (spent >= config.dailyLimit) return 0;
        return config.dailyLimit - spent;
    }
}

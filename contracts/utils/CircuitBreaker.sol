// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CircuitBreaker
 * @notice Emergency pause mechanism for OIKONO ecosystem
 * @dev Multi-sig style with guardian pattern
 */
contract CircuitBreaker is Ownable {
    bool public paused;
    uint256 public pausedAt;
    uint256 public constant MIN_PAUSE_DURATION = 1 hours;
    uint256 public constant MAX_PAUSE_DURATION = 7 days;

    // Guardian addresses (3-of-5 multisig pattern)
    mapping(address => bool) public guardians;
    mapping(address => bool) public guardianVotes;
    uint256 public requiredGuardianVotes;
    uint256 public guardianCount;

    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event GuardianAdded(address indexed guardian);
    event GuardianRemoved(address indexed guardian);
    event EmergencyVoteCast(address indexed guardian, bool vote);

    modifier whenNotPaused() {
        require(!paused, "System is paused");
        _;
    }

    modifier whenPaused() {
        require(paused, "System is not paused");
        _;
    }

    constructor(address initialOwner) Ownable(initialOwner) {
        // Set deployer as first guardian
        guardians[initialOwner] = true;
        guardianCount = 1;
        requiredGuardianVotes = 3; // 3-of-5
    }

    function addGuardian(address guardian) external onlyOwner {
        require(!guardians[guardian], "Already a guardian");
        require(guardianCount < 5, "Max guardians reached");

        guardians[guardian] = true;
        guardianCount++;
        emit GuardianAdded(guardian);
    }

    function removeGuardian(address guardian) external onlyOwner {
        require(guardians[guardian], "Not a guardian");

        guardians[guardian] = false;
        guardianCount--;
        emit GuardianRemoved(guardian);
    }

    /**
     * @notice Pause the system (requires guardian votes)
     */
    function voteToPause() external whenNotPaused {
        require(guardians[msg.sender], "Not a guardian");
        require(!guardianVotes[msg.sender], "Already voted");

        guardianVotes[msg.sender] = true;

        // Count votes
        uint256 voteCount = 0;
        address[] memory allGuardians = getGuardians();
        for (uint256 i = 0; i < allGuardians.length; i++) {
            if (guardianVotes[allGuardians[i]]) {
                voteCount++;
            }
        }

        if (voteCount >= requiredGuardianVotes) {
            _pause(msg.sender);
            // Reset votes after pausing
            _resetVotes();
        }

        emit EmergencyVoteCast(msg.sender, true);
    }

    /**
     * @notice Emergency pause by owner (bypass voting)
     */
    function emergencyPause() external onlyOwner whenNotPaused {
        _pause(msg.sender);
    }

    /**
     * @notice Unpause after minimum duration
     */
    function unpause() external onlyOwner whenPaused {
        require(
            block.timestamp >= pausedAt + MIN_PAUSE_DURATION,
            "Min pause duration not met"
        );
        _unpause(msg.sender);
    }

    /**
     * @notice Force unpause after max duration
     */
    function forceUnpause() external whenPaused {
        require(
            block.timestamp >= pausedAt + MAX_PAUSE_DURATION,
            "Max pause duration not reached"
        );
        _unpause(msg.sender);
    }

    function _pause(address by) internal {
        paused = true;
        pausedAt = block.timestamp;
        emit Paused(by);
    }

    function _unpause(address by) internal {
        paused = false;
        emit Unpaused(by);
    }

    function _resetVotes() internal {
        address[] memory allGuardians = getGuardians();
        for (uint256 i = 0; i < allGuardians.length; i++) {
            guardianVotes[allGuardians[i]] = false;
        }
    }

    function getGuardians() public view returns (address[] memory) {
        address[] memory result = new address[](guardianCount);
        uint256 idx = 0;

        // Return known guardians (simplified - in production use EnumerableSet)
        result[0] = owner();
        if (idx + 1 < guardianCount) {
            // In production, maintain a list of guardians
        }

        return result;
    }

    /**
     * @notice Modifier to use in other contracts
     */
    modifier whenSystemActive() {
        require(!paused, "System paused by circuit breaker");
        _;
    }
}

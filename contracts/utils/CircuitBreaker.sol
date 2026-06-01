// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CircuitBreaker
 * @notice Emergency pause mechanism for OIKONO ecosystem
 * @dev Multi-sig style with guardian pattern
 *      - Up to 5 guardians
 *      - 3-of-5 vote to pause
 *      - Owner can emergency pause
 *      - Auto-unpause after max duration
 */
contract CircuitBreaker is Ownable {
    bool public paused;
    uint256 public pausedAt;
    uint256 public constant MIN_PAUSE_DURATION = 1 hours;
    uint256 public constant MAX_PAUSE_DURATION = 7 days;

    // Guardian system
    mapping(address => bool) public guardians;
    mapping(address => bool) public guardianVotes;
    uint256 public requiredGuardianVotes;
    address[] public guardianList;

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
        guardians[initialOwner] = true;
        guardianList.push(initialOwner);
        requiredGuardianVotes = 3;
    }

    function addGuardian(address guardian) external onlyOwner {
        require(!guardians[guardian], "Already a guardian");
        require(guardianList.length < 5, "Max guardians reached");

        guardians[guardian] = true;
        guardianList.push(guardian);
        emit GuardianAdded(guardian);
    }

    function removeGuardian(address guardian) external onlyOwner {
        require(guardians[guardian], "Not a guardian");

        guardians[guardian] = false;

        // Remove from list
        for (uint256 i = 0; i < guardianList.length; i++) {
            if (guardianList[i] == guardian) {
                guardianList[i] = guardianList[guardianList.length - 1];
                guardianList.pop();
                break;
            }
        }

        // Reset their vote if they had voted
        if (guardianVotes[guardian]) {
            guardianVotes[guardian] = false;
        }

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
        for (uint256 i = 0; i < guardianList.length; i++) {
            if (guardianVotes[guardianList[i]]) {
                voteCount++;
            }
        }

        if (voteCount >= requiredGuardianVotes) {
            _pause(msg.sender);
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

    /**
     * @notice Cancel a guardian's vote (before pause triggers)
     */
    function cancelVote() external {
        require(guardianVotes[msg.sender], "No vote to cancel");
        guardianVotes[msg.sender] = false;
        emit EmergencyVoteCast(msg.sender, false);
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
        for (uint256 i = 0; i < guardianList.length; i++) {
            guardianVotes[guardianList[i]] = false;
        }
    }

    /**
     * @notice Get all guardian addresses
     */
    function getGuardians() external view returns (address[] memory) {
        return guardianList;
    }

    /**
     * @notice Get guardian count
     */
    function getGuardianCount() external view returns (uint256) {
        return guardianList.length;
    }

    /**
     * @notice Check how many votes are currently cast
     */
    function getCurrentVotes() external view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < guardianList.length; i++) {
            if (guardianVotes[guardianList[i]]) {
                count++;
            }
        }
        return count;
    }

    /**
     * @notice Modifier to use in other contracts
     */
    modifier whenSystemActive() {
        require(!paused, "System paused by circuit breaker");
        _;
    }
}

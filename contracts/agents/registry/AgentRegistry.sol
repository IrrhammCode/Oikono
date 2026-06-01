// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AgentRegistry
 * @notice Universal registry for discovering and managing AI agents
 * @dev Like an "App Store" for Web3 game AI agents
 *      - Game developers register their agents
 *      - Other developers can discover and compose agents
 *      - Agents can be public (for anyone) or private (game-specific)
 *
 * @dev Part of OIKONO Agent Kit
 */
contract AgentRegistry is Ownable {
    // ============ Types ============
    enum AgentVisibility {
        PUBLIC,     // Available for all games
        PRIVATE,    // Game-specific only
        COMMUNITY   // Community-maintained
    }

    struct Agent {
        uint256 agentId;
        address creator;
        string name;
        string description;
        AgentVisibility visibility;
        address runtimeAddress;     // Address of the agent contract
        string[] capabilities;      // ["spawn", "economy", "narrative", "balance"]
        uint256 totalUsage;
        uint256 rating;             // Average rating (1-5, basis points)
        uint256 createdAt;
        bool isActive;
    }

    struct AgentReview {
        address reviewer;
        uint256 agentId;
        uint256 rating;             // 1-5 stars
        string comment;
        uint256 timestamp;
    }

    // ============ State ============
    mapping(uint256 => Agent) public agents;
    mapping(uint256 => AgentReview[]) public agentReviews;
    mapping(address => uint256[]) public creatorAgents;
    mapping(uint256 => mapping(address => bool)) public agentUsage; // Track which games use which agents

    uint256 public nextAgentId;
    uint256 public totalAgents;

    // Indexes for discovery
    mapping(string => uint256[]) public agentsByCapability;
    mapping(address => bool) public verifiedCreators;

    // ============ Events ============
    event AgentRegistered(
        uint256 indexed agentId,
        address indexed creator,
        string name,
        string[] capabilities
    );
    event AgentUpdated(uint256 indexed agentId, string name, string description);
    event AgentToggled(uint256 indexed agentId, bool isActive);
    event AgentUsed(uint256 indexed agentId, address indexed game);
    event ReviewSubmitted(uint256 indexed agentId, address reviewer, uint256 rating);
    event CreatorVerified(address indexed creator);

    constructor() Ownable(msg.sender) {}

    // ============ Registration ============

    /**
     * @notice Register a new agent
     * @param name Agent name
     * @param description What the agent does
     * @param visibility Public, Private, or Community
     * @param runtimeAddress Address of the agent contract
     * @param capabilities Array of capabilities ["spawn", "economy", etc.]
     */
    function registerAgent(
        string calldata name,
        string calldata description,
        AgentVisibility visibility,
        address runtimeAddress,
        string[] calldata capabilities
    ) external returns (uint256) {
        require(bytes(name).length > 0, "Name required");
        require(runtimeAddress != address(0), "Invalid address");

        uint256 agentId = nextAgentId++;

        agents[agentId] = Agent({
            agentId: agentId,
            creator: msg.sender,
            name: name,
            description: description,
            visibility: visibility,
            runtimeAddress: runtimeAddress,
            capabilities: capabilities,
            totalUsage: 0,
            rating: 0,
            createdAt: block.timestamp,
            isActive: true
        });

        creatorAgents[msg.sender].push(agentId);

        // Add to capability index
        for (uint256 i = 0; i < capabilities.length; i++) {
            agentsByCapability[capabilities[i]].push(agentId);
        }

        totalAgents++;

        emit AgentRegistered(agentId, msg.sender, name, capabilities);

        return agentId;
    }

    /**
     * @notice Update agent metadata
     */
    function updateAgent(
        uint256 agentId,
        string calldata name,
        string calldata description
    ) external {
        require(agents[agentId].creator == msg.sender, "Not creator");

        agents[agentId].name = name;
        agents[agentId].description = description;

        emit AgentUpdated(agentId, name, description);
    }

    /**
     * @notice Toggle agent active status
     */
    function toggleAgent(uint256 agentId) external {
        require(agents[agentId].creator == msg.sender, "Not creator");
        agents[agentId].isActive = !agents[agentId].isActive;
        emit AgentToggled(agentId, agents[agentId].isActive);
    }

    // ============ Discovery ============

    /**
     * @notice Get agents by capability
     */
    function getAgentsByCapability(string calldata capability) external view returns (uint256[] memory) {
        return agentsByCapability[capability];
    }

    /**
     * @notice Get active public agents
     */
    function getPublicAgents() external view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < nextAgentId; i++) {
            if (agents[i].isActive && agents[i].visibility == AgentVisibility.PUBLIC) {
                count++;
            }
        }

        uint256[] memory result = new uint256[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < nextAgentId; i++) {
            if (agents[i].isActive && agents[i].visibility == AgentVisibility.PUBLIC) {
                result[idx++] = i;
            }
        }

        return result;
    }

    /**
     * @notice Get agent details
     */
    function getAgent(uint256 agentId) external view returns (
        address creator,
        string memory name,
        string memory description,
        uint8 visibility,
        address runtimeAddress,
        string[] memory capabilities,
        uint256 totalUsage,
        uint256 rating,
        bool isActive
    ) {
        Agent memory a = agents[agentId];
        return (
            a.creator, a.name, a.description, uint8(a.visibility),
            a.runtimeAddress, a.capabilities, a.totalUsage, a.rating, a.isActive
        );
    }

    /**
     * @notice Get agent's average rating (1-5 stars)
     */
    function getAverageRating(uint256 agentId) external view returns (uint256) {
        AgentReview[] storage reviews = agentReviews[agentId];
        if (reviews.length == 0) return 0;

        uint256 total = 0;
        for (uint256 i = 0; i < reviews.length; i++) {
            total += reviews[i].rating;
        }
        return total / reviews.length;
    }

    /**
     * @notice Get all agents by a creator
     */
    function getCreatorAgents(address creator) external view returns (uint256[] memory) {
        return creatorAgents[creator];
    }

    // ============ Usage Tracking ============

    /**
     * @notice Record agent usage (called by games when using an agent)
     */
    function recordUsage(uint256 agentId) external {
        require(agents[agentId].isActive, "Agent not active");
        require(
            agents[agentId].creator == msg.sender ||
            agentUsage[agentId][msg.sender] ||
            msg.sender == owner(),
            "Not authorized"
        );
        agents[agentId].totalUsage++;
        agentUsage[agentId][msg.sender] = true;

        emit AgentUsed(agentId, msg.sender);
    }

    // ============ Reviews ============

    /**
     * @notice Submit a review for an agent
     */
    function submitReview(
        uint256 agentId,
        uint256 rating,
        string calldata comment
    ) external {
        require(rating >= 1 && rating <= 5, "Rating 1-5");
        require(agents[agentId].isActive, "Agent not active");

        agentReviews[agentId].push(AgentReview({
            reviewer: msg.sender,
            agentId: agentId,
            rating: rating,
            comment: comment,
            timestamp: block.timestamp
        }));

        // Update average rating inline
        uint256 total = 0;
        for (uint256 i = 0; i < agentReviews[agentId].length; i++) {
            total += agentReviews[agentId][i].rating;
        }
        agents[agentId].rating = total / agentReviews[agentId].length;

        emit ReviewSubmitted(agentId, msg.sender, rating);
    }

    /**
     * @notice Get reviews for an agent
     */
    function getReviews(uint256 agentId) external view returns (AgentReview[] memory) {
        return agentReviews[agentId];
    }

    // ============ Admin ============

    /**
     * @notice Verify a creator (for COMMUNITY agents)
     */
    function verifyCreator(address creator) external onlyOwner {
        verifiedCreators[creator] = true;
        emit CreatorVerified(creator);
    }

    /**
     * @notice Check if creator is verified
     */
    function isVerifiedCreator(address creator) external view returns (bool) {
        return verifiedCreators[creator];
    }

    /**
     * @notice Get total stats
     */
    function getStats() external view returns (
        uint256 _totalAgents,
        uint256 _activeAgents,
        uint256 _totalUsage
    ) {
        _totalAgents = totalAgents;
        uint256 activeCount = 0;
        uint256 usageCount = 0;

        for (uint256 i = 0; i < nextAgentId; i++) {
            if (agents[i].isActive) activeCount++;
            usageCount += agents[i].totalUsage;
        }

        return (_totalAgents, activeCount, usageCount);
    }
}

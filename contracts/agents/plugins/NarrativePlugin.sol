// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../core/AgentTypes.sol";
import "../core/IAgentPlugin.sol";

/**
 * @title NarrativePlugin
 * @notice Universal plugin for AI-generated game narrative
 * @dev Generates quests, dialogues, story events using LLM
 *      Works for RPGs, adventure games, visual novels, etc.
 *
 * @dev Plugin for OIKONO Agent Kit
 */
contract NarrativePlugin is Ownable, IAgentPlugin {
    using AgentTypes for AgentTypes.ExecutionContext;

    // ============ Types ============
    enum QuestType {
        KILL,           // Kill X enemies
        COLLECT,        // Collect items
        EXPLORE,        // Visit locations
        TALK,           // NPC dialogue
        BOSS,           // Boss fight
        STORY           // Story progression
    }

    struct Quest {
        uint256 questId;
        address game;
        address player;
        QuestType questType;
        string title;
        string description;
        uint256 targetCount;
        uint256 currentProgress;
        uint256 reward;
        uint256 difficulty;
        bool isActive;
        bool isCompleted;
        uint256 createdAt;
        uint256 completedAt;
    }

    struct DialogueLine {
        string speaker;
        string text;
        string emotion;  // "happy", "angry", "neutral", "surprised"
    }

    // State
    mapping(uint256 => Quest) public quests;
    mapping(address => uint256[]) public playerQuests;
    uint256 public nextQuestId;

    // Game configurations
    mapping(address => string[]) public questThemes;  // Themes for each game

    // ============ Events ============
    event QuestGenerated(
        uint256 indexed questId,
        address indexed game,
        address indexed player,
        QuestType questType,
        string title,
        uint256 reward
    );
    event QuestProgressed(uint256 indexed questId, uint256 progress);
    event QuestCompleted(uint256 indexed questId, uint256 reward);
    event DialogueGenerated(uint256 indexed questId, DialogueLine[] dialogue);

    constructor() Ownable(msg.sender) {}

    // ============ Configuration ============

    /**
     * @notice Set quest themes for a game
     */
    function setThemes(string[] calldata themes) external {
        questThemes[msg.sender] = themes;
    }

    // ============ Plugin Interface ============

    /**
     * @notice Build LLM prompt for narrative generation
     */
    function getPrompt(
        AgentTypes.ActionType actionType,
        bytes calldata params,
        AgentTypes.ExecutionContext calldata context
    ) external view override returns (string memory) {
        (uint256 zone, string memory eventType) = abi.decode(params, (uint256, string));

        return string(abi.encodePacked(
            "Generate a quest for player at level ", _toString(context.playerLevel),
            " in zone ", _toString(zone),
            ". Event type: ", eventType, ".",
            " Return JSON: {\"title\":\"...\",\"description\":\"...\",",
            "\"type\":\"kill|collect|explore|talk|boss|story\",",
            "\"target\":number,\"reward\":number,\"difficulty\":1-10}"
        ));
    }

    /**
     * @notice Execute quest generation
     */
    function execute(
        AgentTypes.ActionType actionType,
        bytes calldata params,
        AgentTypes.ExecutionContext calldata context
    ) external override returns (bytes memory) {
        (uint256 zone, string memory eventType) = abi.decode(params, (uint256, string));

        // Deterministic quest generation
        bytes32 seed = keccak256(abi.encodePacked(
            blockhash(block.number - 1),
            msg.sender,
            context.player,
            zone,
            nextQuestId
        ));

        uint256 seedNum = uint256(seed);

        // Select quest type
        QuestType questType = QuestType(seedNum % 6);

        // Generate quest data
        string[6] memory titles = [
            "The Hunt Begins", "Gather the Shadows", "Explore the Unknown",
            "Seek the Oracle", "Face Your Destiny", "The Lost Chronicle"
        ];

        string[6] memory descriptions = [
            "Defeat the creatures lurking in the darkness.",
            "Collect the scattered artifacts before they fade.",
            "Discover the hidden paths that few have walked.",
            "Find the wise one who holds the ancient secrets.",
            "Confront the powerful entity that threatens the realm.",
            "Uncover the forgotten story that shaped this world."
        ];

        uint256 difficulty = 1 + (seedNum % 10);
        uint256 target = 1 + (seedNum % 5);
        uint256 reward = (difficulty * target) * 100 * 1e18; // Reward in smallest unit

        // Create quest
        uint256 questId = nextQuestId++;
        quests[questId] = Quest({
            questId: questId,
            game: msg.sender,
            player: context.player,
            questType: questType,
            title: titles[uint256(questType)],
            description: descriptions[uint256(questType)],
            targetCount: target,
            currentProgress: 0,
            reward: reward,
            difficulty: difficulty,
            isActive: true,
            isCompleted: false,
            createdAt: block.timestamp,
            completedAt: 0
        });

        playerQuests[context.player].push(questId);

        emit QuestGenerated(questId, msg.sender, context.player, questType, titles[uint256(questType)], reward);

        return abi.encode(questId, titles[uint256(questType)], reward, difficulty);
    }

    /**
     * @notice Parse AI response
     */
    function parseResponse(
        bytes calldata aiResponse
    ) external pure override returns (bytes memory) {
        return aiResponse;
    }

    // ============ Quest Management ============

    /**
     * @notice Update quest progress
     */
    function updateProgress(uint256 questId, uint256 progress) external {
        Quest storage quest = quests[questId];
        require(quest.isActive, "Quest not active");
        require(
            msg.sender == quest.game || msg.sender == quest.player,
            "Not authorized"
        );

        quest.currentProgress += progress;

        emit QuestProgressed(questId, quest.currentProgress);

        if (quest.currentProgress >= quest.targetCount) {
            _completeQuest(questId);
        }
    }

    function _completeQuest(uint256 questId) internal {
        Quest storage quest = quests[questId];
        quest.isActive = false;
        quest.isCompleted = true;
        quest.completedAt = block.timestamp;

        emit QuestCompleted(questId, quest.reward);
    }

    /**
     * @notice Generate dialogue for NPC interaction
     */
    function generateDialogue(
        uint256 questId,
        string calldata npcName,
        string calldata context
    ) external view returns (DialogueLine[] memory) {
        // In production: LLM generates this
        // For demo: return template
        DialogueLine[] memory dialogue = new DialogueLine[](3);
        dialogue[0] = DialogueLine({speaker: npcName, text: "Greetings, traveler.", emotion: "neutral"});
        dialogue[1] = DialogueLine({speaker: "Player", text: context, emotion: "curious"});
        dialogue[2] = DialogueLine({speaker: npcName, text: "May fortune smile upon your quest.", emotion: "happy"});

        return dialogue;
    }

    // ============ View Functions ============

    function getQuest(uint256 questId) external view returns (
        address game,
        address player,
        QuestType questType,
        string memory title,
        uint256 targetCount,
        uint256 currentProgress,
        uint256 reward,
        uint256 difficulty,
        bool isActive
    ) {
        Quest storage q = quests[questId];
        return (q.game, q.player, q.questType, q.title, q.targetCount, q.currentProgress, q.reward, q.difficulty, q.isActive);
    }

    function getPlayerQuests(address player) external view returns (uint256[] memory) {
        return playerQuests[player];
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

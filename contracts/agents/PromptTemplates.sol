// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title PromptTemplates
 * @notice Pre-built prompt templates for game economy analysis
 * @dev Used by LLMInvoker to generate consistent, high-quality prompts
 */
library PromptTemplates {

    // ============ Economy Analysis ============

    /**
     * @notice Build economy analysis prompt
     */
    function buildEconomyPrompt(
        uint256 winRate,
        uint256 velocity,
        uint256 circulatingSupply,
        uint256 totalSupply,
        uint256 avgEnemyPower,
        uint256 activePlayers,
        uint256 totalDecisions,
        uint256 successRate
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(
            "Analyze this Web3 game economy and recommend adjustments.\n\n",
            "METRICS:\n",
            "- Win rate: ", _toString(winRate / 100), ".", _toString(winRate % 100), "%\n",
            "- Token velocity: ", _toString(velocity), "\n",
            "- Circulating supply: ", _toString(circulatingSupply), "\n",
            "- Total supply: ", _toString(totalSupply), "\n",
            "- Avg enemy power: ", _toString(avgEnemyPower), "\n",
            "- Active players: ", _toString(activePlayers), "\n\n",
            "AGENT HISTORY:\n",
            "- Total decisions: ", _toString(totalDecisions), "\n",
            "- Success rate: ", _toString(successRate / 100), "%\n\n",
            "CONSTRAINTS:\n",
            "- Reward multiplier: +/-20% max change\n",
            "- Burn rate: +/-20% max change\n",
            "- Mint cost: +/-30% max change\n",
            "- Power scale: +/-20% max change\n",
            "- Entry fee: +/-20% max change\n\n",
            "Return pipe-separated values:\n",
            "success|action|rewardMultiplier|burnRate|mintCost|powerScale|entryFee|reasoning\n\n",
            "Example: true|adjust_economy|5|-3|0|10|-5|Win rate too high"
        ));
    }

    // ============ Spawn Analysis ============

    /**
     * @notice Build spawn analysis prompt
     */
    function buildSpawnPrompt(
        address player,
        uint256 level,
        uint256 xp,
        uint256 winRate,
        uint256 avgPower,
        string memory gameType
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(
            "Generate an enemy for this player.\n\n",
            "PLAYER:\n",
            "- Address: ", _addressToString(player), "\n",
            "- Level: ", _toString(level), "\n",
            "- XP: ", _toString(xp), "\n",
            "- Win rate: ", _toString(winRate / 100), "%\n\n",
            "GAME:\n",
            "- Type: ", gameType, "\n",
            "- Avg enemy power: ", _toString(avgPower), "\n\n",
            "CONSTRAINTS:\n",
            "- Power: 40-100\n",
            "- Threat level: 1-10\n",
            "- Scale with player level\n\n",
            "Return pipe-separated values:\n",
            "success|action|name|class|element|power|threat_level|reasoning\n\n",
            "Example: true|spawn|Shadow Wraith|assassin|shadow|75|7|High evasion"
        ));
    }

    // ============ Balance Analysis ============

    /**
     * @notice Build balance analysis prompt
     */
    function buildBalancePrompt(
        uint256 winRate,
        uint256 avgBattleDuration,
        uint256 playerRetention,
        uint256 difficultySweetSpot
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(
            "Analyze game balance and recommend adjustments.\n\n",
            "METRICS:\n",
            "- Win rate: ", _toString(winRate / 100), "%\n",
            "- Avg battle duration: ", _toString(avgBattleDuration), " seconds\n",
            "- Player retention (D7): ", _toString(playerRetention / 100), "%\n",
            "- Difficulty sweet spot: ", _toString(difficultySweetSpot / 100), "\n\n",
            "ANALYSIS:\n",
            "- Win rate > 70%: Too easy, increase difficulty\n",
            "- Win rate < 40%: Too hard, decrease difficulty\n",
            "- Retention < 30%: Players leaving, check difficulty\n",
            "- Battle duration > 10min: Too long, speed up\n\n",
            "Return pipe-separated values:\n",
            "success|action|difficultyChange|reasoning\n\n",
            "Example: true|adjust_balance|10|Win rate too high"
        ));
    }

    // ============ Narrative Analysis ============

    /**
     * @notice Build narrative generation prompt
     */
    function buildNarrativePrompt(
        address player,
        uint256 level,
        string memory zone,
        string memory eventType,
        uint256 questCount
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(
            "Generate narrative content for this player.\n\n",
            "PLAYER:\n",
            "- Address: ", _addressToString(player), "\n",
            "- Level: ", _toString(level), "\n",
            "- Current zone: ", zone, "\n",
            "- Event type: ", eventType, "\n",
            "- Quests completed: ", _toString(questCount), "\n\n",
            "REQUIREMENTS:\n",
            "- Match player level\n",
            "- Fit the zone theme\n",
            "- Provide meaningful progression\n\n",
            "Return pipe-separated values:\n",
            "success|action|questTitle|questDescription|objectives|rewards|reasoning\n\n",
            "Example: true|generate_narrative|Dark Forest Quest|Explore the dark forest|explore,defeat_boss|100xp,50gold|New area unlocked"
        ));
    }

    // ============ Helper Functions ============

    function _addressToString(address addr) internal pure returns (string memory) {
        uint256 value = uint256(uint160(addr));
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(42);
        str[0] = '0';
        str[1] = 'x';
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8((value >> (156 - i * 8)) & 0xf0) >> 4];
            str[3 + i * 2] = alphabet[uint8((value >> (152 - i * 8)) & 0x0f)];
        }
        return string(str);
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) { digits++; temp /= 10; }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}

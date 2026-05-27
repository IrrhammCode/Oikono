// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./AgentTypes.sol";

/**
 * @title IAgentPlugin
 * @notice Interface for OIKONO Agent Kit plugins
 */
interface IAgentPlugin {
    function execute(
        AgentTypes.ActionType actionType,
        bytes calldata params,
        AgentTypes.ExecutionContext calldata context
    ) external returns (bytes memory result);

    function getPrompt(
        AgentTypes.ActionType actionType,
        bytes calldata params,
        AgentTypes.ExecutionContext calldata context
    ) external view returns (string memory prompt);

    function parseResponse(
        bytes calldata aiResponse
    ) external view returns (bytes memory parsed);
}

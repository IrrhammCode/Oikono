// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title Minimal Game Contract for Oikono registration
/// @notice Stores basic game metadata on-chain
contract GameContract {
    string public name;
    string public gameType;
    string public description;
    address public owner;

    constructor(string memory _name, string memory _gameType, string memory _description) {
        name = _name;
        gameType = _gameType;
        description = _description;
        owner = msg.sender;
    }

    function isOwner(address _addr) external view returns (bool) {
        return _addr == owner;
    }
}

/// @title Game Factory - deploys multiple games in one transaction
/// @notice Saves gas by batching deployments
contract GameFactory {
    address[] public deployedGames;

    function deployGames(
        string[] memory names,
        string[] memory types,
        string[] memory descs
    ) external returns (address[] memory) {
        require(names.length == types.length && types.length == descs.length, "Array length mismatch");
        require(names.length <= 20, "Max 20 games per batch");

        address[] memory games = new address[](names.length);
        for (uint256 i = 0; i < names.length; i++) {
            GameContract game = new GameContract(names[i], types[i], descs[i]);
            games[i] = address(game);
            deployedGames.push(address(game));
        }
        return games;
    }

    function getDeployedGames() external view returns (address[] memory) {
        return deployedGames;
    }

    function getDeployedCount() external view returns (uint256) {
        return deployedGames.length;
    }
}

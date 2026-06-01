// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./GameRegistryBase.sol";

/**
 * @title GameContractManager
 * @notice Manages multiple contracts per game
 * @dev Supports games with token, NFT, marketplace, staking contracts
 */
contract GameContractManager is Ownable {

    // ============ Types ============

    struct GameContract {
        address contractAddress;
        string role;
        bytes32[] eventHashes;
        bool isActive;
        uint256 addedAt;
    }

    // ============ State ============

    GameRegistryBase public registry;

    mapping(uint256 => GameContract[]) public gameContracts;
    mapping(uint256 => mapping(address => uint256)) public contractIndex;
    mapping(uint256 => mapping(string => address)) public contractByRole;

    // ============ Events ============

    event ContractAdded(
        uint256 indexed gameId,
        address indexed contractAddress,
        string role
    );

    event ContractRemoved(
        uint256 indexed gameId,
        address indexed contractAddress
    );

    event ContractRoleUpdated(
        uint256 indexed gameId,
        address indexed contractAddress,
        string newRole
    );

    // ============ Constructor ============

    constructor(address _registry, address initialOwner) Ownable(initialOwner) {
        registry = GameRegistryBase(_registry);
    }

    // ============ Contract Management ============

    /**
     * @notice Add a contract to game
     */
    function addContract(
        uint256 gameId,
        address contractAddress,
        string calldata role,
        bytes32[] calldata eventHashes
    ) external {
        (address gameOwner, , , , , , , , ) = registry.getGame(gameId);
        require(gameOwner == msg.sender, "Not game owner");
        require(contractAddress != address(0), "Invalid address");
        require(bytes(role).length > 0, "Role required");
        require(contractIndex[gameId][contractAddress] == 0, "Already added");

        uint256 index = gameContracts[gameId].length;

        gameContracts[gameId].push(GameContract({
            contractAddress: contractAddress,
            role: role,
            eventHashes: eventHashes,
            isActive: true,
            addedAt: block.timestamp
        }));

        contractIndex[gameId][contractAddress] = index + 1;
        contractByRole[gameId][role] = contractAddress;

        emit ContractAdded(gameId, contractAddress, role);
    }

    /**
     * @notice Add a contract on behalf of another user (for proxy contracts)
     */
    function addContractFor(
        uint256 gameId,
        address caller,
        address contractAddress,
        string calldata role,
        bytes32[] calldata eventHashes
    ) external {
        (address gameOwner, , , , , , , , ) = registry.getGame(gameId);
        require(gameOwner == caller, "Not game owner");
        require(contractAddress != address(0), "Invalid address");
        require(bytes(role).length > 0, "Role required");
        require(contractIndex[gameId][contractAddress] == 0, "Already added");

        uint256 index = gameContracts[gameId].length;

        gameContracts[gameId].push(GameContract({
            contractAddress: contractAddress,
            role: role,
            eventHashes: eventHashes,
            isActive: true,
            addedAt: block.timestamp
        }));

        contractIndex[gameId][contractAddress] = index + 1;
        contractByRole[gameId][role] = contractAddress;

        emit ContractAdded(gameId, contractAddress, role);
    }

    /**
     * @notice Remove a contract from game
     */
    function removeContract(uint256 gameId, address contractAddress) external {
        (address gameOwner, , , , , , , , ) = registry.getGame(gameId);
        require(gameOwner == msg.sender, "Not game owner");

        uint256 index = contractIndex[gameId][contractAddress];
        require(index > 0, "Contract not found");

        gameContracts[gameId][index - 1].isActive = false;
        delete contractIndex[gameId][contractAddress];

        emit ContractRemoved(gameId, contractAddress);
    }

    /**
     * @notice Remove a contract on behalf of another user
     */
    function removeContractFor(uint256 gameId, address caller, address contractAddress) external {
        (address gameOwner, , , , , , , , ) = registry.getGame(gameId);
        require(gameOwner == caller, "Not game owner");

        uint256 index = contractIndex[gameId][contractAddress];
        require(index > 0, "Contract not found");

        gameContracts[gameId][index - 1].isActive = false;
        delete contractIndex[gameId][contractAddress];

        emit ContractRemoved(gameId, contractAddress);
    }

    /**
     * @notice Update contract role
     */
    function updateContractRole(
        uint256 gameId,
        address contractAddress,
        string calldata newRole
    ) external {
        (address gameOwner, , , , , , , , ) = registry.getGame(gameId);
        require(gameOwner == msg.sender, "Not game owner");

        uint256 index = contractIndex[gameId][contractAddress];
        require(index > 0, "Contract not found");

        gameContracts[gameId][index - 1].role = newRole;
        contractByRole[gameId][newRole] = contractAddress;

        emit ContractRoleUpdated(gameId, contractAddress, newRole);
    }

    // ============ View Functions ============

    function getGameContracts(uint256 gameId) external view returns (
        address[] memory addresses,
        string[] memory roles,
        bool[] memory active
    ) {
        uint256 len = gameContracts[gameId].length;
        addresses = new address[](len);
        roles = new string[](len);
        active = new bool[](len);

        for (uint256 i = 0; i < len; i++) {
            GameContract storage gc = gameContracts[gameId][i];
            addresses[i] = gc.contractAddress;
            roles[i] = gc.role;
            active[i] = gc.isActive;
        }
    }

    function getContractByRole(uint256 gameId, string calldata role) external view returns (address) {
        return contractByRole[gameId][role];
    }

    function getContractCount(uint256 gameId) external view returns (uint256) {
        return gameContracts[gameId].length;
    }
}

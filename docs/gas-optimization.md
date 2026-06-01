# Gas Optimization for Web3 Game Contracts

## Storage Packing

### Before (Wasteful)
```solidity
struct Player {
    uint256 level;      // 32 bytes
    uint256 xp;         // 32 bytes
    uint256 health;     // 32 bytes
    bool isAlive;       // 1 byte (but takes slot)
}
// Total: 4 storage slots = 80,000 gas
```

### After (Optimized)
```solidity
struct Player {
    uint128 level;      // 16 bytes
    uint128 xp;         // 16 bytes
    uint128 health;     // 16 bytes
    bool isAlive;       // 1 byte
    uint8 padding;      // 15 bytes padding
}
// Total: 2 storage slots = 40,000 gas
```

## Batch Operations

```solidity
// Before: Multiple transactions
function mint(address to, uint256 id) external {
    _mint(to, id);
}

// After: Batch mint
function mintBatch(address[] calldata to, uint256[] calldata ids) external {
    for (uint256 i = 0; i < to.length; i++) {
        _mint(to[i], ids[i]);
    }
}
```

## Event vs Storage Tradeoffs

| Approach | Gas Cost | Use Case |
|----------|----------|----------|
| **Storage** | 20,000 gas/write | Data needed on-chain |
| **Event** | 375 gas/topic + 8 gas/byte | Off-chain indexing |
| **Calldata** | 16 gas/byte | Read-only data |

### Best Practice
```solidity
// Store minimal data on-chain
mapping(uint256 => uint256) public playerLevel;

// Emit detailed data in events
event PlayerAction(
    uint256 indexed playerId,
    string actionType,
    bytes data  // Heavy data goes here
);
```

## Somnia-Specific Optimizations

1. **High TPS** = More events per block = Batch processing
2. **Low gas costs** = Can afford more complex logic
3. **On-chain reactivity** = Same-block event handling

## Recommendations for Oikono

1. **Pack structs** - Use uint128 instead of uint256 where possible
2. **Batch operations** - Process multiple games in one tx
3. **Events for history** - Don't store full history on-chain
4. **Minimal storage** - Only store what's needed for logic

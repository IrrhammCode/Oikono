# Security Patterns for Web3 Game Contracts

## Common Vulnerabilities

### 1. Reentrancy Attacks

**Risk:** External calls before state updates

**Mitigation:**
```solidity
// Use ReentrancyGuard
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract GameContract is ReentrancyGuard {
    function withdraw() external nonReentrant {
        // State update before external call
        uint256 amount = balances[msg.sender];
        balances[msg.sender] = 0;
        
        // External call last
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }
}
```

### 2. Flash Loan Attacks

**Risk:** Price manipulation within single transaction

**Mitigation:**
```solidity
// Use TWAP oracle instead of spot price
function getPrice() internal view returns (uint256) {
    return twapOracle.getTWAP(); // Time-weighted average
    // NOT: spotOracle.getPrice() // Can be manipulated
}
```

### 3. Oracle Manipulation

**Risk:** Single source price feed

**Mitigation:**
```solidity
// Multiple oracle sources
function getPrice() internal view returns (uint256) {
    uint256 price1 = oracle1.getPrice();
    uint256 price2 = oracle2.getPrice();
    uint256 price3 = oracle3.getPrice();
    
    // Use median
    return median(price1, price2, price3);
}
```

### 4. Access Control Issues

**Risk:** Unauthorized function calls

**Mitigation:**
```solidity
// Use role-based access
import "@openzeppelin/contracts/access/AccessControl.sol";

contract GameContract is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant GAME_MASTER_ROLE = keccak256("GAME_MASTER_ROLE");
    
    function adminAction() external onlyRole(ADMIN_ROLE) {
        // Admin only
    }
}
```

### 5. Integer Overflow/Underflow

**Risk:** Arithmetic operations without checks

**Mitigation:**
```solidity
// Solidity 0.8+ has built-in overflow checks
// For older versions, use SafeMath
uint256 result = a + b; // Reverts on overflow in 0.8+
```

## Oikono Security Features

| Feature | Implementation |
|---------|----------------|
| **Circuit Breaker** | 3-of-5 guardian votes to pause |
| **Anti-Sybil** | Cooldowns, stake minimum |
| **TWAP Oracle** | 100-block window |
| **Rate Limiting** | 30s-200s cooldowns |
| **Bounded Changes** | ±20-30% max per epoch |
| **ReentrancyGuard** | OpenZeppelin standard |

## Best Practices

1. **Checks-Effects-Interactions** pattern
2. **Use ReentrancyGuard** for external calls
3. **TWAP oracles** instead of spot prices
4. **Role-based access control**
5. **Circuit breakers** for emergencies
6. **Rate limiting** for user actions
7. **Bounded parameter changes**
8. **Regular security audits**

## Sources

- OpenZeppelin security contracts
- ConsenSys security best practices
- rekt.news exploit database

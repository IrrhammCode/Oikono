# On-Chain JSON Parsing for LLM Responses

## Key Findings

### 1. No Production-Ready JSON Parser Exists

**Confirmed:** Tidak ada library Solidity untuk JSON parsing.

**Implication:** LLM responses tidak bisa di-parse langsung di on-chain.

### 2. ABI Encoding - Bukan untuk JSON

ABI encoding dirancang untuk:
- Inter-contract communication
- Type-safe, compile-time schema
- Tidak bisa parse arbitrary JSON

### 3. EIP-712 - Alternatif Terbaik

**EIP-712** menyediakan:
- Structured data encoding
- Gas-efficient (compile-time typeHash)
- In-place EVM memory layout

**Pattern:**
```solidity
// Define schema at compile time
bytes32 constant DECISION_TYPEHASH = keccak256(
    "Decision(string action,int256 rewardMult,int256 burnRate,string reasoning)"
);

// Verify structured data on-chain
function verifyDecision(bytes32 structHash, bytes memory signature) internal {
    bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    // Verify signature
}
```

### 4. Recommended Architecture

```
LLM Response (JSON)
    ↓
Off-chain Parser (JavaScript/Python)
    ↓
ABI Encode / EIP-712 Struct
    ↓
On-chain Verification
    ↓
Execute Action
```

### 5. Practical Solution for Oikono

**Option A: Off-chain parsing + On-chain execution**
```javascript
// Off-chain (JavaScript)
const response = await llm.invoke(prompt);
const parsed = JSON.parse(response);
const encoded = abi.encode(["string", "int256", "int256"], 
    [parsed.action, parsed.rewardMult, parsed.burnRate]);
await contract.executeAction(encoded);
```

**Option B: Predefined response format**
```solidity
// On-chain - request specific format
string memory prompt = "...Return: action|rewardMult|burnRate";
// Parse simple delimiter-separated values
```

**Option C: Somnia-specific**
- Use Somnia's LLM callback with ABI-encoded response
- LLM returns ABI-encoded data, not JSON
- Direct on-chain parsing

## Recommendations

1. **Don't parse JSON on-chain** - Too expensive, no libraries
2. **Use ABI encoding** - Request LLM to return ABI-encoded data
3. **Off-chain parsing** - Parse JSON off-chain, submit encoded data
4. **EIP-712 for verification** - Verify structured data signatures
5. **Somnia LLM callback** - Use native ABI-encoded responses

## Impact on Oikono

| Component | Current | Recommended |
|-----------|---------|-------------|
| LLMInvoker | JSON parsing | ABI-encoded responses |
| Prompt Templates | Request JSON | Request ABI format |
| Response Handler | Parse JSON | Direct ABI decode |

## Sources

- Solidity ABI documentation
- EIP-712 specification
- snekmate library (Vyper only)

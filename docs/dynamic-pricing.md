# Dynamic Pricing Algorithms for Web3 Games

## Key Findings

### 1. Bonding Curves

**Formula Types:**
- Linear: `P = m*x + b`
- Polynomial: `P = c*x^k`
- Sigmoid: S-shaped curve

**Use Cases:**
- Continuous liquidity without order books
- Predictable pricing based on supply
- Low entry, high exit costs (sigmoid)

### 2. AMM-Style Pricing

**Constant Product Formula:** `x * y = k`

**sudoswap** pioneered AMM for NFTs:
- Treats NFT collections as fungible within pools
- Uses bonding curves for floor assets
- Enables instant buy/sell

### 3. Demand-Based Dynamic Pricing

**Metrics Used:**
- Win rates
- Token velocity
- Circulating supply ratios
- Active player counts

**Oikono Implementation:**
- High win rate (>70%) → Reduce rewards 15%, increase difficulty
- High velocity (>50K) → Reduce rewards, increase burn
- Low supply (<30%) → Stimulate inflation

**Safety Bounds:**
- AI_REWARD_MAX_CHANGE: ±20%
- AI_BURN_MAX_CHANGE: ±20%
- AI_MINT_MAX_CHANGE: ±30%

### 4. Anti-Manipulation Mechanisms

| Mechanism | Implementation |
|-----------|----------------|
| **TWAP Oracle** | 100-block window, 1-hour max age |
| **Circuit Breaker** | 3-of-5 guardian votes to pause |
| **Rate Limiting** | 30s move, 60s battle cooldown |
| **Minimum Stake** | 10 OIK minimum |
| **Auto-Unpause** | 7 days max pause |

### 5. Real Examples

| Game | Pricing Model | Notes |
|------|---------------|-------|
| **Illuvium** | Tiered Dutch auctions | Illuvial NFTs |
| **Gods Unchained** | Player-driven marketplace | Card NFTs |
| **StepN** | Dynamic minting costs | Tied to GST price |

## Recommendations for Oikono

1. **Use TWAP oracles** for price feeds
2. **Implement circuit breakers** for emergencies
3. **Bound all changes** (±20-30% max)
4. **Track demand metrics** for dynamic pricing
5. **Learn from outcomes** to improve pricing

## Sources

- sudoswap documentation
- Uniswap V2/V3 whitepaper
- Paradigm NFT-Fi research
- Illuvium economy design docs
- Oikono implementation

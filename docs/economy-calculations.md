# OIKONO - Economy Calculations Per Game Type

Deep analysis untuk setiap game type Web3.

## 1. RPG Games

### Key Metrics

| Metric | Formula | Healthy Range | Warning Threshold |
|--------|---------|---------------|-------------------|
| **Token Velocity** | `tx_volume / market_cap` | 5-20 | >50 (hyperinflation) |
| **Gold Inflation** | `(mint_rate - burn_rate) / supply` | 0-5%/day | >10%/day |
| **Win Rate** | `wins / battles` | 45-65% | >70% or <35% |
| **Level Speed** | `levels_gained / hours_played` | 0.5-2/hour | >5/hour |
| **Reward Curve** | `base_reward * (1 + level * 0.1)` | Linear | Exponential |

### Calculations

```javascript
// Token Velocity
const tokenVelocity = dailyTxVolume / circulatingSupply;

// Gold Inflation Rate
const goldInflation = (dailyMint - dailyBurn) / totalSupply * 100;

// Level Progression Speed
const levelSpeed = (currentLevel - startLevel) / hoursPlayed;

// Reward Scaling
const rewardMultiplier = 1 + (playerLevel * 0.1);
const adjustedReward = baseReward * rewardMultiplier;

// Sink/Source Ratio
const sinkSourceRatio = totalBurned / totalMinted;
// Healthy: 0.7 - 1.0
// Warning: <0.5 (inflation) or >1.2 (deflation)
```

### Real Examples

| Game | Token Velocity | Win Rate | Issue |
|------|---------------|----------|-------|
| **Axie Infinity** | 100+ | 80%+ | Hyperinflation, SLP crash |
| **Illuvium** | 15 | 55% | Balanced |
| **Big Time** | 25 | 60% | Moderate inflation |

### Warning Signs

- Token velocity >50 → Players dumping tokens
- Win rate >70% → Game too easy, players leaving
- Gold inflation >10%/day → Economy collapsing
- Level speed >5/hour → Content drought coming

---

## 2. Card Games (TCG/CCG)

### Key Metrics

| Metric | Formula | Healthy Range | Warning Threshold |
|--------|---------|---------------|-------------------|
| **Pack EV** | `sum(card_value * probability) / pack_price` | 0.9-1.1 | <0.7 or >1.3 |
| **Meta Diversity** | `1 - max(deck_usage)` | >65% | <50% |
| **Collection Rate** | `cards_owned / total_cards` | 30-50% in 30d | <20% |
| **Card Price Stability** | `std_dev(prices) / avg_price` | <30% | >50% |
| **Match Duration** | `avg(battle_time)` | 5-15 min | >20 min |

### Calculations

```javascript
// Pack Expected Value
const packEV = cards.reduce((sum, card) => {
    return sum + (card.marketPrice * card.dropRate);
}, 0) / packPrice;

// Meta Diversity Index (Herfindahl-Hirschman)
const metaDiversity = 1 - deckUsage.reduce((sum, usage) => {
    return sum + Math.pow(usage / totalGames, 2);
}, 0);
// Range: 0 (monopoly) to 1 (perfect diversity)

// Collection Rate
const collectionRate = ownedCards / totalCards * 100;

// Card Price Stability
const priceStability = stdDev(cardPrices) / avgPrice * 100;
```

### Real Examples

| Game | Pack EV | Meta Diversity | Issue |
|------|---------|----------------|-------|
| **Gods Unchained** | 0.95 | 72% | Balanced |
| **Splinterlands** | 1.05 | 65% | Slight inflation |
| **Axie Infinity** | 1.2 | 45% | Meta stale |

### Warning Signs

- Pack EV <0.7 → Players losing value
- Pack EV >1.3 → Unsustainable inflation
- Meta diversity <50% → Stale meta
- Collection rate <20% in 30d → Too slow

---

## 3. Strategy Games

### Key Metrics

| Metric | Formula | Healthy Range | Warning Threshold |
|--------|---------|---------------|-------------------|
| **Resource Balance** | `income_rate / spend_rate` | 0.8-1.2 | <0.5 or >2.0 |
| **Build Time Curve** | `base_time * (1.5 ^ level)` | Exponential | >2x per level |
| **Unit Power Distribution** | `std_dev(unit_power)` | Balanced | >30% variance |
| **Territory Control** | `player_territory / total_territory` | 10-30% | >50% |
| **Match Duration** | `avg(match_time)` | 10-30 min | >45 min |

### Calculations

```javascript
// Resource Balance
const resourceBalance = dailyIncome / dailySpend;
// Healthy: 0.8 - 1.2
// Warning: <0.5 (starvation) or >2.0 (inflation)

// Build Time Curve
const buildTime = baseTime * Math.pow(1.5, buildingLevel);
// Should be exponential but not too steep

// Unit Power Distribution
const powerVariance = stdDev(unitPowers) / avgPower * 100;
// Healthy: <20%
// Warning: >30% (some units too strong)

// Territory Control (Gini Coefficient)
const territoryGini = calculateGini(territoryDistribution);
// Healthy: 0.3-0.6
// Warning: >0.8 (monopoly)
```

### Real Examples

| Game | Resource Balance | Match Duration | Issue |
|------|------------------|----------------|-------|
| **Dark Forest** | 1.1 | 25 min | Balanced |
| **Ember Sword** | 0.9 | 20 min | Slight starvation |
| **Star Atlas** | 1.5 | 40 min | Resource inflation |

### Warning Signs

- Resource balance <0.5 → Players can't build
- Resource balance >2.0 → Hyperinflation
- Territory Gini >0.8 → Whales dominating
- Match duration >45 min → Too long

---

## 4. PvP Games

### Key Metrics

| Metric | Formula | Healthy Range | Warning Threshold |
|--------|---------|---------------|-------------------|
| **Win Rate Distribution** | `std_dev(player_winrates)` | 40-60% avg | >70% or <30% |
| **ELO Spread** | `max_elo - min_elo` | 1000-2000 | >3000 |
| **Queue Time** | `avg(wait_time)` | <30 sec | >120 sec |
| **Rank Distribution** | Bell curve | Normal | Skewed |
| **Match Balance** | `avg(elo_diff)` | <200 | >500 |

### Calculations

```javascript
// ELO Rating System
const expectedScore = 1 / (1 + Math.pow(10, (opponentELO - playerELO) / 400));
const newELO = playerELO + K * (actualScore - expectedScore);
// K = 32 for new players, 16 for established

// Win Rate Distribution
const winRateStdDev = stdDev(playerWinRates);
// Healthy: 10-15%
// Warning: >20% (huge skill gap)

// Queue Time Optimization
const avgQueueTime = totalWaitTime / totalMatches;
// Healthy: <30 seconds
// Warning: >120 seconds

// Rank Distribution (should be bell curve)
const rankDistribution = playersByRank;
// Check for: top-heavy (too many high rank) or bottom-heavy
```

### Real Examples

| Game | Win Rate Spread | Queue Time | Issue |
|------|-----------------|------------|-------|
| **Thetan Arena** | 15% | 45 sec | Moderate |
| **Blast Royale** | 12% | 20 sec | Balanced |
| **Phantom Galaxies** | 25% | 90 sec | Skill gap |

### Warning Signs

- Win rate >70% for top players → Skill gap too large
- Queue time >120 sec → Not enough players
- ELO spread >3000 → Matchmaking broken
- Rank distribution skewed → Progression issues

---

## 5. Simulation/Tycoon Games

### Key Metrics

| Metric | Formula | Healthy Range | Warning Threshold |
|--------|---------|---------------|-------------------|
| **Resource Production** | `units / hour` | Varies by game | >10x baseline |
| **Trade Volume** | `daily_trades * avg_value` | Growing | Declining |
| **Land Value** | `total_value / total_land` | Stable | >50% variance |
| **Creator Earnings** | `avg(creator_revenue)` | Growing | Declining |
| **Session Length** | `avg(session_time)` | 15-60 min | <5 min |

### Calculations

```javascript
// Resource Production Rate
const productionRate = resourcesProduced / timePeriod;
// Should be stable or slowly growing

// Trade Volume Trend
const tradeVolumeTrend = (currentVolume - previousVolume) / previousVolume * 100;
// Healthy: +5-15% per week
// Warning: -20% or more

// Land Value Distribution
const landValueGini = calculateGini(landValues);
// Healthy: 0.3-0.5
// Warning: >0.7 (whale dominance)

// Creator Economy Health
const creatorEarnings = totalCreatorRevenue / totalCreators;
const creatorRetention = activeCreators / totalCreators * 100;
// Healthy: >60% retention
// Warning: <40% retention

// Session Length
const avgSessionLength = totalPlayTime / totalSessions;
// Healthy: 15-60 minutes
// Warning: <5 minutes (no engagement)
```

### Real Examples

| Game | Trade Volume | Creator Retention | Issue |
|------|--------------|-------------------|-------|
| **The Sandbox** | Growing | 70% | Healthy |
| **Decentraland** | Declining | 45% | Creator exodus |
| **Upland** | Stable | 65% | Moderate |

### Warning Signs

- Trade volume declining 20%+ → Dead economy
- Creator retention <40% → No content
- Land value Gini >0.7 → Whale dominance
- Session length <5 min → No engagement

---

## 6. DeFi/GameFi Games

### Key Metrics

| Metric | Formula | Healthy Range | Warning Threshold |
|--------|---------|---------------|-------------------|
| **APY** | `(rewards / staked) * 365` | 5-50% | >100% |
| **TVL** | `total_value_locked` | Growing | Declining 20%+ |
| **Token Velocity** | `volume / market_cap` | 5-20 | >50 |
| **Deposit/Withdraw Ratio** | `deposits / withdrawals` | 0.8-1.2 | <0.5 |
| **Liquidity Depth** | `pool_value / slippage` | Deep | Thin |

### Calculations

```javascript
// APY Calculation
const dailyReward = stakingReward / totalStaked;
const apy = Math.pow(1 + dailyReward, 365) - 1;

// TVL Trend
const tvlTrend = (currentTVL - previousTVL) / previousTVL * 100;
// Healthy: +5-20% per month
// Warning: -20% or more

// Deposit/Withdraw Ratio
const dwRatio = dailyDeposits / dailyWithdrawals;
// Healthy: 0.8 - 1.2
// Warning: <0.5 (bank run)

// Liquidity Depth
const slippage = calculateSlippage(tradeSize, poolSize);
// Healthy: <1% for $10k trade
// Warning: >5% for $10k trade
```

### Real Examples

| Game | APY | TVL Trend | Issue |
|------|-----|-----------|-------|
| **DeFi Kingdoms** | 25% | Stable | Balanced |
| **STEPN** | 200% | -80% | Unsustainable |
| **PancakeSwap** | 40% | Growing | Healthy |

### Warning Signs

- APY >100% → Unsustainable emissions
- TVL declining 20%+ → Capital flight
- DW ratio <0.5 → Bank run
- Slippage >5% → Thin liquidity

---

## 7. Cross-Game Universal Metrics

### Applies to ALL game types

| Metric | Formula | Healthy Range | Warning |
|--------|---------|---------------|---------|
| **DAU/MAU Ratio** | `daily_active / monthly_active` | 20-40% | <10% |
| **D1 Retention** | `day1_return / new_users` | 40-60% | <25% |
| **D7 Retention** | `day7_return / new_users` | 20-40% | <10% |
| **D30 Retention** | `day30_return / new_users` | 10-20% | <5% |
| **ARPU** | `revenue / active_users` | Varies | Declining |
| **LTV** | `avg_revenue * avg_lifetime` | >3x CAC | <1.5x CAC |

### Calculations

```javascript
// DAU/MAU Ratio (Stickiness)
const stickiness = dailyActiveUsers / monthlyActiveUsers * 100;
// Healthy: 20-40%
// Warning: <10% (users don't come back)

// Retention Curve
const retention = {
    d1: day1Return / newUsers * 100,
    d7: day7Return / newUsers * 100,
    d30: day30Return / newUsers * 100
};
// Healthy: D1: 40-60%, D7: 20-40%, D30: 10-20%

// Lifetime Value
const avgLifetime = 1 / (1 - retention.d30/100);
const ltv = arpu * avgLifetime;
// Healthy: LTV > 3x CAC
// Warning: LTV < 1.5x CAC

// Churn Rate
const churnRate = 1 - (retainedUsers / totalUsers);
// Healthy: <5% monthly
// Warning: >15% monthly
```

---

## 8. Implementation in Oikono

### Update GameRegistryV2 Templates

```solidity
// RPG Template with specific thresholds
MetricTemplate("token_velocity", "uint256", "on_chain", "token", 5, 20, false)
MetricTemplate("gold_inflation", "bps", "calculated", "token", 0, 500, false)
MetricTemplate("win_rate", "bps", "on_chain", "game_logic", 4500, 6500, false)
MetricTemplate("level_speed", "uint256", "calculated", "game_logic", 50, 200, true)
MetricTemplate("sink_source_ratio", "bps", "calculated", "token", 7000, 10000, true)

// Card Game Template
MetricTemplate("pack_ev", "bps", "calculated", "marketplace", 9000, 11000, true)
MetricTemplate("meta_diversity", "bps", "calculated", "game_logic", 6500, 10000, true)
MetricTemplate("collection_rate", "bps", "on_chain", "nft", 3000, 5000, true)

// PvP Template
MetricTemplate("elo_spread", "uint256", "calculated", "game_logic", 1000, 2000, false)
MetricTemplate("queue_time", "duration", "off_chain", "", 0, 30, false)
MetricTemplate("match_balance", "uint256", "calculated", "game_logic", 0, 200, false)
```

### Pattern Detection Rules

```solidity
// RPG Rules
RuleTemplate("spike", "token_velocity", 5000, 1)      // 50% spike
RuleTemplate("drop", "sink_source_ratio", 2000, 1)    // 20% drop
RuleTemplate("trend_up", "gold_inflation", 3000, 7)    // 30% over 7 days

// Card Game Rules
RuleTemplate("drop", "pack_ev", 2000, 1)              // Pack EV dropped 20%
RuleTemplate("drop", "meta_diversity", 1500, 1)       // Meta diversity dropped
RuleTemplate("spike", "card_price_stability", 3000, 1) // Price volatility

// PvP Rules
RuleTemplate("trend_up", "queue_time", 5000, 7)       // Queue time increasing
RuleTemplate("spike", "elo_spread", 2000, 1)          // ELO spread spike
RuleTemplate("drop", "match_balance", 3000, 1)        // Match balance dropped
```

---

## Sources

- https://etonvs.com/crypto/qtm-framework-for-valuing-crypto-tokens/
- https://hold.co/blog/token-velocity
- https://research.despread.io/web3-game-tokenomics/
- https://machinations.io/articles/what-is-game-economy-inflation
- https://learnclash.com/blog/elo-rating-system
- https://en.wikipedia.org/wiki/Elo_rating_system
- https://www.gamedeveloper.com/design/let-s-get-meaningful-about-game-economy-design
- https://a16zcrypto.com/posts/article/web3-game-economy-design/
- https://naavik.co/digest/axie-infinity-economy-deep-dive
- https://www.delphidigital.io/reports/the-world-of-blockchain-gaming/
- https://delphidigital.io/reports/the-gamefi-compendium

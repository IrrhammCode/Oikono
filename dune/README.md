# OIKONO - Dune Analytics Dashboard

Analytics dashboard untuk monitor OIKONO game economy di Somnia Testnet.

## Setup

### 1. Calculate Event Signatures

```bash
cd dune
npm install ethers
node calculate_signatures.js
```

### 2. Create Dune Dashboard

1. Buka [dune.com](https://dune.com)
2. Connect wallet
3. Create New Dashboard
4. Add queries satu per satu

## Contract Addresses (Somnia Testnet)

| Contract | Address |
|----------|---------|
| GameRegistry | `0xce4a2319855968E0Bd6E1826f7A8a08e24a34f53` |
| MetricsRegistry | `0x05fF035dc85f6b33D08af7ce202efaD245C8eE85` |
| PatternDetector | `0xB0dE1515787cB8809D4bAfecaA8523CC943F71eE` |
| SuggestionEngine | `0xF2162A45c05cEB6db4CE8b2Bf3B576b328269a8B` |
| OikonoAgent | `0x8B32e8C3Be192d37C79fAF14BEf0dbE6452153B2` |

## SQL Queries

### Query 1: Games Registered

```sql
-- Track all games registered
SELECT
    block_time,
    CAST(bytearray_to_uint256(SUBSTRING(topic1, 1, 32)) AS INT) AS game_id,
    CONCAT('0x', SUBSTRING(topic2, 13, 20)) AS game_address,
    CONCAT('0x', SUBSTRING(topic3, 13, 20)) AS owner
FROM ethereum.somnia_testnet.logs
WHERE contract_address = 0xce4a2319855968E0Bd6E1826f7A8a08e24a34f53
    AND topic0 = 0x<GameRegistered_signature>
ORDER BY block_time DESC;
```

### Query 2: Metrics Recorded

```sql
-- Track all metrics recorded
SELECT
    block_time,
    CAST(bytearray_to_uint256(SUBSTRING(topic1, 1, 32)) AS INT) AS game_id,
    VARBINARY_TO_STRING(SUBSTRING(data, 1, 32)) AS metric_name,
    CAST(bytearray_to_uint256(SUBSTRING(data, 33, 32)) AS INT) AS value,
    CAST(bytearray_to_uint256(SUBSTRING(data, 65, 32)) AS INT) AS timestamp
FROM ethereum.somnia_testnet.logs
WHERE contract_address = 0x05fF035dc85f6b33D08af7ce202efaD245C8eE85
    AND topic0 = 0x<MetricRecorded_signature>
ORDER BY block_time DESC;
```

### Query 3: Patterns Detected

```sql
-- Track all patterns detected
SELECT
    block_time,
    CAST(bytearray_to_uint256(SUBSTRING(topic1, 1, 32)) AS INT) AS game_id,
    CAST(bytearray_to_uint256(SUBSTRING(topic2, 1, 32)) AS INT) AS pattern_id,
    VARBINARY_TO_STRING(SUBSTRING(data, 1, 32)) AS pattern_type,
    VARBINARY_TO_STRING(SUBSTRING(data, 33, 32)) AS description,
    CAST(bytearray_to_uint256(SUBSTRING(data, 65, 32)) AS INT) AS severity
FROM ethereum.somnia_testnet.logs
WHERE contract_address = 0xB0dE1515787cB8809D4bAfecaA8523CC943F71eE
    AND topic0 = 0x<PatternDetected_signature>
ORDER BY block_time DESC;
```

### Query 4: Suggestions Generated

```sql
-- Track all suggestions generated
SELECT
    block_time,
    CAST(bytearray_to_uint256(SUBSTRING(topic1, 1, 32)) AS INT) AS game_id,
    CAST(bytearray_to_uint256(SUBSTRING(topic2, 1, 32)) AS INT) AS suggestion_id,
    VARBINARY_TO_STRING(SUBSTRING(data, 1, 32)) AS category,
    VARBINARY_TO_STRING(SUBSTRING(data, 33, 32)) AS priority,
    VARBINARY_TO_STRING(SUBSTRING(data, 65, 32)) AS description
FROM ethereum.somnia_testnet.logs
WHERE contract_address = 0xF2162A45c05cEB6db4CE8b2Bf3B576b328269a8B
    AND topic0 = 0x<SuggestionCreated_signature>
ORDER BY block_time DESC;
```

### Query 5: Agent Decisions

```sql
-- Track all agent decisions
SELECT
    block_time,
    CAST(bytearray_to_uint256(SUBSTRING(topic1, 1, 32)) AS INT) AS decision_id,
    CONCAT('0x', SUBSTRING(topic2, 13, 20)) AS game_address,
    VARBINARY_TO_STRING(SUBSTRING(data, 1, 32)) AS decision_type,
    VARBINARY_TO_STRING(SUBSTRING(data, 33, 32)) AS action,
    CASE WHEN bytearray_to_uint256(SUBSTRING(data, 65, 32)) = 1 THEN true ELSE false END AS success
FROM ethereum.somnia_testnet.logs
WHERE contract_address = 0x8B32e8C3Be192d37C79fAF14BEf0dbE6452153B2
    AND topic0 = 0x<DecisionExecuted_signature>
ORDER BY block_time DESC;
```

### Query 6: Daily Summary

```sql
-- Daily summary of all activities
SELECT
    DATE(block_time) AS date,
    COUNT(*) AS total_events,
    COUNT(DISTINCT CONCAT('0x', SUBSTRING(topic1, 13, 20))) AS unique_games
FROM ethereum.somnia_testnet.logs
WHERE contract_address IN (
    0xce4a2319855968E0Bd6E1826f7A8a08e24a34f53,  -- GameRegistry
    0x05fF035dc85f6b33D08af7ce202efaD245C8eE85,  -- MetricsRegistry
    0xB0dE1515787cB8809D4bAfecaA8523CC943F71eE,  -- PatternDetector
    0xF2162A45c05cEB6db4CE8b2Bf3B576b328269a8B   -- SuggestionEngine
)
GROUP BY DATE(block_time)
ORDER BY date DESC;
```

### Query 7: Game Type Distribution

```sql
-- Distribution of game types
SELECT
    VARBINARY_TO_STRING(SUBSTRING(data, 33, 32)) AS game_type,
    COUNT(*) AS game_count
FROM ethereum.somnia_testnet.logs
WHERE contract_address = 0xce4a2319855968E0Bd6E1826f7A8a08e24a34f53
    AND topic0 = 0x<GameRegistered_signature>
GROUP BY game_type
ORDER BY game_count DESC;
```

### Query 8: Pattern Severity Distribution

```sql
-- Distribution of pattern severities
SELECT
    CAST(bytearray_to_uint256(SUBSTRING(data, 65, 32)) AS INT) AS severity,
    COUNT(*) AS pattern_count
FROM ethereum.somnia_testnet.logs
WHERE contract_address = 0xB0dE1515787cB8809D4bAfecaA8523CC943F71eE
    AND topic0 = 0x<PatternDetected_signature>
GROUP BY severity
ORDER BY severity DESC;
```

### Query 9: Suggestion Categories

```sql
-- Distribution of suggestion categories
SELECT
    VARBINARY_TO_STRING(SUBSTRING(data, 1, 32)) AS category,
    COUNT(*) AS suggestion_count
FROM ethereum.somnia_testnet.logs
WHERE contract_address = 0xF2162A45c05cEB6db4CE8b2Bf3B576b328269a8B
    AND topic0 = 0x<SuggestionCreated_signature>
GROUP BY category
ORDER BY suggestion_count DESC;
```

### Query 10: Agent Success Rate

```sql
-- Agent decision success rate
SELECT
    CASE WHEN bytearray_to_uint256(SUBSTRING(data, 65, 32)) = 1 THEN 'Success' ELSE 'Failed' END AS result,
    COUNT(*) AS decision_count,
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS percentage
FROM ethereum.somnia_testnet.logs
WHERE contract_address = 0x8B32e8C3Be192d37C79fAF14BEf0dbE6452153B2
    AND topic0 = 0x<DecisionExecuted_signature>
GROUP BY result;
```

## Dashboard Widgets

### Widget 1: Total Games
```sql
SELECT COUNT(*) AS total_games
FROM ethereum.somnia_testnet.logs
WHERE contract_address = 0xce4a2319855968E0Bd6E1826f7A8a08e24a34f53
    AND topic0 = 0x<GameRegistered_signature>;
```

### Widget 2: Total Metrics Recorded
```sql
SELECT COUNT(*) AS total_metrics
FROM ethereum.somnia_testnet.logs
WHERE contract_address = 0x05fF035dc85f6b33D08af7ce202efaD245C8eE85
    AND topic0 = 0x<MetricRecorded_signature>;
```

### Widget 3: Total Patterns Detected
```sql
SELECT COUNT(*) AS total_patterns
FROM ethereum.somnia_testnet.logs
WHERE contract_address = 0xB0dE1515787cB8809D4bAfecaA8523CC943F71eE
    AND topic0 = 0x<PatternDetected_signature>;
```

### Widget 4: Total Suggestions
```sql
SELECT COUNT(*) AS total_suggestions
FROM ethereum.somnia_testnet.logs
WHERE contract_address = 0xF2162A45c05cEB6db4CE8b2Bf3B576b328269a8B
    AND topic0 = 0x<SuggestionCreated_signature>;
```

### Widget 5: Activity Over Time
```sql
SELECT
    DATE(block_time) AS date,
    COUNT(*) AS events
FROM ethereum.somnia_testnet.logs
WHERE contract_address IN (
    0xce4a2319855968E0Bd6E1826f7A8a08e24a34f53,
    0x05fF035dc85f6b33D08af7ce202efaD245C8eE85,
    0xB0dE1515787cB8809D4bAfecaA8523CC943F71eE,
    0xF2162A45c05cEB6db4CE8b2Bf3B576b328269a8B
)
GROUP BY DATE(block_time)
ORDER BY date DESC
LIMIT 30;
```

## Integration with Frontend

Tambahkan di `frontend/app.js`:

```javascript
// Fetch data from Dune
async function fetchDuneData(queryId) {
  const response = await fetch(
    `https://api.dune.com/api/v1/query/${queryId}/results`,
    {
      headers: {
        'X-Dune-API-Key': 'YOUR_API_KEY'
      }
    }
  );
  return response.json();
}

// Update dashboard with Dune data
async function updateDashboardFromDune() {
  const gamesData = await fetchDuneData(GAMES_QUERY_ID);
  const metricsData = await fetchDuneData(METRICS_QUERY_ID);

  // Update UI
  document.getElementById('statGames').textContent = gamesData.result.rows[0].total_games;
  document.getElementById('statMetrics').textContent = metricsData.result.rows[0].total_metrics;
}
```

## Notes

- Somnia Testnet mungkin belum support di Dune secara native
- Bisa pakai Flipside atau Footprint sebagai alternatif
- Event signatures perlu di-update setelah deploy contract baru

# OIKONO Subgraph

The Graph subgraph untuk index OIKONO game economy events.

## Setup

```bash
cd subgraph
npm install
```

## Generate Code

```bash
npm run codegen
```

## Build

```bash
npm run build
```

## Deploy

### Local (Graph Node)
```bash
# Start local Graph Node
docker-compose up -d

# Create subgraph
npm run create-local

# Deploy
npm run deploy:local
```

### The Graph Studio
```bash
# Login to The Graph Studio
graph auth --studio <DEPLOY_KEY>

# Deploy
npm run deploy
```

## Contract Addresses (Somnia Testnet)

| Contract | Address |
|----------|---------|
| GameRegistry | `0xce4a2319855968E0Bd6E1826f7A8a08e24a34f53` |
| MetricsRegistry | `0x05fF035dc85f6b33D08af7ce202efaD245C8eE85` |
| PatternDetector | `0xB0dE1515787cB8809D4bAfecaA8523CC943F71eE` |
| SuggestionEngine | `0xF2162A45c05cEB6db4CE8b2Bf3B576b328269a8B` |
| OikonoAgent | `0x8B32e8C3Be192d37C79fAF14BEf0dbE6452153B2` |

## GraphQL Queries

### Get all games
```graphql
{
  games(orderBy: registeredAt, orderDirection: desc) {
    id
    name
    gameType
    isActive
    totalEvents
    totalActions
  }
}
```

### Get metrics for a game
```graphql
{
  metrics(where: { game: "1" }) {
    name
    latest
    min
    max
    avg
    count
  }
}
```

### Get patterns for a game
```graphql
{
  patterns(where: { game: "1" }, orderBy: detectedAt, orderDirection: desc) {
    patternType
    description
    severity
    detectedAt
  }
}
```

### Get suggestions for a game
```graphql
{
  suggestions(where: { game: "1" }, orderBy: createdAt, orderDirection: desc) {
    category
    priority
    description
    implemented
  }
}
```

### Get LLM requests
```graphql
{
  lLMRequests(orderBy: sentAt, orderDirection: desc, first: 10) {
    requestId
    game
    decisionType
    promptSummary
    processed
    action
    success
  }
}
```

### Get daily stats
```graphql
{
  dailyStats(orderBy: date, orderDirection: desc, first: 30) {
    date
    totalGames
    totalMetrics
    totalPatterns
    totalSuggestions
    totalDecisions
    totalLLMRequests
  }
}
```

### Get game type distribution
```graphql
{
  gameTypeStats(orderBy: gameCount, orderDirection: desc) {
    gameType
    gameCount
    totalMetrics
    totalPatterns
  }
}
```

## Integration with Frontend

```javascript
// Fetch data from subgraph
const SUBGRAPH_URL = 'https://api.studio.thegraph.com/query/oikono/oikono-subgraph/version/latest';

async function querySubgraph(query) {
  const response = await fetch(SUBGRAPH_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ query }),
  });
  const data = await response.json();
  return data.data;
}

// Example: Get all games
const { games } = await querySubgraph(`{
  games(orderBy: registeredAt, orderDirection: desc) {
    id
    name
    gameType
    isActive
  }
}`);
```

## Entities

| Entity | Description |
|--------|-------------|
| **Game** | Registered game with stats |
| **Metric** | Metric definition and stats |
| **MetricValue** | Historical metric values |
| **Pattern** | Detected pattern |
| **Suggestion** | Generated suggestion |
| **Decision** | Agent decision |
| **LLMRequest** | LLM inference request |
| **DailyStats** | Daily aggregate stats |
| **GameTypeStats** | Stats per game type |

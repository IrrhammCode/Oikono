# OIKONO Envio Indexer

Event indexer untuk OIKONO game economy contracts.

## Setup

```bash
cd envio
npm install
```

## Start Indexer

```bash
npm start
```

## Development

```bash
npm run dev
```

## Events Indexed

### GameRegistry
- `GameRegistered` - New game registered

### MetricsRegistry
- `MetricDefined` - New metric defined for game
- `MetricRecorded` - Metric value recorded

### PatternDetector
- `PatternDetected` - Pattern detected in game data

### SuggestionEngine
- `SuggestionCreated` - New suggestion generated
- `SuggestionImplemented` - Suggestion marked as implemented

### OikonoAgent
- `DecisionRequested` - Agent decision requested
- `DecisionExecuted` - Agent decision executed
- `AgentActionTaken` - Agent action taken

## GraphQL Query Examples

### Get all games
```graphql
{
  games {
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
  patterns(where: { game: "1" }) {
    patternType
    description
    severity
    confidence
    detectedAt
  }
}
```

### Get suggestions for a game
```graphql
{
  suggestions(where: { game: "1" }) {
    category
    priority
    description
    implemented
  }
}
```

## Effects

The indexer can trigger external effects:

1. **autoGenerateSuggestion** - Auto-generate suggestions for high-severity patterns
2. **notifyDeveloper** - Notify developers for critical/high priority suggestions

## Integration with Oikono Frontend

The indexed data can be queried via GraphQL from the Oikono frontend:

```javascript
const query = `
  {
    games(where: { owner: "${userAddress}" }) {
      id
      name
      gameType
      metrics {
        name
        latest
      }
      patterns {
        description
        severity
      }
    }
  }
`;

const response = await fetch('http://localhost:8080/graphql', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ query }),
});
```

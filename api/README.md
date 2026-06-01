# OIKONO API Server

Off-chain data collection API untuk OIKONO game economy.

## Setup

```bash
cd api
npm install
```

## Start Server

```bash
npm start
```

## API Endpoints

### Report Metrics
```bash
POST /api/metrics/report

{
  "gameId": "1",
  "metrics": [
    { "name": "retention_d7", "value": 4200 },
    { "name": "avg_session_length", "value": 1800 },
    { "name": "dau", "value": 1500 }
  ],
  "privateKey": "0x..." // Optional: record on-chain
}
```

### Get Metrics
```bash
GET /api/metrics/:gameId
GET /api/metrics/:gameId?metric=retention_d7&limit=100
```

### Detect Patterns
```bash
POST /api/patterns/detect

{
  "gameId": "1",
  "privateKey": "0x..."
}
```

### Generate Suggestions
```bash
POST /api/suggestions/generate

{
  "gameId": "1",
  "privateKey": "0x..."
}
```

### Get Alerts
```bash
GET /api/alerts/:gameId
GET /api/alerts/:gameId?type=high&limit=50
```

### Health Check
```bash
GET /api/health
```

## Example Usage

### JavaScript
```javascript
// Report metrics
const response = await fetch('http://localhost:3001/api/metrics/report', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    gameId: '1',
    metrics: [
      { name: 'retention_d7', value: 4200 },
      { name: 'dau', value: 1500 },
    ],
  }),
});

const data = await response.json();
console.log(data);
```

### cURL
```bash
# Report metrics
curl -X POST http://localhost:3001/api/metrics/report \
  -H "Content-Type: application/json" \
  -d '{"gameId":"1","metrics":[{"name":"retention_d7","value":4200}]}'

# Get metrics
curl http://localhost:3001/api/metrics/1
```

## Integration with Oikono Frontend

```javascript
// In frontend/app.js
async function reportOffChainMetrics(gameId, metrics) {
  const response = await fetch('http://localhost:3001/api/metrics/report', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ gameId, metrics }),
  });
  return response.json();
}
```

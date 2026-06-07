/**
 * OIKONO - Off-Chain Data Collection API
 *
 * Allows games to report metrics that can't be collected from on-chain events.
 * Examples: retention, session length, DAU/MAU, etc.
 */

const express = require('express');
const cors = require('cors');
const { ethers } = require('ethers');

const app = express();
const PORT = process.env.API_PORT || 3001;

// Middleware
app.use(cors());
app.use(express.json());

// ═══════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════

const CONFIG = {
  // Somnia Testnet
  RPC_URL: 'https://dream-rpc.somnia.network',
  CHAIN_ID: 50312,

  // Contract addresses
  METRICS_REGISTRY: '0x5F447735f4A7DEc10F1dA55cbf05688D4A2bD808',
  PATTERN_DETECTOR: '0x655Cd724318C38284B984A7629EFe05dE57F29eD',
  SUGGESTION_ENGINE: '0xe43c42e639170e5c88c2Ae242330473cf5745f8c',
};

// Contract ABIs (minimal)
const METRICS_ABI = [
  'function recordMetric(uint256 gameId, string name, uint256 value) external',
  'function recordMetrics(uint256 gameId, string[] names, uint256[] values) external',
  'function getLatest(uint256 gameId, string name) external view returns (uint256)',
];

const PATTERN_ABI = [
  'function detectPatterns(uint256 gameId) external',
];

const SUGGESTION_ABI = [
  'function generateSuggestions(uint256 gameId) external',
];

// ═══════════════════════════════════════════════
// IN-MEMORY STORAGE (for demo, use database in production)
// ═══════════════════════════════════════════════

const metricStore = {};  // gameId -> { metricName -> [values] }
const alertStore = [];   // [{ gameId, metricName, value, timestamp, type }]

// ═══════════════════════════════════════════════
// API ENDPOINTS
// ═══════════════════════════════════════════════

/**
 * POST /api/metrics/report
 * Report off-chain metrics for a game
 */
app.post('/api/metrics/report', async (req, res) => {
  try {
    const { gameId, metrics, privateKey } = req.body;

    if (!gameId || !metrics || !Array.isArray(metrics)) {
      return res.status(400).json({ error: 'Invalid request. Need gameId and metrics array.' });
    }

    // Validate metrics format
    for (const metric of metrics) {
      if (!metric.name || metric.value === undefined) {
        return res.status(400).json({ error: 'Each metric needs name and value.' });
      }
    }

    // Store in memory
    if (!metricStore[gameId]) {
      metricStore[gameId] = {};
    }

    const timestamp = Date.now();
    const results = [];

    for (const metric of metrics) {
      if (!metricStore[gameId][metric.name]) {
        metricStore[gameId][metric.name] = [];
      }

      metricStore[gameId][metric.name].push({
        value: metric.value,
        timestamp: timestamp,
      });

      // Keep only last 1000 values
      if (metricStore[gameId][metric.name].length > 1000) {
        metricStore[gameId][metric.name] = metricStore[gameId][metric.name].slice(-1000);
      }

      results.push({
        name: metric.name,
        value: metric.value,
        recorded: true,
      });

      // Check for alerts
      checkForAlerts(gameId, metric.name, metric.value);
    }

    // Optional: Record on-chain if private key provided
    if (privateKey) {
      try {
        const provider = new ethers.JsonRpcProvider(CONFIG.RPC_URL);
        const wallet = new ethers.Wallet(privateKey, provider);
        const metricsContract = new ethers.Contract(
          CONFIG.METRICS_REGISTRY,
          METRICS_ABI,
          wallet
        );

        const names = metrics.map(m => m.name);
        const values = metrics.map(m => BigInt(m.value));

        const tx = await metricsContract.recordMetrics(gameId, names, values);
        await tx.wait();

        results.forEach(r => r.onChainTx = tx.hash);
      } catch (err) {
        console.error('On-chain recording failed:', err.message);
        results.forEach(r => r.onChainError = err.message);
      }
    }

    res.json({
      success: true,
      gameId: gameId,
      metrics: results,
      timestamp: timestamp,
    });

  } catch (err) {
    console.error('Error reporting metrics:', err);
    res.status(500).json({ error: err.message });
  }
});

/**
 * GET /api/metrics/:gameId
 * Get reported metrics for a game
 */
app.get('/api/metrics/:gameId', (req, res) => {
  const { gameId } = req.params;
  const { metric, limit } = req.query;

  if (!metricStore[gameId]) {
    return res.json({ gameId, metrics: {} });
  }

  if (metric) {
    // Get specific metric
    const values = metricStore[gameId][metric] || [];
    const limitNum = parseInt(limit) || 100;
    return res.json({
      gameId,
      metric,
      values: values.slice(-limitNum),
    });
  }

  // Get all metrics summary
  const summary = {};
  for (const [name, values] of Object.entries(metricStore[gameId])) {
    const recent = values.slice(-100);
    summary[name] = {
      count: values.length,
      latest: values[values.length - 1]?.value,
      min: Math.min(...recent.map(v => v.value)),
      max: Math.max(...recent.map(v => v.value)),
      avg: recent.reduce((sum, v) => sum + v.value, 0) / recent.length,
    };
  }

  res.json({ gameId, metrics: summary });
});

/**
 * POST /api/patterns/detect
 * Trigger pattern detection for a game
 */
app.post('/api/patterns/detect', async (req, res) => {
  try {
    const { gameId, privateKey } = req.body;

    if (!gameId || !privateKey) {
      return res.status(400).json({ error: 'Need gameId and privateKey.' });
    }

    const provider = new ethers.JsonRpcProvider(CONFIG.RPC_URL);
    const wallet = new ethers.Wallet(privateKey, provider);
    const patternContract = new ethers.Contract(
      CONFIG.PATTERN_DETECTOR,
      PATTERN_ABI,
      wallet
    );

    const tx = await patternContract.detectPatterns(gameId);
    await tx.wait();

    res.json({
      success: true,
      gameId: gameId,
      txHash: tx.hash,
    });

  } catch (err) {
    console.error('Error detecting patterns:', err);
    res.status(500).json({ error: err.message });
  }
});

/**
 * POST /api/suggestions/generate
 * Generate suggestions for a game
 */
app.post('/api/suggestions/generate', async (req, res) => {
  try {
    const { gameId, privateKey } = req.body;

    if (!gameId || !privateKey) {
      return res.status(400).json({ error: 'Need gameId and privateKey.' });
    }

    const provider = new ethers.JsonRpcProvider(CONFIG.RPC_URL);
    const wallet = new ethers.Wallet(privateKey, provider);
    const suggestionContract = new ethers.Contract(
      CONFIG.SUGGESTION_ENGINE,
      SUGGESTION_ABI,
      wallet
    );

    const tx = await suggestionContract.generateSuggestions(gameId);
    await tx.wait();

    res.json({
      success: true,
      gameId: gameId,
      txHash: tx.hash,
    });

  } catch (err) {
    console.error('Error generating suggestions:', err);
    res.status(500).json({ error: err.message });
  }
});

/**
 * GET /api/alerts/:gameId
 * Get alerts for a game
 */
app.get('/api/alerts/:gameId', (req, res) => {
  const { gameId } = req.params;
  const { type, limit } = req.query;

  let alerts = alertStore.filter(a => a.gameId === gameId);

  if (type) {
    alerts = alerts.filter(a => a.type === type);
  }

  const limitNum = parseInt(limit) || 50;
  alerts = alerts.slice(-limitNum);

  res.json({ gameId, alerts });
});

/**
 * GET /api/health
 * Health check endpoint
 */
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: Date.now(),
    uptime: process.uptime(),
  });
});

// ═══════════════════════════════════════════════
// ALERT SYSTEM
// ═══════════════════════════════════════════════

function checkForAlerts(gameId, metricName, value) {
  // Define alert thresholds
  const thresholds = {
    win_rate: { low: 3000, high: 7000 },      // 30-70% is healthy
    retention_d7: { low: 2000, high: 6000 },   // 20-60% is healthy
    token_velocity: { low: 0, high: 50000 },    // 0-50000 is healthy
  };

  const threshold = thresholds[metricName];
  if (!threshold) return;

  let alertType = null;
  if (value < threshold.low) {
    alertType = 'low';
  } else if (value > threshold.high) {
    alertType = 'high';
  }

  if (alertType) {
    alertStore.push({
      gameId,
      metricName,
      value,
      timestamp: Date.now(),
      type: alertType,
      message: `${metricName} is ${alertType}: ${value} (healthy: ${threshold.low}-${threshold.high})`,
    });

    // Keep only last 1000 alerts
    if (alertStore.length > 1000) {
      alertStore.splice(0, alertStore.length - 1000);
    }
  }
}

// ═══════════════════════════════════════════════
// START SERVER
// ═══════════════════════════════════════════════

app.listen(PORT, () => {
  console.log(`OIKONO API Server running on port ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/api/health`);
});

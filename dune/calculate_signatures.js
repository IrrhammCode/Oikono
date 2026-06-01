/**
 * Calculate Event Signatures for Dune Analytics
 * Run: node calculate_signatures.js
 */

const { ethers } = require('ethers');

// Event definitions
const events = [
  // GameRegistry
  'GameRegistered(uint256 indexed gameId, address indexed gameAddress, address indexed owner, string name, string gameType)',

  // MetricsRegistry
  'MetricDefined(uint256 indexed gameId, string metricName, string dataType, string source)',
  'MetricRecorded(uint256 indexed gameId, string metricName, uint256 value, uint256 timestamp)',

  // PatternDetector
  'PatternDetected(uint256 indexed gameId, uint256 indexed patternId, string patternType, string description, uint256 severity)',

  // SuggestionEngine
  'SuggestionCreated(uint256 indexed gameId, uint256 indexed suggestionId, string category, string priority, string description)',
  'SuggestionImplemented(uint256 indexed gameId, uint256 indexed suggestionId, uint256 implementedAt)',
  'OutcomeRecorded(uint256 indexed suggestionId, bool success, uint256 impact)',

  // OikonoAgent
  'DecisionRequested(uint256 indexed decisionId, address indexed game, string decisionType, string promptSummary)',
  'DecisionExecuted(uint256 indexed decisionId, address indexed game, string action, bool success)',
  'AgentActionTaken(address indexed game, string actionType, string description)',
];

console.log('OIKONO Event Signatures for Dune Analytics');
console.log('==========================================\n');

events.forEach(event => {
  const signature = ethers.id(event);
  const name = event.split('(')[0];
  console.log(`${name}:`);
  console.log(`  ${signature}`);
  console.log('');
});

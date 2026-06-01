import {
  MetricsRegistry,
  PatternDetector,
  SuggestionEngine,
  GameRegistry,
  OikonoAgent,
} from "generated";

// ═══════════════════════════════════════════════
// GAME REGISTRY EVENTS
// ═══════════════════════════════════════════════

GameRegistry.GameRegistered.handler(async ({ event, context }) => {
  const { gameId, gameAddress, owner, name, gameType } = event.params;

  // Create or update game entity
  const game: Game = {
    id: gameId.toString(),
    gameId: gameId,
    gameAddress: gameAddress,
    owner: owner,
    name: name,
    gameType: gameType,
    isActive: true,
    isVerified: false,
    registeredAt: event.block.timestamp,
    lastActivity: event.block.timestamp,
    totalEvents: 0n,
    totalActions: 0n,
  };

  context.Game.set(game);

  // Update daily stats
  await updateDailyStats(context, event.block.timestamp);

  // Update game type stats
  await updateGameTypeStats(context, gameType);
});

// ═══════════════════════════════════════════════
// METRICS REGISTRY EVENTS
// ═══════════════════════════════════════════════

MetricsRegistry.MetricDefined.handler(async ({ event, context }) => {
  const { gameId, metricName, dataType, source } = event.params;

  // Create metric entity
  const metric: Metric = {
    id: `${gameId}-${metricName}`,
    game: gameId.toString(),
    name: metricName,
    dataType: dataType,
    source: source,
    latest: 0n,
    min: 0n,
    max: 0n,
    avg: 0n,
    count: 0n,
    lastUpdated: event.block.timestamp,
  };

  context.Metric.set(metric);

  // Update game last activity
  const game = await context.Game.get(gameId.toString());
  if (game) {
    context.Game.set({
      ...game,
      lastActivity: event.block.timestamp,
    });
  }
});

MetricsRegistry.MetricRecorded.handler(async ({ event, context }) => {
  const { gameId, metricName, value, timestamp } = event.params;

  const metricId = `${gameId}-${metricName}`;
  const metric = await context.Metric.get(metricId);

  if (metric) {
    // Update metric stats
    const newCount = metric.count + 1n;
    const newMin = metric.min === 0n ? value : (value < metric.min ? value : metric.min);
    const newMax = value > metric.max ? value : metric.max;
    const newAvg = (metric.avg * metric.count + value) / newCount;

    context.Metric.set({
      ...metric,
      latest: value,
      min: newMin,
      max: newMax,
      avg: newAvg,
      count: newCount,
      lastUpdated: timestamp,
    });

    // Create metric value history
    const metricValue: MetricValue = {
      id: `${metricId}-${timestamp}`,
      metric: metricId,
      value: value,
      timestamp: timestamp,
      blockNumber: event.block.number,
    };

    context.MetricValue.set(metricValue);

    // Update game last activity
    const game = await context.Game.get(gameId.toString());
    if (game) {
      context.Game.set({
        ...game,
        lastActivity: timestamp,
        totalEvents: game.totalEvents + 1n,
      });
    }
  }
});

// ═══════════════════════════════════════════════
// PATTERN DETECTOR EVENTS
// ═══════════════════════════════════════════════

PatternDetector.PatternDetected.handler(async ({ event, context }) => {
  const { gameId, patternId, patternType, description, severity } = event.params;

  const pattern: Pattern = {
    id: `${gameId}-${patternId}`,
    game: gameId.toString(),
    patternId: patternId,
    patternType: patternType,
    metricName: "", // Will be updated from contract
    description: description,
    severity: severity,
    confidence: 0n, // Will be updated from contract
    detectedAt: event.block.timestamp,
    isActive: true,
  };

  context.Pattern.set(pattern);

  // Update game last activity
  const game = await context.Game.get(gameId.toString());
  if (game) {
    context.Game.set({
      ...game,
      lastActivity: event.block.timestamp,
    });
  }

  // Auto-generate suggestion for high severity patterns
  if (severity >= 7n) {
    await context.effect("autoGenerateSuggestion", {
      gameId: gameId.toString(),
      patternId: patternId.toString(),
      severity: severity,
    });
  }
});

// ═══════════════════════════════════════════════
// SUGGESTION ENGINE EVENTS
// ═══════════════════════════════════════════════

SuggestionEngine.SuggestionCreated.handler(async ({ event, context }) => {
  const { gameId, suggestionId, category, priority, description } = event.params;

  const suggestion: Suggestion = {
    id: `${gameId}-${suggestionId}`,
    game: gameId.toString(),
    suggestionId: suggestionId,
    category: category,
    priority: priority,
    description: description,
    action: "", // Will be updated from contract
    confidence: 0n, // Will be updated from contract
    expectedImpact: 0n, // Will be updated from contract
    implemented: false,
    createdAt: event.block.timestamp,
  };

  context.Suggestion.set(suggestion);

  // Update game last activity
  const game = await context.Game.get(gameId.toString());
  if (game) {
    context.Game.set({
      ...game,
      lastActivity: event.block.timestamp,
    });
  }

  // Notify developer for high priority suggestions
  if (priority === "critical" || priority === "high") {
    await context.effect("notifyDeveloper", {
      gameId: gameId.toString(),
      suggestionId: suggestionId.toString(),
      priority: priority,
      description: description,
    });
  }
});

SuggestionEngine.SuggestionImplemented.handler(async ({ event, context }) => {
  const { gameId, suggestionId, implementedAt } = event.params;

  const suggestionIdStr = `${gameId}-${suggestionId}`;
  const suggestion = await context.Suggestion.get(suggestionIdStr);

  if (suggestion) {
    context.Suggestion.set({
      ...suggestion,
      implemented: true,
      implementedAt: implementedAt,
    });

    // Update game stats
    const game = await context.Game.get(gameId.toString());
    if (game) {
      context.Game.set({
        ...game,
        totalActions: game.totalActions + 1n,
        lastActivity: implementedAt,
      });
    }
  }
});

// ═══════════════════════════════════════════════
// OIKONO AGENT EVENTS
// ═══════════════════════════════════════════════

OikonoAgent.DecisionRequested.handler(async ({ event, context }) => {
  const { decisionId, game, decisionType, promptSummary } = event.params;

  // Store decision request
  // Note: We'll update with full details when DecisionExecuted fires
});

OikonoAgent.DecisionExecuted.handler(async ({ event, context }) => {
  const { decisionId, game, action, success } = event.params;

  const decision: Decision = {
    id: decisionId.toString(),
    game: game.toString(),
    decisionId: decisionId,
    decisionType: "", // Will be updated from request
    action: action,
    success: success,
    executedAt: event.block.timestamp,
  };

  context.Decision.set(decision);

  // Update game stats
  const gameEntity = await context.Game.get(game.toString());
  if (gameEntity) {
    context.Game.set({
      ...gameEntity,
      totalActions: gameEntity.totalActions + 1n,
      lastActivity: event.block.timestamp,
    });
  }
});

OikonoAgent.AgentActionTaken.handler(async ({ event, context }) => {
  const { game, actionType, description } = event.params;

  // Log action for analytics
  // Could trigger additional effects based on action type
});

// ═══════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════

async function updateDailyStats(context: any, timestamp: bigint) {
  const date = new Date(Number(timestamp) * 1000).toISOString().split("T")[0];
  const existing = await context.DailyStats.get(date);

  if (existing) {
    context.DailyStats.set({
      ...existing,
      totalGames: existing.totalGames + 1n,
    });
  } else {
    context.DailyStats.set({
      id: date,
      date: date,
      totalGames: 1n,
      totalMetrics: 0n,
      totalPatterns: 0n,
      totalSuggestions: 0n,
      totalDecisions: 0n,
    });
  }
}

async function updateGameTypeStats(context: any, gameType: string) {
  const existing = await context.GameTypeStats.get(gameType);

  if (existing) {
    context.GameTypeStats.set({
      ...existing,
      gameCount: existing.gameCount + 1n,
    });
  } else {
    context.GameTypeStats.set({
      id: gameType,
      gameType: gameType,
      gameCount: 1n,
      totalMetrics: 0n,
      totalPatterns: 0n,
      avgSuccessRate: 0n,
    });
  }
}

// ═══════════════════════════════════════════════
// EFFECTS (External Actions)
// ═══════════════════════════════════════════════

// These effects can trigger external actions like:
// - Sending notifications
// - Calling other contracts
// - Updating external databases
// - Sending emails/Slack messages

export const effects = {
  autoGenerateSuggestion: async (params: {
    gameId: string;
    patternId: string;
    severity: bigint;
  }) => {
    console.log(
      `Auto-generating suggestion for game ${params.gameId}, pattern ${params.patternId}`
    );
    // Could call SuggestionEngine.generateSuggestions() here
  },

  notifyDeveloper: async (params: {
    gameId: string;
    suggestionId: string;
    priority: string;
    description: string;
  }) => {
    console.log(
      `Notifying developer: ${params.priority} suggestion for game ${params.gameId}`
    );
    // Could send email, Slack, Discord notification here
  },
};

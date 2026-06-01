import { BigInt, Bytes, log } from "@graphprotocol/graph-ts";
import {
  GameRegistered,
  MetricDefined,
  MetricRecorded,
  PatternDetected,
  SuggestionCreated,
  SuggestionImplemented,
  DecisionRequested,
  DecisionExecuted,
  AgentActionTaken,
  LLMRequestSent,
  LLMResponseReceived,
} from "../generated/schema";

// ═══════════════════════════════════════════════
// GAME REGISTRY EVENTS
// ═══════════════════════════════════════════════

export function handleGameRegistered(event: GameRegistered): void {
  let game = new Game(event.params.gameId.toString());
  game.gameId = event.params.gameId;
  game.gameAddress = event.params.gameAddress;
  game.owner = event.params.owner;
  game.name = event.params.name;
  game.gameType = event.params.gameType;
  game.isActive = true;
  game.isVerified = false;
  game.registeredAt = event.block.timestamp;
  game.lastActivity = event.block.timestamp;
  game.totalEvents = BigInt.fromI32(0);
  game.totalActions = BigInt.fromI32(0);
  game.save();

  // Update daily stats
  let date = event.block.timestamp.toI32() / 86400;
  let dailyStats = DailyStats.load(date.toString());
  if (dailyStats == null) {
    dailyStats = new DailyStats(date.toString());
    dailyStats.date = new Date(event.block.timestamp.toI32() * 1000)
      .toISOString()
      .split("T")[0];
    dailyStats.totalGames = BigInt.fromI32(0);
    dailyStats.totalMetrics = BigInt.fromI32(0);
    dailyStats.totalPatterns = BigInt.fromI32(0);
    dailyStats.totalSuggestions = BigInt.fromI32(0);
    dailyStats.totalDecisions = BigInt.fromI32(0);
    dailyStats.totalLLMRequests = BigInt.fromI32(0);
  }
  dailyStats.totalGames = dailyStats.totalGames.plus(BigInt.fromI32(1));
  dailyStats.save();

  // Update game type stats
  let gameTypeStats = GameTypeStats.load(event.params.gameType);
  if (gameTypeStats == null) {
    gameTypeStats = new GameTypeStats(event.params.gameType);
    gameTypeStats.gameType = event.params.gameType;
    gameTypeStats.gameCount = BigInt.fromI32(0);
    gameTypeStats.totalMetrics = BigInt.fromI32(0);
    gameTypeStats.totalPatterns = BigInt.fromI32(0);
    gameTypeStats.avgSuccessRate = BigInt.fromI32(0);
  }
  gameTypeStats.gameCount = gameTypeStats.gameCount.plus(BigInt.fromI32(1));
  gameTypeStats.save();

  log.info("Game registered: {} - {} ({})", [
    event.params.gameId.toString(),
    event.params.name,
    event.params.gameType,
  ]);
}

// ═══════════════════════════════════════════════
// METRICS REGISTRY EVENTS
// ═══════════════════════════════════════════════

export function handleMetricDefined(event: MetricDefined): void {
  let metricId =
    event.params.gameId.toString() + "-" + event.params.metricName;
  let metric = new Metric(metricId);
  metric.game = event.params.gameId.toString();
  metric.name = event.params.metricName;
  metric.dataType = event.params.dataType;
  metric.source = event.params.source;
  metric.latest = BigInt.fromI32(0);
  metric.min = BigInt.fromI32(0);
  metric.max = BigInt.fromI32(0);
  metric.avg = BigInt.fromI32(0);
  metric.count = BigInt.fromI32(0);
  metric.lastUpdated = event.block.timestamp;
  metric.save();

  // Update game last activity
  let game = Game.load(event.params.gameId.toString());
  if (game != null) {
    game.lastActivity = event.block.timestamp;
    game.save();
  }

  log.info("Metric defined: {} for game {}", [
    event.params.metricName,
    event.params.gameId.toString(),
  ]);
}

export function handleMetricRecorded(event: MetricRecorded): void {
  let metricId =
    event.params.gameId.toString() + "-" + event.params.metricName;
  let metric = Metric.load(metricId);

  if (metric != null) {
    // Update metric stats
    let newCount = metric.count.plus(BigInt.fromI32(1));
    let newMin =
      metric.min.equals(BigInt.fromI32(0))
        ? event.params.value
        : event.params.value.lt(metric.min)
          ? event.params.value
          : metric.min;
    let newMax = event.params.value.gt(metric.max)
      ? event.params.value
      : metric.max;
    let newAvg = metric.avg
      .times(metric.count)
      .plus(event.params.value)
      .div(newCount);

    metric.latest = event.params.value;
    metric.min = newMin;
    metric.max = newMax;
    metric.avg = newAvg;
    metric.count = newCount;
    metric.lastUpdated = event.params.timestamp;
    metric.save();

    // Create metric value history
    let metricValueId =
      metricId + "-" + event.params.timestamp.toString();
    let metricValue = new MetricValue(metricValueId);
    metricValue.metric = metricId;
    metricValue.value = event.params.value;
    metricValue.timestamp = event.params.timestamp;
    metricValue.blockNumber = event.block.number;
    metricValue.save();

    // Update game
    let game = Game.load(event.params.gameId.toString());
    if (game != null) {
      game.lastActivity = event.params.timestamp;
      game.totalEvents = game.totalEvents.plus(BigInt.fromI32(1));
      game.save();
    }

    log.info("Metric recorded: {} = {} for game {}", [
      event.params.metricName,
      event.params.value.toString(),
      event.params.gameId.toString(),
    ]);
  }
}

// ═══════════════════════════════════════════════
// PATTERN DETECTOR EVENTS
// ═══════════════════════════════════════════════

export function handlePatternDetected(event: PatternDetected): void {
  let patternId =
    event.params.gameId.toString() + "-" + event.params.patternId.toString();
  let pattern = new Pattern(patternId);
  pattern.game = event.params.gameId.toString();
  pattern.patternId = event.params.patternId;
  pattern.patternType = event.params.patternType;
  pattern.metricName = "";
  pattern.description = event.params.description;
  pattern.severity = event.params.severity;
  pattern.confidence = BigInt.fromI32(0);
  pattern.detectedAt = event.block.timestamp;
  pattern.isActive = true;
  pattern.save();

  // Update game
  let game = Game.load(event.params.gameId.toString());
  if (game != null) {
    game.lastActivity = event.block.timestamp;
    game.save();
  }

  // Update daily stats
  let date = event.block.timestamp.toI32() / 86400;
  let dailyStats = DailyStats.load(date.toString());
  if (dailyStats != null) {
    dailyStats.totalPatterns = dailyStats.totalPatterns.plus(
      BigInt.fromI32(1)
    );
    dailyStats.save();
  }

  log.info("Pattern detected: {} - {} (severity: {})", [
    event.params.patternType,
    event.params.description,
    event.params.severity.toString(),
  ]);
}

// ═══════════════════════════════════════════════
// SUGGESTION ENGINE EVENTS
// ═══════════════════════════════════════════════

export function handleSuggestionCreated(event: SuggestionCreated): void {
  let suggestionId =
    event.params.gameId.toString() +
    "-" +
    event.params.suggestionId.toString();
  let suggestion = new Suggestion(suggestionId);
  suggestion.game = event.params.gameId.toString();
  suggestion.suggestionId = event.params.suggestionId;
  suggestion.category = event.params.category;
  suggestion.priority = event.params.priority;
  suggestion.description = event.params.description;
  suggestion.action = "";
  suggestion.confidence = BigInt.fromI32(0);
  suggestion.expectedImpact = BigInt.fromI32(0);
  suggestion.implemented = false;
  suggestion.createdAt = event.block.timestamp;
  suggestion.save();

  // Update game
  let game = Game.load(event.params.gameId.toString());
  if (game != null) {
    game.lastActivity = event.block.timestamp;
    game.save();
  }

  // Update daily stats
  let date = event.block.timestamp.toI32() / 86400;
  let dailyStats = DailyStats.load(date.toString());
  if (dailyStats != null) {
    dailyStats.totalSuggestions = dailyStats.totalSuggestions.plus(
      BigInt.fromI32(1)
    );
    dailyStats.save();
  }

  log.info("Suggestion created: {} - {} ({})", [
    event.params.category,
    event.params.priority,
    event.params.description,
  ]);
}

export function handleSuggestionImplemented(
  event: SuggestionImplemented
): void {
  let suggestionId =
    event.params.gameId.toString() +
    "-" +
    event.params.suggestionId.toString();
  let suggestion = Suggestion.load(suggestionId);

  if (suggestion != null) {
    suggestion.implemented = true;
    suggestion.implementedAt = event.params.implementedAt;
    suggestion.save();

    // Update game
    let game = Game.load(event.params.gameId.toString());
    if (game != null) {
      game.totalActions = game.totalActions.plus(BigInt.fromI32(1));
      game.lastActivity = event.params.implementedAt;
      game.save();
    }

    log.info("Suggestion implemented: {}", [suggestionId]);
  }
}

// ═══════════════════════════════════════════════
// OIKONO AGENT EVENTS
// ═══════════════════════════════════════════════

export function handleDecisionRequested(event: DecisionRequested): void {
  // Store decision request for later reference
  log.info("Decision requested: {} for game {}", [
    event.params.decisionType,
    event.params.game.toHexString(),
  ]);
}

export function handleDecisionExecuted(event: DecisionExecuted): void {
  let decision = new Decision(event.params.decisionId.toString());
  decision.game = event.params.game.toHexString();
  decision.decisionId = event.params.decisionId;
  decision.decisionType = "";
  decision.action = event.params.action;
  decision.success = event.params.success;
  decision.executedAt = event.block.timestamp;
  decision.save();

  // Update game
  let game = Game.load(event.params.game.toHexString());
  if (game != null) {
    game.totalActions = game.totalActions.plus(BigInt.fromI32(1));
    game.lastActivity = event.block.timestamp;
    game.save();
  }

  // Update daily stats
  let date = event.block.timestamp.toI32() / 86400;
  let dailyStats = DailyStats.load(date.toString());
  if (dailyStats != null) {
    dailyStats.totalDecisions = dailyStats.totalDecisions.plus(
      BigInt.fromI32(1)
    );
    dailyStats.save();
  }

  log.info("Decision executed: {} - {} (success: {})", [
    event.params.decisionId.toString(),
    event.params.action,
    event.params.success.toString(),
  ]);
}

export function handleAgentActionTaken(event: AgentActionTaken): void {
  log.info("Agent action taken: {} - {}", [
    event.params.actionType,
    event.params.description,
  ]);
}

// ═══════════════════════════════════════════════
// LLM INVOKER EVENTS
// ═══════════════════════════════════════════════

export function handleLLMRequestSent(event: LLMRequestSent): void {
  let llmRequest = new LLMRequest(event.params.requestId.toString());
  llmRequest.requestId = event.params.requestId;
  llmRequest.game = event.params.game;
  llmRequest.decisionType = event.params.decisionType;
  llmRequest.promptSummary = event.params.promptSummary;
  llmRequest.sentAt = event.block.timestamp;
  llmRequest.processed = false;
  llmRequest.save();

  // Update daily stats
  let date = event.block.timestamp.toI32() / 86400;
  let dailyStats = DailyStats.load(date.toString());
  if (dailyStats != null) {
    dailyStats.totalLLMRequests = dailyStats.totalLLMRequests.plus(
      BigInt.fromI32(1)
    );
    dailyStats.save();
  }

  log.info("LLM request sent: {} for game {}", [
    event.params.requestId.toString(),
    event.params.game.toHexString(),
  ]);
}

export function handleLLMResponseReceived(
  event: LLMResponseReceived
): void {
  let llmRequest = LLMRequest.load(event.params.requestId.toString());

  if (llmRequest != null) {
    llmRequest.processed = true;
    llmRequest.action = event.params.action;
    llmRequest.success = event.params.success;
    llmRequest.save();

    log.info("LLM response received: {} - {} (success: {})", [
      event.params.requestId.toString(),
      event.params.action,
      event.params.success.toString(),
    ]);
  }
}

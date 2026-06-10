/**
 * WagerVerse Arena - Define metrics and record realistic data
 * Wager/Betting PvP game on OIKONO
 */
const hre = require("hardhat");

const CONTRACTS = {
    GameRegistry: "0x6eB1d23419629901F78947B1207024f7F28380a6",
    MetricsRegistry: "0x5F447735f4A7DEc10F1dA55cbf05688D4A2bD808",
    PatternDetector: "0x655Cd724318C38284B984A7629EFe05dE57F29eD",
    SuggestionEngine: "0xe43c42e639170e5c88c2Ae242330473cf5745f8c",
    WagerVerseArena: "0xd5f3E959b213e1B6811852bB7F4Ea8a5C868e21c",
};

// WagerVerse Arena game type config (from config.js)
const WAGER_METRICS = [
    { name: "wager_volume",      dataType: "uint256", source: "on-chain", healthyMin: 500,  healthyMax: 5000,  isHigherBetter: true,  description: "Daily wager volume (OIK)" },
    { name: "win_rate",          dataType: "uint256", source: "on-chain", healthyMin: 4500, healthyMax: 5500,  isHigherBetter: false, description: "Player win rate (basis points)" },
    { name: "avg_wager_size",    dataType: "uint256", source: "on-chain", healthyMin: 10,   healthyMax: 100,   isHigherBetter: false, description: "Average wager size (OIK)" },
    { name: "payout_ratio",      dataType: "uint256", source: "on-chain", healthyMin: 9000, healthyMax: 9800,  isHigherBetter: true,  description: "Payout to wager ratio (basis points)" },
    { name: "active_players",    dataType: "uint256", source: "on-chain", healthyMin: 20,   healthyMax: 500,   isHigherBetter: true,  description: "Daily active players" },
    { name: "match_queue_time",  dataType: "uint256", source: "on-chain", healthyMin: 5,    healthyMax: 30,    isHigherBetter: false, description: "Avg matchmaking time (seconds)" },
];

const PATTERN_RULES = [
    { ruleType: "spike", metricName: "wager_volume",    threshold: 300, period: 86400 },
    { ruleType: "drop",  metricName: "payout_ratio",    threshold: 10,  period: 86400 },
    { ruleType: "spike", metricName: "win_rate",         threshold: 20,  period: 86400 },
    { ruleType: "drop",  metricName: "active_players",   threshold: 30,  period: 86400 },
];

async function main() {
    const [signer] = await hre.ethers.getSigners();
    console.log("WagerVerse Arena - Metrics Setup");
    console.log("Wallet:", signer.address);
    console.log("");

    const metricsRegistry = await hre.ethers.getContractAt("MetricsRegistry", CONTRACTS.MetricsRegistry);
    const patternDetector = await hre.ethers.getContractAt("PatternDetector", CONTRACTS.PatternDetector);
    const suggestionEngine = await hre.ethers.getContractAt("SuggestionEngine", CONTRACTS.SuggestionEngine);

    // Find WagerVerse Arena game ID
    const gr = await hre.ethers.getContractAt("GameRegistry", CONTRACTS.GameRegistry);
    let gameId = 0;
    try {
        gameId = await gr.gameByAddress(CONTRACTS.WagerVerseArena);
        console.log("WagerVerse Arena Game ID:", Number(gameId));
    } catch (e) {
        console.log("Could not find game ID, using first available");
        gameId = 1;
    }

    if (Number(gameId) === 0) {
        console.log("Game not registered, checking other IDs...");
        for (let i = 0; i < 15; i++) {
            try {
                const game = await gr.getGame(i);
                if (game[2] && game[2].includes("Wager")) {
                    gameId = i;
                    console.log("Found at ID:", i, "-", game[2]);
                    break;
                }
            } catch (e) {}
        }
    }

    // ===== DEFINE METRICS =====
    console.log("\n--- DEFINING WAGERVERSE METRICS ---");
    for (const m of WAGER_METRICS) {
        try {
            const tx = await metricsRegistry.defineMetric(
                gameId, m.name, m.dataType, m.source,
                m.healthyMin, m.healthyMax, m.isHigherBetter
            );
            await tx.wait();
            console.log("[OK]", m.name, "(" + m.description + ")");
        } catch (e) {
            console.log("[SKIP]", m.name, "-", e.message.slice(0, 50));
        }
    }

    // ===== RECORD REALISTIC DATA =====
    console.log("\n--- RECORDING WAGERVERSE DATA ---");

    // Simulate 7 days of data
    const dailyData = [
        { wager_volume: 1200, win_rate: 4850, avg_wager_size: 45, payout_ratio: 9500, active_players: 120, match_queue_time: 8 },
        { wager_volume: 1450, win_rate: 4900, avg_wager_size: 52, payout_ratio: 9400, active_players: 135, match_queue_time: 7 },
        { wager_volume: 980,  win_rate: 5100, avg_wager_size: 38, payout_ratio: 9600, active_players: 95,  match_queue_time: 12 },
        { wager_volume: 2100, win_rate: 4700, avg_wager_size: 65, payout_ratio: 9200, active_players: 180, match_queue_time: 5 },
        { wager_volume: 1800, win_rate: 4950, avg_wager_size: 55, payout_ratio: 9350, active_players: 150, match_queue_time: 6 },
        { wager_volume: 850,  win_rate: 5300, avg_wager_size: 30, payout_ratio: 9700, active_players: 80,  match_queue_time: 15 },
        { wager_volume: 3200, win_rate: 4200, avg_wager_size: 85, payout_ratio: 8800, active_players: 250, match_queue_time: 4 }, // Anomaly day!
    ];

    for (let day = 0; day < dailyData.length; day++) {
        const d = dailyData[day];
        console.log("\nDay " + (day + 1) + ":");

        for (const m of WAGER_METRICS) {
            const value = d[m.name];
            if (value !== undefined) {
                try {
                    const tx = await metricsRegistry.recordMetric(gameId, m.name, value);
                    await tx.wait();
                    const isHealthy = value >= m.healthyMin && value <= m.healthyMax;
                    console.log("  " + (isHealthy ? "[OK]" : "[!] ") + m.name + " = " + value + (isHealthy ? "" : " (OUT OF RANGE)"));
                } catch (e) {
                    console.log("  [ERR]", m.name, e.message.slice(0, 40));
                }
            }
        }
    }

    // ===== READ STATS =====
    console.log("\n--- WAGERVERSE METRICS STATS ---");
    for (const m of WAGER_METRICS) {
        try {
            const stats = await metricsRegistry.getStats(gameId, m.name);
            const isHealthy = await metricsRegistry.isHealthy(gameId, m.name);
            console.log("[STATS] " + m.name + ": latest=" + Number(stats.latest) + ", avg=" + Number(stats.avg) + ", count=" + Number(stats.count) + ", healthy=" + isHealthy);
        } catch (e) {
            console.log("[ERR]", m.name);
        }
    }

    // ===== PATTERN DETECTION =====
    console.log("\n--- PATTERN DETECTION ---");
    try {
        // Add default wager rules
        try {
            const rulesTx = await patternDetector.addDefaultRules(gameId, "wager");
            await rulesTx.wait();
            console.log("[OK] Default wager rules added");
        } catch (e) {
            console.log("[SKIP] Default rules:", e.message.slice(0, 50));
        }

        // Add custom rules
        for (const r of PATTERN_RULES) {
            try {
                const tx = await patternDetector.addRule(gameId, r.ruleType, r.metricName, r.threshold, r.period);
                await tx.wait();
                console.log("[OK] Rule:", r.ruleType, r.metricName, "threshold=" + r.threshold + "%");
            } catch (e) {
                console.log("[SKIP] Rule:", r.ruleType, r.metricName);
            }
        }

        // Detect patterns
        const detectTx = await patternDetector.detectPatterns(gameId);
        await detectTx.wait();

        const patterns = await patternDetector.getActivePatterns(gameId);
        console.log("\n[ALERT] Active Patterns: " + patterns.length);
        for (const p of patterns) {
            console.log("  [!] " + p.patternType + " | " + p.metricName + " | Severity: " + Number(p.severity) + " | " + p.description);
        }
    } catch (e) {
        console.log("[ERR] Pattern detection:", e.message.slice(0, 80));
    }

    // ===== SUGGESTIONS =====
    console.log("\n--- AI SUGGESTIONS ---");
    try {
        const sugTx = await suggestionEngine.generateSuggestions(gameId);
        await sugTx.wait();

        const suggestions = await suggestionEngine.getActiveSuggestions(gameId);
        console.log("[IDEA] Suggestions: " + suggestions.length);
        for (const s of suggestions) {
            console.log("  [>] [" + s.priority + "] " + s.category + ": " + s.description.slice(0, 70));
            console.log("      Action: " + s.action.slice(0, 70));
            console.log("      Confidence: " + (Number(s.confidence) / 100) + "%");
        }
    } catch (e) {
        console.log("[ERR] Suggestions:", e.message.slice(0, 80));
    }

    console.log("\n=== WAGERVERSE ARENA SETUP COMPLETE ===");
}

main().catch(console.error);

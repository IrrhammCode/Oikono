/**
 * OIKONO — Real On-Chain Demo Data Generator
 * 
 * Executes REAL transactions on Somnia Testnet for:
 * 1. WagerVerse Arena (PvP) — metrics, patterns, suggestions
 * 2. Void Hunters (RPG) — enemy generation, battle, metrics
 * 3. Worms Arena (Strategy) — pattern detection, suggestions
 * 
 * npx hardhat run scripts/demo-real-data.js --network somnia_testnet
 */

const hre = require("hardhat");

const CONTRACTS = {
    GameRegistry: "0x6eB1d23419629901F78947B1207024f7F28380a6",
    MetricsRegistry: "0x5F447735f4A7DEc10F1dA55cbf05688D4A2bD808",
    PatternDetector: "0x655Cd724318C38284B984A7629EFe05dE57F29eD",
    SuggestionEngine: "0xe43c42e639170e5c88c2Ae242330473cf5745f8c",
    PlayerRegistry: "0xA530dbDB02f46F4A1B7c18cEE8eA57148fC470Ae",
    GameMaster: "0x40E8b775490b3BbB87A30693024E80fbF3D87347",
    EnemyNFT: "0x8B0E52280c2E5047B8fd7AffD20333f36463b037",
    BattleArena: "0x12EA4e91489B4FF6089C55a3833fc2e9b035d3Cf",
    OIKToken: "0xA03916C493cc00869FBd1D56cb89ba0d14A12116",
    AntiSybil: "0x96A9C1436C98155870bA29F5fD3637cbaC7f4bd3",
};

// Games to demo
const GAMES = {
    wagerverse: { id: 10, name: "WagerVerse Arena", type: "wager" },
    voidhunters: { id: 0, name: "Void Hunters", type: "rpg" },
    wormsarena: { id: 0, name: "Worms Arena", type: "strategy" },
};

async function findGameId(gr, name) {
    for (let i = 0; i < 20; i++) {
        try {
            const game = await gr.getGame(i);
            if (game[2] && game[2].includes(name.slice(0, 6))) return i;
        } catch (e) {}
    }
    return 0;
}

async function txLog(label, txPromise) {
    try {
        const tx = await txPromise;
        const receipt = await tx.wait();
        console.log("  [TX]", label, "→", receipt.hash.slice(0, 18) + "...");
        return receipt;
    } catch (e) {
        console.log("  [ERR]", label, "→", e.message.slice(0, 60));
        return null;
    }
}

async function main() {
    const [signer] = await hre.ethers.getSigners();
    const addr = signer.address;

    console.log("=".repeat(60));
    console.log("  OIKONO — REAL ON-CHAIN DEMO DATA");
    console.log("  Executing actual transactions on Somnia Testnet");
    console.log("=".repeat(60));
    console.log("");
    console.log("Wallet:", addr);
    console.log("");

    // Load contracts
    const gr = await hre.ethers.getContractAt("GameRegistry", CONTRACTS.GameRegistry);
    const metrics = await hre.ethers.getContractAt("MetricsRegistry", CONTRACTS.MetricsRegistry);
    const patterns = await hre.ethers.getContractAt("PatternDetector", CONTRACTS.PatternDetector);
    const suggestions = await hre.ethers.getContractAt("SuggestionEngine", CONTRACTS.SuggestionEngine);
    const playerReg = await hre.ethers.getContractAt("PlayerRegistry", CONTRACTS.PlayerRegistry);
    const gameMaster = await hre.ethers.getContractAt("GameMaster", CONTRACTS.GameMaster);
    const enemyNFT = await hre.ethers.getContractAt("EnemyNFT", CONTRACTS.EnemyNFT);
    const antiSybil = await hre.ethers.getContractAt("AntiSybil", CONTRACTS.AntiSybil);

    // Find game IDs
    console.log("--- LOCATING GAMES ---");
    GAMES.wagerverse.id = await findGameId(gr, "WagerVerse");
    GAMES.voidhunters.id = await findGameId(gr, "Void Hunters");
    GAMES.wormsarena.id = await findGameId(gr, "Worms");
    console.log("WagerVerse Arena → ID", Number(GAMES.wagerverse.id));
    console.log("Void Hunters → ID", Number(GAMES.voidhunters.id));
    console.log("Worms Arena → ID", Number(GAMES.wormsarena.id));
    console.log("");

    // ============================================================
    //  PART 1: PLAYER ACTIONS (Real Transactions)
    // ============================================================
    console.log("=".repeat(60));
    console.log("  PART 1: PLAYER ACTIONS (On-Chain)");
    console.log("=".repeat(60));
    console.log("");

    // Register player if needed
    const exists = await playerReg.playerExists(addr);
    if (!exists) {
        console.log("[PLAYER] Registering player...");
        await txLog("registerPlayer(50, 50)", playerReg.registerPlayer(50, 50));
    } else {
        const p = await playerReg.getPlayer(addr);
        console.log("[PLAYER] Already registered — Level", Number(p[3]), "XP", Number(p[2]));
    }

    // Generate enemies via GameMaster (real AI transaction)
    console.log("");
    console.log("[ENEMY] Generating enemies via GameMaster AI...");
    for (let i = 0; i < 3; i++) {
        await txLog("triggerEnemyGeneration", gameMaster.triggerEnemyGeneration(addr));
    }

    // Check enemies minted
    const enemies = await enemyNFT.getPlayerEnemies(addr);
    console.log("");
    console.log("[RESULT] Enemies minted:", enemies.length);
    for (let i = 0; i < enemies.length; i++) {
        const e = await enemyNFT.getEnemy(enemies[i]);
        console.log("  #" + Number(enemies[i]) + " " + e[0] + " — " + e[1] + ", " + e[2] + ", power " + Number(e[3]));
    }

    // ============================================================
    //  PART 2: WAGERVERSE ARENA METRICS
    // ============================================================
    console.log("");
    console.log("=".repeat(60));
    console.log("  PART 2: WAGERVERSE ARENA — METRICS");
    console.log("=".repeat(60));
    console.log("");

    const wId = GAMES.wagerverse.id;
    const wagerMetrics = [
        { name: "wager_volume", min: 500, max: 5000, higher: true },
        { name: "win_rate", min: 4500, max: 5500, higher: false },
        { name: "avg_wager_size", min: 10, max: 100, higher: false },
        { name: "payout_ratio", min: 9000, max: 9800, higher: true },
        { name: "active_players", min: 20, max: 500, higher: true },
        { name: "match_queue_time", min: 5, max: 30, higher: false },
    ];

    // Define metrics
    console.log("[DEFINE] WagerVerse metrics...");
    for (const m of wagerMetrics) {
        try {
            await txLog("defineMetric(" + m.name + ")", metrics.defineMetric(wId, m.name, "uint256", "on-chain", m.min, m.max, m.higher));
        } catch (e) {
            console.log("  [SKIP]", m.name, "— already defined");
        }
    }

    // Record 7 days of data (real on-chain writes)
    console.log("");
    console.log("[RECORD] 7 days of WagerVerse data...");
    const wagerData = [
        { wager_volume: 1200, win_rate: 4850, avg_wager_size: 45, payout_ratio: 9500, active_players: 120, match_queue_time: 8 },
        { wager_volume: 1450, win_rate: 4900, avg_wager_size: 52, payout_ratio: 9400, active_players: 135, match_queue_time: 7 },
        { wager_volume: 980,  win_rate: 5100, avg_wager_size: 38, payout_ratio: 9600, active_players: 95,  match_queue_time: 12 },
        { wager_volume: 2100, win_rate: 4700, avg_wager_size: 65, payout_ratio: 9200, active_players: 180, match_queue_time: 5 },
        { wager_volume: 1800, win_rate: 4950, avg_wager_size: 55, payout_ratio: 9350, active_players: 150, match_queue_time: 6 },
        { wager_volume: 850,  win_rate: 5300, avg_wager_size: 30, payout_ratio: 9700, active_players: 80,  match_queue_time: 15 },
        { wager_volume: 3200, win_rate: 4200, avg_wager_size: 85, payout_ratio: 8800, active_players: 250, match_queue_time: 4 },
    ];

    for (let day = 0; day < wagerData.length; day++) {
        const d = wagerData[day];
        console.log("  Day " + (day + 1) + ":");
        for (const m of wagerMetrics) {
            const val = d[m.name];
            if (val !== undefined) {
                try {
                    await txLog(m.name + "=" + val, metrics.recordMetric(wId, m.name, val));
                } catch (e) {
                    console.log("    [ERR]", m.name);
                }
            }
        }
    }

    // ============================================================
    //  PART 3: VOID HUNTERS METRICS (RPG)
    // ============================================================
    console.log("");
    console.log("=".repeat(60));
    console.log("  PART 3: VOID HUNTERS — METRICS (RPG)");
    console.log("=".repeat(60));
    console.log("");

    const vId = GAMES.voidhunters.id;
    const rpgMetrics = [
        { name: "win_rate", min: 4500, max: 6500, higher: false },
        { name: "token_velocity", min: 500, max: 2000, higher: false },
        { name: "retention_d7", min: 2000, max: 4000, higher: true },
        { name: "avg_session_length", min: 900, max: 3600, higher: true },
    ];

    console.log("[DEFINE] Void Hunters RPG metrics...");
    for (const m of rpgMetrics) {
        try {
            await txLog("defineMetric(" + m.name + ")", metrics.defineMetric(vId, m.name, "uint256", "on-chain", m.min, m.max, m.higher));
        } catch (e) {
            console.log("  [SKIP]", m.name);
        }
    }

    console.log("");
    console.log("[RECORD] Void Hunters data (7 days)...");
    const rpgData = [
        { win_rate: 5200, token_velocity: 1200, retention_d7: 3200, avg_session_length: 1800 },
        { win_rate: 5400, token_velocity: 1100, retention_d7: 3100, avg_session_length: 1650 },
        { win_rate: 5100, token_velocity: 1300, retention_d7: 2800, avg_session_length: 1500 },
        { win_rate: 5600, token_velocity: 1000, retention_d7: 2500, avg_session_length: 1200 },
        { win_rate: 7200, token_velocity: 800,  retention_d7: 1800, avg_session_length: 900 },  // Problem!
        { win_rate: 7500, token_velocity: 700,  retention_d7: 1500, avg_session_length: 800 },  // Worse!
        { win_rate: 7800, token_velocity: 600,  retention_d7: 1200, avg_session_length: 700 },  // Critical!
    ];

    for (let day = 0; day < rpgData.length; day++) {
        const d = rpgData[day];
        console.log("  Day " + (day + 1) + ":");
        for (const m of rpgMetrics) {
            const val = d[m.name];
            if (val !== undefined) {
                try {
                    await txLog(m.name + "=" + val, metrics.recordMetric(vId, m.name, val));
                } catch (e) {
                    console.log("    [ERR]", m.name);
                }
            }
        }
    }

    // ============================================================
    //  PART 4: WORMS ARENA METRICS (Strategy)
    // ============================================================
    console.log("");
    console.log("=".repeat(60));
    console.log("  PART 4: WORMS ARENA — METRICS (Strategy)");
    console.log("=".repeat(60));
    console.log("");

    const sId = GAMES.wormsarena.id;
    const stratMetrics = [
        { name: "win_rate", min: 4000, max: 6000, higher: false },
        { name: "avg_game_length", min: 600, max: 1800, higher: false },
        { name: "build_diversity", min: 5000, max: 10000, higher: true },
        { name: "comeback_rate", min: 1500, max: 3500, higher: true },
    ];

    console.log("[DEFINE] Worms Arena strategy metrics...");
    for (const m of stratMetrics) {
        try {
            await txLog("defineMetric(" + m.name + ")", metrics.defineMetric(sId, m.name, "uint256", "on-chain", m.min, m.max, m.higher));
        } catch (e) {
            console.log("  [SKIP]", m.name);
        }
    }

    console.log("");
    console.log("[RECORD] Worms Arena data (7 days)...");
    const stratData = [
        { win_rate: 5100, avg_game_length: 1200, build_diversity: 7500, comeback_rate: 2200 },
        { win_rate: 5300, avg_game_length: 1100, build_diversity: 7200, comeback_rate: 2100 },
        { win_rate: 4800, avg_game_length: 1300, build_diversity: 7800, comeback_rate: 2400 },
        { win_rate: 5500, avg_game_length: 1000, build_diversity: 6500, comeback_rate: 1800 },
        { win_rate: 6200, avg_game_length: 800,  build_diversity: 4500, comeback_rate: 1200 },  // Meta stagnation!
        { win_rate: 6800, avg_game_length: 600,  build_diversity: 3000, comeback_rate: 800 },   // Critical!
        { win_rate: 7200, avg_game_length: 500,  build_diversity: 2000, comeback_rate: 500 },   // Emergency!
    ];

    for (let day = 0; day < stratData.length; day++) {
        const d = stratData[day];
        console.log("  Day " + (day + 1) + ":");
        for (const m of stratMetrics) {
            const val = d[m.name];
            if (val !== undefined) {
                try {
                    await txLog(m.name + "=" + val, metrics.recordMetric(sId, m.name, val));
                } catch (e) {
                    console.log("    [ERR]", m.name);
                }
            }
        }
    }

    // ============================================================
    //  PART 5: PATTERN DETECTION (All Games)
    // ============================================================
    console.log("");
    console.log("=".repeat(60));
    console.log("  PART 5: PATTERN DETECTION (On-Chain)");
    console.log("=".repeat(60));
    console.log("");

    for (const [key, game] of Object.entries(GAMES)) {
        console.log("[DETECT] " + game.name + " (ID " + Number(game.id) + ")...");
        try {
            await txLog("addDefaultRules", patterns.addDefaultRules(game.id, game.type));
        } catch (e) {
            console.log("  [SKIP] Rules already exist");
        }
        try {
            await txLog("detectPatterns", patterns.detectPatterns(game.id));
            const active = await patterns.getActivePatterns(game.id);
            console.log("  [RESULT] " + active.length + " patterns detected:");
            for (const p of active) {
                console.log("    [!] " + p.patternType + " | " + p.metricName + " | severity " + Number(p.severity));
            }
        } catch (e) {
            console.log("  [ERR]", e.message.slice(0, 60));
        }
        console.log("");
    }

    // ============================================================
    //  PART 6: AI SUGGESTIONS (All Games)
    // ============================================================
    console.log("=".repeat(60));
    console.log("  PART 6: AI SUGGESTIONS (On-Chain)");
    console.log("=".repeat(60));
    console.log("");

    for (const [key, game] of Object.entries(GAMES)) {
        console.log("[SUGGEST] " + game.name + "...");
        try {
            await txLog("generateSuggestions", suggestions.generateSuggestions(game.id));
            const active = await suggestions.getActiveSuggestions(game.id);
            console.log("  [RESULT] " + active.length + " suggestions:");
            for (const s of active) {
                console.log("    [>] [" + s.priority + "] " + s.category + ": " + s.description.slice(0, 60));
            }
        } catch (e) {
            console.log("  [ERR]", e.message.slice(0, 60));
        }
        console.log("");
    }

    // ============================================================
    //  SUMMARY
    // ============================================================
    console.log("=".repeat(60));
    console.log("  ALL TRANSACTIONS COMPLETE");
    console.log("=".repeat(60));
    console.log("");

    // Read final stats
    const gmStats = await gameMaster.getStats();
    const totalEnemies = await enemyNFT.totalEnemiesMinted();

    console.log("  Enemies Generated:     " + Number(totalEnemies));
    console.log("  GameMaster LLM Calls:  " + Number(gmStats[1]));
    console.log("  Games with Metrics:    3 (WagerVerse, Void Hunters, Worms Arena)");
    console.log("  Patterns Detected:     Check frontend");
    console.log("  Suggestions Generated: Check frontend");
    console.log("");
    console.log("  All data is REAL on-chain transactions on Somnia Testnet.");
    console.log("  Open the frontend to see metrics, patterns, and suggestions.");
    console.log("");
}

main().catch(console.error);

const { ethers } = require("hardhat");

// Contract addresses on Somnia Testnet
const CONTRACTS = {
    GameRegistry: "0x6eB1d23419629901F78947B1207024f7F28380a6",
    MetricsRegistry: "0x5F447735f4A7DEc10F1dA55cbf05688D4A2bD808",
    PatternDetector: "0x655Cd724318C38284B984A7629EFe05dE57F29eD",
    SuggestionEngine: "0xe43c42e639170e5c88c2Ae242330473cf5745f8c",
    GameTypeManager: "0x5C995903E49e21cE75D4c39A4FDa8a559b5E2C5C",
};

// Minimal ABIs for testing
const ABIS = {
    GameRegistry: [
        "function registerGame(string name, string gameType, string description, address gameAddress, string metadata, tuple(bool canSpawn, bool canAdjustEconomy, bool canGenerateNarrative, bool canAdjustDifficulty, uint256 maxChangePerEpoch, uint256 epochLength) config) external returns (uint256)",
        "function getGame(uint256 gameId) external view returns (address gameAddress, address owner, string name, string gameType, string description, string metadata, bool isActive, bool isVerified, uint256 totalEvents, uint256 totalActions)",
        "function getConfig(uint256 gameId) external view returns (tuple(bool canSpawn, bool canAdjustEconomy, bool canGenerateNarrative, bool canAdjustDifficulty, uint256 maxChangePerEpoch, uint256 epochLength))",
        "function getGamesByOwner(address owner) external view returns (uint256[])",
        "function getTotalGames() external view returns (uint256)",
        "function addContract(uint256 gameId, address contractAddress, string role, bytes32[] eventHashes) external",
        "function deactivateGame(uint256 gameId) external",
        "function activateGame(uint256 gameId) external",
        "event GameRegistered(uint256 indexed gameId, address indexed gameAddress, address indexed owner, string name, string gameType)",
    ],
    MetricsRegistry: [
        "function defineMetric(uint256 gameId, string name, string dataType, string source, uint256 healthyMin, uint256 healthyMax, bool isHigherBetter) external",
        "function recordMetric(uint256 gameId, string name, uint256 value) external",
        "function getMetricNames(uint256 gameId) external view returns (string[])",
        "function getStats(uint256 gameId, string name) external view returns (uint256 latest, uint256 min, uint256 max, uint256 avg, uint256 count, uint256 lastUpdated)",
        "function isHealthy(uint256 gameId, string name) external view returns (bool)",
        "function getChange(uint256 gameId, string name) external view returns (int256)",
    ],
    PatternDetector: [
        "function detectPatterns(uint256 gameId) external",
        "function getActivePatterns(uint256 gameId) external view returns (tuple(uint256 patternId, uint256 gameId, string patternType, string metricName, string metricName2, string description, uint256 severity, uint256 confidence, uint256 detectedAt, bool isActive, bytes data)[])",
        "function getPatternCount(uint256 gameId) external view returns (uint256)",
        "function addDefaultRules(uint256 gameId, string gameType) external",
    ],
    SuggestionEngine: [
        "function generateSuggestions(uint256 gameId) external",
        "function getActiveSuggestions(uint256 gameId) external view returns (tuple(uint256 suggestionId, uint256 gameId, uint256 patternId, string category, string priority, string description, string action, uint256 confidence, uint256 expectedImpact, bool implemented, uint256 implementedAt, bytes outcomeData)[])",
        "function getSuggestionCount(uint256 gameId) external view returns (uint256)",
    ],
    GameTypeManager: [
        "function applyTemplate(uint256 gameId, string typeName) external",
        "function getRegisteredTypes() external view returns (string[])",
    ],
};

async function main() {
    const [signer] = await ethers.getSigners();
    const address = await signer.getAddress();
    console.log("🔑 Wallet:", address);
    console.log("💰 Balance:", ethers.formatEther(await ethers.provider.getBalance(address)), "STT\n");

    // Get contract instances
    const gameRegistry = new ethers.Contract(CONTRACTS.GameRegistry, ABIS.GameRegistry, signer);
    const metricsRegistry = new ethers.Contract(CONTRACTS.MetricsRegistry, ABIS.MetricsRegistry, signer);
    const patternDetector = new ethers.Contract(CONTRACTS.PatternDetector, ABIS.PatternDetector, signer);
    const suggestionEngine = new ethers.Contract(CONTRACTS.SuggestionEngine, ABIS.SuggestionEngine, signer);
    const gameTypeManager = new ethers.Contract(CONTRACTS.GameTypeManager, ABIS.GameTypeManager, signer);

    // ═══════════════════════════════════════
    // TEST 1: Register Game
    // ═══════════════════════════════════════
    console.log("═══ TEST 1: Register Game ═══");
    try {
        const totalBefore = await gameRegistry.getTotalGames();
        console.log("  Total games before:", totalBefore.toString());

        const config = {
            canSpawn: true,
            canAdjustEconomy: true,
            canGenerateNarrative: false,
            canAdjustDifficulty: true,
            maxChangePerEpoch: 2000, // 20%
            epochLength: 6500,
        };

        const metadata = JSON.stringify({
            website: "https://test-game.example",
            primaryAddress: address,
            contracts: [],
            token: { name: "TestGold", symbol: "TGOLD", totalSupply: "1000000", circSupply: "250000", utility: "mixed" },
            economy: { targetWinRate: 55, targetRetention: 30, inflationTolerance: "medium", economyStyle: "balanced", maxChangePerEpoch: 20 },
            permissions: { canSpawn: true, canAdjustEconomy: true, canGenerateNarrative: false, canAdjustDifficulty: true },
        });

        const tx = await gameRegistry.registerGame(
            "Test Game " + Date.now(),
            "rpg",
            "Automated test game",
            address, // Using signer address as game address for testing
            metadata,
            config
        );
        console.log("  TX Hash:", tx.hash);
        const receipt = await tx.wait();
        console.log("  ✅ Game registered! Gas used:", receipt.gasUsed.toString());

        // Parse event
        const event = receipt.logs.find((l) => {
            try { return gameRegistry.interface.parseLog(l)?.name === "GameRegistered"; } catch { return false; }
        });
        const gameId = gameRegistry.interface.parseLog(event).args.gameId;
        console.log("  📋 Game ID:", gameId.toString());

        // ═══════════════════════════════════════
        // TEST 2: Read Game Data
        // ═══════════════════════════════════════
        console.log("\n═══ TEST 2: Read Game Data ═══");
        const game = await gameRegistry.getGame(gameId);
        console.log("  Name:", game.name);
        console.log("  Type:", game.gameType);
        console.log("  Owner:", game.owner);
        console.log("  Active:", game.isActive);
        console.log("  Verified:", game.isVerified);

        const configData = await gameRegistry.getConfig(gameId);
        console.log("  Config - canSpawn:", configData.canSpawn);
        console.log("  Config - canAdjustEconomy:", configData.canAdjustEconomy);
        console.log("  Config - maxChangePerEpoch:", configData.maxChangePerEpoch.toString());

        const ownerGames = await gameRegistry.getGamesByOwner(address);
        console.log("  Owner games count:", ownerGames.length);

        // ═══════════════════════════════════════
        // TEST 3: Apply Template
        // ═══════════════════════════════════════
        console.log("\n═══ TEST 3: Apply Game Type Template ═══");
        try {
            const templateTx = await gameTypeManager.applyTemplate(gameId, "rpg");
            await templateTx.wait();
            console.log("  ✅ RPG template applied!");
        } catch (e) {
            console.log("  ⚠️ Template apply failed (expected if no template registered):", e.message.slice(0, 80));
        }

        // ═══════════════════════════════════════
        // TEST 4: Record Metrics
        // ═══════════════════════════════════════
        console.log("\n═══ TEST 4: Record Metrics ═══");
        try {
            // Define a metric first
            const defineTx = await metricsRegistry.defineMetric(gameId, "win_rate", "uint256", "on-chain", 4500, 6500, false);
            await defineTx.wait();
            console.log("  ✅ Metric 'win_rate' defined");

            // Record some values
            const values = [5200, 5400, 5100, 5600, 5300];
            for (const val of values) {
                const recTx = await metricsRegistry.recordMetric(gameId, "win_rate", val);
                await recTx.wait();
                console.log("  📊 Recorded win_rate =", val);
            }

            // Read stats
            const stats = await metricsRegistry.getStats(gameId, "win_rate");
            console.log("\n  📈 Stats:");
            console.log("    Latest:", stats.latest.toString());
            console.log("    Min:", stats.min.toString());
            console.log("    Max:", stats.max.toString());
            console.log("    Avg:", stats.avg.toString());
            console.log("    Count:", stats.count.toString());

            // Check health
            const isHealthy = await metricsRegistry.isHealthy(gameId, "win_rate");
            console.log("    Healthy:", isHealthy);

            // Get change
            const change = await metricsRegistry.getChange(gameId, "win_rate");
            console.log("    Change:", change.toString());

            // Get metric names
            const names = await metricsRegistry.getMetricNames(gameId);
            console.log("    All metrics:", names.join(", "));
        } catch (e) {
            console.log("  ⚠️ Metrics test failed:", e.message.slice(0, 120));
        }

        // ═══════════════════════════════════════
        // TEST 5: Detect Patterns
        // ═══════════════════════════════════════
        console.log("\n═══ TEST 5: Detect Patterns ═══");
        try {
            // Add default rules first
            try {
                const rulesTx = await patternDetector.addDefaultRules(gameId, "rpg");
                await rulesTx.wait();
                console.log("  ✅ Default RPG rules added");
            } catch (e) {
                console.log("  ⚠️ addDefaultRules failed:", e.message.slice(0, 80));
            }

            // Detect patterns
            const detectTx = await patternDetector.detectPatterns(gameId);
            await detectTx.wait();
            console.log("  ✅ Pattern detection executed");

            // Read patterns
            const patterns = await patternDetector.getActivePatterns(gameId);
            console.log("  🔍 Active patterns:", patterns.length);
            for (const p of patterns) {
                console.log("    -", p.patternType, "| severity:", p.severity.toString(), "|", p.description);
            }

            const count = await patternDetector.getPatternCount(gameId);
            console.log("  📊 Total pattern count:", count.toString());
        } catch (e) {
            console.log("  ⚠️ Pattern test failed:", e.message.slice(0, 120));
        }

        // ═══════════════════════════════════════
        // TEST 6: Generate Suggestions
        // ═══════════════════════════════════════
        console.log("\n═══ TEST 6: Generate Suggestions ═══");
        try {
            const genTx = await suggestionEngine.generateSuggestions(gameId);
            await genTx.wait();
            console.log("  ✅ Suggestions generated");

            const suggestions = await suggestionEngine.getActiveSuggestions(gameId);
            console.log("  💡 Active suggestions:", suggestions.length);
            for (const s of suggestions) {
                console.log("    -", `[${s.priority}]`, s.category, ":", s.description.slice(0, 60));
                console.log("      Action:", s.action.slice(0, 60));
                console.log("      Confidence:", (Number(s.confidence) / 100).toFixed(0) + "%");
            }

            const sugCount = await suggestionEngine.getSuggestionCount(gameId);
            console.log("  📊 Total suggestion count:", sugCount.toString());
        } catch (e) {
            console.log("  ⚠️ Suggestion test failed:", e.message.slice(0, 120));
        }

        // ═══════════════════════════════════════
        // TEST 7: Game Management
        // ═══════════════════════════════════════
        console.log("\n═══ TEST 7: Game Management ═══");
        try {
            // Deactivate
            const deactTx = await gameRegistry.deactivateGame(gameId);
            await deactTx.wait();
            const gameAfterDeact = await gameRegistry.getGame(gameId);
            console.log("  ⏸ Deactivated - isActive:", gameAfterDeact.isActive);

            // Reactivate
            const actTx = await gameRegistry.activateGame(gameId);
            await actTx.wait();
            const gameAfterAct = await gameRegistry.getGame(gameId);
            console.log("  ▶ Reactivated - isActive:", gameAfterAct.isActive);
        } catch (e) {
            console.log("  ⚠️ Game management test failed:", e.message.slice(0, 80));
        }

        console.log("\n══════════════════════════════════════");
        console.log("  ✅ ALL TESTS COMPLETE!");
        console.log("══════════════════════════════════════");
        console.log("\n📋 Game ID:", gameId.toString(), "(use this in frontend)");
        console.log("🔗 Explorer: https://shannon-explorer.somnia.network/tx/" + tx.hash);

    } catch (e) {
        console.error("❌ Test failed:", e.message);
    }
}

main().catch(console.error);

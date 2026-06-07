const { ethers } = require("hardhat");

const CONTRACTS = {
    GameRegistry: "0x6eB1d23419629901F78947B1207024f7F28380a6",
    MetricsRegistry: "0x5F447735f4A7DEc10F1dA55cbf05688D4A2bD808",
    PatternDetector: "0x655Cd724318C38284B984A7629EFe05dE57F29eD",
    SuggestionEngine: "0xe43c42e639170e5c88c2Ae242330473cf5745f8c",
    GameTypeManager: "0x5C995903E49e21cE75D4c39A4FDa8a559b5E2C5C",
    OikonoAgent: "0x586e9ACF26D76A1aD52054b3EF3e9c72A9917b05",
    AgentRuntime: "0x3ee2954bd1e9188a35f40aFF521EF2a7FD375f54",
    SpawnPlugin: "0xBd4bfbCefbF5d02B179003F48294768d4DF718AD",
    GameMaster: "0x40E8b775490b3BbB87A30693024E80fbF3D87347",
    EnemyNFT: "0x8B0E52280c2E5047B8fd7AffD20333f36463b037",
    PlayerRegistry: "0xA530dbDB02f46F4A1B7c18cEE8eA57148fC470Ae",
    BattleArena: "0x12EA4e91489B4FF6089C55a3833fc2e9b035d3Cf",
    OIKToken: "0xA03916C493cc00869FBd1D56cb89ba0d14A12116",
};

async function main() {
    const [signer] = await ethers.getSigners();
    console.log("🔍 Backend Health Check - Somnia Testnet");
    console.log("   Wallet:", await signer.getAddress());
    console.log("");

    // Check each contract is deployed
    console.log("═══ CONTRACT DEPLOYMENT CHECK ═══");
    for (const [name, addr] of Object.entries(CONTRACTS)) {
        const code = await ethers.provider.getCode(addr);
        const deployed = code !== "0x";
        console.log(`  ${name}: ${deployed ? "✅" : "❌ NOT DEPLOYED"} (${addr.slice(0, 10)}...)`);
    }
    console.log("");

    // Check GameRegistry functions
    console.log("═══ GAMEREGISTRY FUNCTION CHECK ═══");
    const grAbi = [
        "function nextGameId() external view returns (uint256)",
        "function getGame(uint256) external view returns (address,address,string,string,string,string,bool,bool,uint256,uint256)",
        "function getConfig(uint256) external view returns (tuple(bool,bool,bool,bool,uint256,uint256))",
        "function getGamesByOwner(address) external view returns (uint256[])",
        "function getTotalGames() external view returns (uint256)",
        "function deactivateGame(uint256) external",
        "function activateGame(uint256) external",
    ];
    const gr = new ethers.Contract(CONTRACTS.GameRegistry, grAbi, signer);
    
    try {
        const total = await gr.getTotalGames();
        console.log("  getTotalGames():", total.toString());
    } catch(e) { console.log("  getTotalGames(): ❌", e.message.slice(0, 60)); }

    try {
        const games = await gr.getGamesByOwner(await signer.getAddress());
        console.log("  getGamesByOwner():", games.length, "games");
        if (games.length > 0) {
            const game = await gr.getGame(games[0]);
            console.log("    Game 0 - name:", game.name, "| type:", game.gameType, "| active:", game.isActive);
            const config = await gr.getConfig(games[0]);
            console.log("    Config - spawn:", config.canSpawn, "| economy:", config.canAdjustEconomy, "| epoch:", config.epochLength.toString());
        }
    } catch(e) { console.log("  getGamesByOwner(): ❌", e.message.slice(0, 80)); }

    // Check MetricsRegistry
    console.log("");
    console.log("═══ METRICSREGISTRY CHECK ═══");
    const mrAbi = [
        "function getMetricNames(uint256) external view returns (string[])",
        "function getStats(uint256,string) external view returns (uint256,uint256,uint256,uint256,uint256,uint256)",
        "function isHealthy(uint256,string) external view returns (bool)",
        "function getChange(uint256,string) external view returns (int256)",
    ];
    const mr = new ethers.Contract(CONTRACTS.MetricsRegistry, mrAbi, signer);
    
    try {
        const names = await mr.getMetricNames(0);
        console.log("  getMetricNames(0):", names.length > 0 ? names.join(", ") : "(empty)");
        if (names.length > 0) {
            const stats = await mr.getStats(0, names[0]);
            console.log("  getStats:", "latest=" + stats.latest, "min=" + stats.min, "max=" + stats.max, "avg=" + stats.avg, "count=" + stats.count);
            const healthy = await mr.isHealthy(0, names[0]);
            console.log("  isHealthy:", healthy);
            const change = await mr.getChange(0, names[0]);
            console.log("  getChange:", change.toString());
        }
    } catch(e) { console.log("  MetricsRegistry error:", e.message.slice(0, 80)); }

    // Check PatternDetector
    console.log("");
    console.log("═══ PATTERNDETECTOR CHECK ═══");
    const pdAbi = [
        "function getPatternCount(uint256) external view returns (uint256)",
        "function getActivePatterns(uint256) external view returns (tuple(uint256,uint256,string,string,string,string,uint256,uint256,uint256,bool,bytes)[])",
    ];
    const pd = new ethers.Contract(CONTRACTS.PatternDetector, pdAbi, signer);
    
    try {
        const count = await pd.getPatternCount(0);
        console.log("  getPatternCount(0):", count.toString());
        const patterns = await pd.getActivePatterns(0);
        console.log("  getActivePatterns(0):", patterns.length, "patterns");
    } catch(e) { console.log("  PatternDetector error:", e.message.slice(0, 80)); }

    // Check SuggestionEngine
    console.log("");
    console.log("═══ SUGGESTIONENGINE CHECK ═══");
    const seAbi = [
        "function getSuggestionCount(uint256) external view returns (uint256)",
        "function getActiveSuggestions(uint256) external view returns (tuple(uint256,uint256,uint256,string,string,string,string,uint256,uint256,bool,uint256,bytes)[])",
    ];
    const se = new ethers.Contract(CONTRACTS.SuggestionEngine, seAbi, signer);
    
    try {
        const count = await se.getSuggestionCount(0);
        console.log("  getSuggestionCount(0):", count.toString());
        const suggestions = await se.getActiveSuggestions(0);
        console.log("  getActiveSuggestions(0):", suggestions.length, "suggestions");
    } catch(e) { console.log("  SuggestionEngine error:", e.message.slice(0, 80)); }

    console.log("");
    console.log("════════════════════════════════════");
    console.log("  ✅ BACKEND HEALTH CHECK COMPLETE");
    console.log("════════════════════════════════════");
}

main().catch(console.error);

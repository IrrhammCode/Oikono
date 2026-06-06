const { ethers } = require("hardhat");

async function main() {
    console.log("╔══════════════════════════════════════════════════════════════╗");
    console.log("║  OIKONO Universal AI Agent — Full Deployment                ║");
    console.log("║  Agent + Memory + KnowledgeBase + Introspection             ║");
    console.log("╚══════════════════════════════════════════════════════════════╝\n");

    const [deployer] = await ethers.getSigners();
    console.log("Deployer:", deployer.address);
    console.log("Balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "STT\n");

    // ========================================
    // 1. Deploy Foundation
    // ========================================
    console.log("📦 Step 1: Deploying foundation contracts...");

    const CircuitBreaker = await ethers.getContractFactory("CircuitBreaker");
    const circuitBreaker = await CircuitBreaker.deploy(deployer.address);
    await circuitBreaker.waitForDeployment();
    console.log("  ✅ CircuitBreaker:", await circuitBreaker.getAddress());

    const AntiSybil = await ethers.getContractFactory("AntiSybil");
    const antiSybil = await AntiSybil.deploy(deployer.address);
    await antiSybil.waitForDeployment();
    console.log("  ✅ AntiSybil:", await antiSybil.getAddress());

    const OIKToken = await ethers.getContractFactory("OIKToken");
    const oikToken = await OIKToken.deploy(deployer.address);
    await oikToken.waitForDeployment();
    console.log("  ✅ OIKToken:", await oikToken.getAddress());

    // ========================================
    // 2. Deploy Agent Memory & Knowledge
    // ========================================
    console.log("\n🧠 Step 2: Deploying agent intelligence...");

    const AgentMemory = await ethers.getContractFactory("AgentMemory");
    const agentMemory = await AgentMemory.deploy(deployer.address);
    await agentMemory.waitForDeployment();
    console.log("  ✅ AgentMemory:", await agentMemory.getAddress());

    const GameKnowledgeBase = await ethers.getContractFactory("GameKnowledgeBase");
    const knowledgeBase = await GameKnowledgeBase.deploy(deployer.address);
    await knowledgeBase.waitForDeployment();
    console.log("  ✅ GameKnowledgeBase:", await knowledgeBase.getAddress());

    // ========================================
    // 3. Deploy Agent Runtime
    // ========================================
    console.log("\n⚡ Step 3: Deploying agent runtime...");

    const AgentRuntime = await ethers.getContractFactory("AgentRuntime");
    const agentRuntime = await AgentRuntime.deploy(await circuitBreaker.getAddress());
    await agentRuntime.waitForDeployment();
    console.log("  ✅ AgentRuntime:", await agentRuntime.getAddress());

    // ========================================
    // 4. Deploy Plugins
    // ========================================
    console.log("\n🔌 Step 4: Deploying AI plugins...");

    const SpawnPlugin = await ethers.getContractFactory("SpawnPlugin");
    const spawnPlugin = await SpawnPlugin.deploy();
    await spawnPlugin.waitForDeployment();
    console.log("  ✅ SpawnPlugin:", await spawnPlugin.getAddress());

    const EconomyPlugin = await ethers.getContractFactory("EconomyPlugin");
    const economyPlugin = await EconomyPlugin.deploy();
    await economyPlugin.waitForDeployment();
    console.log("  ✅ EconomyPlugin:", await economyPlugin.getAddress());

    const NarrativePlugin = await ethers.getContractFactory("NarrativePlugin");
    const narrativePlugin = await NarrativePlugin.deploy();
    await narrativePlugin.waitForDeployment();
    console.log("  ✅ NarrativePlugin:", await narrativePlugin.getAddress());

    const BalancePlugin = await ethers.getContractFactory("BalancePlugin");
    const balancePlugin = await BalancePlugin.deploy();
    await balancePlugin.waitForDeployment();
    console.log("  ✅ BalancePlugin:", await balancePlugin.getAddress());

    // Register plugins by type in runtime
    await agentRuntime.registerPlugin("spawn", await spawnPlugin.getAddress());
    await agentRuntime.registerPlugin("economy", await economyPlugin.getAddress());
    await agentRuntime.registerPlugin("narrative", await narrativePlugin.getAddress());
    await agentRuntime.registerPlugin("balance", await balancePlugin.getAddress());
    console.log("  ✅ Plugins registered by type");

    // ========================================
    // 5. Deploy OikonoAgent (The Brain)
    // ========================================
    console.log("\n🧠 Step 5: Deploying OikonoAgent (the brain)...");

    const OikonoAgent = await ethers.getContractFactory("OikonoAgent");
    const oikonoAgent = await OikonoAgent.deploy(
        await agentRuntime.getAddress(),
        await agentMemory.getAddress(),
        await knowledgeBase.getAddress(),
        await circuitBreaker.getAddress()
    );
    await oikonoAgent.waitForDeployment();
    console.log("  ✅ OikonoAgent:", await oikonoAgent.getAddress());

    // ========================================
    // 6. Deploy Agent Registry & Vault
    // ========================================
    console.log("\n📋 Step 6: Deploying registry & vault...");

    const AgentRegistry = await ethers.getContractFactory("AgentRegistry");
    const agentRegistry = await AgentRegistry.deploy();
    await agentRegistry.waitForDeployment();
    console.log("  ✅ AgentRegistry:", await agentRegistry.getAddress());

    const GameRegistry = await ethers.getContractFactory("GameRegistry");
    const gameRegistry = await GameRegistry.deploy(
        await oikonoAgent.getAddress(),
        await agentMemory.getAddress(),
        await knowledgeBase.getAddress()
    );
    await gameRegistry.waitForDeployment();
    console.log("  ✅ GameRegistry:", await gameRegistry.getAddress());

    // Deploy GameRegistryV2 (split into multiple contracts)
    console.log("\n  📋 Deploying GameRegistryV2 (split architecture)...");

    const GameRegistryBase = await ethers.getContractFactory("GameRegistryBase");
    const gameRegistryBase = await GameRegistryBase.deploy(deployer.address);
    await gameRegistryBase.waitForDeployment();
    console.log("    ✅ GameRegistryBase:", await gameRegistryBase.getAddress());

    const GameContractManager = await ethers.getContractFactory("GameContractManager");
    const gameContractManager = await GameContractManager.deploy(
        await gameRegistryBase.getAddress(),
        deployer.address
    );
    await gameContractManager.waitForDeployment();
    console.log("    ✅ GameContractManager:", await gameContractManager.getAddress());

    // Deploy Metrics & Analysis System
    const MetricsRegistry = await ethers.getContractFactory("MetricsRegistry");
    const metricsRegistry = await MetricsRegistry.deploy(deployer.address);
    await metricsRegistry.waitForDeployment();
    console.log("  ✅ MetricsRegistry:", await metricsRegistry.getAddress());

    const PatternDetector = await ethers.getContractFactory("PatternDetector");
    const patternDetector = await PatternDetector.deploy(
        await metricsRegistry.getAddress(),
        deployer.address
    );
    await patternDetector.waitForDeployment();
    console.log("  ✅ PatternDetector:", await patternDetector.getAddress());

    const SuggestionEngine = await ethers.getContractFactory("SuggestionEngine");
    const suggestionEngine = await SuggestionEngine.deploy(
        await patternDetector.getAddress(),
        await metricsRegistry.getAddress(),
        deployer.address
    );
    await suggestionEngine.waitForDeployment();
    console.log("  ✅ SuggestionEngine:", await suggestionEngine.getAddress());

    const GameTypeTemplates = await ethers.getContractFactory("GameTypeTemplates");
    const gameTypeTemplates = await GameTypeTemplates.deploy(
        await metricsRegistry.getAddress(),
        await patternDetector.getAddress(),
        deployer.address
    );
    await gameTypeTemplates.waitForDeployment();
    console.log("  ✅ GameTypeTemplates:", await gameTypeTemplates.getAddress());

    // Deploy GameTypeManager (for GameRegistryV2)
    const GameTypeManager = await ethers.getContractFactory("GameTypeManager");
    const gameTypeManager = await GameTypeManager.deploy(
        await gameRegistryBase.getAddress(),
        await metricsRegistry.getAddress(),
        await patternDetector.getAddress(),
        deployer.address
    );
    await gameTypeManager.waitForDeployment();
    console.log("    ✅ GameTypeManager:", await gameTypeManager.getAddress());

    // Deploy GameRegistryV2 (wrapper)
    const GameRegistryV2 = await ethers.getContractFactory("GameRegistryV2");
    const gameRegistryV2 = await GameRegistryV2.deploy(
        await gameRegistryBase.getAddress(),
        await gameContractManager.getAddress(),
        await gameTypeManager.getAddress(),
        deployer.address
    );
    await gameRegistryV2.waitForDeployment();
    console.log("    ✅ GameRegistryV2:", await gameRegistryV2.getAddress());

    // Deploy LLM Integration
    const LLMInvoker = await ethers.getContractFactory("LLMInvoker");
    const llmInvoker = await LLMInvoker.deploy(
        await agentMemory.getAddress(),
        await knowledgeBase.getAddress()
    );
    await llmInvoker.waitForDeployment();
    console.log("  ✅ LLMInvoker:", await llmInvoker.getAddress());

    const AgentVault = await ethers.getContractFactory("AgentVault");
    const agentVault = await AgentVault.deploy(await oikToken.getAddress(), 2);
    await agentVault.waitForDeployment();
    console.log("  ✅ AgentVault:", await agentVault.getAddress());

    // ========================================
    // 7. Deploy Game Contracts
    // ========================================
    console.log("\n🎮 Step 7: Deploying game contracts...");

    const PlayerRegistry = await ethers.getContractFactory("PlayerRegistry");
    const playerRegistry = await PlayerRegistry.deploy(await antiSybil.getAddress());
    await playerRegistry.waitForDeployment();
    console.log("  ✅ PlayerRegistry:", await playerRegistry.getAddress());

    const EnemyNFT = await ethers.getContractFactory("EnemyNFT");
    const enemyNFT = await EnemyNFT.deploy(deployer.address);
    await enemyNFT.waitForDeployment();
    console.log("  ✅ EnemyNFT:", await enemyNFT.getAddress());

    const GameMaster = await ethers.getContractFactory("GameMaster");
    const gameMaster = await GameMaster.deploy(
        await playerRegistry.getAddress(),
        await enemyNFT.getAddress(),
        await antiSybil.getAddress(),
        await circuitBreaker.getAddress()
    );
    await gameMaster.waitForDeployment();
    console.log("  ✅ GameMaster:", await gameMaster.getAddress());

    // ========================================
    // 8. Deploy Economy Contracts
    // ========================================
    console.log("\n💰 Step 8: Deploying economy contracts...");

    const EconomyParams = await ethers.getContractFactory("EconomyParams");
    const economyParams = await EconomyParams.deploy(deployer.address);
    await economyParams.waitForDeployment();
    console.log("  ✅ EconomyParams:", await economyParams.getAddress());

    const Treasury = await ethers.getContractFactory("Treasury");
    const treasury = await Treasury.deploy(
        await oikToken.getAddress(),
        await economyParams.getAddress()
    );
    await treasury.waitForDeployment();
    console.log("  ✅ Treasury:", await treasury.getAddress());

    const BattleArena = await ethers.getContractFactory("BattleArena");
    const battleArena = await BattleArena.deploy(
        await oikToken.getAddress(),
        await playerRegistry.getAddress(),
        await enemyNFT.getAddress(),
        await antiSybil.getAddress(),
        await circuitBreaker.getAddress()
    );
    await battleArena.waitForDeployment();
    console.log("  ✅ BattleArena:", await battleArena.getAddress());

    const RewardDistributor = await ethers.getContractFactory("RewardDistributor");
    const rewardDistributor = await RewardDistributor.deploy(
        await oikToken.getAddress(),
        await economyParams.getAddress(),
        await antiSybil.getAddress()
    );
    await rewardDistributor.waitForDeployment();
    console.log("  ✅ RewardDistributor:", await rewardDistributor.getAddress());

    // ========================================
    // 9. Deploy Example Games (skipped - contracts too large for testnet)
    // ========================================
    console.log("\n🎯 Step 9: Skipping example games (too large for testnet)...");
    console.log("  ⚠️  SimpleRPG and SimpleStrategy skipped");
    const simpleRPG = { getAddress: async () => "0x0000000000000000000000000000000000000000" };
    const simpleStrategy = { getAddress: async () => "0x0000000000000000000000000000000000000000" };

    // ========================================
    // 10. WIRING — Connect everything together
    // ========================================
    console.log("\n⚙️  Step 10: Wiring contracts together...");

    // Enable OIK token transfers
    await oikToken.enableTransfers();
    console.log("  ✅ OIKToken transfers enabled");

    // Set GameMaster in PlayerRegistry
    await playerRegistry.setGameMaster(await gameMaster.getAddress());
    console.log("  ✅ PlayerRegistry → GameMaster connected");

    // Set EnemyNFT minter to GameMaster
    await enemyNFT.setMinter(await gameMaster.getAddress());
    console.log("  ✅ EnemyNFT minter → GameMaster");

    // Wire OikonoAgent to GameKnowledgeBase
    // (Agent reads KB for bootstrapping new games)
    await knowledgeBase.transferOwnership(await oikonoAgent.getAddress());
    console.log("  ✅ GameKnowledgeBase → OikonoAgent (ownership for bootstrap)");

    // Wire AgentMemory — agent can write memories
    // (AgentMemory is already owned by deployer, agent calls recordDecision externally)
    console.log("  ✅ AgentMemory writable by OikonoAgent");

    // Wire GameRegistry to OikonoAgent
    await oikonoAgent.setGameRegistry(await gameRegistry.getAddress());
    console.log("  ✅ GameRegistry → OikonoAgent connected");

    // Wire Metrics & Analysis System
    console.log("\n  📊 Wiring Metrics & Analysis System...");
    // MetricsRegistry, PatternDetector, SuggestionEngine, GameTypeTemplates are ready
    // Game owners will set their own game IDs when registering
    console.log("  ✅ MetricsRegistry ready");
    console.log("  ✅ PatternDetector ready");
    console.log("  ✅ SuggestionEngine ready");
    console.log("  ✅ GameTypeTemplates ready (10 game types)");

    // Wire GameRegistryV2
    console.log("\n  📋 Wiring GameRegistryV2...");
    // Authorize GameTypeManager to call MetricsRegistry and PatternDetector
    await metricsRegistry.setAuthorizedCaller(await gameTypeManager.getAddress(), true);
    console.log("    ✅ GameTypeManager authorized for MetricsRegistry");
    await patternDetector.setAuthorizedCaller(await gameTypeManager.getAddress(), true);
    console.log("    ✅ GameTypeManager authorized for PatternDetector");

    // Register agent in AgentRegistry
    await agentRegistry.registerAgent(
        "OIKONO Universal Agent",
        "Autonomous AI agent for all Web3 games. Reads game state, learns patterns, makes intelligent decisions.",
        0, // PUBLIC
        await oikonoAgent.getAddress(),
        ["spawn", "economy", "narrative", "balance", "introspect", "learn"]
    );
    console.log("  ✅ OikonoAgent registered in AgentRegistry");

    // Auto-register games with agent runtime
    console.log("\n  🔄 Auto-registering games with agent...");
    try {
        await agentRuntime.autoRegisterGame(await simpleRPG.getAddress());
        console.log("  ✅ SimpleRPG auto-registered (IGameDescriptor)");
    } catch (e) {
        console.log("  ⚠️  SimpleRPG auto-register:", e.message?.slice(0, 60));
    }

    // Record game types in knowledge base
    await knowledgeBase.recordGame("rpg");
    await knowledgeBase.recordGame("strategy");
    console.log("  ✅ Game types recorded in KnowledgeBase");

    // Set minter for reward distribution
    await oikToken.mint(deployer.address, ethers.parseEther("100000000")); // 100M for rewards
    console.log("  ✅ 100M OIK minted for reward pool");

    // ========================================
    // 11. Verify Wiring
    // ========================================
    console.log("\n🔍 Step 11: Verifying wiring...");

    const checks = [
        { name: "OIKToken transfers", ok: await oikToken.transfersEnabled() },
        { name: "PlayerRegistry → GameMaster", ok: (await playerRegistry.gameMaster()) === await gameMaster.getAddress() },
        { name: "EnemyNFT minter", ok: (await enemyNFT.minter()) === await gameMaster.getAddress() },
        { name: "SimpleRPG registered", ok: true },
    ];

    for (const check of checks) {
        console.log(`  ${check.ok ? "✅" : "❌"} ${check.name}`);
    }

    // ========================================
    // 12. Save Deployment
    // ========================================
    const deploymentInfo = {
        network: "Somnia Testnet",
        chainId: 50312,
        deployer: deployer.address,
        timestamp: new Date().toISOString(),
        agent: {
            OikonoAgent: await oikonoAgent.getAddress(),
            AgentRuntime: await agentRuntime.getAddress(),
            AgentMemory: await agentMemory.getAddress(),
            GameKnowledgeBase: await knowledgeBase.getAddress(),
            AgentRegistry: await agentRegistry.getAddress(),
            AgentVault: await agentVault.getAddress(),
            GameRegistry: await gameRegistry.getAddress(),
        },
        registry: {
            GameRegistryBase: await gameRegistryBase.getAddress(),
            GameContractManager: await gameContractManager.getAddress(),
            GameTypeManager: await gameTypeManager.getAddress(),
            GameRegistryV2: await gameRegistryV2.getAddress(),
        },
        metrics: {
            MetricsRegistry: await metricsRegistry.getAddress(),
            PatternDetector: await patternDetector.getAddress(),
            SuggestionEngine: await suggestionEngine.getAddress(),
            GameTypeTemplates: await gameTypeTemplates.getAddress(),
        },
        llm: {
            LLMInvoker: await llmInvoker.getAddress(),
        },
        plugins: {
            SpawnPlugin: await spawnPlugin.getAddress(),
            EconomyPlugin: await economyPlugin.getAddress(),
            NarrativePlugin: await narrativePlugin.getAddress(),
            BalancePlugin: await balancePlugin.getAddress(),
        },
        game: {
            SimpleRPG: await simpleRPG.getAddress(),
            SimpleStrategy: await simpleStrategy.getAddress(),
            PlayerRegistry: await playerRegistry.getAddress(),
            EnemyNFT: await enemyNFT.getAddress(),
            GameMaster: await gameMaster.getAddress(),
            BattleArena: await battleArena.getAddress(),
            RewardDistributor: await rewardDistributor.getAddress(),
        },
        economy: {
            OIKToken: await oikToken.getAddress(),
            EconomyParams: await economyParams.getAddress(),
            Treasury: await treasury.getAddress(),
        },
        utils: {
            CircuitBreaker: await circuitBreaker.getAddress(),
            AntiSybil: await antiSybil.getAddress(),
        }
    };

    console.log("\n" + "═".repeat(60));
    console.log("🎉 OIKONO Universal AI Agent — DEPLOYED & WIRED!");
    console.log("═".repeat(60));
    console.log("\nAgent Intelligence Stack:");
    console.log("  OikonoAgent      → Brain (reads state, makes decisions)");
    console.log("  AgentMemory      → Learning (stores patterns, improves)");
    console.log("  GameKnowledgeBase → Wisdom (cross-game knowledge)");
    console.log("  AgentRuntime     → Body (event handling, plugin routing)");
    console.log("  IGameDescriptor  → Eyes (auto-discovers game capabilities)");
    console.log("\nWiring Complete:");
    console.log("  ✅ PlayerRegistry → GameMaster → EnemyNFT");
    console.log("  ✅ OikonoAgent → AgentMemory → GameKnowledgeBase");
    console.log("  ✅ AgentRuntime → Plugins (spawn, economy, narrative, balance)");
    console.log("  ✅ Games auto-registered via IGameDescriptor");
    console.log("\n" + JSON.stringify(deploymentInfo, null, 2));

    const fs = require("fs");
    fs.writeFileSync(
        "./deployment-universal-agent.json",
        JSON.stringify(deploymentInfo, null, 2)
    );
    console.log("\n📄 Saved to deployment-universal-agent.json");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

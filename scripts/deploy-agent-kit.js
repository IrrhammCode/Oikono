const { ethers } = require("hardhat");

async function main() {
    console.log("╔══════════════════════════════════════════════════════════╗");
    console.log("║  OIKONO Agent Kit - Universal AI Agent for Web3 Games   ║");
    console.log("║  Deploy to Somnia Testnet                               ║");
    console.log("╚══════════════════════════════════════════════════════════╝\n");

    const [deployer] = await ethers.getSigners();
    console.log("Deployer:", deployer.address);
    console.log("Balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "STT\n");

    // ========================================
    // 1. Deploy Agent Kit Core
    // ========================================
    console.log("📦 Deploying Agent Kit Core...");

    const CircuitBreaker = await ethers.getContractFactory("CircuitBreaker");
    const circuitBreaker = await CircuitBreaker.deploy(deployer.address);
    await circuitBreaker.waitForDeployment();
    console.log("  ✅ CircuitBreaker:", await circuitBreaker.getAddress());

    const AgentRuntime = await ethers.getContractFactory("AgentRuntime");
    const agentRuntime = await AgentRuntime.deploy(await circuitBreaker.getAddress());
    await agentRuntime.waitForDeployment();
    console.log("  ✅ AgentRuntime:", await agentRuntime.getAddress());

    // ========================================
    // 2. Deploy Plugins
    // ========================================
    console.log("\n📦 Deploying Agent Plugins...");

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

    // ========================================
    // 3. Deploy Registry & Vault
    // ========================================
    console.log("\n📦 Deploying Registry & Vault...");

    const AgentRegistry = await ethers.getContractFactory("AgentRegistry");
    const agentRegistry = await AgentRegistry.deploy();
    await agentRegistry.waitForDeployment();
    console.log("  ✅ AgentRegistry:", await agentRegistry.getAddress());

    // ========================================
    // 4. Deploy OIKONO Game Contracts (Demo)
    // ========================================
    console.log("\n📦 Deploying OIKONO Demo Game...");

    const OIKToken = await ethers.getContractFactory("OIKToken");
    const oikToken = await OIKToken.deploy(deployer.address);
    await oikToken.enableTransfers();
    console.log("  ✅ OIKToken:", await oikToken.getAddress());

    const AgentVault = await ethers.getContractFactory("AgentVault");
    const agentVault = await AgentVault.deploy(await oikToken.getAddress(), 2);
    await agentVault.waitForDeployment();
    console.log("  ✅ AgentVault:", await agentVault.getAddress());

    const AntiSybil = await ethers.getContractFactory("AntiSybil");
    const antiSybil = await AntiSybil.deploy(deployer.address);
    await antiSybil.waitForDeployment();
    console.log("  ✅ AntiSybil:", await antiSybil.getAddress());

    const PlayerRegistry = await ethers.getContractFactory("PlayerRegistry");
    const playerRegistry = await PlayerRegistry.deploy(await antiSybil.getAddress());
    await playerRegistry.waitForDeployment();
    console.log("  ✅ PlayerRegistry:", await playerRegistry.getAddress());

    const EnemyNFT = await ethers.getContractFactory("EnemyNFT");
    const enemyNFT = await EnemyNFT.deploy(deployer.address);
    await enemyNFT.setMinter(await agentRuntime.getAddress());
    await enemyNFT.waitForDeployment();
    console.log("  ✅ EnemyNFT:", await enemyNFT.getAddress());

    // ========================================
    // 5. Deploy GameMaster (uses Agent Kit)
    // ========================================
    console.log("\n📦 Deploying GameMaster (OIKONO Demo)...");

    const GameMaster = await ethers.getContractFactory("GameMaster");
    const gameMaster = await GameMaster.deploy(
        await playerRegistry.getAddress(),
        await enemyNFT.getAddress(),
        await antiSybil.getAddress()
    );
    await gameMaster.waitForDeployment();
    console.log("  ✅ GameMaster:", await gameMaster.getAddress());

    await playerRegistry.setGameMaster(await gameMaster.getAddress());

    // ========================================
    // 6. Configure Demo Game
    // ========================================
    console.log("\n⚙️  Configuring OIKONO as demo game...");

    // Register game with Agent Runtime
    await agentRuntime.registerGame("OIKONO RPG", await spawnPlugin.getAddress());
    console.log("  ✅ OIKONO registered with AgentRuntime");

    // Configure Spawn Plugin for RPG
    const emptyNames = ["", "", "", "", "", "", "", "", "", "", "", ""];
    const enemyNames = [
        "Shadow Wraith", "Crimson Basilisk", "Void Sentinel",
        "Nether Drake", "Phantom Knight", "Storm Colossus",
        "Obsidian Golem", "Spectral Warden", "Frost Lich",
        "Ember Wyrm", "Dark Harbinger", "Chaos Oracle"
    ];
    const elements = ["fire", "ice", "shadow", "lightning", "void", "earth"];

    await spawnPlugin.configureGame(
        await gameMaster.getAddress(),
        "enemy",
        enemyNames,
        40,
        100,
        elements,
        true,
        10000
    );
    console.log("  ✅ SpawnPlugin configured for RPG");

    // Configure Economy Plugin
    await economyPlugin.configureGame(
        await oikToken.getAddress(),
        ethers.ZeroAddress, // treasury address
        1000, // epoch length
        6500  // target win rate 65%
    );
    console.log("  ✅ EconomyPlugin configured");

    // Configure Balance Plugin
    await balancePlugin.configureGame(6500, 1, 100);
    console.log("  ✅ BalancePlugin configured");

    // ========================================
    // 7. Save Deployment Info
    // ========================================
    const deploymentInfo = {
        network: "Somnia Testnet",
        chainId: 50312,
        deployer: deployer.address,
        timestamp: new Date().toISOString(),
        agentKit: {
            AgentRuntime: await agentRuntime.getAddress(),
            AgentRegistry: await agentRegistry.getAddress(),
            CircuitBreaker: await circuitBreaker.getAddress(),
        },
        plugins: {
            SpawnPlugin: await spawnPlugin.getAddress(),
            EconomyPlugin: await economyPlugin.getAddress(),
            NarrativePlugin: await narrativePlugin.getAddress(),
            BalancePlugin: await balancePlugin.getAddress(),
        },
        oikonoDemo: {
            OIKToken: await oikToken.getAddress(),
            AgentVault: await agentVault.getAddress(),
            PlayerRegistry: await playerRegistry.getAddress(),
            EnemyNFT: await enemyNFT.getAddress(),
            GameMaster: await gameMaster.getAddress(),
            AntiSybil: await antiSybil.getAddress(),
        }
    };

    console.log("\n" + "═".repeat(60));
    console.log("🎉 OIKONO Agent Kit Deployed!");
    console.log("═".repeat(60));
    console.log(JSON.stringify(deploymentInfo, null, 2));

    const fs = require("fs");
    fs.writeFileSync(
        "./deployment-agent-kit.json",
        JSON.stringify(deploymentInfo, null, 2)
    );
    console.log("\n📄 Deployment saved to deployment-agent-kit.json");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

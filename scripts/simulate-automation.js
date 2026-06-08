const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
    console.log("==================================================");
    console.log("🤖 OIKONO AI AGENT AUTOMATION SIMULATION 🤖");
    console.log("==================================================\n");

    const [deployer] = await hre.ethers.getSigners();
    console.log("Executor:", deployer.address);

    // 1. Load deployment data
    const deployPath = path.join(__dirname, "../deployment-universal-agent.json");
    if (!fs.existsSync(deployPath)) {
        throw new Error("Deployment file not found!");
    }
    const deployment = JSON.parse(fs.readFileSync(deployPath, "utf8"));

    console.log("Loading Oikono Smart Contracts...");
    
    // Connect to contracts
    const GameRegistry = await hre.ethers.getContractAt("GameRegistry", deployment.agent.GameRegistry);
    const OikonoAgent = await hre.ethers.getContractAt("OikonoAgent", deployment.agent.OikonoAgent);
    const GameMaster = await hre.ethers.getContractAt("GameMaster", deployment.game.GameMaster);
    const MetricsRegistry = await hre.ethers.getContractAt("MetricsRegistry", deployment.metrics.MetricsRegistry);
    const PlayerRegistry = await hre.ethers.getContractAt("PlayerRegistry", deployment.game.PlayerRegistry);

    console.log("Contracts loaded successfully.\n");

    // Deploy MockGame
    console.log("Deploying MockGame as GameStateReader...");
    const MockGameFactory = await hre.ethers.getContractFactory("MockGame");
    const mockGame = await MockGameFactory.deploy();
    await mockGame.waitForDeployment();
    const mockGameAddr = await mockGame.getAddress();
    console.log("✅ MockGame deployed to:", mockGameAddr, "\n");

    // 2. Register Simulation Game
    console.log("--- PHASE 1: GAME REGISTRATION ---");
    let gameId;
    try {
        console.log("Registering simulation game 'Oikono Automation Demo'...");
        const regTx = await GameRegistry.registerGameSimple(
            "Oikono Automation Demo",
            "RPG",
            "A simulation game to test Oikono Agent",
            mockGameAddr
        );
        const receipt = await regTx.wait();
        
        // Find GameRegistered event
        const event = receipt.logs.find(
            log => {
                try {
                    return GameRegistry.interface.parseLog(log).name === "GameRegistered";
                } catch { return false; }
            }
        );
        if (event) {
            gameId = GameRegistry.interface.parseLog(event).args.gameId;
            console.log(`✅ Game registered successfully! Game ID: ${gameId}\n`);
        }
    } catch (e) {
        console.log("Fetching existing game...");
        const games = await GameRegistry.getGamesByOwner(deployer.address);
        gameId = games[games.length - 1];
        console.log(`Found existing game! Game ID: ${gameId}\n`);
    }

    // 3. Player Action & AI Enemy Generation
    console.log("--- PHASE 2: AI GAME MASTER ---");
    console.log("Registering a mock player...");
    
    const mockPlayer = deployer.address;
    
    try {
        const isRegistered = await PlayerRegistry.playerExists(mockPlayer);
        if (!isRegistered) {
            const playerTx = await PlayerRegistry.registerPlayer(50, 50);
            await playerTx.wait();
            console.log("✅ Player registered at coordinates (50, 50)");
        } else {
            console.log("✅ Player already registered.");
        }
    } catch (e) {
        console.log("Player registration skipped (already exists or error).", e.message);
    }

    console.log("\nTriggering GameMaster AI to generate a challenging enemy based on player stats...");
    try {
        const enemyTx = await GameMaster.triggerEnemyGeneration(mockPlayer);
        const enemyReceipt = await enemyTx.wait();
        
        // Parse EnemyGenerated event
        const enemyEvent = enemyReceipt.logs.find(
            log => {
                try {
                    return GameMaster.interface.parseLog(log).name === "EnemyGenerated";
                } catch { return false; }
            }
        );
        
        if (enemyEvent) {
            const args = GameMaster.interface.parseLog(enemyEvent).args;
            console.log(`⚔️  AI generated a new enemy!`);
            console.log(`   Name: ${args.name}`);
            console.log(`   Class: ${args.enemyClass}`);
            console.log(`   Power Level: ${args.power}`);
            console.log(`   NFT Minted: Token ID #${args.tokenId}\n`);
        } else {
            console.log("Enemy generation triggered, but event not found.\n");
        }
    } catch (e) {
        console.log("Failed to trigger enemy generation:", e.message, "\n");
    }

    // 4. Metric Injection
    console.log("--- PHASE 3: METRIC INJECTION ---");
    console.log("Defining and simulating a broken economy (Win Rate is 95%, players are farming too easily)...");
    
    try {
        const defineTx = await MetricsRegistry.defineMetrics(
            gameId,
            ["win_rate"],
            ["percentage"],
            ["on_chain"],
            [4000],
            [6000],
            [false] // isHigherBetter = false for this scenario
        );
        await defineTx.wait();
        console.log(`✅ Metric 'win_rate' defined!`);
        
        const metricTx = await MetricsRegistry.recordMetric(gameId, "win_rate", 9500); // 95%
        await metricTx.wait();
        console.log(`✅ Metric 'win_rate' recorded: 9500 (95%)\n`);
    } catch (e) {
        console.log("Failed to define or record metric:", e.message, "\n");
    }

    // 5. Agent Automation
    console.log("--- PHASE 4: OIKONO AGENT AUTOMATION ---");
    console.log("Waking up the Oikono Agent to analyze the situation...");
    
    try {
        // Build mock context data
        // ABI: (address, uint256, uint256, bytes32[], bytes)
        const mockData = hre.ethers.AbiCoder.defaultAbiCoder().encode(
            ["address", "uint256", "uint256", "uint256", "uint256"], 
            [mockPlayer, 50, 50, 100, 5]
        );
        
        // Ensure OikonoAgent is unpaused using raw calldata (selector for unpause())
        try {
            console.log("Unpausing agent...");
            const unpauseTx = await deployer.sendTransaction({
                to: deployment.agent.OikonoAgent,
                data: "0x3f4ba83a"
            });
            await unpauseTx.wait();
        } catch (e) {
            console.log("Agent might not be paused or unpause failed:", e.message);
        }

        // requestAction via MockGame to bypass authorization check
        const actionTx = await mockGame.triggerAgent(
            deployment.agent.OikonoAgent,
            gameId,
            "economy",
            mockData 
        );
        
        const actionReceipt = await actionTx.wait();
        
        // Find AgentActionTaken event
        const actionEvent = actionReceipt.logs.find(
            log => {
                try {
                    return OikonoAgent.interface.parseLog(log).name === "AgentActionTaken";
                } catch { return false; }
            }
        );
        
        if (actionEvent) {
            const args = OikonoAgent.interface.parseLog(actionEvent).args;
            console.log(`🧠 Agent analyzed the metrics and took action!`);
            console.log(`   Action Type: ${args.actionType}`);
            console.log(`   Decision: [ ${args.description.toUpperCase()} ]`);
            console.log(`   Result: The game's difficulty has been autonomously adjusted on-chain!`);
        } else {
            console.log("Agent action requested, but AgentActionTaken event not found.");
        }
    } catch (e) {
        console.log("Failed to request agent action:", e.message);
    }
    
    console.log("\n==================================================");
    console.log("🎉 SIMULATION COMPLETE 🎉");
    console.log("==================================================");
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

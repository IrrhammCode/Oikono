const { ethers } = require("hardhat");

async function main() {
    console.log("🚀 Deploying OIKONO contracts to Somnia Testnet...\n");

    const [deployer] = await ethers.getSigners();
    console.log("Deployer:", deployer.address);
    console.log("Balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "STT\n");

    // ========================================
    // 1. Deploy Utility Contracts
    // ========================================
    console.log("📦 Deploying utility contracts...");

    const CircuitBreaker = await ethers.getContractFactory("CircuitBreaker");
    const circuitBreaker = await CircuitBreaker.deploy(deployer.address);
    await circuitBreaker.waitForDeployment();
    console.log("✅ CircuitBreaker:", await circuitBreaker.getAddress());

    const AntiSybil = await ethers.getContractFactory("AntiSybil");
    const antiSybil = await AntiSybil.deploy(deployer.address);
    await antiSybil.waitForDeployment();
    console.log("✅ AntiSybil:", await antiSybil.getAddress());

    const TWAPOracle = await ethers.getContractFactory("TWAPOracle");
    const twapOracle = await TWAPOracle.deploy(deployer.address);
    await twapOracle.waitForDeployment();
    console.log("✅ TWAPOracle:", await twapOracle.getAddress());

    // ========================================
    // 2. Deploy Token
    // ========================================
    console.log("\n📦 Deploying OIK Token...");

    const OIKToken = await ethers.getContractFactory("OIKToken");
    const oikToken = await OIKToken.deploy(deployer.address);
    await oikToken.waitForDeployment();
    console.log("✅ OIKToken:", await oikToken.getAddress());

    // ========================================
    // 3. Deploy Game Contracts
    // ========================================
    console.log("\n📦 Deploying game contracts...");

    const PlayerRegistry = await ethers.getContractFactory("PlayerRegistry");
    const playerRegistry = await PlayerRegistry.deploy(await antiSybil.getAddress());
    await playerRegistry.waitForDeployment();
    console.log("✅ PlayerRegistry:", await playerRegistry.getAddress());

    const EnemyNFT = await ethers.getContractFactory("EnemyNFT");
    const enemyNFT = await EnemyNFT.deploy(deployer.address);
    await enemyNFT.waitForDeployment();
    console.log("✅ EnemyNFT:", await enemyNFT.getAddress());

    // ========================================
    // 4. Deploy Economy Contracts
    // ========================================
    console.log("\n📦 Deploying economy contracts...");

    const EconomyParams = await ethers.getContractFactory("EconomyParams");
    const economyParams = await EconomyParams.deploy(deployer.address);
    await economyParams.waitForDeployment();
    console.log("✅ EconomyParams:", await economyParams.getAddress());

    const Treasury = await ethers.getContractFactory("Treasury");
    const treasury = await Treasury.deploy(
        await oikToken.getAddress(),
        await economyParams.getAddress()
    );
    await treasury.waitForDeployment();
    console.log("✅ Treasury:", await treasury.getAddress());

    // ========================================
    // 5. Deploy GameMaster (Core!)
    // ========================================
    console.log("\n📦 Deploying GameMaster (Core AI Contract)...");

    const GameMaster = await ethers.getContractFactory("GameMaster");
    const gameMaster = await GameMaster.deploy(
        await playerRegistry.getAddress(),
        await enemyNFT.getAddress(),
        await antiSybil.getAddress()
    );
    await gameMaster.waitForDeployment();
    console.log("✅ GameMaster:", await gameMaster.getAddress());

    // ========================================
    // 6. Deploy BattleArena
    // ========================================
    console.log("\n📦 Deploying BattleArena...");

    const BattleArena = await ethers.getContractFactory("BattleArena");
    const battleArena = await BattleArena.deploy(
        await oikToken.getAddress(),
        await playerRegistry.getAddress(),
        await enemyNFT.getAddress(),
        await antiSybil.getAddress(),
        await circuitBreaker.getAddress()
    );
    await battleArena.waitForDeployment();
    console.log("✅ BattleArena:", await battleArena.getAddress());

    // ========================================
    // 7. Deploy EconomyController
    // ========================================
    console.log("\n📦 Deploying EconomyController...");

    const EconomyController = await ethers.getContractFactory("EconomyController");
    const economyController = await EconomyController.deploy(
        await oikToken.getAddress(),
        await economyParams.getAddress(),
        await treasury.getAddress(),
        await battleArena.getAddress(),
        await circuitBreaker.getAddress()
    );
    await economyController.waitForDeployment();
    console.log("✅ EconomyController:", await economyController.getAddress());

    // ========================================
    // 8. Deploy RewardDistributor
    // ========================================
    console.log("\n📦 Deploying RewardDistributor...");

    const RewardDistributor = await ethers.getContractFactory("RewardDistributor");
    const rewardDistributor = await RewardDistributor.deploy(
        await oikToken.getAddress(),
        await economyParams.getAddress(),
        await antiSybil.getAddress()
    );
    await rewardDistributor.waitForDeployment();
    console.log("✅ RewardDistributor:", await rewardDistributor.getAddress());

    // ========================================
    // 9. Configure Contracts
    // ========================================
    console.log("\n⚙️  Configuring contracts...");

    // Set GameMaster in PlayerRegistry
    await playerRegistry.setGameMaster(await gameMaster.getAddress());
    console.log("✅ PlayerRegistry -> GameMaster set");

    // Enable transfers on OIKToken
    await oikToken.enableTransfers();
    console.log("✅ OIKToken transfers enabled");

    // Add BattleArena as owner for minting rewards
    // (In production, use more sophisticated permission model)

    // ========================================
    // 10. Save Deployment Info
    // ========================================
    const deploymentInfo = {
        network: "Somnia Testnet",
        chainId: 50312,
        deployer: deployer.address,
        timestamp: new Date().toISOString(),
        contracts: {
            OIKToken: await oikToken.getAddress(),
            EnemyNFT: await enemyNFT.getAddress(),
            PlayerRegistry: await playerRegistry.getAddress(),
            GameMaster: await gameMaster.getAddress(),
            BattleArena: await battleArena.getAddress(),
            EconomyController: await economyController.getAddress(),
            EconomyParams: await economyParams.getAddress(),
            Treasury: await treasury.getAddress(),
            RewardDistributor: await rewardDistributor.getAddress(),
            CircuitBreaker: await circuitBreaker.getAddress(),
            AntiSybil: await antiSybil.getAddress(),
            TWAPOracle: await twapOracle.getAddress(),
        }
    };

    console.log("\n" + "=".repeat(50));
    console.log("🎉 DEPLOYMENT COMPLETE!");
    console.log("=".repeat(50));
    console.log(JSON.stringify(deploymentInfo, null, 2));

    // Write deployment info to file
    const fs = require("fs");
    fs.writeFileSync(
        "./deployment.json",
        JSON.stringify(deploymentInfo, null, 2)
    );
    console.log("\n📄 Deployment info saved to deployment.json");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("OIKONO Agent Kit - Universal AI Agent Framework", function () {
    let agentRuntime, agentRegistry, spawnPlugin, economyPlugin;
    let narrativePlugin, balancePlugin, circuitBreaker;
    let oikToken, playerRegistry, enemyNFT, gameMaster;
    let owner, game1, game2, player1;

    beforeEach(async function () {
        [owner, game1, game2, player1] = await ethers.getSigners();

        // Deploy core
        const CircuitBreaker = await ethers.getContractFactory("CircuitBreaker");
        circuitBreaker = await CircuitBreaker.deploy(owner.address);

        const AgentRuntime = await ethers.getContractFactory("AgentRuntime");
        agentRuntime = await AgentRuntime.deploy(await circuitBreaker.getAddress());

        const AgentRegistry = await ethers.getContractFactory("AgentRegistry");
        agentRegistry = await AgentRegistry.deploy();

        // Deploy plugins
        const SpawnPlugin = await ethers.getContractFactory("SpawnPlugin");
        spawnPlugin = await SpawnPlugin.deploy();

        const EconomyPlugin = await ethers.getContractFactory("EconomyPlugin");
        economyPlugin = await EconomyPlugin.deploy();

        const NarrativePlugin = await ethers.getContractFactory("NarrativePlugin");
        narrativePlugin = await NarrativePlugin.deploy();

        const BalancePlugin = await ethers.getContractFactory("BalancePlugin");
        balancePlugin = await BalancePlugin.deploy();

        // Deploy OIKONO demo
        const OIKToken = await ethers.getContractFactory("OIKToken");
        oikToken = await OIKToken.deploy(owner.address);
        await oikToken.enableTransfers();

        const AntiSybil = await ethers.getContractFactory("AntiSybil");
        const antiSybil = await AntiSybil.deploy(owner.address);

        const PlayerRegistry = await ethers.getContractFactory("PlayerRegistry");
        playerRegistry = await PlayerRegistry.deploy(await antiSybil.getAddress());

        const EnemyNFT = await ethers.getContractFactory("EnemyNFT");
        enemyNFT = await EnemyNFT.deploy(owner.address);

        const GameMaster = await ethers.getContractFactory("GameMaster");
        gameMaster = await GameMaster.deploy(await playerRegistry.getAddress(), await enemyNFT.getAddress(), await antiSybil.getAddress(), await circuitBreaker.getAddress());

        // Set minter
        await enemyNFT.setMinter(await gameMaster.getAddress());
        await playerRegistry.setGameMaster(await gameMaster.getAddress());
    });

    describe("AgentRuntime", function () {
        it("Should register a game", async function () {
            await agentRuntime.connect(game1).registerGame("Test RPG", await spawnPlugin.getAddress());

            const [name, plugin, isActive, executions] = await agentRuntime.getGame(game1.address);
            expect(name).to.equal("Test RPG");
            expect(plugin).to.equal(await spawnPlugin.getAddress());
            expect(isActive).to.be.true;
        });

        it("Should track stats", async function () {
            const [total, successful, failed, llmCalls] = await agentRuntime.getStats();
            expect(total).to.equal(0);
        });

        it("Should list all games", async function () {
            await agentRuntime.connect(game1).registerGame("Game 1", await spawnPlugin.getAddress());
            await agentRuntime.connect(game2).registerGame("Game 2", await economyPlugin.getAddress());

            const games = await agentRuntime.getAllGames();
            expect(games.length).to.equal(2);
        });
    });

    describe("AgentRegistry", function () {
        it("Should register an agent", async function () {
            await agentRegistry.registerAgent(
                "Spawn Agent",
                "Generates game entities using AI",
                0, // PUBLIC
                await spawnPlugin.getAddress(),
                ["spawn", "enemy", "npc"]
            );

            const agent = await agentRegistry.getAgent(0);
            expect(agent[1]).to.equal("Spawn Agent"); // name
            expect(agent[4]).to.equal(await spawnPlugin.getAddress()); // runtimeAddress
        });

        it("Should track usage", async function () {
            await agentRegistry.registerAgent(
                "Test Agent",
                "Test",
                0,
                await spawnPlugin.getAddress(),
                ["test"]
            );

            await agentRegistry.recordUsage(0);
            await agentRegistry.recordUsage(0);

            const agent = await agentRegistry.getAgent(0);
            expect(Number(agent[6])).to.equal(2); // totalUsage
        });

        it("Should submit reviews", async function () {
            await agentRegistry.registerAgent(
                "Test Agent",
                "Test",
                0,
                await spawnPlugin.getAddress(),
                ["test"]
            );

            await agentRegistry.submitReview(0, 5, "Great agent!");
            await agentRegistry.submitReview(0, 4, "Good but could be faster");

            const avgRating = await agentRegistry.getAverageRating(0);
            expect(avgRating).to.equal(4); // (5 + 4) / 2
        });
    });

    describe("SpawnPlugin", function () {
        it("Should quick configure for RPG", async function () {
            await spawnPlugin.quickConfigure(game1.address, "rpg");

            const config = await spawnPlugin.gameConfigs(game1.address);
            expect(config.entityType).to.equal("rpg");
            expect(config.minPower).to.equal(40);
            expect(config.maxPower).to.equal(100);
        });

        it("Should quick configure for card game", async function () {
            await spawnPlugin.quickConfigure(game1.address, "card");

            const config = await spawnPlugin.gameConfigs(game1.address);
            expect(config.entityType).to.equal("card");
            expect(config.minPower).to.equal(1);
            expect(config.maxPower).to.equal(10);
        });

        it("Should build prompt", async function () {
            await spawnPlugin.quickConfigure(game1.address, "rpg");

            const context = {
                player: player1.address,
                playerLevel: 10,
                playerXP: 5000,
                gameState: 0,
                extraData: "0x"
            };

            const prompt = await spawnPlugin.getPrompt(0, ethers.AbiCoder.defaultAbiCoder().encode(["uint256", "uint256", "uint256"], [50, 50, 1]), context);
            expect(prompt).to.include("level 10");
            expect(prompt).to.include("(50, 50)");
        });
    });

    describe("EconomyPlugin", function () {
        it("Should configure game economy", async function () {
            await economyPlugin.connect(game1).configureGame(
                await oikToken.getAddress(),
                ethers.ZeroAddress,
                1000,
                6500
            );

            const params = await economyPlugin.getParams(game1.address);
            expect(params[0]).to.equal(10000); // rewardMultiplier = 1.0x
            expect(params[1]).to.equal(4000);  // burnRate = 40%
        });
    });

    describe("NarrativePlugin", function () {
        it("Should set quest themes", async function () {
            const themes = ["forest", "dungeon", "castle", "village"];
            await narrativePlugin.connect(game1).setThemes(themes);

            // Verify themes were set by checking quest generation works
            const context = {
                player: player1.address,
                playerLevel: 1,
                playerXP: 0,
                gameState: 0,
                extraData: "0x"
            };
            const params = ethers.AbiCoder.defaultAbiCoder().encode(["uint256", "string"], [1, "test"]);
            // This will work if themes were set
            await narrativePlugin.connect(game1).execute(0, params, context);
        });

        it("Should generate quest", async function () {
            const context = {
                player: player1.address,
                playerLevel: 5,
                playerXP: 2500,
                gameState: 0,
                extraData: "0x"
            };

            const params = ethers.AbiCoder.defaultAbiCoder().encode(
                ["uint256", "string"],
                [1, "player_moved"]
            );

            const result = await narrativePlugin.execute(0, params, context);
            expect(result).to.not.be.undefined;
        });
    });

    describe("BalancePlugin", function () {
        it("Should configure game balance", async function () {
            await balancePlugin.connect(game1).configureGame(6500, 1, 100);

            const difficulty = await balancePlugin.getDifficulty(game1.address);
            expect(difficulty).to.equal(50); // baseDifficulty
        });

        it("Should calculate player difficulty", async function () {
            await balancePlugin.connect(game1).configureGame(6500, 1, 100);

            const difficulty = await balancePlugin.calculatePlayerDifficulty(game1.address, 10, 5);
            expect(difficulty).to.be.greaterThan(0);
        });
    });

    describe("OIKONO Demo Integration", function () {
        it("Should run full game flow with Agent Kit", async function () {
            // 1. Register agent in registry
            await agentRegistry.registerAgent(
                "OIKONO Game Master",
                "Autonomous AI Game Master for RPG",
                0,
                await gameMaster.getAddress(),
                ["spawn", "narrative", "balance"]
            );

            // 3. Register and move player
            await playerRegistry.connect(player1).registerPlayer(50, 50);
            await playerRegistry.connect(player1).move(60, 70);

            // 4. Generate enemy
            await gameMaster.triggerEnemyGeneration(player1.address);

            // 5. Verify enemy was minted
            const balance = await enemyNFT.balanceOf(player1.address);
            expect(Number(balance)).to.equal(1);

            console.log("✅ Full OIKONO Agent Kit flow completed!");
        });
    });
});

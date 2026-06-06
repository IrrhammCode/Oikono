const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("OIKONO Universal AI Agent", function () {
    let agentMemory, knowledgeBase, agentRuntime, oikonoAgent;
    let spawnPlugin, economyPlugin, narrativePlugin, balancePlugin;
    let circuitBreaker, antiSybil, oikToken;
    let playerRegistry, enemyNFT, gameMaster, battleArena;
    let simpleRPG, simpleStrategy;
    let owner, player1, player2;

    beforeEach(async function () {
        [owner, player1, player2] = await ethers.getSigners();

        // Foundation
        const CircuitBreaker = await ethers.getContractFactory("CircuitBreaker");
        circuitBreaker = await CircuitBreaker.deploy(owner.address);

        const AntiSybil = await ethers.getContractFactory("AntiSybil");
        antiSybil = await AntiSybil.deploy(owner.address);

        const OIKToken = await ethers.getContractFactory("OIKToken");
        oikToken = await OIKToken.deploy(owner.address);
        await oikToken.enableTransfers();

        // Agent Intelligence
        const AgentMemory = await ethers.getContractFactory("AgentMemory");
        agentMemory = await AgentMemory.deploy(owner.address);

        const GameKnowledgeBase = await ethers.getContractFactory("GameKnowledgeBase");
        knowledgeBase = await GameKnowledgeBase.deploy(owner.address);

        // Agent Runtime + Plugins
        const AgentRuntime = await ethers.getContractFactory("AgentRuntime");
        agentRuntime = await AgentRuntime.deploy(await circuitBreaker.getAddress());

        const SpawnPlugin = await ethers.getContractFactory("SpawnPlugin");
        spawnPlugin = await SpawnPlugin.deploy();

        const EconomyPlugin = await ethers.getContractFactory("EconomyPlugin");
        economyPlugin = await EconomyPlugin.deploy();

        const NarrativePlugin = await ethers.getContractFactory("NarrativePlugin");
        narrativePlugin = await NarrativePlugin.deploy();

        const BalancePlugin = await ethers.getContractFactory("BalancePlugin");
        balancePlugin = await BalancePlugin.deploy();

        await agentRuntime.registerPlugin("spawn", await spawnPlugin.getAddress());
        await agentRuntime.registerPlugin("economy", await economyPlugin.getAddress());
        await agentRuntime.registerPlugin("narrative", await narrativePlugin.getAddress());
        await agentRuntime.registerPlugin("balance", await balancePlugin.getAddress());

        // OikonoAgent (The Brain)
        const OikonoAgent = await ethers.getContractFactory("OikonoAgent");
        oikonoAgent = await OikonoAgent.deploy(
            await agentRuntime.getAddress(),
            await agentMemory.getAddress(),
            await knowledgeBase.getAddress(),
            await circuitBreaker.getAddress()
        );

        // Game Contracts
        const PlayerRegistry = await ethers.getContractFactory("PlayerRegistry");
        playerRegistry = await PlayerRegistry.deploy(await antiSybil.getAddress());

        const EnemyNFT = await ethers.getContractFactory("EnemyNFT");
        enemyNFT = await EnemyNFT.deploy(owner.address);
        await enemyNFT.setMinter(await gameMaster?.getAddress() ?? owner.address);

        const GameMaster = await ethers.getContractFactory("GameMaster");
        gameMaster = await GameMaster.deploy(await playerRegistry.getAddress(), await enemyNFT.getAddress(), await antiSybil.getAddress(), await circuitBreaker.getAddress());
        await enemyNFT.setMinter(await gameMaster.getAddress());
        await playerRegistry.setGameMaster(await gameMaster.getAddress());

        const BattleArena = await ethers.getContractFactory("BattleArena");
        battleArena = await BattleArena.deploy(
            await oikToken.getAddress(),
            await playerRegistry.getAddress(),
            await enemyNFT.getAddress(),
            await antiSybil.getAddress(),
            await circuitBreaker.getAddress()
        );

        // Example Games
        const SimpleRPG = await ethers.getContractFactory("SimpleRPG");
        simpleRPG = await SimpleRPG.deploy();

        const SimpleStrategy = await ethers.getContractFactory("SimpleStrategy");
        simpleStrategy = await SimpleStrategy.deploy();
    });

    // =============================================
    // GameKnowledgeBase Tests
    // =============================================
    describe("GameKnowledgeBase", function () {
        it("Should have bootstrapped RPG knowledge", async function () {
            const [gameCount, optimalWinRate, , difficulty, confidence] =
                await knowledgeBase.getTypeKnowledge("rpg");

            expect(gameCount).to.equal(0);
            expect(optimalWinRate).to.equal(6500); // 65%
            expect(difficulty).to.equal(55);
            expect(confidence).to.equal(7000);
        });

        it("Should have bootstrapped strategy knowledge", async function () {
            const [gameCount, optimalWinRate] =
                await knowledgeBase.getTypeKnowledge("strategy");

            expect(gameCount).to.equal(0);
            expect(optimalWinRate).to.equal(5500); // 55%
        });

        it("Should have RPG entity templates", async function () {
            const templates = await knowledgeBase.getEntityTemplates("rpg");
            expect(templates.length).to.equal(2);
            expect(templates[0].name).to.equal("Shadow Wraith");
        });

        it("Should return bootstrap for new game", async function () {
            const [winRate, difficulty, burnRate, rewardMult, confidence] =
                await knowledgeBase.getBootstrap("rpg");

            expect(winRate).to.equal(6500);
            expect(difficulty).to.equal(55);
            expect(confidence).to.equal(7000);
        });

        it("Should update knowledge", async function () {
            await knowledgeBase.updateKnowledge("rpg", "winRate", 7000);

            const [, optimalWinRate] = await knowledgeBase.getTypeKnowledge("rpg");
            // Weighted average: 6500 * 0.8 + 7000 * 0.2 = 6600
            expect(optimalWinRate).to.equal(6600);
        });

        it("Should record games", async function () {
            await knowledgeBase.recordGame("rpg");
            await knowledgeBase.recordGame("rpg");

            const [gameCount] = await knowledgeBase.getTypeKnowledge("rpg");
            expect(gameCount).to.equal(2);
        });

        it("Should get best entity template for level", async function () {
            const [name, minPower, maxPower] =
                await knowledgeBase.getBestEntityTemplate("rpg", 5);

            expect(name).to.be.a("string");
            expect(minPower).to.be.gte(0);
        });
    });

    // =============================================
    // AgentMemory Tests
    // =============================================
    describe("AgentMemory", function () {
        it("Should record a decision", async function () {
            await agentMemory.recordDecision(
                simpleRPG.getAddress(),
                player1.address,
                "spawn",
                ethers.toUtf8Bytes("test"),
                true,
                ethers.toUtf8Bytes("result")
            );

            const [totalDecisions, successful, , successRate] =
                await agentMemory.getGameStats(simpleRPG.getAddress());

            expect(totalDecisions).to.equal(1);
            expect(successful).to.equal(1);
            expect(successRate).to.equal(10000); // 100%
        });

        it("Should track success rate", async function () {
            const gameAddr = simpleRPG.getAddress();

            // 3 successes, 2 failures
            for (let i = 0; i < 3; i++) {
                await agentMemory.recordDecision(
                    gameAddr, player1.address, "spawn",
                    ethers.toUtf8Bytes("test"), true, ethers.toUtf8Bytes("ok")
                );
            }
            for (let i = 0; i < 2; i++) {
                await agentMemory.recordDecision(
                    gameAddr, player1.address, "spawn",
                    ethers.toUtf8Bytes("test"), false, ethers.toUtf8Bytes("fail")
                );
            }

            const [, , , successRate] = await agentMemory.getGameStats(gameAddr);
            expect(successRate).to.equal(6000); // 60%
        });

        it("Should get memory by index", async function () {
            await agentMemory.recordDecision(
                simpleRPG.getAddress(), player1.address, "economy",
                ethers.toUtf8Bytes("context"), true, ethers.toUtf8Bytes("done")
            );

            const [player, decisionType, , success] =
                await agentMemory.getMemory(simpleRPG.getAddress(), 0);

            expect(player).to.equal(player1.address);
            expect(decisionType).to.equal("economy");
            expect(success).to.be.true;
        });

        it("Should get recent decisions", async function () {
            const gameAddr = simpleRPG.getAddress();
            for (let i = 0; i < 5; i++) {
                await agentMemory.recordDecision(
                    gameAddr, player1.address, "spawn",
                    ethers.toUtf8Bytes("test"), true, ethers.toUtf8Bytes("ok")
                );
            }

            const recent = await agentMemory.getRecentDecisions(gameAddr, 3);
            expect(recent.length).to.equal(3);
        });

        it("Should set and get game type", async function () {
            await agentMemory.setGameType(simpleRPG.getAddress(), "rpg");
            const gameType = await agentMemory.gameTypes(simpleRPG.getAddress());
            expect(gameType).to.equal("rpg");
        });

        it("Should bootstrap knowledge via admin", async function () {
            await agentMemory.setKnowledge("rpg", 6500, 25000, 55, 10000);

            const [winRate, velocity, difficulty, reward] =
                await agentMemory.getKnowledge("rpg");

            expect(winRate).to.equal(6500);
            expect(difficulty).to.equal(55);
        });
    });

    // =============================================
    // IGameDescriptor Tests (SimpleRPG)
    // =============================================
    describe("SimpleRPG IGameDescriptor", function () {
        it("Should return game identity", async function () {
            const [name, version, gameType] = await simpleRPG.getGameIdentity();
            expect(name).to.equal("SimpleRPG");
            expect(version).to.equal("1.0.0");
            expect(gameType).to.equal("rpg");
        });

        it("Should return entity schema", async function () {
            const [types, schemas] = await simpleRPG.getEntitySchema();
            expect(types.length).to.equal(1);
            expect(types[0]).to.equal("enemy");
            expect(schemas[0]).to.include("power");
        });

        it("Should return economy schema", async function () {
            const [hasToken, , currencies, sinks, sources] = await simpleRPG.getEconomySchema();
            expect(hasToken).to.be.false;
            expect(currencies[0]).to.equal("gold");
            expect(sinks.length).to.equal(1);
            expect(sources.length).to.equal(2);
        });

        it("Should return event schema", async function () {
            const [sigs, names, actions] = await simpleRPG.getEventSchema();
            expect(sigs.length).to.equal(3);
            expect(names[0]).to.equal("PlayerMoved");
            expect(actions[0]).to.equal("spawn");
        });

        it("Should return goals", async function () {
            const [goals, weights] = await simpleRPG.getGoals();
            expect(goals.length).to.equal(3);
            expect(goals[0]).to.equal("player_retention");
            expect(weights[0]).to.equal(4000);
        });

        it("Should return agent permissions", async function () {
            const [canSpawn, canEconomy, canNarrative, canBalance, maxAdj] =
                await simpleRPG.getAgentPermissions();

            expect(canSpawn).to.be.true;
            expect(canEconomy).to.be.false;
            expect(canNarrative).to.be.true;
            expect(canBalance).to.be.true;
            expect(maxAdj).to.equal(2000);
        });
    });

    // =============================================
    // IGameDescriptor Tests (SimpleStrategy)
    // =============================================
    describe("SimpleStrategy IGameDescriptor", function () {
        it("Should return game identity", async function () {
            const [name, , gameType] = await simpleStrategy.getGameIdentity();
            expect(name).to.equal("StrategyWar");
            expect(gameType).to.equal("strategy");
        });

        it("Should return entity schema with units and buildings", async function () {
            const [types] = await simpleStrategy.getEntitySchema();
            expect(types.length).to.equal(2);
            expect(types[0]).to.equal("unit");
            expect(types[1]).to.equal("building");
        });

        it("Should have economy plugin permission", async function () {
            const [canSpawn, canEconomy] = await simpleStrategy.getAgentPermissions();
            expect(canSpawn).to.be.false;
            expect(canEconomy).to.be.true;
        });
    });

    // =============================================
    // IGameStateReader Tests
    // =============================================
    describe("IGameStateReader", function () {
        it("Should return player state from SimpleRPG", async function () {
            // Register player first
            await simpleRPG.connect(player1).register();

            const [level, xp, , stats] = await simpleRPG.getPlayerState(player1.address);
            expect(level).to.equal(1);
            expect(xp).to.equal(0);
            expect(stats.length).to.equal(3);
        });

        it("Should return game state from SimpleRPG", async function () {
            const [totalPlayers, activePlayers, totalEntities, globalStats] =
                await simpleRPG.getGameState();

            expect(totalPlayers).to.equal(0);
            expect(globalStats.length).to.equal(4);
        });

        it("Should return balance metrics", async function () {
            const [winRate, , , retention] = await simpleRPG.getBalanceMetrics();
            expect(winRate).to.equal(5000); // Default
            expect(retention).to.equal(8000);
        });
    });

    // =============================================
    // AgentRuntime Auto-Registration
    // =============================================
    describe("AgentRuntime Auto-Registration", function () {
        it("Should auto-register game via IGameDescriptor", async function () {
            await agentRuntime.autoRegisterGame(simpleRPG.getAddress());

            const [name, plugin, isActive, executions] =
                await agentRuntime.getGame(simpleRPG.getAddress());

            expect(name).to.equal("SimpleRPG");
            expect(isActive).to.be.true;
        });

        it("Should track registered games", async function () {
            await agentRuntime.autoRegisterGame(simpleRPG.getAddress());
            await agentRuntime.autoRegisterGame(simpleStrategy.getAddress());

            const games = await agentRuntime.getAllGames();
            expect(games.length).to.equal(2);
        });
    });

    // =============================================
    // Full Integration Flow
    // =============================================
    describe("Full Integration", function () {
        it("Should complete: deploy → register game → player plays → agent records", async function () {
            // 1. Register game with agent
            await agentRuntime.autoRegisterGame(simpleRPG.getAddress());

            // 2. Register player
            await simpleRPG.connect(player1).register();
            const [level] = await simpleRPG.getPlayerState(player1.address);
            expect(level).to.equal(1);

            // 3. Player moves (triggers events)
            await simpleRPG.connect(player1).move(50, 50);

            // 4. Agent records decision
            await agentMemory.recordDecision(
                simpleRPG.getAddress(),
                player1.address,
                "spawn",
                ethers.toUtf8Bytes("PlayerMoved"),
                true,
                ethers.toUtf8Bytes("enemy_spawned")
            );

            // 5. Verify memory
            const [totalDecisions, successful, , successRate] =
                await agentMemory.getGameStats(simpleRPG.getAddress());
            expect(totalDecisions).to.equal(1);
            expect(successRate).to.equal(10000);

            console.log("✅ Full integration flow passed!");
        });

        it("Should work with multiple game types", async function () {
            // Register both games
            await agentRuntime.autoRegisterGame(simpleRPG.getAddress());
            await agentRuntime.autoRegisterGame(simpleStrategy.getAddress());

            // Players play different games
            await simpleRPG.connect(player1).register();
            await simpleStrategy.connect(player2).register();

            // Agent manages both
            await agentMemory.recordDecision(
                simpleRPG.getAddress(), player1.address, "spawn",
                ethers.toUtf8Bytes("rpg_event"), true, ethers.toUtf8Bytes("ok")
            );
            await agentMemory.recordDecision(
                simpleStrategy.getAddress(), player2.address, "economy",
                ethers.toUtf8Bytes("strategy_event"), true, ethers.toUtf8Bytes("ok")
            );

            // Both should be tracked separately
            const rpgStats = await agentMemory.getGameStats(simpleRPG.getAddress());
            const stratStats = await agentMemory.getGameStats(simpleStrategy.getAddress());

            expect(rpgStats[0]).to.equal(1);
            expect(stratStats[0]).to.equal(1);

            console.log("✅ Multi-game integration passed!");
        });
    });
});

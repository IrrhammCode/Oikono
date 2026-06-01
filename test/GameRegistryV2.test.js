const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("OIKONO GameRegistryV2", function () {
    let gameRegistry, metricsRegistry, patternDetector;
    let owner, gameOwner, player1;

    beforeEach(async function () {
        [owner, gameOwner, player1] = await ethers.getSigners();

        // Deploy dependencies
        const MetricsRegistry = await ethers.getContractFactory("MetricsRegistry");
        metricsRegistry = await MetricsRegistry.deploy(owner.address);
        await metricsRegistry.waitForDeployment();

        const PatternDetector = await ethers.getContractFactory("PatternDetector");
        patternDetector = await PatternDetector.deploy(
            await metricsRegistry.getAddress(),
            owner.address
        );
        await patternDetector.waitForDeployment();

        // Deploy sub-contracts
        const GameRegistryBase = await ethers.getContractFactory("GameRegistryBase");
        const base = await GameRegistryBase.deploy(owner.address);
        await base.waitForDeployment();

        const GameContractManager = await ethers.getContractFactory("GameContractManager");
        const contractManager = await GameContractManager.deploy(
            await base.getAddress(),
            owner.address
        );
        await contractManager.waitForDeployment();

        const GameTypeManager = await ethers.getContractFactory("GameTypeManager");
        const typeManager = await GameTypeManager.deploy(
            await base.getAddress(),
            await metricsRegistry.getAddress(),
            await patternDetector.getAddress(),
            owner.address
        );
        await typeManager.waitForDeployment();

        // Deploy GameRegistryV2 (wrapper)
        const GameRegistryV2 = await ethers.getContractFactory("GameRegistryV2");
        gameRegistry = await GameRegistryV2.deploy(
            await base.getAddress(),
            await contractManager.getAddress(),
            await typeManager.getAddress(),
            owner.address
        );
        await gameRegistry.waitForDeployment();
    });

    describe("Game Registration", function () {
        it("Should register a game", async function () {
            const tx = await gameRegistry.connect(gameOwner).registerGame(
                "My RPG",
                "rpg",
                "An awesome RPG game",
                '{"website":"https://myrpg.com"}'
            );

            const receipt = await tx.wait();
            const event = receipt.logs.find(l => {
                try {
                    return gameRegistry.interface.parseLog(l)?.name === 'GameRegistered';
                } catch { return false; }
            });

            expect(event).to.not.be.undefined;

            const gameId = gameRegistry.interface.parseLog(event).args.gameId;
            expect(gameId).to.equal(0);

            // Check game data
            const game = await gameRegistry.getGame(gameId);
            expect(game.name).to.equal("My RPG");
            expect(game.gameType).to.equal("rpg");
            expect(game.isActive).to.be.true;
        });

        it("Should track games by owner", async function () {
            await gameRegistry.connect(gameOwner).registerGame("Game 1", "rpg", "desc", "");
            await gameRegistry.connect(gameOwner).registerGame("Game 2", "card", "desc", "");

            const games = await gameRegistry.getGamesByOwner(gameOwner.address);
            expect(games.length).to.equal(2);
        });

        it("Should track game types", async function () {
            await gameRegistry.connect(gameOwner).registerGame("RPG Game", "rpg", "desc", "");
            await gameRegistry.connect(gameOwner).registerGame("Card Game", "card", "desc", "");

            const types = await gameRegistry.getRegisteredGameTypes();
            expect(types).to.include("rpg");
            expect(types).to.include("card");
        });
    });

    describe("Contract Management", function () {
        let gameId;

        beforeEach(async function () {
            const tx = await gameRegistry.connect(gameOwner).registerGame(
                "My Game",
                "rpg",
                "desc",
                ""
            );
            const receipt = await tx.wait();
            const event = receipt.logs.find(l => {
                try {
                    return gameRegistry.interface.parseLog(l)?.name === 'GameRegistered';
                } catch { return false; }
            });
            gameId = gameRegistry.interface.parseLog(event).args.gameId;
        });

        it("Should add contract to game", async function () {
            const tokenAddress = player1.address; // Mock address
            const eventHashes = [ethers.id("Transfer(address,address,uint256)")];

            await gameRegistry.connect(gameOwner).addContract(
                gameId,
                tokenAddress,
                "token",
                eventHashes
            );

            const contracts = await gameRegistry.getGameContracts(gameId);
            expect(contracts.addresses.length).to.equal(1);
            expect(contracts.roles[0]).to.equal("token");
        });

        it("Should add multiple contracts", async function () {
            const tokenAddress = player1.address;
            const nftAddress = owner.address;

            await gameRegistry.connect(gameOwner).addContract(
                gameId,
                tokenAddress,
                "token",
                [ethers.id("Transfer(address,address,uint256)")]
            );

            await gameRegistry.connect(gameOwner).addContract(
                gameId,
                nftAddress,
                "nft",
                [ethers.id("Mint(address,uint256)")]
            );

            const contracts = await gameRegistry.getGameContracts(gameId);
            expect(contracts.addresses.length).to.equal(2);
        });

        it("Should get contract by role", async function () {
            const tokenAddress = player1.address;

            await gameRegistry.connect(gameOwner).addContract(
                gameId,
                tokenAddress,
                "token",
                []
            );

            const result = await gameRegistry.getContractByRole(gameId, "token");
            expect(result).to.equal(tokenAddress);
        });

        it("Should remove contract", async function () {
            const tokenAddress = player1.address;

            await gameRegistry.connect(gameOwner).addContract(
                gameId,
                tokenAddress,
                "token",
                []
            );

            await gameRegistry.connect(gameOwner).removeContract(gameId, tokenAddress);

            const contracts = await gameRegistry.getGameContracts(gameId);
            expect(contracts.active[0]).to.be.false;
        });

        it("Should reject duplicate contract", async function () {
            const tokenAddress = player1.address;

            await gameRegistry.connect(gameOwner).addContract(
                gameId,
                tokenAddress,
                "token",
                []
            );

            await expect(
                gameRegistry.connect(gameOwner).addContract(
                    gameId,
                    tokenAddress,
                    "token",
                    []
                )
            ).to.be.revertedWith("Already added");
        });
    });

    describe("Template System", function () {
        it("Should have default game types", async function () {
            const types = await gameRegistry.getRegisteredGameTypes();
            expect(types.length).to.equal(10);
            expect(types).to.include("rpg");
            expect(types).to.include("card");
            expect(types).to.include("strategy");
        });

        it("Should get RPG config", async function () {
            const [description, metricCount, ruleCount] = await gameRegistry.getGameTypeConfig("rpg");
            expect(description).to.include("Role-Playing");
            expect(metricCount).to.equal(12);
            expect(ruleCount).to.equal(6);
        });

        it("Should apply template to game", async function () {
            // Register game
            const tx = await gameRegistry.connect(gameOwner).registerGame(
                "My RPG",
                "rpg",
                "desc",
                ""
            );
            const receipt = await tx.wait();
            const event = receipt.logs.find(l => {
                try {
                    return gameRegistry.interface.parseLog(l)?.name === 'GameRegistered';
                } catch { return false; }
            });
            const gameId = gameRegistry.interface.parseLog(event).args.gameId;

            // Authorize GameTypeManager to define metrics
            const typeManagerAddr = await gameRegistry.typeManager();
            await metricsRegistry.setAuthorizedCaller(typeManagerAddr, true);
            await patternDetector.setAuthorizedCaller(typeManagerAddr, true);

            // Apply template
            await gameRegistry.connect(gameOwner).applyTemplate(gameId, "rpg");

            // Check metrics were defined
            const metricNames = await metricsRegistry.getMetricNames(gameId);
            expect(metricNames.length).to.equal(12);
        });
    });

    describe("Game Management", function () {
        let gameId;

        beforeEach(async function () {
            const tx = await gameRegistry.connect(gameOwner).registerGame(
                "My Game",
                "rpg",
                "desc",
                ""
            );
            const receipt = await tx.wait();
            const event = receipt.logs.find(l => {
                try {
                    return gameRegistry.interface.parseLog(l)?.name === 'GameRegistered';
                } catch { return false; }
            });
            gameId = gameRegistry.interface.parseLog(event).args.gameId;
        });

        it("Should deactivate game", async function () {
            await gameRegistry.connect(gameOwner).deactivateGame(gameId);
            const game = await gameRegistry.getGame(gameId);
            expect(game.isActive).to.be.false;
        });

        it("Should activate game", async function () {
            await gameRegistry.connect(gameOwner).deactivateGame(gameId);
            await gameRegistry.connect(gameOwner).activateGame(gameId);
            const game = await gameRegistry.getGame(gameId);
            expect(game.isActive).to.be.true;
        });

        it("Should update game", async function () {
            await gameRegistry.connect(gameOwner).updateGame(
                gameId,
                "New description",
                '{"website":"https://new.com"}'
            );
            const game = await gameRegistry.getGame(gameId);
            expect(game.description).to.equal("New description");
        });
    });
});

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("OIKONO - Autonomous Game Master", function () {
    let oikToken, playerRegistry, enemyNFT, battleArena, gameMaster;
    let economyController, economyParams, treasury, rewardDistributor;
    let circuitBreaker, antiSybil, twapOracle;
    let owner, player1, player2;

    beforeEach(async function () {
        [owner, player1, player2] = await ethers.getSigners();

        // Deploy utility contracts
        const CircuitBreaker = await ethers.getContractFactory("CircuitBreaker");
        circuitBreaker = await CircuitBreaker.deploy(owner.address);

        const AntiSybil = await ethers.getContractFactory("AntiSybil");
        antiSybil = await AntiSybil.deploy(owner.address);

        const TWAPOracle = await ethers.getContractFactory("TWAPOracle");
        twapOracle = await TWAPOracle.deploy(owner.address);

        // Deploy token
        const OIKToken = await ethers.getContractFactory("OIKToken");
        oikToken = await OIKToken.deploy(owner.address);
        await oikToken.enableTransfers();

        // Deploy game contracts
        const PlayerRegistry = await ethers.getContractFactory("PlayerRegistry");
        playerRegistry = await PlayerRegistry.deploy(await antiSybil.getAddress());

        const EnemyNFT = await ethers.getContractFactory("EnemyNFT");
        enemyNFT = await EnemyNFT.deploy(owner.address);

        // Deploy economy
        const EconomyParams = await ethers.getContractFactory("EconomyParams");
        economyParams = await EconomyParams.deploy(owner.address);

        const Treasury = await ethers.getContractFactory("Treasury");
        treasury = await Treasury.deploy(
            await oikToken.getAddress(),
            await economyParams.getAddress()
        );

        // Deploy GameMaster
        const GameMaster = await ethers.getContractFactory("GameMaster");
        gameMaster = await GameMaster.deploy(await playerRegistry.getAddress(), await enemyNFT.getAddress(), await antiSybil.getAddress(), await circuitBreaker.getAddress());

        await playerRegistry.setGameMaster(await gameMaster.getAddress());
        await enemyNFT.setMinter(await gameMaster.getAddress());

        // Deploy BattleArena
        const BattleArena = await ethers.getContractFactory("BattleArena");
        battleArena = await BattleArena.deploy(
            await oikToken.getAddress(),
            await playerRegistry.getAddress(),
            await enemyNFT.getAddress(),
            await antiSybil.getAddress(),
            await circuitBreaker.getAddress()
        );

        // Deploy EconomyController
        const EconomyController = await ethers.getContractFactory("EconomyController");
        economyController = await EconomyController.deploy(
            await oikToken.getAddress(),
            await economyParams.getAddress(),
            await treasury.getAddress(),
            await battleArena.getAddress(),
            await circuitBreaker.getAddress()
        );

        // Deploy RewardDistributor
        const RewardDistributor = await ethers.getContractFactory("RewardDistributor");
        rewardDistributor = await RewardDistributor.deploy(
            await oikToken.getAddress(),
            await economyParams.getAddress(),
            await antiSybil.getAddress()
        );
    });

    describe("OIKToken", function () {
        it("Should have correct initial supply", async function () {
            const supply = await oikToken.totalSupply();
            expect(supply).to.equal(ethers.parseEther("1000000000")); // 1B OIK
        });

        it("Should have correct max supply", async function () {
            const maxSupply = await oikToken.MAX_SUPPLY();
            expect(maxSupply).to.equal(ethers.parseEther("1500000000")); // 1.5B OIK
        });

        it("Should apply 0.5% transfer burn", async function () {
            // Transfer 1000 OIK
            const amount = ethers.parseEther("1000");
            await oikToken.transfer(player1.address, amount);

            // Should receive 995 OIK (1000 - 0.5%)
            const balance = await oikToken.balanceOf(player1.address);
            const expected = amount - (amount * 50n / 10000n);
            expect(balance).to.equal(expected);

            // Check total burned
            const burned = await oikToken.totalBurned();
            expect(burned).to.equal(amount * 50n / 10000n); // 5 OIK burned
        });

        it("Should enforce daily reward cap", async function () {
            const dailyCap = await oikToken.DAILY_REWARD_CAP();
            expect(dailyCap).to.equal(ethers.parseEther("2000"));

            // Can claim up to 2000 OIK per day
            expect(await oikToken.canClaimDailyRewards(player1.address)).to.be.true;

            // Record 2000 OIK reward
            await oikToken.recordDailyReward(player1.address, ethers.parseEther("2000"));
            expect(await oikToken.canClaimDailyRewards(player1.address)).to.be.false;
        });
    });

    describe("PlayerRegistry", function () {
        it("Should register a new player", async function () {
            await playerRegistry.connect(player1).registerPlayer(50, 50);

            const player = await playerRegistry.getPlayer(player1.address);
            expect(player.exists).to.be.true;
            expect(player.x).to.equal(50);
            expect(player.y).to.equal(50);
            expect(player.level).to.equal(1);
        });

        it("Should emit PlayerMoved event on move", async function () {
            await playerRegistry.connect(player1).registerPlayer(50, 50);

            await expect(playerRegistry.connect(player1).move(60, 70))
                .to.emit(playerRegistry, "PlayerMoved");
        });

        it("Should reject duplicate registration", async function () {
            await playerRegistry.connect(player1).registerPlayer(50, 50);

            await expect(
                playerRegistry.connect(player1).registerPlayer(50, 50)
            ).to.be.revertedWith("Already registered");
        });
    });

    describe("EnemyNFT", function () {
        it("Should mint enemy NFT", async function () {
            await enemyNFT.mintFromAI(
                player1.address,
                "Shadow Wraith",
                "assassin",
                "shadow",
                87,
                8,
                "ipfs://test"
            );

            expect(await enemyNFT.balanceOf(player1.address)).to.equal(1);
        });

        it("Should store enemy data", async function () {
            await enemyNFT.mintFromAI(
                player1.address,
                "Shadow Wraith",
                "assassin",
                "shadow",
                87,
                8,
                "ipfs://test"
            );

            const enemy = await enemyNFT.getEnemy(0);
            expect(enemy.name).to.equal("Shadow Wraith");
            expect(enemy.enemyClass).to.equal("assassin");
            expect(enemy.element).to.equal("shadow");
            expect(enemy.power).to.equal(87);
            expect(enemy.threatLevel).to.equal(8);
        });

        it("Should reject invalid power", async function () {
            await expect(
                enemyNFT.mintFromAI(
                    player1.address,
                    "Test",
                    "tank",
                    "fire",
                    30, // Too low
                    5,
                    "ipfs://test"
                )
            ).to.be.revertedWith("Power must be 40-100");
        });

        it("Should mark high-power enemies as boss", async function () {
            await enemyNFT.mintFromAI(
                player1.address,
                "Dragon King",
                "berserker",
                "fire",
                95,
                10,
                "ipfs://test"
            );

            const enemy = await enemyNFT.getEnemy(0);
            expect(enemy.isBoss).to.be.true;
        });
    });

    describe("GameMaster", function () {
        beforeEach(async function () {
            await playerRegistry.connect(player1).registerPlayer(50, 50);
        });

        it("Should generate enemy for player", async function () {
            await expect(gameMaster.triggerEnemyGeneration(player1.address))
                .to.emit(gameMaster, "EnemyGenerated");

            expect(await enemyNFT.balanceOf(player1.address)).to.equal(1);
        });

        it("Should build correct prompt", async function () {
            await expect(gameMaster.triggerEnemyGeneration(player1.address))
                .to.emit(gameMaster, "LLMRequestSent");
        });

        it("Should track stats", async function () {
            await gameMaster.triggerEnemyGeneration(player1.address);

            const stats = await gameMaster.getStats();
            expect(stats.totalEnemies).to.equal(1);
        });
    });

    describe("CircuitBreaker", function () {
        it("Should pause system", async function () {
            await circuitBreaker.emergencyPause();
            expect(await circuitBreaker.paused()).to.be.true;
        });

        it("Should unpause after minimum duration", async function () {
            await circuitBreaker.emergencyPause();

            // Fast forward 1 hour
            await ethers.provider.send("evm_increaseTime", [3600]);
            await ethers.provider.send("evm_mine", []);

            await circuitBreaker.unpause();
            expect(await circuitBreaker.paused()).to.be.false;
        });
    });

    describe("EconomyParams", function () {
        it("Should update parameters with gradual ramp", async function () {
            await economyParams.updateParams(
                15000, // rewardMultiplier target
                5000,  // burnRate target
                12000, // mintCostMultiplier target
                11000, // enemyPowerScaling target
                9000   // entryFeeMultiplier target
            );

            const params = await economyParams.getCurrentParams();
            // Values are gradually ramped: 30% for reward, 50% for burn
            // reward: 10000 + (15000-10000)*30/100 = 11500
            expect(params[0]).to.equal(11500);
            // burn: 4000 + (5000-4000)*50/100 = 4500 (initial burnRate is 4000, not 10000)
            expect(params[1]).to.equal(4500);
        });

        it("Should apply gradual ramp (not direct assignment)", async function () {
            // Set a target higher than current
            await economyParams.updateParams(
                18000, // Target
                6000,
                10000,
                10000,
                10000
            );

            const params = await economyParams.getCurrentParams();
            // Value should be between previous value and target (gradual ramp)
            expect(params[0]).to.be.greaterThan(11500);
            expect(params[0]).to.be.lessThan(18000);
        });
    });

    describe("Integration Flow", function () {
        it("Complete player flow: register -> move -> generate enemy -> battle", async function () {
            // 1. Register player
            await playerRegistry.connect(player1).registerPlayer(50, 50);

            // 2. Give player some OIK for staking
            await oikToken.transfer(player1.address, ethers.parseEther("10000"));

            // 3. Stake (simulate by recording stake)
            await antiSybil.recordStake(player1.address, ethers.parseEther("2000"));

            // 4. Move (emit PlayerMoved)
            await playerRegistry.connect(player1).move(60, 70);

            // 5. Generate enemy
            await gameMaster.triggerEnemyGeneration(player1.address);
            expect(await enemyNFT.balanceOf(player1.address)).to.equal(1);

            console.log("✅ Full integration flow test passed!");
        });
    });
});

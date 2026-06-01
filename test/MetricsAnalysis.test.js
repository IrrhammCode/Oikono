const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("OIKONO Metrics & Analysis System", function () {
    let metricsRegistry, patternDetector, suggestionEngine, gameTypeTemplates;
    let owner, gameOwner, user1;

    beforeEach(async function () {
        [owner, gameOwner, user1] = await ethers.getSigners();

        // Deploy MetricsRegistry
        const MetricsRegistry = await ethers.getContractFactory("MetricsRegistry");
        metricsRegistry = await MetricsRegistry.deploy(owner.address);
        await metricsRegistry.waitForDeployment();

        // Deploy PatternDetector
        const PatternDetector = await ethers.getContractFactory("PatternDetector");
        patternDetector = await PatternDetector.deploy(
            await metricsRegistry.getAddress(),
            owner.address
        );
        await patternDetector.waitForDeployment();

        // Deploy SuggestionEngine
        const SuggestionEngine = await ethers.getContractFactory("SuggestionEngine");
        suggestionEngine = await SuggestionEngine.deploy(
            await patternDetector.getAddress(),
            await metricsRegistry.getAddress(),
            owner.address
        );
        await suggestionEngine.waitForDeployment();

        // Deploy GameTypeTemplates
        const GameTypeTemplates = await ethers.getContractFactory("GameTypeTemplates");
        gameTypeTemplates = await GameTypeTemplates.deploy(
            await metricsRegistry.getAddress(),
            await patternDetector.getAddress(),
            owner.address
        );
        await gameTypeTemplates.waitForDeployment();

        // Setup: Register a game
        await metricsRegistry.setGameOwner(1, gameOwner.address);
        await patternDetector.setGameOwner(1, gameOwner.address);
        await suggestionEngine.setGameOwner(1, gameOwner.address);
    });

    // =============================================
    // MetricsRegistry Tests
    // =============================================
    describe("MetricsRegistry", function () {
        it("Should define a metric", async function () {
            await metricsRegistry.connect(gameOwner).defineMetric(
                1, "win_rate", "bps", "on_chain", 4000, 7000, false
            );

            const [dataType, source, healthyMin, healthyMax, isHigherBetter, isActive] =
                await metricsRegistry.getMetricDef(1, "win_rate");

            expect(dataType).to.equal("bps");
            expect(source).to.equal("on_chain");
            expect(healthyMin).to.equal(4000);
            expect(healthyMax).to.equal(7000);
            expect(isActive).to.be.true;
        });

        it("Should record metric value", async function () {
            await metricsRegistry.connect(gameOwner).defineMetric(
                1, "win_rate", "bps", "on_chain", 4000, 7000, false
            );

            await metricsRegistry.connect(gameOwner).recordMetric(1, "win_rate", 6500);

            const latest = await metricsRegistry.getLatest(1, "win_rate");
            expect(latest).to.equal(6500);
        });

        it("Should track metric stats", async function () {
            await metricsRegistry.connect(gameOwner).defineMetric(
                1, "win_rate", "bps", "on_chain", 4000, 7000, false
            );

            await metricsRegistry.connect(gameOwner).recordMetric(1, "win_rate", 6000);
            await metricsRegistry.connect(gameOwner).recordMetric(1, "win_rate", 7000);
            await metricsRegistry.connect(gameOwner).recordMetric(1, "win_rate", 5000);

            const [latest, min, max, avg, count] = await metricsRegistry.getStats(1, "win_rate");

            expect(latest).to.equal(5000);
            expect(min).to.equal(5000);
            expect(max).to.equal(7000);
            expect(count).to.equal(3);
        });

        it("Should check if metric is healthy", async function () {
            await metricsRegistry.connect(gameOwner).defineMetric(
                1, "win_rate", "bps", "on_chain", 4000, 7000, false
            );

            await metricsRegistry.connect(gameOwner).recordMetric(1, "win_rate", 6500);
            expect(await metricsRegistry.isHealthy(1, "win_rate")).to.be.true;

            await metricsRegistry.connect(gameOwner).recordMetric(1, "win_rate", 8000);
            expect(await metricsRegistry.isHealthy(1, "win_rate")).to.be.false;
        });

        it("Should calculate change percentage", async function () {
            await metricsRegistry.connect(gameOwner).defineMetric(
                1, "win_rate", "bps", "on_chain", 4000, 7000, false
            );

            await metricsRegistry.connect(gameOwner).recordMetric(1, "win_rate", 6000);
            await metricsRegistry.connect(gameOwner).recordMetric(1, "win_rate", 6600);

            const change = await metricsRegistry.getChange(1, "win_rate");
            expect(change).to.equal(1000); // 10% increase
        });

        it("Should calculate moving average", async function () {
            await metricsRegistry.connect(gameOwner).defineMetric(
                1, "win_rate", "bps", "on_chain", 4000, 7000, false
            );

            await metricsRegistry.connect(gameOwner).recordMetric(1, "win_rate", 5000);
            await metricsRegistry.connect(gameOwner).recordMetric(1, "win_rate", 6000);
            await metricsRegistry.connect(gameOwner).recordMetric(1, "win_rate", 7000);

            const ma = await metricsRegistry.getMovingAverage(1, "win_rate", 3);
            expect(ma).to.equal(6000);
        });

        it("Should get metric history", async function () {
            await metricsRegistry.connect(gameOwner).defineMetric(
                1, "win_rate", "bps", "on_chain", 4000, 7000, false
            );

            await metricsRegistry.connect(gameOwner).recordMetric(1, "win_rate", 5000);
            await metricsRegistry.connect(gameOwner).recordMetric(1, "win_rate", 6000);
            await metricsRegistry.connect(gameOwner).recordMetric(1, "win_rate", 7000);

            const history = await metricsRegistry.getHistory(1, "win_rate", 3);
            expect(history.length).to.equal(3);
            expect(history[0].value).to.equal(5000);
            expect(history[2].value).to.equal(7000);
        });

        it("Should define multiple metrics at once", async function () {
            const names = ["win_rate", "retention", "velocity"];
            const dataTypes = ["bps", "bps", "uint256"];
            const sources = ["on_chain", "off_chain", "on_chain"];
            const healthyMins = [4000, 3000, 0];
            const healthyMaxs = [7000, 6000, 50000];
            const isHigherBetters = [false, true, false];

            await metricsRegistry.connect(gameOwner).defineMetrics(
                1, names, dataTypes, sources, healthyMins, healthyMaxs, isHigherBetters
            );

            const metricNames = await metricsRegistry.getMetricNames(1);
            expect(metricNames.length).to.equal(3);
        });

        it("Should reject non-owner from defining metrics", async function () {
            await expect(
                metricsRegistry.connect(user1).defineMetric(
                    1, "win_rate", "bps", "on_chain", 4000, 7000, false
                )
            ).to.be.revertedWith("Not game owner");
        });
    });

    // =============================================
    // PatternDetector Tests
    // =============================================
    describe("PatternDetector", function () {
        beforeEach(async function () {
            // Define metrics
            await metricsRegistry.connect(gameOwner).defineMetric(
                1, "win_rate", "bps", "on_chain", 4000, 7000, false
            );
            await metricsRegistry.connect(gameOwner).defineMetric(
                1, "retention_d7", "bps", "off_chain", 3000, 6000, true
            );
        });

        it("Should add detection rule", async function () {
            await patternDetector.connect(gameOwner).addRule(
                1, "spike", "win_rate", 2000, 1
            );

            const count = await patternDetector.ruleCount(1);
            expect(count).to.equal(1);
        });

        it("Should detect spike pattern", async function () {
            // Add spike rule
            await patternDetector.connect(gameOwner).addRule(
                1, "spike", "win_rate", 2000, 1
            );

            // Record metrics with spike
            await metricsRegistry.connect(gameOwner).recordMetric(1, "win_rate", 5000);
            await metricsRegistry.connect(gameOwner).recordMetric(1, "win_rate", 7000); // 40% spike

            // Detect patterns
            await patternDetector.detectPatterns(1);

            const patternCount = await patternDetector.getPatternCount(1);
            expect(patternCount).to.be.gt(0);
        });

        it("Should detect drop pattern", async function () {
            // Add drop rule
            await patternDetector.connect(gameOwner).addRule(
                1, "drop", "retention_d7", 1500, 1
            );

            // Record metrics with drop
            await metricsRegistry.connect(gameOwner).recordMetric(1, "retention_d7", 5000);
            await metricsRegistry.connect(gameOwner).recordMetric(1, "retention_d7", 3000); // 40% drop

            // Detect patterns
            await patternDetector.detectPatterns(1);

            const patternCount = await patternDetector.getPatternCount(1);
            expect(patternCount).to.be.gt(0);
        });

        it("Should detect anomaly when metric outside healthy range", async function () {
            // Record metric outside healthy range
            await metricsRegistry.connect(gameOwner).recordMetric(1, "win_rate", 8000); // > 7000 max

            // Detect patterns
            await patternDetector.detectPatterns(1);

            const patterns = await patternDetector.getActivePatterns(1);
            expect(patterns.length).to.be.gt(0);
            expect(patterns[0].patternType).to.equal("anomaly");
        });

        it("Should detect divergence between metrics", async function () {
            // Record metrics moving in opposite directions
            await metricsRegistry.connect(gameOwner).recordMetric(1, "win_rate", 5000);
            await metricsRegistry.connect(gameOwner).recordMetric(1, "retention_d7", 5000);

            await metricsRegistry.connect(gameOwner).recordMetric(1, "win_rate", 7000); // Up 40%
            await metricsRegistry.connect(gameOwner).recordMetric(1, "retention_d7", 3000); // Down 40%

            // Detect patterns
            await patternDetector.detectPatterns(1);

            const patterns = await patternDetector.getActivePatterns(1);
            const divergence = patterns.find(p => p.patternType === "divergence");
            expect(divergence).to.not.be.undefined;
        });

        it("Should add default rules for RPG", async function () {
            await patternDetector.connect(gameOwner).addDefaultRules(1, "rpg");

            const count = await patternDetector.ruleCount(1);
            expect(count).to.equal(4); // RPG has 4 default rules
        });

        it("Should get active patterns", async function () {
            // Create some patterns
            await metricsRegistry.connect(gameOwner).recordMetric(1, "win_rate", 8000);
            await patternDetector.detectPatterns(1);

            const activePatterns = await patternDetector.getActivePatterns(1);
            expect(activePatterns.length).to.be.gt(0);
        });
    });

    // =============================================
    // SuggestionEngine Tests
    // =============================================
    describe("SuggestionEngine", function () {
        beforeEach(async function () {
            // Setup metrics and patterns
            await metricsRegistry.connect(gameOwner).defineMetric(
                1, "win_rate", "bps", "on_chain", 4000, 7000, false
            );

            await metricsRegistry.connect(gameOwner).recordMetric(1, "win_rate", 5000);
            await metricsRegistry.connect(gameOwner).recordMetric(1, "win_rate", 7000); // Spike

            await patternDetector.connect(gameOwner).addRule(
                1, "spike", "win_rate", 2000, 1
            );

            await patternDetector.detectPatterns(1);
        });

        it("Should generate suggestions from patterns", async function () {
            await suggestionEngine.connect(gameOwner).generateSuggestions(1);

            const count = await suggestionEngine.getSuggestionCount(1);
            expect(count).to.be.gt(0);
        });

        it("Should get active suggestions", async function () {
            await suggestionEngine.connect(gameOwner).generateSuggestions(1);

            const activeSuggestions = await suggestionEngine.getActiveSuggestions(1);
            expect(activeSuggestions.length).to.be.gt(0);
        });

        it("Should mark suggestion as implemented", async function () {
            await suggestionEngine.connect(gameOwner).generateSuggestions(1);

            await suggestionEngine.connect(gameOwner).markImplemented(1, 0);

            const suggestion = await suggestionEngine.getSuggestion(1, 0);
            expect(suggestion.implemented).to.be.true;
        });

        it("Should record outcome", async function () {
            await suggestionEngine.connect(gameOwner).generateSuggestions(1);
            await suggestionEngine.connect(gameOwner).markImplemented(1, 0);

            await suggestionEngine.connect(gameOwner).recordOutcome(
                1, 0, true, 7000, "Improved retention by 5%"
            );

            const outcomes = await suggestionEngine.getOutcomes(0);
            expect(outcomes.length).to.equal(1);
            expect(outcomes[0].success).to.be.true;
        });

        it("Should track success rate", async function () {
            await suggestionEngine.connect(gameOwner).generateSuggestions(1);
            await suggestionEngine.connect(gameOwner).markImplemented(1, 0);
            await suggestionEngine.connect(gameOwner).recordOutcome(1, 0, true, 7000, "");

            // Get the suggestion to check its category
            const suggestion = await suggestionEngine.getSuggestion(1, 0);
            const successRate = await suggestionEngine.getSuccessRate(suggestion.category);
            expect(successRate).to.be.gt(0);
        });
    });

    // =============================================
    // GameTypeTemplates Tests
    // =============================================
    describe("GameTypeTemplates", function () {
        it("Should have default game types", async function () {
            const types = await gameTypeTemplates.getRegisteredTypes();
            expect(types.length).to.equal(10);
            expect(types).to.include("rpg");
            expect(types).to.include("card");
            expect(types).to.include("strategy");
        });

        it("Should get RPG config", async function () {
            const [description, metricCount, ruleCount] = await gameTypeTemplates.getConfig("rpg");

            expect(description).to.include("Role-Playing");
            expect(metricCount).to.equal(10);
            expect(ruleCount).to.equal(4);
        });

        it("Should get metric templates for RPG", async function () {
            const metrics = await gameTypeTemplates.getMetricTemplates("rpg");

            expect(metrics.length).to.equal(10);
            expect(metrics[0].name).to.equal("win_rate");
        });

        it("Should get rule templates for RPG", async function () {
            const rules = await gameTypeTemplates.getRuleTemplates("rpg");

            expect(rules.length).to.equal(4);
        });

        it("Should apply template to game", async function () {
            // Set game owner to GameTypeTemplates contract so it can define metrics
            await metricsRegistry.setGameOwner(1, await gameTypeTemplates.getAddress());
            await patternDetector.setGameOwner(1, await gameTypeTemplates.getAddress());

            await gameTypeTemplates.connect(gameOwner).applyTemplate(1, "rpg");

            // Check that metrics were defined
            const metricNames = await metricsRegistry.getMetricNames(1);
            expect(metricNames.length).to.equal(10);
        });

        it("Should register custom game type", async function () {
            const metrics = [{
                name: "custom_metric",
                dataType: "bps",
                source: "on_chain",
                healthyMin: 0,
                healthyMax: 10000,
                isHigherBetter: true
            }];

            const rules = [{
                ruleType: "spike",
                metricName: "custom_metric",
                threshold: 2000,
                period: 1
            }];

            await gameTypeTemplates.registerGameType(
                "custom", "Custom game type", metrics, rules
            );

            const types = await gameTypeTemplates.getRegisteredTypes();
            expect(types).to.include("custom");
        });
    });

    // =============================================
    // Integration Tests
    // =============================================
    describe("Integration", function () {
        it("Full flow: template → metrics → patterns → suggestions", async function () {
            // Set game owner to GameTypeTemplates contract
            await metricsRegistry.setGameOwner(1, await gameTypeTemplates.getAddress());
            await patternDetector.setGameOwner(1, await gameTypeTemplates.getAddress());

            // 1. Apply template
            await gameTypeTemplates.connect(gameOwner).applyTemplate(1, "rpg");

            // Set game owner back for recording metrics
            await metricsRegistry.setGameOwner(1, gameOwner.address);
            await patternDetector.setGameOwner(1, gameOwner.address);

            // 2. Record metrics
            await metricsRegistry.connect(gameOwner).recordMetric(1, "win_rate", 5000);
            await metricsRegistry.connect(gameOwner).recordMetric(1, "win_rate", 7000); // Spike

            // 3. Detect patterns
            await patternDetector.detectPatterns(1);

            // 4. Generate suggestions
            await suggestionEngine.connect(gameOwner).generateSuggestions(1);

            // 5. Check results
            const patterns = await patternDetector.getActivePatterns(1);
            const suggestions = await suggestionEngine.getActiveSuggestions(1);

            expect(patterns.length).to.be.gt(0);
            expect(suggestions.length).to.be.gt(0);
        });

        it("Full flow with outcome tracking", async function () {
            // Set game owner to GameTypeTemplates contract
            await metricsRegistry.setGameOwner(1, await gameTypeTemplates.getAddress());
            await patternDetector.setGameOwner(1, await gameTypeTemplates.getAddress());

            // Setup
            await gameTypeTemplates.connect(gameOwner).applyTemplate(1, "rpg");

            // Set game owner back for recording metrics
            await metricsRegistry.setGameOwner(1, gameOwner.address);
            await patternDetector.setGameOwner(1, gameOwner.address);
            await metricsRegistry.connect(gameOwner).recordMetric(1, "win_rate", 5000);
            await metricsRegistry.connect(gameOwner).recordMetric(1, "win_rate", 7000);
            await patternDetector.detectPatterns(1);
            await suggestionEngine.connect(gameOwner).generateSuggestions(1);

            // Implement suggestion
            await suggestionEngine.connect(gameOwner).markImplemented(1, 0);

            // Record outcome
            await suggestionEngine.connect(gameOwner).recordOutcome(
                1, 0, true, 8000, "Win rate normalized"
            );

            // Check learning
            const suggestion = await suggestionEngine.getSuggestion(1, 0);
            const successRate = await suggestionEngine.getSuccessRate(suggestion.category);
            expect(successRate).to.equal(10000); // 100% success
        });
    });
});

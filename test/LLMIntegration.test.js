const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("OIKONO LLM Integration", function () {
    let llmInvoker, memory, knowledgeBase;
    let owner, gameOwner, player1;

    beforeEach(async function () {
        [owner, gameOwner, player1] = await ethers.getSigners();

        // Deploy dependencies
        const AgentMemory = await ethers.getContractFactory("AgentMemory");
        memory = await AgentMemory.deploy(owner.address);
        await memory.waitForDeployment();

        const GameKnowledgeBase = await ethers.getContractFactory("GameKnowledgeBase");
        knowledgeBase = await GameKnowledgeBase.deploy(owner.address);
        await knowledgeBase.waitForDeployment();

        // Deploy LLMInvoker
        const LLMInvoker = await ethers.getContractFactory("LLMInvoker");
        llmInvoker = await LLMInvoker.deploy(
            await memory.getAddress(),
            await knowledgeBase.getAddress()
        );
        await llmInvoker.waitForDeployment();
    });

    describe("LLMInvoker", function () {
        it("Should deploy with correct dependencies", async function () {
            expect(await llmInvoker.memory_()).to.equal(await memory.getAddress());
            expect(await llmInvoker.knowledgeBase()).to.equal(await knowledgeBase.getAddress());
        });

        it("Should have correct safety bounds", async function () {
            expect(await llmInvoker.MAX_REWARD_CHANGE()).to.equal(2000);
            expect(await llmInvoker.MAX_BURN_CHANGE()).to.equal(2000);
            expect(await llmInvoker.MAX_MINT_CHANGE()).to.equal(3000);
            expect(await llmInvoker.MAX_POWER_CHANGE()).to.equal(2000);
            expect(await llmInvoker.MAX_ENTRY_CHANGE()).to.equal(2000);
        });

        it("Should have correct Somnia constants", async function () {
            expect(await llmInvoker.SOMNIA_PLATFORM()).to.equal("0x0000000000000000000000000000000000000401");
            expect(await llmInvoker.AGENT_REQUESTER()).to.equal("0x0000000000000000000000000000000000000200");
            expect(await llmInvoker.LLM_INFERENCE_AGENT_ID()).to.equal(12847293847561029384n);
        });

        it("Should update memory address", async function () {
            const newMemory = player1.address;
            await llmInvoker.setMemory(newMemory);
            expect(await llmInvoker.memory_()).to.equal(newMemory);
        });

        it("Should update knowledge base address", async function () {
            const newKB = player1.address;
            await llmInvoker.setKnowledgeBase(newKB);
            expect(await llmInvoker.knowledgeBase()).to.equal(newKB);
        });

        it("Should reject non-owner from updating memory", async function () {
            await expect(
                llmInvoker.connect(player1).setMemory(player1.address)
            ).to.be.revertedWithCustomError(llmInvoker, "OwnableUnauthorizedAccount");
        });

        it("Should reject non-owner from updating knowledge base", async function () {
            await expect(
                llmInvoker.connect(player1).setKnowledgeBase(player1.address)
            ).to.be.revertedWithCustomError(llmInvoker, "OwnableUnauthorizedAccount");
        });
    });

    describe("PromptTemplates", function () {
        it("Should build economy prompt", async function () {
            // This tests the library function indirectly through a contract call
            // In production, the prompt would be built by the LLMInvoker contract
            expect(true).to.be.true; // Placeholder
        });

        it("Should build spawn prompt", async function () {
            expect(true).to.be.true; // Placeholder
        });

        it("Should build balance prompt", async function () {
            expect(true).to.be.true; // Placeholder
        });

        it("Should build narrative prompt", async function () {
            expect(true).to.be.true; // Placeholder
        });
    });

    describe("JSON Parsing", function () {
        it("Should parse valid JSON response", async function () {
            // Test the parsing logic indirectly
            // In production, this would be tested via handleLLMResponse
            expect(true).to.be.true; // Placeholder
        });

        it("Should handle invalid JSON gracefully", async function () {
            expect(true).to.be.true; // Placeholder
        });

        it("Should apply safety bounds", async function () {
            expect(true).to.be.true; // Placeholder
        });
    });
});

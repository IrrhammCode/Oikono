const { ethers } = require("hardhat");

const GAMES = [
    { name: "WagerVerse Arena", type: "pvp", desc: "Competitive PvP wager arena with delegated gameplay and real-time matchmaking" },
    { name: "Worms Arena", type: "strategy", desc: "Turn-based strategy battler with on-chain worm armies and seasonal leaderboards" },
    { name: "Infinite Craft", type: "sandbox", desc: "On-chain crafting game with composable NFT items and player-driven marketplace" },
    { name: "Void Hunters", type: "rpg", desc: "Dark sci-fi RPG with void creature hunting, NFT loot drops, and cooperative raids" },
    { name: "Kingsomni", type: "card", desc: "Strategic card game set in the Somnia kingdom with alliance wars" },
    { name: "Gamers Lab", type: "puzzle", desc: "Proof-of-play puzzle platform with on-chain score anchoring and daily challenges" },
    { name: "Somn Tournament", type: "racing", desc: "High-speed on-chain racing tournaments with NFT vehicles and pit stop strategy" },
    { name: "NFT Bridge World", type: "simulation", desc: "Cross-chain simulation with NFT bridging and AI-driven economy balancing" },
    { name: "DeFi Arena", type: "defi", desc: "DeFi gaming arena with yield farming mechanics and token wagering" },
];

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying with:", deployer.address);
    
    const balance = await ethers.provider.getBalance(deployer.address);
    console.log("Balance:", ethers.formatEther(balance), "STT");

    // Deploy GameFactory
    console.log("\n1. Deploying GameFactory...");
    const Factory = await ethers.getContractFactory("GameFactory");
    const factory = await Factory.deploy();
    await factory.waitForDeployment();
    const factoryAddr = await factory.getAddress();
    console.log("GameFactory deployed at:", factoryAddr);

    // Deploy all 9 games in ONE transaction
    console.log("\n2. Deploying 9 games in batch...");
    const names = GAMES.map(g => g.name);
    const types = GAMES.map(g => g.type);
    const descs = GAMES.map(g => g.desc);

    const tx = await factory.deployGames(names, types, descs);
    const receipt = await tx.wait();
    console.log("Batch deploy TX:", receipt.hash);
    console.log("Gas used:", receipt.gasUsed.toString());

    // Get deployed addresses
    const deployed = await factory.getDeployedGames();
    console.log("\n3. Deployed game addresses:");
    const addresses = [];
    for (let i = 0; i < deployed.length; i++) {
        console.log(`   ${GAMES[i].name}: ${deployed[i]}`);
        addresses.push(deployed[i]);
    }

    const balanceAfter = await ethers.provider.getBalance(deployer.address);
    console.log("\nBalance after:", ethers.formatEther(balanceAfter), "STT");
    console.log("Cost:", ethers.formatEther(balance - balanceAfter), "STT");

    // Output for config.js update
    console.log("\n4. Copy this to update EXAMPLE_DATA in app.js:");
    console.log("const DEPLOYED_ADDRESSES = " + JSON.stringify(addresses, null, 2) + ";");

    // Save addresses to file
    const fs = require("fs");
    const output = {
        factory: factoryAddr,
        games: GAMES.map((g, i) => ({
            name: g.name,
            type: g.type,
            address: deployed[i],
        })),
        deployer: deployer.address,
        network: "somnia_testnet",
        timestamp: new Date().toISOString(),
    };
    fs.writeFileSync("deployed-games.json", JSON.stringify(output, null, 2));
    console.log("\nSaved to deployed-games.json");
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

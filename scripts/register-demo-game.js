/**
 * Quick script to register a game in GameRegistry for demo
 */
const hre = require("hardhat");

async function main() {
    const [signer] = await hre.ethers.getSigners();
    const addr = signer.address;

    const GameRegistry = await hre.ethers.getContractAt("GameRegistry", "0x6eB1d23419629901F78947B1207024f7F28380a6");
    const PlayerRegistry = await hre.ethers.getContractAt("PlayerRegistry", "0xA530dbDB02f46F4A1B7c18cEE8eA57148fC470Ae");

    // Check if game already registered
    try {
        const games = await GameRegistry.getGamesByOwner(addr);
        console.log("Existing games:", games.map(g => Number(g)));
        if (games.length > 0) {
            console.log("Game already registered! ID:", Number(games[0]));
            return;
        }
    } catch (e) {
        console.log("Checking existing games...");
    }

    // Register game using registerGameSimple
    console.log("Registering game in GameRegistry...");
    try {
        const tx = await GameRegistry.registerGameSimple(
            "Oikono Demo Game",
            "RPG",
            "Demo game for Somnia AI Hackathon",
            await PlayerRegistry.getAddress()
        );
        const receipt = await tx.wait();
        console.log("Game registered! TX:", receipt.hash);

        // Find gameId from event
        const event = receipt.logs.find(function(l) {
            try { return GameRegistry.interface.parseLog(l).name === "GameRegistered"; }
            catch(e) { return false; }
        });
        if (event) {
            const args = GameRegistry.interface.parseLog(event).args;
            console.log("Game ID:", Number(args.gameId));
            console.log("Game Address:", args.gameAddress);
        }
    } catch (e) {
        console.log("Registration failed:", e.message.slice(0, 100));
    }
}

main().catch(console.error);

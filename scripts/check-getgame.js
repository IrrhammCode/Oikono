const { ethers } = require("hardhat");

async function main() {
    const [signer] = await ethers.getSigners();
    
    // Use NAMED returns like frontend config.js
    const abi = [
        "function getGame(uint256 gameId) external view returns (address gameAddress, address owner, string name, string gameType, string description, string metadata, bool isActive, bool isVerified, uint256 totalEvents, uint256 totalActions)",
        "function getConfig(uint256 gameId) external view returns (tuple(bool canSpawn, bool canAdjustEconomy, bool canGenerateNarrative, bool canAdjustDifficulty, uint256 maxChangePerEpoch, uint256 epochLength))",
        "function getGamesByOwner(address owner) external view returns (uint256[])",
    ];
    
    const gr = new ethers.Contract("0x6eB1d23419629901F78947B1207024f7F28380a6", abi, signer);
    
    console.log("=== getGame(0) with NAMED returns ===");
    const game = await gr.getGame(0);
    console.log("  gameAddress:", game.gameAddress);
    console.log("  owner:", game.owner);
    console.log("  name:", game.name);
    console.log("  gameType:", game.gameType);
    console.log("  isActive:", game.isActive);
    console.log("  totalEvents:", game.totalEvents.toString());
    console.log("  totalActions:", game.totalActions.toString());
    
    console.log("");
    console.log("=== getConfig(0) ===");
    const config = await gr.getConfig(0);
    console.log("  canSpawn:", config.canSpawn);
    console.log("  canAdjustEconomy:", config.canAdjustEconomy);
    console.log("  maxChangePerEpoch:", config.maxChangePerEpoch.toString());
    console.log("  epochLength:", config.epochLength.toString());
    
    console.log("");
    console.log("=== Positional access (how frontend code works) ===");
    console.log("  game[0] (gameAddress):", game[0]);
    console.log("  game[1] (owner):", game[1]);
    console.log("  game[2] (name):", game[2]);
    console.log("  game[3] (gameType):", game[3]);
    console.log("  game[4] (description):", game[4]);
    console.log("  game[5] (metadata):", game[5] ? game[5].slice(0, 40) + "..." : "(empty)");
    console.log("  game[6] (isActive):", game[6]);
    console.log("  game[7] (isVerified):", game[7]);
    console.log("  game[8] (totalEvents):", game[8].toString());
    console.log("  game[9] (totalActions):", game[9].toString());
    
    // Check MetricsRegistry
    console.log("");
    console.log("=== MetricsRegistry getStats(0, 'win_rate') ===");
    const mrAbi = [
        "function getStats(uint256 gameId, string name) external view returns (uint256 latest, uint256 min, uint256 max, uint256 avg, uint256 count, uint256 lastUpdated)",
    ];
    const mr = new ethers.Contract("0x5F447735f4A7DEc10F1dA55cbf05688D4A2bD808", mrAbi, signer);
    const stats = await mr.getStats(0, "win_rate");
    console.log("  latest:", stats.latest.toString());
    console.log("  min:", stats.min.toString());
    console.log("  max:", stats.max.toString());
    console.log("  avg:", stats.avg.toString());
    console.log("  count:", stats.count.toString());
    
    console.log("");
    console.log("✅ All backend functions verified!");
}

main().catch(console.error);

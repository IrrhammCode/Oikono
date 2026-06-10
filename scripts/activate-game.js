const hre = require("hardhat");
async function main() {
    const gr = await hre.ethers.getContractAt("GameRegistry", "0x6eB1d23419629901F78947B1207024f7F28380a6");
    
    // Activate game 0
    console.log("Activating game 0...");
    const tx = await gr.activateGame(0);
    const receipt = await tx.wait();
    console.log("Activated! TX:", receipt.hash);

    // Verify
    const game = await gr.getGame(0);
    console.log("Game 0 active:", game[6]);
}
main().catch(console.error);

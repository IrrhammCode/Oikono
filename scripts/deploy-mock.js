const hre = require("hardhat");

async function main() {
  console.log("Deploying Mock Contracts to Somnia Testnet...");

  const MockGame = await hre.ethers.getContractFactory("MockGame");
  const game = await MockGame.deploy();
  await game.waitForDeployment();
  console.log("Primary Game Contract (MockGame):", await game.getAddress());

  console.log("\nDeployment Successful!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

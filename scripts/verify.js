const { ethers } = require("hardhat");
const fs = require("fs");

// ═══════════════════════════════════════════════
// OIKONO — Contract Verification Script
// Verifies contracts on Somnia block explorer
// ═══════════════════════════════════════════════

async function main() {
    console.log("╔══════════════════════════════════════════════════════════════╗");
    console.log("║  OIKONO — Contract Verification                             ║");
    console.log("╚══════════════════════════════════════════════════════════════╝\n");

    // Load deployment info
    let deploymentInfo;
    try {
        deploymentInfo = JSON.parse(fs.readFileSync("./deployment-universal-agent.json", "utf8"));
    } catch (e) {
        console.error("❌ deployment-universal-agent.json not found. Run deploy first.");
        process.exit(1);
    }

    const contracts = {
        ...deploymentInfo.agent,
        ...deploymentInfo.registry,
        ...deploymentInfo.metrics,
        ...deploymentInfo.llm,
        ...deploymentInfo.plugins,
        ...deploymentInfo.game,
        ...deploymentInfo.economy,
        ...deploymentInfo.utils,
    };

    console.log("📋 Contracts to verify:");
    for (const [name, address] of Object.entries(contracts)) {
        if (address && address !== "0x0000000000000000000000000000000000000000") {
            console.log(`  • ${name}: ${address}`);
        }
    }

    console.log("\n⚠️  Note: Somnia testnet explorer may not support automated verification.");
    console.log("    You can verify manually at: https://shannon-explorer.somnia.network/\n");

    // Try to verify using hardhat-verify if available
    try {
        const hre = require("hardhat");

        for (const [name, address] of Object.entries(contracts)) {
            if (!address || address === "0x0000000000000000000000000000000000000000") continue;

            try {
                console.log(`\n🔍 Verifying ${name} at ${address}...`);
                await hre.run("verify:verify", {
                    address: address,
                    constructorArguments: [],
                });
                console.log(`  ✅ ${name} verified!`);
            } catch (e) {
                if (e.message.includes("Already Verified")) {
                    console.log(`  ✅ ${name} already verified`);
                } else {
                    console.log(`  ⚠️  ${name}: ${e.message.slice(0, 80)}`);
                }
            }
        }
    } catch (e) {
        console.log("📝 Manual verification steps:");
        console.log("  1. Go to https://shannon-explorer.somnia.network/");
        console.log("  2. Search for contract address");
        console.log("  3. Click 'Verify & Publish'");
        console.log("  4. Select compiler: Solidity 0.8.26");
        console.log("  5. Paste flattened source code");
        console.log("  6. Submit\n");

        console.log("💡 To flatten contracts:");
        console.log("  npx hardhat flatten contracts/game/GameMaster.sol > flattened/GameMaster_flat.sol\n");
    }

    // Generate verification URLs
    console.log("\n📎 Contract URLs:");
    const explorer = "https://shannon-explorer.somnia.network/address";
    for (const [name, address] of Object.entries(contracts)) {
        if (address && address !== "0x0000000000000000000000000000000000000000") {
            console.log(`  ${name}: ${explorer}/${address}`);
        }
    }

    console.log("\n✅ Verification script complete!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

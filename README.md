# OIKONO — Autonomous AI Game Master on Somnia

> Universal AI Agent for Web3 Games. One import. Three lines of config. Infinite possibilities.

## Overview

OIKONO is an autonomous AI agent system built on **Somnia Agentic L1** that brings intelligent, on-chain game mechanics to any Web3 game. It leverages Somnia's unique features:

- **On-Chain Reactivity** — React to game events in the same block (MEV-resistant)
- **LLM Inference** — AI-powered decision making via Qwen3-30B
- **Agent Memory** — On-chain learning from past decisions
- **Dynamic NFTs** — AI-generated game entities as ERC-721 tokens

## Architecture

```
Your Game → GameReactor → Plugins → Somnia LLM → Result
   emit        1 import    spawn     Qwen3-30B    NFT
   events                  economy                state
                           narrative               rewards
                           balance
```

## Smart Contracts

### Agent System (`contracts/agents/`)
| Contract | Description |
|----------|-------------|
| `OikonoAgent.sol` | The BRAIN — autonomous AI agent with LLM integration |
| `AgentMemory.sol` | On-chain learning memory (decision history, patterns) |
| `GameKnowledgeBase.sol` | Cross-game knowledge base |
| `GameReactor.sol` | Entry point for games (1 import, 3 lines config) |
| `AgentRuntime.sol` | Plugin execution runtime |

### AI Plugins (`contracts/agents/plugins/`)
| Plugin | Description |
|--------|-------------|
| `SpawnPlugin` | Generate enemies, NPCs, items with AI-determined stats |
| `EconomyPlugin` | AI-driven economy management (rewards, burn, inflation) |
| `NarrativePlugin` | AI-generated quests, dialogues, story events |
| `BalancePlugin` | Automatic game balancing based on win rates |

### Game Contracts (`contracts/game/`)
| Contract | Description |
|----------|-------------|
| `GameMaster.sol` | Autonomous AI Game Master (Somnia Reactivity + LLM) |
| `BattleArena.sol` | Battle system with rewards |
| `PlayerRegistry.sol` | Player management |
| `EnemyNFT.sol` | AI-generated enemy NFTs (ERC-721) |

### Economy (`contracts/economy/`)
| Contract | Description |
|----------|-------------|
| `OIKToken.sol` | OIK token (ERC-20 with 0.5% burn tax) |
| `Treasury.sol` | Token burn and buyback |
| `RewardDistributor.sol` | Reward distribution with emission phases |
| `EconomyParams.sol` | Configurable economy parameters |

### Utilities (`contracts/utils/`)
| Contract | Description |
|----------|-------------|
| `AntiSybil.sol` | Anti-bot protection (cooldowns, stake minimum) |
| `CircuitBreaker.sol` | Emergency pause system (guardian voting) |
| `TWAPOracle.sol` | TWAP price oracle |

## Quick Start

### Prerequisites
- Node.js v18+
- MetaMask or compatible wallet

### Installation
```bash
git clone <repo-url>
cd oikono
npm install
```

### Compile
```bash
npm run compile
```

### Test
```bash
npm test
```

### Deploy to Testnet
```bash
# Set your private key
export PRIVATE_KEY=your_private_key_here

# Deploy all contracts
npm run deploy:testnet

# Deploy universal agent (with full AI stack)
npm run deploy:agent
```

### Run Frontend
```bash
npm run dev
# Open http://localhost:9090
```

## Network Configuration

| Network | Chain ID | RPC |
|---------|----------|-----|
| Somnia Testnet | 50312 | `https://dream-rpc.somnia.network` |
| Somnia Mainnet | 5031 | `https://mainnet-rpc.somnia.network` |

## Integration Guide

### For Game Developers

1. **Import GameReactor**
```solidity
import "@oikono/contracts/agents/GameReactor.sol";

contract MyGame is GameReactor {
    constructor() GameReactor("MyGame", GameType.RPG) {
        enablePlugin(AgentPlugin.SPAWN);
        enablePlugin(AgentPlugin.BALANCE);
    }
}
```

2. **Emit Events**
```solidity
function move(uint256 x, uint256 y) external {
    emit PlayerMoved(msg.sender, x, y, xp, level);
    // Agent handles everything!
}
```

3. **That's it!** The agent automatically:
   - Detects game events via Somnia Reactivity
   - Reads game state
   - Makes AI-powered decisions
   - Executes actions (spawn enemies, adjust economy, etc.)
   - Learns from outcomes

## Project Structure

```
oikono/
├── contracts/           # Solidity smart contracts
│   ├── agents/          # AI agent system
│   ├── game/            # Game contracts
│   ├── economy/         # Token economics
│   ├── tokens/          # OIK token
│   ├── utils/           # Utilities
│   └── examples/        # Example games
├── frontend/            # Web interface
├── scripts/             # Deployment scripts
├── test/                # Test files
└── hardhat.config.js    # Hardhat configuration
```

## Testing

The project has comprehensive test coverage:

```bash
npm test
```

Test suites:
- **AgentKit.test.js** — Agent runtime, plugins, registry
- **CoreContracts.test.js** — CircuitBreaker, AntiSybil, BattleArena, Treasury
- **OIKONO.test.js** — GameMaster, PlayerRegistry, EnemyNFT integration
- **UniversalAgent.test.js** — OikonoAgent, AgentMemory, KnowledgeBase

## Deployment

After deployment, update `frontend/config.js` with the deployed contract addresses:

```javascript
const CONFIG = {
  CONTRACTS: {
    OikonoAgent: '0x...',
    AgentRuntime: '0x...',
    // ... other addresses
  }
};
```

## Security

- **Circuit Breaker** — Emergency pause via guardian voting (3/5 required)
- **Anti-Sybil** — Cooldowns, stake minimums, unique opponent tracking
- **Burn Tax** — 0.5% on OIK transfers
- **Daily Reward Cap** — 2000 OIK per player per day

## License

MIT

## Links

- [Somnia Network](https://somnia.network)
- [Somnia Documentation](https://docs.somnia.network)

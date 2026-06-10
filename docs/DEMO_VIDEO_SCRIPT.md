# 🎬 OIKONO Demo Video Script (2-5 minutes)

## Recording Setup
- **Screen recorder:** OBS / Windows Game Bar (Win+G)
- **Resolution:** 1920x1080
- **Browser:** Chrome with MetaMask
- **Network:** Somnia Testnet (Chain ID: 50312)

## Pre-Recording Checklist
- [ ] MetaMask connected to Somnia Testnet
- [ ] Wallet has STT tokens (faucet)
- [ ] Frontend running (`npm run dev` → localhost:9090)
- [ ] All contracts deployed (already done)

---

## 🎬 Scene 1: Intro (15 sec)

**Show:** Landing page of OIKONO

**Say/Txt:**
> "This is OIKONO — an Autonomous AI Game Master built on Somnia Agentic L1. 
> It uses on-chain AI to manage game economies, generate enemies, and balance gameplay — all autonomously."

---

## 🎬 Scene 2: Connect Wallet + System Status (20 sec)

**Action:** Click "Connect Wallet" → Show MetaMask popup → Connect

**Show:** Dashboard with real-time stats
- Total Players
- Total Enemies
- Agent Memory entries
- OIK Token balance

**Say/Txt:**
> "Connecting to Somnia Testnet. The dashboard shows real-time on-chain data — 
> player count, enemy count, agent decisions, and OIK token balance."

---

## 🎬 Scene 3: Register Player + AI Enemy Generation (45 sec)

**Action:** 
1. Click "Register Player" → Enter coordinates (50, 50)
2. Show transaction on explorer
3. Click "Generate Enemy" → AI generates enemy
4. Show enemy NFT details (name, class, element, power, threat level)

**Say/Txt:**
> "I'm registering a player at position (50, 50). Now the AI GameMaster analyzes 
> the player's level, XP, and game state to generate a challenging enemy.
> 
> The enemy is minted as an NFT with AI-determined stats: name, class, element, 
> power level, and threat rating. This uses Somnia's on-chain LLM inference."

---

## 🎬 Scene 4: Battle System (30 sec)

**Action:**
1. Select enemy → Click "Battle"
2. Show entry fee (10 OIK) → Approve → Execute
3. Show battle result (Victory/Defeat, XP gained, reward)

**Say/Txt:**
> "The player battles the AI-generated enemy. Entry fee is 10 OIK — 40% gets burned, 
> creating deflationary pressure. The AI tracks win rates and adjusts difficulty over time."

---

## 🎬 Scene 5: Agent Autonomous Decision (45 sec)

**Action:**
1. Inject metrics (show win_rate at 82% — too high)
2. Run pattern detection → Show "win_rate_spike" detected
3. Generate suggestions → Show AI recommendation
4. Execute agent action → Show autonomous adjustment

**Say/Txt:**
> "Here's where it gets interesting. The agent detects that win rate is 82% — way above 
> the healthy 45-65% range. Pattern detection flags this as a spike. The AI generates 
> a suggestion: 'Increase difficulty by 15%'.
> 
> The agent autonomously executes this adjustment on-chain. No human intervention needed."

---

## 🎬 Scene 6: On-Chain Proof (30 sec)

**Action:**
1. Open Somnia Explorer → Show deployed contracts
2. Show transaction history
3. Show EnemyNFT with metadata
4. Show AgentMemory entries

**Say/Txt:**
> "Everything is on-chain on Somnia Testnet. Here are 25+ deployed contracts, 
> each with verified source code. Enemy NFTs, agent memory, game metrics — 
> all transparent and verifiable."

---

## 🎬 Scene 7: Architecture + Somnia Integration (30 sec)

**Show:** Architecture diagram or README

**Say/Txt:**
> "OIKONO leverages three key Somnia features:
> 1. On-Chain Reactivity — same-block event detection
> 2. LLM Inference — Qwen3-30B for AI decisions
> 3. Agent Memory — on-chain learning from outcomes
> 
> One import, three lines of code, and any game has an autonomous AI brain."

---

## 🎬 Scene 8: Outro (15 sec)

**Show:** GitHub repo + landing page

**Say/Txt:**
> "OIKONO — Autonomous AI Game Master on Somnia L1.
> GitHub: github.com/IrrhammCode/oikono
> Built for the Somnia AI Hackathon."

---

## Post-Recording
1. Edit to 2-5 minutes
2. Add captions/subtitles
3. Upload to YouTube (unlisted is fine)
4. Add link to README and submission

## Key Points to Highlight
- ✅ Working prototype (not just mockups)
- ✅ Real on-chain transactions on Somnia Testnet
- ✅ Agent-first design (Somnia Reactivity + LLM + Memory)
- ✅ Autonomous operation (no manual intervention)
- ✅ 25+ contracts, comprehensive test coverage

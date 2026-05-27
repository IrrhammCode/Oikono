/* ═══════════════════════════════════════════════
   OIKONO — AI Agent Interface
   Wallet Connection + Contract Interaction
   ═══════════════════════════════════════════════ */

// ── Somnia Testnet Config ──
const SOMNIA_CHAIN_ID = '0xC478'; // 50312
const SOMNIA_RPC = 'https://dream-rpc.somnia.network';
const SOMNIA_WS = 'wss://dream-rpc.somnia.network/ws';

// ── Contract Addresses (update after deployment) ──
const CONTRACTS = {
  PlayerRegistry: '0x0000000000000000000000000000000000000000',
  GameMaster: '0x0000000000000000000000000000000000000000',
  EnemyNFT: '0x0000000000000000000000000000000000000000',
  BattleArena: '0x0000000000000000000000000000000000000000',
  OIKToken: '0x0000000000000000000000000000000000000000',
};

// ── Minimal ABIs ──
const ABI_PlayerRegistry = [
  'function registerPlayer(uint256 x, uint256 y) external',
  'function move(uint256 x, uint256 y) external',
  'function getPlayer(address player) external view returns (uint256 x, uint256 y, uint256 xp, uint256 level, uint256 totalBattles, uint256 wins, uint256 losses, bool exists)',
  'function playerExists(address player) external view returns (bool)',
  'function totalPlayers() external view returns (uint256)',
  'event PlayerRegistered(address indexed player, uint256 x, uint256 y)',
  'event PlayerMoved(address indexed player, uint256 x, uint256 y, uint256 xp, uint256 level)',
  'event PlayerLevelUp(address indexed player, uint256 newLevel)',
];

const ABI_GameMaster = [
  'function triggerEnemyGeneration(address player) external',
  'function getStats() external view returns (uint256 totalEnemies, uint256 totalLLM, uint256 subscriptions)',
  'event EnemyGenerated(address indexed player, uint256 indexed tokenId, string name, string enemyClass, uint256 power)',
  'event LLMRequestSent(uint256 indexed requestId, address indexed player, string prompt)',
];

const ABI_EnemyNFT = [
  'function getEnemy(uint256 tokenId) external view returns (string name, string enemyClass, string element, uint256 power, uint256 threatLevel, address creator, uint256 battlesWon, uint256 battlesLost, bool isBoss)',
  'function getPlayerEnemies(address player) external view returns (uint256[] memory)',
  'function totalEnemiesMinted() external view returns (uint256)',
  'function balanceOf(address owner) external view returns (uint256)',
  'function ownerOf(uint256 tokenId) external view returns (address)',
  'event EnemyMinted(uint256 indexed tokenId, address indexed creator, string name, string enemyClass, uint256 power)',
];

const ABI_BattleArena = [
  'function executeBattle(uint256 enemyTokenId) external',
  'function claimRewards() external',
  'function getPendingRewards(address player) external view returns (uint256)',
  'function getPlayerBattleHistory(address player) external view returns (tuple(address player, uint256 enemyTokenId, bool playerWon, uint256 xpGained, uint256 rewardAmount, uint256 timestamp)[])',
  'function baseEntryFee() external view returns (uint256)',
  'function baseReward() external view returns (uint256)',
  'function rewardMultiplier() external view returns (uint256)',
  'event BattleStarted(address indexed player, uint256 enemyTokenId, uint256 entryFee)',
  'event BattleEnded(address indexed player, uint256 enemyTokenId, bool playerWon, uint256 reward, uint256 xpGained)',
  'event RewardClaimed(address indexed player, uint256 amount)',
];

const ABI_OIKToken = [
  'function balanceOf(address account) external view returns (uint256)',
  'function decimals() external view returns (uint8)',
  'function approve(address spender, uint256 amount) external returns (bool)',
  'function allowance(address owner, address spender) external view returns (uint256)',
];

// ── State ──
let provider = null;
let signer = null;
let userAddress = null;
let contracts = {};

// ══════════════════════════════════════════════
// WALLET CONNECTION
// ══════════════════════════════════════════════

async function connectWallet() {
  if (typeof window.ethereum === 'undefined') {
    alert('MetaMask not detected. Please install MetaMask.');
    return;
  }

  try {
    // Request accounts
    const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
    userAddress = accounts[0];

    // Setup ethers provider & signer
    provider = new ethers.BrowserProvider(window.ethereum);
    signer = await provider.getSigner();

    // Ensure Somnia testnet
    await ensureSomniaNetwork();

    // Initialize contracts
    initContracts();

    // Update UI
    updateConnectionUI(true);

    // Load player data
    await loadPlayerData();

    // Listen for events
    listenContractEvents();

    // Listen for account/chain changes
    window.ethereum.on('accountsChanged', handleAccountsChanged);
    window.ethereum.on('chainChanged', () => window.location.reload());

    agentLog('Wallet connected: ' + shortAddr(userAddress), 'success');
    agentLog('Somnia Testnet (Chain ID: 50312)', 'info');

  } catch (err) {
    console.error('Connection failed:', err);
    agentLog('Connection failed: ' + err.message, 'error');
  }
}

function disconnectWallet() {
  userAddress = null;
  signer = null;
  contracts = {};

  updateConnectionUI(false);
  agentLog('Wallet disconnected', 'info');
}

async function ensureSomniaNetwork() {
  const chainId = await window.ethereum.request({ method: 'eth_chainId' });
  if (chainId !== SOMNIA_CHAIN_ID) {
    try {
      await window.ethereum.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: SOMNIA_CHAIN_ID }],
      });
    } catch (switchError) {
      // Chain not added yet
      if (switchError.code === 4902) {
        await window.ethereum.request({
          method: 'wallet_addEthereumChain',
          params: [{
            chainId: SOMNIA_CHAIN_ID,
            chainName: 'Somnia Testnet',
            nativeCurrency: { name: 'STT', symbol: 'STT', decimals: 18 },
            rpcUrls: [SOMNIA_RPC],
            blockExplorerUrls: ['https://testnet.somnia.network'],
          }],
        });
      } else {
        throw switchError;
      }
    }
  }
}

function handleAccountsChanged(accounts) {
  if (accounts.length === 0) {
    // Disconnected
    userAddress = null;
    signer = null;
    contracts = {};
    updateConnectionUI(false);
    agentLog('Wallet disconnected', 'info');
  } else {
    userAddress = accounts[0];
    updateConnectionUI(true);
    loadPlayerData();
    agentLog('Account changed: ' + shortAddr(userAddress), 'info');
  }
}

function initContracts() {
  contracts.playerRegistry = new ethers.Contract(CONTRACTS.PlayerRegistry, ABI_PlayerRegistry, signer);
  contracts.gameMaster = new ethers.Contract(CONTRACTS.GameMaster, ABI_GameMaster, signer);
  contracts.enemyNFT = new ethers.Contract(CONTRACTS.EnemyNFT, ABI_EnemyNFT, signer);
  contracts.battleArena = new ethers.Contract(CONTRACTS.BattleArena, ABI_BattleArena, signer);
  contracts.oikToken = new ethers.Contract(CONTRACTS.OIKToken, ABI_OIKToken, signer);
}

// ══════════════════════════════════════════════
// UI UPDATES
// ══════════════════════════════════════════════

function updateConnectionUI(connected) {
  const connectBtn = document.getElementById('connectBtn');
  const connectText = document.getElementById('connectText');
  const disconnectBtn = document.getElementById('disconnectBtn');
  const networkStatus = document.getElementById('networkStatus');
  const connStatus = document.getElementById('connStatus');
  const playerStatus = document.getElementById('playerStatus');
  const statusText = document.getElementById('statusText');
  const walletAddress = document.getElementById('walletAddress');

  if (connected) {
    connectText.textContent = shortAddr(userAddress);
    connectBtn.classList.add('connected');
    if (disconnectBtn) disconnectBtn.style.display = 'inline-flex';
    if(networkStatus) networkStatus.textContent = 'somnia_testnet://connected';
    if(connStatus) {
      connStatus.textContent = '✓ Wallet connected: ' + shortAddr(userAddress);
      connStatus.className = 'terminal__success';
    }
    if(playerStatus) playerStatus.classList.add('status-badge--online');
    if(statusText) statusText.textContent = 'CONNECTED';
    if(walletAddress) walletAddress.textContent = shortAddr(userAddress);
    
    // Populate player address in dashboard
    const pAddr = document.getElementById('playerAddress');
    if(pAddr) pAddr.textContent = shortAddr(userAddress);
    
    // Set route to dashboard
    window.location.hash = '#/dashboard';
  } else {
    connectText.textContent = 'Connect Wallet';
    connectBtn.classList.remove('connected');
    if (disconnectBtn) disconnectBtn.style.display = 'none';
    if(networkStatus) networkStatus.textContent = 'somnia_testnet://disconnected';
    if(connStatus) {
      connStatus.textContent = '... Awaiting wallet connection...';
      connStatus.className = 'terminal__success';
    }
    if(playerStatus) playerStatus.classList.remove('status-badge--online');
    if(statusText) statusText.textContent = 'NOT CONNECTED';
    if(walletAddress) walletAddress.textContent = 'Not connected';
    
    // Set route to landing
    window.location.hash = '#/';
  }
}

// ── Single Page Router ──
function showDashboardView() {
  const landingSections = document.querySelectorAll('.landing-section');
  const appView = document.getElementById('appDashboard');
  const navLinks = document.querySelector('.navbar__links');
  const navbar = document.getElementById('navbar');
  const footer = document.querySelector('.footer');

  landingSections.forEach(el => el.style.display = 'none');
  if(appView) appView.style.display = 'grid';
  if(navLinks) navLinks.style.display = 'none';
  if(navbar) navbar.classList.add('navbar--app');
  if(footer) footer.style.display = 'none';
}

function showLandingView() {
  const landingSections = document.querySelectorAll('.landing-section');
  const appView = document.getElementById('appDashboard');
  const navLinks = document.querySelector('.navbar__links');
  const navbar = document.getElementById('navbar');
  const footer = document.querySelector('.footer');

  landingSections.forEach(el => el.style.display = '');
  if(appView) appView.style.display = 'none';
  if(navLinks) navLinks.style.display = '';
  if(navbar) navbar.classList.remove('navbar--app');
  if(footer) footer.style.display = '';
}

function handleRouting() {
  const hash = window.location.hash || '#/';
  
  if (hash === '#/dashboard') {
    if (userAddress) {
      showDashboardView();
    } else {
      // Redirect to landing if not logged in
      window.location.hash = '#/';
    }
  } else {
    // Show landing
    showLandingView();
    
    // Support section navigation scroll
    const matched = hash.match(/^#\/([a-zA-Z0-9_-]+)$/);
    if (matched) {
      const sectionId = matched[1];
      const el = document.getElementById(sectionId);
      if (el) {
        setTimeout(() => {
          el.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }, 100);
      }
    }
  }
}

async function loadPlayerData() {
  if (!contracts.playerRegistry || !userAddress) return;

  try {
    const exists = await contracts.playerRegistry.playerExists(userAddress);

    if (exists) {
      const data = await contracts.playerRegistry.getPlayer(userAddress);
      document.getElementById('playerAddress').textContent = shortAddr(userAddress);
      document.getElementById('playerLevel').textContent = data.level.toString();
      document.getElementById('playerXP').textContent = data.xp.toString();

      // Enable game buttons
      document.getElementById('registerBtn').disabled = true;
      document.getElementById('registerBtn').innerHTML = '<span class="cmd-text">Registered</span>';
      setGameButtonsEnabled(true);

      agentLog('Player data loaded — Level ' + data.level + ', XP: ' + data.xp, 'success');
    } else {
      document.getElementById('playerAddress').textContent = shortAddr(userAddress);
      document.getElementById('playerLevel').textContent = '-';
      document.getElementById('playerXP').textContent = '-';

      document.getElementById('registerBtn').disabled = false;
      document.getElementById('registerBtn').innerHTML = '<span class="cmd-text">Register Player</span>';
      setGameButtonsEnabled(false);

      agentLog('Player not registered yet. Click Register to start.', 'info');
    }

    // Load enemy count
    try {
      const enemyCount = await contracts.enemyNFT.balanceOf(userAddress);
      agentLog('You own ' + enemyCount + ' enemy NFT(s)', 'info');
    } catch (_) {}

    // Load OIK balance
    try {
      const balance = await contracts.oikToken.balanceOf(userAddress);
      const decimals = await contracts.oikToken.decimals();
      const formatted = Number(balance) / Math.pow(10, Number(decimals));
      document.getElementById('playerGold').textContent = formatted.toFixed(0);
    } catch (_) {}

  } catch (err) {
    console.error('Failed to load player data:', err);
    agentLog('Failed to load player data: ' + err.message, 'error');
  }
}

function setGameButtonsEnabled(enabled) {
  const ids = ['moveBtn', 'gatherBtn', 'trainBtn', 'buildBtn', 'battleBtn'];
  ids.forEach(id => {
    const btn = document.getElementById(id);
    if (btn) btn.disabled = !enabled;
  });
}

// ══════════════════════════════════════════════
// GAME ACTIONS
// ══════════════════════════════════════════════

async function registerPlayer() {
  if (!contracts.playerRegistry) return;
  try {
    agentLog('Registering player on-chain...', 'info');
    const x = Math.floor(Math.random() * 98) + 1;
    const y = Math.floor(Math.random() * 98) + 1;
    const tx = await contracts.playerRegistry.registerPlayer(x, y);
    agentLog('TX sent: ' + tx.hash, 'tx');
    await tx.wait();
    agentLog('Player registered at (' + x + ', ' + y + ')', 'success');
    await loadPlayerData();
  } catch (err) {
    agentLog('Register failed: ' + parseError(err), 'error');
  }
}

async function movePlayer() {
  if (!contracts.playerRegistry) return;
  try {
    const x = Math.floor(Math.random() * 98) + 1;
    const y = Math.floor(Math.random() * 98) + 1;
    agentLog('Moving to (' + x + ', ' + y + ')...', 'info');
    const tx = await contracts.playerRegistry.move(x, y);
    agentLog('TX sent: ' + tx.hash, 'tx');
    const receipt = await tx.wait();
    agentLog('Moved to (' + x + ', ' + y + '). XP gained!', 'success');

    // Trigger enemy generation via GameMaster
    try {
      agentLog('Triggering AI enemy generation...', 'info');
      const tx2 = await contracts.gameMaster.triggerEnemyGeneration(userAddress);
      agentLog('Enemy TX sent: ' + tx2.hash, 'tx');
      await tx2.wait();
      agentLog('Enemy generated! Check your NFTs.', 'success');
    } catch (e2) {
      agentLog('Enemy generation: ' + parseError(e2), 'info');
    }

    await loadPlayerData();
  } catch (err) {
    agentLog('Move failed: ' + parseError(err), 'error');
  }
}

async function gatherResources() {
  // Simplified: move to a random spot to gain XP
  if (!contracts.playerRegistry) return;
  try {
    const x = Math.floor(Math.random() * 98) + 1;
    const y = Math.floor(Math.random() * 98) + 1;
    agentLog('Gathering resources at (' + x + ', ' + y + ')...', 'info');
    const tx = await contracts.playerRegistry.move(x, y);
    agentLog('TX sent: ' + tx.hash, 'tx');
    await tx.wait();
    agentLog('Resources gathered! +XP', 'success');
    await loadPlayerData();
  } catch (err) {
    agentLog('Gather failed: ' + parseError(err), 'error');
  }
}

async function trainUnit() {
  // Placeholder — would need a dedicated training contract
  agentLog('Training unit... (feature requires dedicated contract)', 'info');
  agentLog('For now, move around to gain XP and level up!', 'info');
}

async function buildStructure() {
  // Placeholder — would need a dedicated building contract
  agentLog('Building structure... (feature requires dedicated contract)', 'info');
  agentLog('For now, battle enemies to earn OIK tokens!', 'info');
}

async function findBattle() {
  if (!contracts.enemyNFT || !contracts.battleArena) return;
  try {
    // Find an enemy to battle
    const totalMinted = await contracts.enemyNFT.totalEnemiesMinted();
    if (totalMinted === 0n) {
      agentLog('No enemies exist yet. Move around to spawn one!', 'info');
      return;
    }

    // Pick the latest enemy
    const enemyId = Number(totalMinted) - 1;
    const enemy = await contracts.enemyNFT.getEnemy(enemyId);
    agentLog('Found enemy: ' + enemy[0] + ' (Power: ' + enemy[3] + ')', 'info');

    // Check OIK balance for entry fee
    const entryFee = await contracts.battleArena.baseEntryFee();
    const balance = await contracts.oikToken.balanceOf(userAddress);
    const adjustedFee = (entryFee * BigInt(enemy[3])) / 100n;

    if (balance < adjustedFee) {
      agentLog('Insufficient OIK for entry fee. Need: ' + ethers.formatEther(adjustedFee), 'error');
      return;
    }

    // Approve OIK spending
    const allowance = await contracts.oikToken.allowance(userAddress, CONTRACTS.BattleArena);
    if (allowance < adjustedFee) {
      agentLog('Approving OIK spending...', 'info');
      const approveTx = await contracts.oikToken.approve(CONTRACTS.BattleArena, adjustedFee);
      await approveTx.wait();
      agentLog('OIK approved', 'success');
    }

    // Execute battle
    agentLog('Entering battle against ' + enemy[0] + '...', 'info');
    const tx = await contracts.battleArena.executeBattle(enemyId);
    agentLog('Battle TX sent: ' + tx.hash, 'tx');
    const receipt = await tx.wait();

    // Parse BattleEnded event
    const battleLog = receipt.logs.find(log => {
      try { return contracts.battleArena.interface.parseLog(log)?.name === 'BattleEnded'; }
      catch { return false; }
    });

    if (battleLog) {
      const parsed = contracts.battleArena.interface.parseLog(battleLog);
      const won = parsed.args.playerWon;
      const xp = parsed.args.xpGained;
      const reward = parsed.args.reward;
      if (won) {
        agentLog('VICTORY! +' + xp + ' XP, +' + ethers.formatEther(reward) + ' OIK reward', 'success');
      } else {
        agentLog('DEFEAT. +' + xp + ' XP gained. Try again!', 'info');
      }
    }

    await loadPlayerData();
  } catch (err) {
    agentLog('Battle failed: ' + parseError(err), 'error');
  }
}

// ══════════════════════════════════════════════
// EVENT LISTENING
// ══════════════════════════════════════════════

function listenContractEvents() {
  if (!contracts.playerRegistry || !contracts.gameMaster) return;

  // PlayerMoved events
  contracts.playerRegistry.on('PlayerMoved', (player, x, y, xp, level) => {
    addLiveEvent('event', 'PlayerMoved', shortAddr(player) + ' → (' + x + ',' + y + ') | XP: ' + xp);
  });

  // PlayerLevelUp events
  contracts.playerRegistry.on('PlayerLevelUp', (player, newLevel) => {
    addLiveEvent('mint', 'LevelUp', shortAddr(player) + ' reached Level ' + newLevel);
  });

  // EnemyGenerated events
  contracts.gameMaster.on('EnemyGenerated', (player, tokenId, name, enemyClass, power) => {
    addLiveEvent('mint', 'EnemyMinted', name + ' (#' + tokenId + ') Power: ' + power + ' for ' + shortAddr(player));
  });

  // Battle events
  if (contracts.battleArena) {
    contracts.battleArena.on('BattleEnded', (player, enemyTokenId, playerWon, reward, xpGained) => {
      const result = playerWon ? 'WON' : 'LOST';
      addLiveEvent('tx', 'Battle', shortAddr(player) + ' ' + result + ' vs Enemy #' + enemyTokenId);
    });
  }

  agentLog('Listening for on-chain events...', 'info');
}

function addLiveEvent(type, label, message) {
  const eventStream = document.getElementById('eventStream');
  if (!eventStream) return;

  const clsMap = {
    event: 'stream-line__type--event',
    agent: 'stream-line__type--agent',
    mint: 'stream-line__type--mint',
    tx: 'stream-line__type--tx',
  };

  const now = new Date();
  const time = now.toTimeString().slice(0, 8);

  const line = document.createElement('div');
  line.className = 'stream-line';
  line.innerHTML =
    '<span class="stream-line__time">' + time + '</span>' +
    '<span class="stream-line__type ' + (clsMap[type] || clsMap.event) + '">' + label + '</span>' +
    '<span class="stream-line__msg">' + message + '</span>';

  eventStream.prepend(line);
  while (eventStream.children.length > 30) {
    eventStream.removeChild(eventStream.lastChild);
  }
}

// ══════════════════════════════════════════════
// AGENT LOG (Game Panel)
// ══════════════════════════════════════════════

function agentLog(message, type) {
  const output = document.getElementById('agentOutput');
  if (!output) return;

  const typeCls = {
    info: 'stream-line__type--info',
    success: 'stream-line__type--mint',
    error: 'stream-line__type--event',
    tx: 'stream-line__type--tx',
  };

  const now = new Date();
  const time = now.toTimeString().slice(0, 8);

  const line = document.createElement('div');
  line.className = 'stream-line';
  line.innerHTML =
    '<span class="stream-line__time">' + time + '</span>' +
    '<span class="stream-line__type ' + (typeCls[type] || typeCls.info) + '">' + (type || 'INFO').toUpperCase() + '</span>' +
    '<span class="stream-line__msg">' + message + '</span>';

  output.appendChild(line);
  output.scrollTop = output.scrollHeight;
}

// ══════════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════════

function shortAddr(addr) {
  if (!addr) return '-';
  return addr.slice(0, 6) + '..' + addr.slice(-4);
}

function parseError(err) {
  if (err.reason) return err.reason;
  if (err.data?.message) return err.data.message;
  if (err.message) {
    const match = err.message.match(/reason="([^"]+)"/);
    if (match) return match[1];
    return err.message.slice(0, 120);
  }
  return 'Unknown error';
}

// ══════════════════════════════════════════════
// LANDING PAGE EFFECTS (preserved from original)
// ══════════════════════════════════════════════

document.addEventListener('DOMContentLoaded', () => {

  // ── Navbar scroll effect ──
  const navbar = document.getElementById('navbar');
  window.addEventListener('scroll', () => {
    if (window.scrollY > 40) {
      navbar.classList.add('scrolled');
    } else {
      navbar.classList.remove('scrolled');
    }
  }, { passive: true });

  // ── Intersection Observer for fade-up animations ──
  const fadeElements = document.querySelectorAll('.fade-up');
  const fadeObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
        fadeObserver.unobserve(entry.target);
      }
    });
  }, { threshold: 0.1, rootMargin: '0px 0px -50px 0px' });
  fadeElements.forEach(el => fadeObserver.observe(el));

  // ── Code tab switching ──
  const codeTabs = document.querySelectorAll('.code-block__tab');
  const codeSolidity = document.getElementById('code-solidity');
  const codeJs = document.getElementById('code-js');

  codeTabs.forEach(tab => {
    tab.addEventListener('click', () => {
      codeTabs.forEach(t => t.classList.remove('active'));
      tab.classList.add('active');
      const target = tab.dataset.tab;
      if (target === 'solidity') {
        codeSolidity.style.display = 'block';
        codeJs.style.display = 'none';
      } else {
        codeSolidity.style.display = 'none';
        codeJs.style.display = 'block';
      }
    });
  });

  // ── Copy button ──
  const copyBtn = document.getElementById('copyBtn');
  if (copyBtn) {
    copyBtn.addEventListener('click', () => {
      const activeCode = codeSolidity.style.display !== 'none' ? codeSolidity : codeJs;
      navigator.clipboard.writeText(activeCode.textContent).then(() => {
        copyBtn.textContent = '✓ copied';
        setTimeout(() => { copyBtn.textContent = 'copy'; }, 2000);
      });
    });
  }

  // ── Block counter animation ──
  const statBlocks = document.getElementById('statBlocks');
  let blockCount = 18_247_391;
  function updateBlocks() {
    blockCount += Math.floor(Math.random() * 3) + 1;
    if (statBlocks) statBlocks.textContent = blockCount.toLocaleString();
  }
  updateBlocks();
  setInterval(updateBlocks, 800);

  // ── TPS counter ──
  const statTps = document.getElementById('statTps');
  if (statTps) {
    setInterval(() => {
      const base = 1050000;
      const variance = Math.floor(Math.random() * 5000) - 2500;
      statTps.textContent = (base + variance).toLocaleString();
    }, 3000);
  }

  // ── Smooth scroll ──
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', (e) => {
      const href = anchor.getAttribute('href');
      if (href.startsWith('#/')) {
        return; // Let hashchange router handle it
      }
      e.preventDefault();
      try {
        const target = document.querySelector(href);
        if (target) target.scrollIntoView({ behavior: 'smooth', block: 'start' });
      } catch (err) {
        console.warn('Smooth scroll fallback failed:', err);
      }
    });
  });

  // ── Hash Router Event Listeners ──
  window.addEventListener('hashchange', handleRouting);
  // Trigger initial routing setup
  handleRouting();

  // ── Capability card tilt ──
  document.querySelectorAll('.cap-card').forEach(card => {
    card.addEventListener('mousemove', (e) => {
      const rect = card.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      const rotateX = (y - rect.height / 2) / 20;
      const rotateY = (rect.width / 2 - x) / 20;
      card.style.transform = 'perspective(1000px) rotateX(' + rotateX + 'deg) rotateY(' + rotateY + 'deg) translateY(-4px)';
    });
    card.addEventListener('mouseleave', () => {
      card.style.transform = 'perspective(1000px) rotateX(0) rotateY(0) translateY(0)';
    });
  });

  // ── Sandbox Playground ──
  const manifestToggle = document.getElementById('manifestToggle');
  const manifestBody = document.getElementById('manifestBody');
  if (manifestToggle && manifestBody) {
    manifestToggle.addEventListener('click', () => {
      manifestBody.classList.toggle('open');
      const arrow = manifestToggle.querySelector('.arrow');
      arrow.textContent = manifestBody.classList.contains('open') ? '▲' : '▼';
    });
  }

  // Sandbox simulation (preserved)
  const btnMove = document.getElementById('btnTrigMove');
  const btnNPC = document.getElementById('btnTrigNPC');
  const btnEpoch = document.getElementById('btnTrigEpoch');
  const steps = ['stepEvent', 'stepAwake', 'stepInference', 'stepMint'].map(id => document.getElementById(id));
  const terminalBody = document.getElementById('llmTerminalBody');
  const nftContainer = document.getElementById('nftCardContainer');
  let isSimulating = false;

  function setStep(index) {
    steps.forEach((step, i) => {
      if (!step) return;
      if (i < index) { step.classList.remove('active'); step.classList.add('done'); }
      else if (i === index) { step.classList.add('active'); step.classList.remove('done'); }
      else { step.classList.remove('active', 'done'); }
    });
  }

  function updateStepText(type) {
    if (!steps[0]) return;
    if (type === 'epoch') {
      steps[0].querySelector('span').textContent = 'Epoch Reached (Block #1000)';
      steps[1].querySelector('span').textContent = 'Economy Controller Awakened';
      steps[2].querySelector('span').textContent = 'Macro Analytics Active';
      steps[3].querySelector('span').textContent = 'Policy Auto-Executed';
    } else {
      steps[0].querySelector('span').textContent = 'Event Emitted (Somnia L1)';
      steps[1].querySelector('span').textContent = 'Oikono Awakened (Reactivity)';
      steps[2].querySelector('span').textContent = 'LLM Inference Active';
      steps[3].querySelector('span').textContent = 'Dynamic NFT Minted';
    }
  }

  function termPrint(msg, type) {
    if (!terminalBody) return;
    const line = document.createElement('div');
    line.className = 'terminal__line';
    line.innerHTML = '<span class="terminal__prompt">▸</span><span class="terminal__' + (type || 'comment') + '">' + msg + '</span>';
    terminalBody.appendChild(line);
    terminalBody.scrollTop = terminalBody.scrollHeight;
  }

  function typeText(text, callback) {
    if (!terminalBody) { if (callback) callback(); return; }
    const line = document.createElement('div');
    line.className = 'terminal__line';
    line.innerHTML = '<span class="terminal__prompt">▸</span><span class="terminal__msg"></span>';
    terminalBody.appendChild(line);
    const span = line.querySelector('.terminal__msg');
    let i = 0;
    const interval = setInterval(() => {
      span.textContent += text[i];
      terminalBody.scrollTop = terminalBody.scrollHeight;
      i++;
      if (i >= text.length) { clearInterval(interval); if (callback) callback(); }
    }, 15);
  }

  function generateNFTCard(data) {
    return '<div class="nft-card">' +
      '<div class="nft-card__header"><span class="nft-card__type">' + data.element + ' CLASS</span><span class="nft-card__id">#' + (Math.floor(Math.random() * 9000) + 1000) + '</span></div>' +
      '<div class="nft-card__image"><div class="nft-card__image-glow"></div>' + data.icon + '</div>' +
      '<div class="nft-card__title">' + data.name + '</div>' +
      '<div class="nft-card__stats">' +
        '<div class="stat-box"><div class="stat-box__label">POWER</div><div class="stat-box__val">' + data.power + '</div></div>' +
        '<div class="stat-box"><div class="stat-box__label">SPEED</div><div class="stat-box__val">' + data.speed + '</div></div>' +
        '<div class="stat-box"><div class="stat-box__label">INTEL</div><div class="stat-box__val">' + data.intel + '</div></div>' +
        '<div class="stat-box"><div class="stat-box__label">RARITY</div><div class="stat-box__val">' + data.rarity + '</div></div>' +
      '</div></div>';
  }

  function generatePolicyCard(data) {
    return '<div class="policy-card nft-card">' +
      '<div class="nft-card__header" style="justify-content:center"><span class="nft-card__type" style="background:rgba(6,182,212,0.2);border-color:#06b6d4;color:#06b6d4">L2 POLICY RESOLUTION</span></div>' +
      '<div class="nft-card__title" style="text-align:center;margin-bottom:1rem;font-size:0.95rem">Epoch #1000 Adjustments</div>' +
      '<div class="nft-card__stats" style="grid-template-columns:1fr">' +
        '<div class="stat-box" style="display:flex;justify-content:space-between"><div class="stat-box__label">REWARD MULTIPLIER</div><div class="stat-box__val" style="color:#ef4444">' + data.multiplier + '</div></div>' +
        '<div class="stat-box" style="display:flex;justify-content:space-between"><div class="stat-box__label">ENEMY POWER SCALING</div><div class="stat-box__val" style="color:#10b981">' + data.power + '</div></div>' +
        '<div class="stat-box" style="display:flex;justify-content:space-between"><div class="stat-box__label">TOKEN BURN</div><div class="stat-box__val" style="color:#f59e0b">' + data.burn + '</div></div>' +
        '<div class="stat-box" style="display:flex;justify-content:space-between"><div class="stat-box__label">MINTING COST</div><div class="stat-box__val" style="color:#a855f7">' + data.mintCost + '</div></div>' +
      '</div>' +
      '<div style="margin-top:1rem;font-family:monospace;font-size:0.65rem;color:#52525b;text-align:center">AUTO-EXECUTED ON-CHAIN</div></div>';
  }

  function runSimulation(type) {
    if (isSimulating || !terminalBody || !nftContainer) return;
    isSimulating = true;
    [btnMove, btnNPC, btnEpoch].forEach(b => { if (b) b.disabled = true });
    steps.forEach(s => { if (s) s.classList.remove('active', 'done'); });
    updateStepText(type);
    terminalBody.innerHTML = '';
    nftContainer.innerHTML = '<div class="nft-placeholder">Processing on-chain...</div>';

    let rawPayload, llmPrompt, llmOutput, resultData;
    if (type === 'move') {
      rawPayload = '0xa9059cbb000000000000000000000000e3d...';
      llmPrompt = '[SYSTEM] Player(0xe3d...) entered coordinates (42, 88) Dark Forest.';
      llmOutput = 'Analyzing zone: Dark Forest. Output: "Shadow Wraith", Element: Void, High Evasion.';
      resultData = { name: "Shadow Wraith", element: "VOID", icon: "🌌", power: 78, speed: 92, intel: 45, rarity: "Epic" };
    } else if (type === 'npc') {
      rawPayload = '0x173a82f30000000000000000000000001b8...';
      llmPrompt = '[SYSTEM] Player(0x1b8...) interacted with NPC #492. Tone: Hostile.';
      llmOutput = 'Hostile tone detected. Output: "Obsidian Golem", Element: Earth, High Defense.';
      resultData = { name: "Obsidian Golem", element: "EARTH", icon: "🗿", power: 95, speed: 12, intel: 20, rarity: "Legendary" };
    } else {
      rawPayload = '0x3b1c90f4000000000000000000000000000...';
      llmPrompt = '[SYSTEM] L2 Epoch #1000. Circulation=1.2M STT, WinRate=68%.';
      llmOutput = 'Win rate too easy. Policy: -15% rewards, +10% enemy power, burn 50k STT, +5% mint cost.';
      resultData = { multiplier: "-15%", power: "+10%", burn: "50,000 STT", mintCost: "+5%" };
    }

    setTimeout(() => { setStep(0); termPrint(type === 'epoch' ? 'Broadcasting L2 Epoch Trigger...' : 'Broadcasting L1 Event Payload...'); termPrint(rawPayload, 'msg'); }, 500);
    setTimeout(() => { setStep(1); termPrint('Event caught. OIKONO Awakened.'); termPrint('Parsing ABI -> ' + llmPrompt, 'msg'); }, 2000);
    setTimeout(() => {
      setStep(2);
      termPrint('Executing LLM Inference...');
      typeText(llmOutput, () => {
        setTimeout(() => {
          setStep(3);
          termPrint('Subcommittee consensus verified.');
          termPrint(type === 'epoch' ? 'Executing Economy Policy...' : 'Minting Dynamic NFT...', 'msg');
          setTimeout(() => {
            setStep(4);
            termPrint('Transaction Confirmed.');
            nftContainer.innerHTML = type === 'epoch' ? generatePolicyCard(resultData) : generateNFTCard(resultData);
            setTimeout(() => {
              const card = nftContainer.querySelector('.nft-card');
              if (card) card.classList.add('visible');
              isSimulating = false;
              [btnMove, btnNPC, btnEpoch].forEach(b => { if (b) b.disabled = false; });
            }, 100);
          }, 800);
        }, 1000);
      });
    }, 3500);
  }

  if (btnMove) btnMove.addEventListener('click', () => runSimulation('move'));
  if (btnNPC) btnNPC.addEventListener('click', () => runSimulation('npc'));
  if (btnEpoch) btnEpoch.addEventListener('click', () => runSimulation('epoch'));

  // ── Console branding ──
  console.log('%c[SYS] OIKONO Agent Interface Loaded', 'color: #a855f7; font-size: 14px; font-weight: bold;');
  console.log('%c[SYS] Reactive pipeline: ONLINE', 'color: #10b981; font-size: 11px;');
  console.log('%c[SYS] Somnia Testnet (Chain ID: 50312)', 'color: #8b949e; font-size: 11px;');
});

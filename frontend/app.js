// ═══════════════════════════════════════════════
// OIKONO - Data-Driven Game Economy Agent
// With proper routing and game registration
// ═══════════════════════════════════════════════

const SOMNIA_CHAIN_ID = '0xC488';
const SOMNIA_RPC = 'https://dream-rpc.somnia.network';

let provider = null;
let signer = null;
let userAddress = null;
let contracts = {};
let registeredGames = [];
let currentView = 'overview';

// ══════════════════════════════════════════════
// WALLET CONNECTION
// ══════════════════════════════════════════════

async function connectWallet() {
    if (typeof window.ethereum === 'undefined') {
        showNotification('MetaMask not detected', 'error');
        return;
    }

    const btn = document.getElementById('connectBtn');
    setButtonLoading(btn, true, 'Connecting...');

    try {
        const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
        userAddress = accounts[0];
        provider = new ethers.BrowserProvider(window.ethereum);
        signer = await provider.getSigner();

        await ensureSomniaNetwork();
        initContracts();
        await loadDashboardData();

        showNotification('Connected: ' + shortAddr(userAddress), 'success');

        // Start pattern auto-detection
        startPatternAutoDetection();

        // If on landing page, stay there. If trying to access dashboard, go there
        if (window.location.hash.startsWith('#/dashboard')) {
            showDashboard();
        }
    } catch (err) {
        showNotification('Connection failed: ' + err.message, 'error');
    } finally {
        setButtonLoading(btn, false, 'Connect Wallet');
        updateUI(!!userAddress);
    }
}

async function ensureSomniaNetwork() {
    const chainId = await window.ethereum.request({ method: 'eth_chainId' });
    if (chainId !== SOMNIA_CHAIN_ID) {
        try {
            await window.ethereum.request({
                method: 'wallet_switchEthereumChain',
                params: [{ chainId: SOMNIA_CHAIN_ID }],
            });
        } catch (e) {
            if (e.code === 4902) {
                await window.ethereum.request({
                    method: 'wallet_addEthereumChain',
                    params: [{
                        chainId: SOMNIA_CHAIN_ID,
                        chainName: 'Somnia Testnet',
                        nativeCurrency: { name: 'STT', symbol: 'STT', decimals: 18 },
                        rpcUrls: [SOMNIA_RPC],
                    }],
                });
            }
        }
    }
}

function initContracts() {
    if (!CONFIG || !CONFIG.CONTRACTS) return;

    for (const [name, abi] of Object.entries(CONFIG.ABI)) {
        if (CONFIG.CONTRACTS[name] && CONFIG.CONTRACTS[name] !== '0x0000000000000000000000000000000000000000') {
            contracts[name] = new ethers.Contract(CONFIG.CONTRACTS[name], abi, signer);
        }
    }
}

function updateUI(connected) {
    const connectBtn = document.getElementById('connectBtn');
    const launchBtn = document.getElementById('launchBtn');
    const walletAddress = document.getElementById('walletAddress');

    if (connected) {
        connectBtn.textContent = shortAddr(userAddress);
        connectBtn.classList.add('btn--connected');
        launchBtn.style.display = 'inline-flex';
        if (walletAddress) walletAddress.textContent = shortAddr(userAddress);
    } else {
        connectBtn.textContent = 'Connect Wallet';
        connectBtn.classList.remove('btn--connected');
        launchBtn.style.display = 'none';
    }
}

// ══════════════════════════════════════════════
// ROUTING
// ══════════════════════════════════════════════

function showDashboard(view = 'overview') {
    document.getElementById('dashboard').style.display = 'grid';
    document.querySelectorAll('body > *:not(#dashboard):not(script)').forEach(el => {
        if (el.tagName !== 'SCRIPT') el.style.display = 'none';
    });
    loadDashboardData();
    switchView(view);
    window.location.hash = '#/dashboard/' + view;
}

function showLanding() {
    window.location.hash = '#/';
    showLandingDirect();
}

function showRegisterPage() {
    console.log('showRegisterPage called');
    window.location.hash = '#/register';
    showRegisterPageDirect();
}

function switchView(view) {
    currentView = view;
    document.querySelectorAll('.sidebar__link').forEach(link => {
        link.classList.toggle('sidebar__link--active', link.dataset.view === view);
    });
    document.querySelectorAll('.view').forEach(v => {
        v.style.display = v.id === `view-${view}` ? '' : 'none';
    });
    const titles = { overview: 'Overview', metrics: 'Metrics', patterns: 'Patterns', suggestions: 'Suggestions', games: 'My Games' };
    document.getElementById('dashboardTitle').textContent = titles[view] || 'Overview';
    loadViewData(view);
    window.location.hash = '#/dashboard/' + view;
}

function scrollToSection(id) {
    const el = document.getElementById(id);
    if (el) el.scrollIntoView({ behavior: 'smooth' });
}

// Handle hash changes for routing
function handleRoute() {
    const hash = window.location.hash || '#/';
    console.log('handleRoute called, hash:', hash);

    if (hash === '#/register') {
        // Show register page (without changing hash again)
        showRegisterPageDirect();
    } else if (hash.startsWith('#/dashboard')) {
        if (!userAddress) {
            // Not connected, redirect to landing
            window.location.hash = '#/';
            return;
        }
        const view = hash.split('/')[2] || 'overview';
        document.getElementById('dashboard').style.display = 'grid';
        document.getElementById('developers').style.display = 'none';
        document.querySelectorAll('body > section:not(#dashboard):not(#developers)').forEach(el => {
            el.style.display = 'none';
        });
        // Hide nav and footer on dashboard
        const nav = document.querySelector('.nav');
        const footer = document.querySelector('.footer');
        if (nav) nav.style.display = 'none';
        if (footer) footer.style.display = 'none';
        switchView(view);
    } else {
        // Landing page
        showLandingDirect();
    }
}

// Direct versions (don't change hash to avoid loops)
function showRegisterPageDirect() {
    console.log('showRegisterPageDirect called');

    // Hide dashboard
    const dashboard = document.getElementById('dashboard');
    if (dashboard) dashboard.style.display = 'none';

    // Hide landing sections
    document.querySelectorAll('body > section:not(#dashboard):not(#developers)').forEach(el => {
        el.style.display = 'none';
    });

    // Show register page
    const developers = document.getElementById('developers');
    if (developers) {
        developers.style.display = 'block';
    }

    // Hide nav and footer
    const nav = document.querySelector('.nav');
    const footer = document.querySelector('.footer');
    if (nav) nav.style.display = 'none';
    if (footer) footer.style.display = 'none';
}

function showLandingDirect() {
    document.getElementById('dashboard').style.display = 'none';
    document.getElementById('developers').style.display = 'none';
    document.querySelectorAll('body > section:not(#dashboard):not(#developers)').forEach(el => {
        el.style.display = '';
    });
    document.querySelector('.nav').style.display = '';
    document.querySelector('.footer').style.display = '';
}

// ══════════════════════════════════════════════
// DASHBOARD DATA
// ══════════════════════════════════════════════

async function loadDashboardData() {
    if (!userAddress) return;

    try {
        if (contracts.GameRegistry) {
            const gameIds = await contracts.GameRegistry.getGamesByOwner(userAddress);
            registeredGames = [];
            for (const id of gameIds) {
                try {
                    const game = await contracts.GameRegistry.getGame(Number(id));
                    // ABI returns: owner, name, gameType, description, metadata, isActive, isVerified, totalEvents, totalActions
                    registeredGames.push({
                        id: Number(id),
                        owner: game[0],
                        name: game[1],
                        gameType: game[2],
                        description: game[3],
                        metadata: game[4],
                        isActive: game[5],
                        isVerified: game[6],
                        totalEvents: Number(game[7]),
                        totalActions: Number(game[8])
                    });
                } catch (e) {
                    console.error('Failed to load game:', e);
                }
            }
        }

        // Update overview stats
        document.getElementById('statGames').textContent = registeredGames.length;

        // Load patterns count
        if (contracts.PatternDetector && registeredGames.length > 0) {
            try {
                const count = await contracts.PatternDetector.getPatternCount(registeredGames[0].id);
                document.getElementById('statPatterns').textContent = count.toString();
            } catch (e) {}
        }

        // Load suggestions count
        if (contracts.SuggestionEngine && registeredGames.length > 0) {
            try {
                const count = await contracts.SuggestionEngine.getSuggestionCount(registeredGames[0].id);
                document.getElementById('statSuggestions').textContent = count.toString();
            } catch (e) {}
        }

        // Update success rate via OikonoAgent stats
        if (contracts.OikonoAgent) {
            try {
                const agentStats = await contracts.OikonoAgent.getStats();
                const decisions = Number(agentStats[0]);
                const successEl = document.getElementById('statSuccess');
                successEl.textContent = decisions > 0 ? decisions + ' decisions' : 'N/A';
            } catch (e) {
                document.getElementById('statSuccess').textContent = 'N/A';
            }
        } else {
            document.getElementById('statSuccess').textContent = 'N/A';
        }

        // Update activity feed
        updateActivityFeed();

        // Update games list
        updateGamesList();

    } catch (err) {
        console.error('Failed to load dashboard:', err);
    }
}

function loadViewData(view) {
    switch (view) {
        case 'overview':
            loadDashboardData();
            break;
        case 'metrics':
            loadMetrics();
            break;
        case 'patterns':
            loadPatterns();
            break;
        case 'suggestions':
            loadSuggestions();
            break;
        case 'games':
            updateGamesList();
            break;
    }
}

// ══════════════════════════════════════════════
// METRICS
// ══════════════════════════════════════════════

async function loadMetrics() {
    const grid = document.getElementById('metricsGrid');
    const select = document.getElementById('metricsGameSelect');

    // Populate game select (preserve current selection)
    const prevSelected = select.value;
    select.innerHTML = '<option value="">Select game...</option>';
    registeredGames.forEach(game => {
        const opt = document.createElement('option');
        opt.value = game.id;
        opt.textContent = game.name + ' (' + game.gameType + ')';
        if (String(game.id) === prevSelected) opt.selected = true;
        select.appendChild(opt);
    });

    const gameId = select.value;
    if (!gameId || !contracts.MetricsRegistry) {
        grid.innerHTML = '<div class="empty-state"><p>Select a game to view metrics</p></div>';
        return;
    }

    try {
        const metricNames = await contracts.MetricsRegistry.getMetricNames(gameId);

        if (metricNames.length === 0) {
            grid.innerHTML = '<div class="empty-state"><p>No metrics defined yet. Apply a game type template first.</p></div>';
            return;
        }

        let html = '';
        for (const name of metricNames) {
            try {
                const stats = await contracts.MetricsRegistry.getStats(gameId, name);
                const latest = stats[0];
                const min = stats[1];
                const max = stats[2];
                const avg = stats[3];
                const count = stats[4];
                // stats[5] = lastUpdated (unused in display)
                const isHealthy = await contracts.MetricsRegistry.isHealthy(gameId, name);
                let changeText = '';
                try {
                    const change = await contracts.MetricsRegistry.getChange(gameId, name);
                    const changeNum = Number(change);
                    changeText = changeNum >= 0 ? `+${changeNum}` : `${changeNum}`;
                } catch (e) {}

                html += `
                    <div class="metric-card ${isHealthy ? '' : 'metric-card--warning'}">
                        <div class="metric-card__header">
                            <span class="metric-card__name">${name}</span>
                            <span class="metric-card__status ${isHealthy ? 'status--good' : 'status--warning'}">
                                ${isHealthy ? '● Healthy' : '⚠ Warning'}
                            </span>
                        </div>
                        <div class="metric-card__value">${latest}${changeText ? ` <small style="color:${Number(changeText)>=0?'var(--accent-success)':'var(--accent-danger)'}">${changeText}</small>` : ''}</div>
                        <div class="metric-card__stats">
                            <span>Min: ${min}</span>
                            <span>Max: ${max}</span>
                            <span>Avg: ${avg}</span>
                            <span>Count: ${count}</span>
                        </div>
                    </div>
                `;
            } catch (e) {
                console.error('Failed to load metric:', name, e);
            }
        }

        grid.innerHTML = html || '<div class="empty-state"><p>Failed to load metrics</p></div>';
    } catch (err) {
        console.error('Error loading metrics:', err);
        grid.innerHTML = '<div class="empty-state"><p>Error loading metrics</p></div>';
    }
}

async function recordMetric() {
    const select = document.getElementById('metricsGameSelect');
    const gameId = select?.value;
    const metricName = document.getElementById('recordMetricName')?.value;
    const metricValue = document.getElementById('recordMetricValue')?.value;

    if (!gameId) {
        showNotification('Please select a game first', 'error');
        return;
    }

    if (!metricName || !metricValue) {
        showNotification('Please enter metric name and value', 'error');
        return;
    }

    if (!contracts.MetricsRegistry) {
        showNotification('MetricsRegistry contract not available', 'error');
        return;
    }

    try {
        showNotification('Recording metric...', 'info');
        const tx = await contracts.MetricsRegistry.recordMetric(
            gameId,
            metricName,
            parseInt(metricValue)
        );
        showNotification('TX sent: ' + tx.hash, 'info');
        await tx.wait();
        showNotification('Metric recorded: ' + metricName + ' = ' + metricValue, 'success');

        // Clear inputs
        document.getElementById('recordMetricName').value = '';
        document.getElementById('recordMetricValue').value = '';

        // Auto-detect patterns after metric recording
        if (contracts.PatternDetector && registeredGames.length > 0) {
            try {
                const tx = await contracts.PatternDetector.detectPatterns(gameId);
                await tx.wait();
                console.log('Auto-detected patterns after metric recording');
            } catch (e) {
                console.error('Auto-detection after metric failed:', e);
            }
        }

        // Reload metrics
        loadMetrics();
    } catch (err) {
        showNotification('Failed to record metric: ' + parseError(err), 'error');
    }
}

// ══════════════════════════════════════════════
// PATTERNS
// ══════════════════════════════════════════════

async function loadPatterns() {
    const list = document.getElementById('patternsList');

    if (!contracts.PatternDetector || registeredGames.length === 0) {
        list.innerHTML = '<div class="empty-state"><p>No games registered yet. Register a game first.</p></div>';
        return;
    }

    // Collect patterns from ALL registered games
    let allPatterns = [];
    for (const game of registeredGames) {
        try {
            const patterns = await contracts.PatternDetector.getActivePatterns(game.id);
            patterns.forEach(p => allPatterns.push({ ...p, gameName: game.name, gameId: game.id }));
        } catch (e) {
            console.error('Failed to load patterns for game', game.id, e);
        }
    }

    if (allPatterns.length === 0) {
        list.innerHTML = '<div class="empty-state"><p>No patterns detected yet. Click "Scan Now" to detect patterns.</p></div>';
        return;
    }

    list.innerHTML = allPatterns.map(p => `
        <div class="pattern-item">
            <div class="pattern-item__header">
                <span class="pattern-item__type">${p.patternType}</span>
                <span class="pattern-item__severity severity--${Number(p.severity) >= 7 ? 'high' : Number(p.severity) >= 4 ? 'medium' : 'low'}">Severity: ${p.severity}/10</span>
            </div>
            <p class="pattern-item__desc">${p.description}</p>
            <div class="pattern-item__meta">
                <span>Game: ${p.gameName}</span>
                <span>Confidence: ${(Number(p.confidence) / 100).toFixed(0)}%</span>
                <span>Metric: ${p.metricName}</span>
            </div>
        </div>
    `).join('');
}

async function detectPatterns(e) {
    if (!contracts.PatternDetector || registeredGames.length === 0) {
        showNotification('No games registered', 'error');
        return;
    }

    const btn = e?.target || document.querySelector('[onclick*="detectPatterns"]');
    setButtonLoading(btn, true, 'Scanning...');

    try {
        let scanned = 0;
        for (const game of registeredGames) {
            try {
                const tx = await contracts.PatternDetector.detectPatterns(game.id);
                showNotification(`Scanning ${game.name}... TX: ${tx.hash}`, 'info');
                await tx.wait();
                scanned++;
            } catch (err) {
                console.error('Detection failed for game', game.id, err);
            }
        }
        showNotification(`Pattern detection complete for ${scanned} game(s)`, 'success');
        loadPatterns();
    } catch (err) {
        showNotification('Detection failed: ' + parseError(err), 'error');
    } finally {
        setButtonLoading(btn, false, 'Scan Now');
    }
}

// ══════════════════════════════════════════════
// SUGGESTIONS
// ══════════════════════════════════════════════

async function loadSuggestions() {
    const list = document.getElementById('suggestionsList');

    if (!contracts.SuggestionEngine || registeredGames.length === 0) {
        list.innerHTML = '<div class="empty-state"><p>No games registered yet. Register a game first.</p></div>';
        return;
    }

    // Collect suggestions from ALL registered games
    let allSuggestions = [];
    for (const game of registeredGames) {
        try {
            const suggestions = await contracts.SuggestionEngine.getActiveSuggestions(game.id);
            suggestions.forEach(s => allSuggestions.push({ ...s, gameName: game.name, gameId: game.id }));
        } catch (e) {
            console.error('Failed to load suggestions for game', game.id, e);
        }
    }

    if (allSuggestions.length === 0) {
        list.innerHTML = '<div class="empty-state"><p>No suggestions yet. Detect patterns first, then generate suggestions.</p></div>';
        return;
    }

    list.innerHTML = allSuggestions.map(s => `
        <div class="suggestion-item">
            <div class="suggestion-item__header">
                <span class="suggestion-item__category">${s.category}</span>
                <span class="suggestion-item__priority priority--${s.priority}">${s.priority}</span>
            </div>
            <p class="suggestion-item__desc">${s.description}</p>
            <p class="suggestion-item__action">💡 ${s.action}</p>
            <div class="suggestion-item__meta">
                <span>Game: ${s.gameName}</span>
                <span>Confidence: ${(Number(s.confidence) / 100).toFixed(0)}%</span>
                <span>Impact: ${(Number(s.expectedImpact) / 100).toFixed(0)}%</span>
            </div>
            ${!s.implemented ? `<button class="btn btn--ghost btn--sm" onclick="markImplemented(${s.gameId}, ${s.suggestionId})">✓ Mark Implemented</button>` : '<span class="badge badge--active">Implemented</span>'}
        </div>
    `).join('');
}

async function generateSuggestions(e) {
    if (!contracts.SuggestionEngine || registeredGames.length === 0) {
        showNotification('No games registered', 'error');
        return;
    }

    const btn = e?.target || document.querySelector('[onclick*="generateSuggestions"]');
    setButtonLoading(btn, true, 'Generating...');

    try {
        let generated = 0;
        for (const game of registeredGames) {
            try {
                const tx = await contracts.SuggestionEngine.generateSuggestions(game.id);
                showNotification(`Generating for ${game.name}... TX: ${tx.hash}`, 'info');
                await tx.wait();
                generated++;
            } catch (err) {
                console.error('Generation failed for game', game.id, err);
            }
        }
        showNotification(`Suggestions generated for ${generated} game(s)`, 'success');
        loadSuggestions();
    } catch (err) {
        showNotification('Generation failed: ' + parseError(err), 'error');
    } finally {
        setButtonLoading(btn, false, 'Generate');
    }
}

async function markImplemented(gameId, suggestionId) {
    try {
        const tx = await contracts.SuggestionEngine.markImplemented(gameId, suggestionId);
        showNotification('Marking... TX: ' + tx.hash, 'info');
        await tx.wait();
        showNotification('Marked as implemented', 'success');
        loadSuggestions();
    } catch (err) {
        showNotification('Failed: ' + parseError(err), 'error');
    }
}

// ══════════════════════════════════════════════
// GAMES
// ══════════════════════════════════════════════

function updateGamesList() {
    const list = document.getElementById('gamesList');
    if (!list) return;

    let html = '';

    // Selalu tampilkan tombol Register Game
    html += `
        <div class="game-card" style="border-style: dashed; text-align: center; padding: var(--space-4);">
            <button class="btn btn--primary" id="addGameBtn">+ Register Game</button>
        </div>
    `;

    // Tambahkan game cards
    if (registeredGames.length > 0) {
        html += registeredGames.map(game => `
            <div class="game-card">
                <div class="game-card__header">
                    <div class="game-card__info">
                        <h4 class="game-card__name">${game.name}</h4>
                        <span class="game-card__type">${game.gameType}</span>
                    </div>
                    <span class="badge badge--${game.isActive ? 'active' : 'inactive'}">${game.isActive ? 'Active' : 'Inactive'}</span>
                </div>
                <div class="game-card__stats">
                    <div class="game-card__stat">
                        <div class="game-card__stat-value">${game.totalEvents}</div>
                        <div class="game-card__stat-label">Events</div>
                    </div>
                    <div class="game-card__stat">
                        <div class="game-card__stat-value">${game.totalActions}</div>
                        <div class="game-card__stat-label">Actions</div>
                    </div>
                    <div class="game-card__stat">
                        <div class="game-card__stat-value">${game.isVerified ? 'Yes' : 'No'}</div>
                        <div class="game-card__stat-label">Verified</div>
                    </div>
                </div>
                <div class="game-card__footer">
                    <span class="game-card__address">${game.address === '0x0000000000000000000000000000000000000000' ? 'Off-chain' : shortAddr(game.address)}</span>
                </div>
                <div class="game-card__actions">
                    <button class="btn btn--ghost btn--sm" data-action="view" data-game-id="${game.id}">View Details</button>
                    <button class="btn btn--ghost btn--sm" data-action="toggle" data-game-id="${game.id}" data-active="${game.isActive}">
                        ${game.isActive ? 'Deactivate' : 'Activate'}
                    </button>
                </div>
            </div>
        `).join('');
    } else {
        html += `<div class="empty-state"><p>No games registered yet.</p></div>`;
    }

    list.innerHTML = html;

    // Attach event listeners after rendering
    document.getElementById('addGameBtn')?.addEventListener('click', showRegisterPage);

    list.querySelectorAll('[data-action="view"]').forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.preventDefault();
            e.stopPropagation();
            const gameId = parseInt(btn.dataset.gameId);
            console.log('View Details clicked, gameId:', gameId);
            viewGameDetails(gameId);
        });
    });

    list.querySelectorAll('[data-action="toggle"]').forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.preventDefault();
            e.stopPropagation();
            const gameId = parseInt(btn.dataset.gameId);
            const isActive = btn.dataset.active === 'true';
            console.log('Toggle clicked, gameId:', gameId, 'isActive:', isActive);
            toggleGameStatus(gameId, isActive);
        });
    });
}

async function toggleGameStatus(gameId, currentlyActive) {
    console.log('toggleGameStatus called', { gameId, currentlyActive });

    if (!contracts.GameRegistry) {
        showNotification('GameRegistry not available', 'error');
        return;
    }

    try {
        const tx = currentlyActive
            ? await contracts.GameRegistry.deactivateGame(gameId)
            : await contracts.GameRegistry.activateGame(gameId);

        showNotification('Transaction sent: ' + tx.hash, 'info');
        await tx.wait();
        showNotification('Game ' + (currentlyActive ? 'deactivated' : 'activated'), 'success');

        await loadDashboardData();
        updateGamesList();
    } catch (err) {
        showNotification('Failed: ' + parseError(err), 'error');
    }
}

// ══════════════════════════════════════════════
// REGISTRATION
// ══════════════════════════════════════════════

// Use templates from config.js
const GAME_TYPE_TEMPLATES = CONFIG.GAME_TYPE_TEMPLATES || {};

// Multi-contract state
let gameContracts = [];

function addGameContract() {
    const addressInput = document.getElementById('contractAddress');
    const roleSelect = document.getElementById('contractRole');

    const address = addressInput.value.trim();
    const role = roleSelect.value;

    console.log('addGameContract called', { address, role });

    if (!address || !address.startsWith('0x')) {
        showNotification('Invalid! Contract address must start with 0x', 'error');
        return;
    }

    if (gameContracts.find(c => c.address.toLowerCase() === address.toLowerCase())) {
        showNotification('Contract already added', 'error');
        return;
    }

    gameContracts.push({ address, role });
    updateContractList();

    // Clear input
    addressInput.value = '';
}

function removeGameContract(index) {
    gameContracts.splice(index, 1);
    updateContractList();
}

function updateContractList() {
    const list = document.getElementById('contractList');
    if (!list) return;

    if (gameContracts.length === 0) {
        list.innerHTML = '<p class="form-hint">No contracts added yet</p>';
        return;
    }

    list.innerHTML = gameContracts.map((c, i) => {
        const roleInfo = CONFIG.CONTRACT_ROLES[c.role] || { label: c.role, icon: '📄' };
        return `
            <div class="contract-item">
                <span class="contract-item__icon">${roleInfo.icon}</span>
                <span class="contract-item__role">${roleInfo.label}</span>
                <span class="contract-item__address">${shortAddr(c.address)}</span>
                <button type="button" class="btn btn--ghost btn--sm" onclick="removeGameContract(${i})">Remove</button>
            </div>
        `;
    }).join('');
}

function updateRangeDisplay(input, displayId) {
    const display = document.getElementById(displayId);
    if (display) {
        display.textContent = input.value + '%';
    }
}

function updateTemplatePreview() {
    const gameType = document.getElementById('gameType').value;
    const preview = document.getElementById('templatePreview');

    if (!gameType || !GAME_TYPE_TEMPLATES[gameType]) {
        preview.innerHTML = '<p class="form-section-desc">Select a game type to see included metrics</p>';
        return;
    }

    const template = GAME_TYPE_TEMPLATES[gameType];

    // Get all config from form
    const targetWinRate = document.getElementById('targetWinRate')?.value || 55;
    const targetRetention = document.getElementById('targetRetention')?.value || 30;
    const inflationTolerance = document.getElementById('inflationTolerance')?.value || 'medium';
    const economyStyle = document.getElementById('economyStyle')?.value || 'balanced';
    const maxChange = document.getElementById('maxChange')?.value || 20;
    const checkFrequency = document.getElementById('checkFrequency')?.value || 'hourly';
    const autonomyLevel = document.getElementById('autonomyLevel')?.value || 'semi-auto';
    const entryModel = document.querySelector('input[name="entryModel"]:checked')?.value || 'free';

    // Get permissions
    const permSpawn = document.getElementById('permSpawn')?.checked ?? true;
    const permEconomy = document.getElementById('permEconomy')?.checked ?? true;
    const permNarrative = document.getElementById('permNarrative')?.checked ?? false;
    const permDifficulty = document.getElementById('permDifficulty')?.checked ?? true;

    preview.innerHTML = `
        <div class="template-metrics">
            <div class="template-header">
                <h5>${template.name} Template</h5>
                <p class="template-desc">${template.description}</p>
            </div>

            <div class="template-config">
                <h6>Economy Goals:</h6>
                <div class="template-config__grid">
                    <div class="template-config__item">
                        <span class="template-config__label">Target Win Rate</span>
                        <span class="template-config__value">${targetWinRate}%</span>
                    </div>
                    <div class="template-config__item">
                        <span class="template-config__label">Target D7 Retention</span>
                        <span class="template-config__value">${targetRetention}%</span>
                    </div>
                    <div class="template-config__item">
                        <span class="template-config__label">Inflation Tolerance</span>
                        <span class="template-config__value">${inflationTolerance}</span>
                    </div>
                    <div class="template-config__item">
                        <span class="template-config__label">Economy Style</span>
                        <span class="template-config__value">${economyStyle}</span>
                    </div>
                    <div class="template-config__item">
                        <span class="template-config__label">Max Change/Epoch</span>
                        <span class="template-config__value">${maxChange}%</span>
                    </div>
                    <div class="template-config__item">
                        <span class="template-config__label">Entry Model</span>
                        <span class="template-config__value">${entryModel}</span>
                    </div>
                </div>
            </div>

            <div class="template-config">
                <h6>Agent Permissions:</h6>
                <div class="template-config__grid">
                    <div class="template-config__item">
                        <span class="template-config__label">Spawn Entities</span>
                        <span class="template-config__value">${permSpawn ? 'Yes' : 'No'}</span>
                    </div>
                    <div class="template-config__item">
                        <span class="template-config__label">Adjust Economy</span>
                        <span class="template-config__value">${permEconomy ? 'Yes' : 'No'}</span>
                    </div>
                    <div class="template-config__item">
                        <span class="template-config__label">Generate Narrative</span>
                        <span class="template-config__value">${permNarrative ? 'Yes' : 'No'}</span>
                    </div>
                    <div class="template-config__item">
                        <span class="template-config__label">Adjust Difficulty</span>
                        <span class="template-config__value">${permDifficulty ? 'Yes' : 'No'}</span>
                    </div>
                </div>
            </div>

            <div class="template-config">
                <h6>Integration:</h6>
                <div class="template-config__grid">
                    <div class="template-config__item">
                        <span class="template-config__label">Check Frequency</span>
                        <span class="template-config__value">${checkFrequency}</span>
                    </div>
                    <div class="template-config__item">
                        <span class="template-config__label">Autonomy Level</span>
                        <span class="template-config__value">${autonomyLevel}</span>
                    </div>
                </div>
            </div>

            <div class="template-metrics__list">
                <h6>Metrics Tracked:</h6>
                ${template.metrics.map(m => `
                    <div class="template-metric-item">
                        <span class="template-metric-name">${m.name}</span>
                        <span class="template-metric-healthy">${m.healthy}</span>
                    </div>
                `).join('')}
            </div>

            <div class="template-rules">
                <h6>Detection Rules:</h6>
                ${template.rules.map(r => `
                    <div class="template-rule-item">
                        <span class="template-rule-type">${r.type}</span>
                        <span class="template-rule-metric">${r.metric}</span>
                        <span class="template-rule-threshold">${r.threshold}</span>
                    </div>
                `).join('')}
            </div>
        </div>
    `;
}

async function registerGame() {
    console.log('registerGame called');

    // Check wallet connection
    if (!userAddress) {
        showNotification('Please connect wallet first', 'error');
        return;
    }

    if (!contracts.GameRegistry) {
        showNotification('Contracts not loaded. Please reconnect wallet.', 'error');
        return;
    }

    const name = document.getElementById('gameName').value;
    const gameType = document.getElementById('gameType').value;
    const description = document.getElementById('gameDesc').value;
    const primaryGameAddress = document.getElementById('primaryGameAddress')?.value?.trim();

    console.log('Form values:', { name, gameType, description, primaryGameAddress });

    if (!name || name.trim() === '') {
        showNotification('Please enter a game name', 'error');
        return;
    }

    if (!gameType) {
        showNotification('Please select a game type', 'error');
        return;
    }

    if (!primaryGameAddress || !primaryGameAddress.startsWith('0x') || primaryGameAddress.length !== 42) {
        showNotification('Please enter a valid primary game contract address', 'error');
        return;
    }

    const btn = document.querySelector('#registerForm .btn--primary');
    if (!btn) {
        console.error('Register button not found');
        return;
    }

    setButtonLoading(btn, true, 'Registering...');

    try {
        showNotification('Preparing transaction...', 'info');

        if (!contracts.GameRegistry) {
            showNotification('GameRegistry contract not available', 'error');
            return;
        }

        console.log('GameRegistry target:', contracts.GameRegistry.target);
        console.log('Wallet:', userAddress);

        let gameId;

        // Build metadata JSON with full configuration
        const metadata = JSON.stringify({
            website: document.getElementById('gameWebsite')?.value || '',
            primaryAddress: primaryGameAddress,
            contracts: gameContracts.map(c => ({ address: c.address, role: c.role })),

            // Token Economics
            token: {
                name: document.getElementById('tokenName')?.value || '',
                symbol: document.getElementById('tokenSymbol')?.value || '',
                totalSupply: document.getElementById('totalSupply')?.value || '',
                circSupply: document.getElementById('circSupply')?.value || '',
                utility: document.getElementById('tokenUtility')?.value || 'mixed',
                sinks: {
                    entry: document.getElementById('sinkEntry')?.checked ?? false,
                    craft: document.getElementById('sinkCraft')?.checked ?? false,
                    market: document.getElementById('sinkMarket')?.checked ?? false,
                    staking: document.getElementById('sinkStaking')?.checked ?? false,
                    cosmetic: document.getElementById('sinkCosmetic')?.checked ?? false,
                },
                sources: {
                    battle: document.getElementById('srcBattle')?.checked ?? false,
                    quest: document.getElementById('srcQuest')?.checked ?? false,
                    staking: document.getElementById('srcStaking')?.checked ?? false,
                    airdrop: document.getElementById('srcAirdrop')?.checked ?? false,
                }
            },

            // Player Economics
            player: {
                entryModel: document.querySelector('input[name="entryModel"]:checked')?.value || 'free',
                segments: {
                    casual: document.getElementById('segCasual')?.checked ?? false,
                    hardcore: document.getElementById('segHardcore')?.checked ?? false,
                    whale: document.getElementById('segWhale')?.checked ?? false,
                    trader: document.getElementById('segTrader')?.checked ?? false,
                }
            },

            // Economy Goals
            economy: {
                targetWinRate: parseInt(document.getElementById('targetWinRate')?.value || 55),
                targetRetention: parseInt(document.getElementById('targetRetention')?.value || 30),
                inflationTolerance: document.getElementById('inflationTolerance')?.value || 'medium',
                economyStyle: document.getElementById('economyStyle')?.value || 'balanced',
                maxChangePerEpoch: parseInt(document.getElementById('maxChange')?.value || 20),
            },

            // Agent Permissions
            permissions: {
                canSpawn: document.getElementById('permSpawn')?.checked ?? true,
                canAdjustEconomy: document.getElementById('permEconomy')?.checked ?? true,
                canGenerateNarrative: document.getElementById('permNarrative')?.checked ?? false,
                canAdjustDifficulty: document.getElementById('permDifficulty')?.checked ?? true,
            },

            // Alert Thresholds
            alerts: {
                winRateLow: parseInt(document.getElementById('winRateLow')?.value || 40),
                winRateHigh: parseInt(document.getElementById('winRateHigh')?.value || 70),
                velocityAlert: parseInt(document.getElementById('velocityAlert')?.value || 50000),
                retentionDrop: parseInt(document.getElementById('retentionDrop')?.value || 15),
                inflationAlert: parseInt(document.getElementById('inflationAlert')?.value || 10),
            },

            // Integration Settings
            integration: {
                checkFrequency: document.getElementById('checkFrequency')?.value || 'hourly',
                autonomyLevel: document.getElementById('autonomyLevel')?.value || 'semi-auto',
                notifications: {
                    onChain: document.getElementById('notifOnChain')?.checked ?? true,
                    email: document.getElementById('notifEmail')?.checked ?? false,
                    discord: document.getElementById('notifDiscord')?.checked ?? false,
                    telegram: document.getElementById('notifTelegram')?.checked ?? false,
                }
            }
        });

        // Encode AgentConfig struct from form data
        const agentConfig = {
            canSpawn: document.getElementById('permSpawn')?.checked ?? true,
            canAdjustEconomy: document.getElementById('permEconomy')?.checked ?? true,
            canGenerateNarrative: document.getElementById('permNarrative')?.checked ?? false,
            canAdjustDifficulty: document.getElementById('permDifficulty')?.checked ?? true,
            maxChangePerEpoch: parseInt(document.getElementById('maxChange')?.value || 20),
            epochLength: parseInt(document.getElementById('epochLength')?.value || 6500),
        };

        console.log('AgentConfig:', agentConfig);

        const tx = await contracts.GameRegistry.registerGame(
            name.trim(),
            gameType,
            description || 'No description provided',
            primaryGameAddress,
            metadata,
            agentConfig
        );

        showNotification('TX sent: ' + tx.hash, 'info');
        const receipt = await tx.wait();

        // Parse GameRegistered event to get gameId
        const log = receipt.logs.find(l => {
            try {
                return contracts.GameRegistry.interface.parseLog(l)?.name === 'GameRegistered';
            } catch { return false; }
        });

        if (log) {
            gameId = contracts.GameRegistry.interface.parseLog(log).args.gameId;
            showNotification('Game registered! ID: ' + gameId, 'success');

            // Link primary game contract via GameRegistry.addContract
            try {
                const addPrimaryTx = await contracts.GameRegistry.addContract(
                    gameId,
                    primaryGameAddress,
                    'game_logic',
                    [] // Event hashes - can be added later
                );
                await addPrimaryTx.wait();
                showNotification('Primary contract linked', 'success');
            } catch (e) {
                console.error('Failed to link primary contract:', e);
                showNotification('Failed to link primary contract: ' + parseError(e), 'error');
            }

            // Add additional contracts via GameRegistry.addContract(gameId, address, role, eventHashes)
            for (const c of gameContracts) {
                try {
                    const addTx = await contracts.GameRegistry.addContract(
                        gameId,
                        c.address,
                        c.role,
                        [] // Event hashes - can be added later
                    );
                    await addTx.wait();
                    showNotification('Contract added: ' + c.role, 'success');
                } catch (e) {
                    console.error('Failed to add contract:', e);
                    showNotification('Failed to add contract ' + c.role + ': ' + parseError(e), 'error');
                }
            }

            // Apply game type template via GameTypeManager contract
            try {
                showNotification('Applying game type template...', 'info');
                if (!contracts.GameTypeManager) {
                    console.error('GameTypeManager contract not available');
                    showNotification('Template skipped - GameTypeManager not loaded', 'warning');
                } else {
                    const templateTx = await contracts.GameTypeManager.applyTemplate(gameId, gameType);
                    await templateTx.wait();
                    showNotification('Template applied! Metrics and rules configured.', 'success');
                }
            } catch (e) {
                console.error('Template application failed:', e);
                showNotification('Template application failed: ' + parseError(e), 'warning');
            }
        } else {
            showNotification('Game registered but could not parse event', 'warning');
        }

        // Reset form
        const form = document.getElementById('registerForm');
        if (form) form.reset();
        const preview = document.getElementById('templatePreview');
        if (preview) preview.innerHTML = '<p class="form-section-desc">Select a game type to see included metrics</p>';
        gameContracts = [];
        updateContractList();

        // Reload dashboard data
        await loadDashboardData();

        // Auto-subscribe to reactivity events for the new game
        await autoSubscribeReactivity(gameId, primaryGameAddress);

        // Switch to dashboard
        showDashboard('games');

    } catch (err) {
        console.error('Registration failed:', err);
        showNotification('Registration failed: ' + parseError(err), 'error');
    } finally {
        setButtonLoading(btn, false, 'Register Game');
    }
}

// ══════════════════════════════════════════════
// AUTO-SUBSCRIBE REACTIVITY
// ══════════════════════════════════════════════

async function autoSubscribeReactivity(gameId, gameAddress) {
    if (!contracts.GameMaster || !contracts.AgentRuntime) {
        console.log('GameMaster or AgentRuntime not available for reactivity subscription');
        return;
    }

    try {
        showNotification('Setting up on-chain reactivity...', 'info');

        // PlayerMoved event signature
        const playerMovedSig = ethers.id('PlayerMoved(address,uint256,uint256,uint256,uint256)');

        // Subscribe via GameMaster (uses Somnia Reactivity Precompile)
        try {
            const subscriptionDeposit = ethers.parseEther('0.01'); // Small deposit for subscription
            const tx = await contracts.GameMaster.subscribeToPlayerMoved(playerMovedSig, { value: subscriptionDeposit });
            await tx.wait();
            showNotification('GameMaster subscribed to PlayerMoved events', 'success');
        } catch (e) {
            console.error('GameMaster subscription failed:', e);
            showNotification('GameMaster subscription failed: ' + parseError(e), 'warning');
        }

        // Also register the game with AgentRuntime for plugin-based handling
        try {
            if (contracts.SpawnPlugin) {
                const pluginAddr = contracts.SpawnPlugin.target;
                const regTx = await contracts.AgentRuntime.registerGame(
                    document.getElementById('gameName')?.value || 'Game ' + gameId,
                    pluginAddr
                );
                await regTx.wait();
                showNotification('Game registered with AgentRuntime', 'success');
            }
        } catch (e) {
            console.error('AgentRuntime registration failed:', e);
            // Non-fatal — game still works without agent runtime
        }

        // Subscribe AgentRuntime to game events
        try {
            const subscriptionDeposit = ethers.parseEther('0.01');
            const playerMovedSig = ethers.id('PlayerMoved(address,uint256,uint256,uint256,uint256)');
            const subTx = await contracts.AgentRuntime.subscribeToEvent(playerMovedSig, subscriptionDeposit, { value: subscriptionDeposit });
            await subTx.wait();
            showNotification('AgentRuntime subscribed to game events', 'success');
        } catch (e) {
            console.error('AgentRuntime event subscription failed:', e);
        }

        showNotification('On-chain reactivity configured!', 'success');
    } catch (err) {
        console.error('Auto-subscribe reactivity failed:', err);
        showNotification('Reactivity setup failed: ' + parseError(err), 'warning');
    }
}

// ══════════════════════════════════════════════
// PATTERN DETECTOR AUTO-RUN
// ══════════════════════════════════════════════

let patternDetectionInterval = null;
const PATTERN_DETECTION_INTERVAL = 5 * 60 * 1000; // 5 minutes

function startPatternAutoDetection() {
    if (patternDetectionInterval) return; // Already running

    patternDetectionInterval = setInterval(async () => {
        if (!contracts.PatternDetector || registeredGames.length === 0) return;

        try {
            for (const game of registeredGames) {
                if (!game.isActive) continue;
                try {
                    const tx = await contracts.PatternDetector.detectPatterns(game.id);
                    await tx.wait();
                    console.log('Auto-detected patterns for game:', game.name);
                } catch (e) {
                    // Silently fail — don't spam notifications
                    console.error('Auto-detection failed for game', game.id, e);
                }
            }
        } catch (e) {
            console.error('Pattern auto-detection error:', e);
        }
    }, PATTERN_DETECTION_INTERVAL);

    console.log('Pattern auto-detection started (every 5 minutes)');
}

function stopPatternAutoDetection() {
    if (patternDetectionInterval) {
        clearInterval(patternDetectionInterval);
        patternDetectionInterval = null;
        console.log('Pattern auto-detection stopped');
    }
}

// ══════════════════════════════════════════════
// GAME DETAILS VIEW
// ══════════════════════════════════════════════

async function viewGameDetails(gameId) {
    console.log('viewGameDetails called', gameId);
    const game = registeredGames.find(g => g.id === gameId);
    console.log('Found game:', game);

    if (!game) {
        showNotification('Game not found', 'error');
        return;
    }

    // Create a modal-style detail view
    let detailHtml = `
        <div class="game-detail-overlay" id="gameDetailOverlay">
            <div class="game-detail-modal">
                <div class="game-detail-header">
                    <h3>${game.name}</h3>
                    <span class="badge badge--${game.isActive ? 'active' : 'inactive'}">${game.isActive ? 'Active' : 'Inactive'}</span>
                    <button class="btn btn--ghost btn--sm" onclick="closeGameDetails()">✕ Close</button>
                </div>
                <div class="game-detail-body">
                    <div class="detail-section">
                        <h4>📋 Game Info</h4>
                        <div class="detail-grid">
                            <div class="detail-item">
                                <span class="detail-label">Game ID</span>
                                <span class="detail-value">${game.id}</span>
                            </div>
                            <div class="detail-item">
                                <span class="detail-label">Type</span>
                                <span class="detail-value">${game.gameType}</span>
                            </div>
                            <div class="detail-item">
                                <span class="detail-label">Description</span>
                                <span class="detail-value">${game.description}</span>
                            </div>
                            <div class="detail-item">
                                <span class="detail-label">Verified</span>
                                <span class="detail-value">${game.isVerified ? '✅ Yes' : '❌ No'}</span>
                            </div>
                        </div>
                    </div>

                    <div class="detail-section">
                        <h4>📊 Activity Stats</h4>
                        <div class="detail-grid">
                            <div class="detail-item">
                                <span class="detail-label">Total Events</span>
                                <span class="detail-value detail-value--lg">${game.totalEvents}</span>
                            </div>
                            <div class="detail-item">
                                <span class="detail-label">Total Actions</span>
                                <span class="detail-value detail-value--lg">${game.totalActions}</span>
                            </div>
                        </div>
                    </div>

                    <div class="detail-section" id="detailMetrics-${gameId}">
                        <h4>📈 Metrics Overview</h4>
                        <div class="detail-loading">Loading metrics...</div>
                    </div>

                    <div class="detail-section" id="detailPatterns-${gameId}">
                        <h4>🔍 Recent Patterns</h4>
                        <div class="detail-loading">Loading patterns...</div>
                    </div>

                    <div class="detail-section" id="detailSuggestions-${gameId}">
                        <h4>💡 Active Suggestions</h4>
                        <div class="detail-loading">Loading suggestions...</div>
                    </div>

                    <div class="detail-section">
                        <h4>🔗 Contract Addresses</h4>
                        <div class="detail-grid">
                            ${game.metadata ? (() => {
                                try {
                                    const meta = JSON.parse(game.metadata);
                                    let html = '';
                                    if (meta.primaryAddress) {
                                        html += `<div class="detail-item"><span class="detail-label">Primary</span><span class="detail-value detail-value--mono">${shortAddr(meta.primaryAddress)}</span></div>`;
                                    }
                                    if (meta.contracts && meta.contracts.length > 0) {
                                        meta.contracts.forEach(c => {
                                            const roleInfo = CONFIG.CONTRACT_ROLES[c.role] || { label: c.role };
                                            html += `<div class="detail-item"><span class="detail-label">${roleInfo.label}</span><span class="detail-value detail-value--mono">${shortAddr(c.address)}</span></div>`;
                                        });
                                    }
                                    return html;
                                } catch (e) {
                                    return '<div class="detail-item"><span class="detail-value">No contract info</span></div>';
                                }
                            })() : '<div class="detail-item"><span class="detail-value">No metadata</span></div>'}
                        </div>
                    </div>

                    <div class="detail-section">
                        <h4>🤖 Agent Config</h4>
                        <div class="detail-grid" id="detailAgentConfig-${gameId}">
                            <div class="detail-loading">Loading config...</div>
                        </div>
                    </div>

                    <div class="detail-section">
                        <h4>⚙️ Actions</h4>
                        <div class="detail-actions">
                            <button class="btn btn--ghost btn--sm" onclick="toggleGameStatus(${gameId}, ${game.isActive}); closeGameDetails();">
                                ${game.isActive ? '⏸ Deactivate' : '▶ Activate'}
                            </button>
                            <button class="btn btn--ghost btn--sm" onclick="detectPatterns(); closeGameDetails();">
                                🔍 Scan Patterns
                            </button>
                            <button class="btn btn--ghost btn--sm" onclick="generateSuggestions(); closeGameDetails();">
                                💡 Generate Suggestions
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    `;

    // Add modal styles if not present
    if (!document.getElementById('gameDetailStyles')) {
        const style = document.createElement('style');
        style.id = 'gameDetailStyles';
        style.textContent = `
            .game-detail-overlay {
                position: fixed; top: 0; left: 0; right: 0; bottom: 0;
                background: rgba(0,0,0,0.7); z-index: 2000;
                display: flex; align-items: center; justify-content: center;
                padding: 20px;
            }
            .game-detail-modal {
                background: var(--bg-card, #1a1a2e); border-radius: 12px;
                max-width: 700px; width: 100%; max-height: 85vh;
                overflow-y: auto; border: 1px solid var(--border, #333);
            }
            .game-detail-header {
                display: flex; align-items: center; gap: 12px;
                padding: 20px 24px; border-bottom: 1px solid var(--border, #333);
                position: sticky; top: 0; background: var(--bg-card, #1a1a2e); z-index: 1;
            }
            .game-detail-header h3 { flex: 1; margin: 0; }
            .game-detail-body { padding: 0 24px 24px; }
            .detail-section { margin-top: 20px; }
            .detail-section h4 { margin-bottom: 12px; font-size: 14px; color: var(--text-secondary, #888); }
            .detail-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
            .detail-item { padding: 8px 12px; background: var(--bg-secondary, #16213e); border-radius: 8px; }
            .detail-label { display: block; font-size: 11px; color: var(--text-secondary, #888); margin-bottom: 2px; }
            .detail-value { font-size: 14px; }
            .detail-value--lg { font-size: 24px; font-weight: bold; color: var(--accent-primary, #00d4ff); }
            .detail-value--mono { font-family: monospace; font-size: 12px; }
            .detail-loading { color: var(--text-secondary, #888); font-style: italic; padding: 8px; }
            .detail-actions { display: flex; gap: 8px; flex-wrap: wrap; }
            .detail-pattern-item, .detail-suggestion-item {
                padding: 8px 12px; background: var(--bg-secondary, #16213e);
                border-radius: 8px; margin-bottom: 6px; font-size: 13px;
            }
            .detail-pattern-item .severity { font-weight: bold; }
            .severity--high { color: #ff4444; }
            .severity--medium { color: #ffaa00; }
            .severity--low { color: #44ff44; }
        `;
        document.head.appendChild(style);
    }

    // Insert modal
    document.body.insertAdjacentHTML('beforeend', detailHtml);

    // Load async details
    loadGameDetailMetrics(gameId);
    loadGameDetailPatterns(gameId);
    loadGameDetailSuggestions(gameId);
    loadGameDetailAgentConfig(gameId);
}

function closeGameDetails() {
    const overlay = document.getElementById('gameDetailOverlay');
    if (overlay) overlay.remove();
}

async function loadGameDetailMetrics(gameId) {
    const container = document.getElementById(`detailMetrics-${gameId}`);
    if (!container || !contracts.MetricsRegistry) {
        if (container) container.innerHTML = '<div class="detail-item"><span class="detail-value">Metrics not available</span></div>';
        return;
    }

    try {
        const metricNames = await contracts.MetricsRegistry.getMetricNames(gameId);
        if (metricNames.length === 0) {
            container.innerHTML = '<div class="detail-item"><span class="detail-value">No metrics defined. Apply a game type template first.</span></div>';
            return;
        }

        let html = '<div class="detail-grid">';
        for (const name of metricNames.slice(0, 10)) { // Limit to 10 for display
            try {
                const stats = await contracts.MetricsRegistry.getStats(gameId, name);
                const isHealthy = await contracts.MetricsRegistry.isHealthy(gameId, name);
                html += `
                    <div class="detail-item">
                        <span class="detail-label">${name} ${isHealthy ? '🟢' : '🟡'}</span>
                        <span class="detail-value">${stats[0]} <small>(avg: ${stats[3]})</small></span>
                    </div>
                `;
            } catch (e) {}
        }
        html += '</div>';
        container.innerHTML = html;
    } catch (e) {
        container.innerHTML = '<div class="detail-item"><span class="detail-value">Failed to load metrics</span></div>';
    }
}

async function loadGameDetailPatterns(gameId) {
    const container = document.getElementById(`detailPatterns-${gameId}`);
    if (!container || !contracts.PatternDetector) {
        if (container) container.innerHTML = '<div class="detail-item"><span class="detail-value">Pattern detector not available</span></div>';
        return;
    }

    try {
        const patterns = await contracts.PatternDetector.getActivePatterns(gameId);
        if (patterns.length === 0) {
            container.innerHTML = '<div class="detail-item"><span class="detail-value">No patterns detected yet</span></div>';
            return;
        }

        let html = '';
        for (const p of patterns.slice(0, 5)) {
            const sev = Number(p.severity) >= 7 ? 'high' : Number(p.severity) >= 4 ? 'medium' : 'low';
            html += `
                <div class="detail-pattern-item">
                    <span class="severity severity--${sev}">${p.patternType}</span>
                    — ${p.description}
                    <small>(severity: ${p.severity}/10, confidence: ${(Number(p.confidence)/100).toFixed(0)}%)</small>
                </div>
            `;
        }
        container.innerHTML = html;
    } catch (e) {
        container.innerHTML = '<div class="detail-item"><span class="detail-value">Failed to load patterns</span></div>';
    }
}

async function loadGameDetailSuggestions(gameId) {
    const container = document.getElementById(`detailSuggestions-${gameId}`);
    if (!container || !contracts.SuggestionEngine) {
        if (container) container.innerHTML = '<div class="detail-item"><span class="detail-value">Suggestion engine not available</span></div>';
        return;
    }

    try {
        const suggestions = await contracts.SuggestionEngine.getActiveSuggestions(gameId);
        if (suggestions.length === 0) {
            container.innerHTML = '<div class="detail-item"><span class="detail-value">No suggestions yet. Detect patterns first.</span></div>';
            return;
        }

        let html = '';
        for (const s of suggestions.slice(0, 5)) {
            html += `
                <div class="detail-suggestion-item">
                    <strong>${s.category}</strong> <span class="badge badge--sm">${s.priority}</span>
                    — ${s.description}
                    <br><small>💡 ${s.action}</small>
                </div>
            `;
        }
        container.innerHTML = html;
    } catch (e) {
        container.innerHTML = '<div class="detail-item"><span class="detail-value">Failed to load suggestions</span></div>';
    }
}

async function loadGameDetailAgentConfig(gameId) {
    const container = document.getElementById(`detailAgentConfig-${gameId}`);
    if (!container || !contracts.GameRegistry) {
        if (container) container.innerHTML = '<div class="detail-item"><span class="detail-value">Config not available</span></div>';
        return;
    }

    try {
        const config = await contracts.GameRegistry.getConfig(gameId);
        container.innerHTML = `
            <div class="detail-item">
                <span class="detail-label">Spawn Entities</span>
                <span class="detail-value">${config.canSpawn ? '✅' : '❌'}</span>
            </div>
            <div class="detail-item">
                <span class="detail-label">Adjust Economy</span>
                <span class="detail-value">${config.canAdjustEconomy ? '✅' : '❌'}</span>
            </div>
            <div class="detail-item">
                <span class="detail-label">Generate Narrative</span>
                <span class="detail-value">${config.canGenerateNarrative ? '✅' : '❌'}</span>
            </div>
            <div class="detail-item">
                <span class="detail-label">Adjust Difficulty</span>
                <span class="detail-value">${config.canAdjustDifficulty ? '✅' : '❌'}</span>
            </div>
            <div class="detail-item">
                <span class="detail-label">Max Change/Epoch</span>
                <span class="detail-value">${Number(config.maxChangePerEpoch) / 100}%</span>
            </div>
            <div class="detail-item">
                <span class="detail-label">Epoch Length</span>
                <span class="detail-value">${Number(config.epochLength)} blocks</span>
            </div>
        `;
    } catch (e) {
        container.innerHTML = '<div class="detail-item"><span class="detail-value">Failed to load agent config</span></div>';
    }
}

// ══════════════════════════════════════════════
// ACTIVITY FEED
// ══════════════════════════════════════════════

function updateActivityFeed() {
    const list = document.getElementById('activityList');
    if (!list) return;

    if (registeredGames.length === 0) {
        list.innerHTML = '<div class="empty-state"><p>No activity yet. Register a game to get started.</p></div>';
        return;
    }

    let html = '';

    // Show registered games as activity
    for (const game of registeredGames) {
        html += `
            <div class="activity-item">
                <div class="activity-item__icon">${game.isActive ? '🟢' : '🔴'}</div>
                <div class="activity-item__content">
                    <div class="activity-item__title">${game.name} <span class="badge badge--sm">${game.gameType}</span></div>
                    <div class="activity-item__desc">
                        ${game.isActive ? 'Active' : 'Inactive'} · 
                        ${game.totalEvents} events · 
                        ${game.totalActions} actions
                        ${game.isVerified ? ' · ✓ Verified' : ''}
                    </div>
                </div>
            </div>
        `;
    }

    list.innerHTML = html;
}

// ══════════════════════════════════════════════
// NOTIFICATIONS
// ══════════════════════════════════════════════

function showNotification(message, type = 'info') {
    const container = document.getElementById('notifications') || createNotificationContainer();
    const notification = document.createElement('div');
    notification.className = `notification notification--${type}`;
    notification.innerHTML = `
        <div class="notification__content">
            <span class="notification__message">${message}</span>
            <button class="notification__close" onclick="this.parentElement.parentElement.remove()">×</button>
        </div>
    `;
    container.appendChild(notification);
    setTimeout(() => { if (notification.parentElement) notification.remove(); }, 5000);
}

function createNotificationContainer() {
    const container = document.createElement('div');
    container.id = 'notifications';
    container.style.cssText = 'position:fixed;top:80px;right:20px;z-index:1000;display:flex;flex-direction:column;gap:10px;';
    document.body.appendChild(container);
    return container;
}

// ══════════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════════

function shortAddr(addr) {
    if (!addr) return '-';
    return addr.slice(0, 6) + '...' + addr.slice(-4);
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

function setButtonLoading(btn, loading, text) {
    if (!btn) return;
    if (loading) {
        btn.disabled = true;
        btn.dataset.originalText = btn.innerHTML;
        btn.innerHTML = '<span class="btn__spinner"></span> ' + text;
    } else {
        btn.disabled = false;
        if (btn.dataset.originalText) {
            btn.innerHTML = btn.dataset.originalText;
        } else {
            btn.innerHTML = text;
        }
    }
}

// ══════════════════════════════════════════════
// GLOBAL FUNCTIONS
// ══════════════════════════════════════════════

window.updateTemplatePreview = updateTemplatePreview;
window.registerGame = registerGame;
window.addGameContract = addGameContract;
window.removeGameContract = removeGameContract;
window.showLanding = showLanding;
window.showRegisterPage = showRegisterPage;
window.showDashboard = showDashboard;
window.scrollToSection = scrollToSection;
window.detectPatterns = detectPatterns;
window.generateSuggestions = generateSuggestions;
window.markImplemented = markImplemented;
window.loadMetrics = loadMetrics;
window.recordMetric = recordMetric;
window.toggleGameStatus = toggleGameStatus;
window.viewGameDetails = viewGameDetails;
window.closeGameDetails = closeGameDetails;
window.startPatternAutoDetection = startPatternAutoDetection;
window.stopPatternAutoDetection = stopPatternAutoDetection;

// ══════════════════════════════════════════════
// INITIALIZATION
// ══════════════════════════════════════════════

document.addEventListener('DOMContentLoaded', () => {
    console.log('DOMContentLoaded fired');

    // Connect wallet button
    const connectBtn = document.getElementById('connectBtn');
    if (connectBtn) connectBtn.addEventListener('click', connectWallet);

    // Launch dashboard button
    const launchBtn = document.getElementById('launchBtn');
    if (launchBtn) launchBtn.addEventListener('click', () => showDashboard());

    // Hero register button
    const heroRegisterBtn = document.getElementById('heroRegisterBtn');
    if (heroRegisterBtn) {
        heroRegisterBtn.addEventListener('click', (e) => {
            e.preventDefault();
            console.log('heroRegisterBtn clicked');
            showRegisterPage();
        });
    }

    // Hero how button
    const heroHowBtn = document.getElementById('heroHowBtn');
    if (heroHowBtn) {
        heroHowBtn.addEventListener('click', (e) => {
            e.preventDefault();
            const el = document.getElementById('how-it-works');
            if (el) el.scrollIntoView({ behavior: 'smooth' });
        });
    }

    // Back to home button
    const backBtn = document.querySelector('.dashboard__actions .btn');
    if (backBtn) backBtn.addEventListener('click', showLanding);

    // Sidebar navigation
    document.querySelectorAll('.sidebar__link').forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            const view = link.dataset.view;
            switchView(view);
        });
    });

    // Register form - button onclick handles registration
    // No form submit listener needed

    // Smooth scroll for anchor links
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', (e) => {
            const href = anchor.getAttribute('href');
            if (href.length > 1 && !href.startsWith('#/')) {
                e.preventDefault();
                const target = document.querySelector(href);
                if (target) target.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        });
    });

    // Handle routing on page load
    handleRoute();

    // Listen for hash changes
    window.addEventListener('hashchange', handleRoute);

    // Check if already connected
    if (window.ethereum) {
        window.ethereum.request({ method: 'eth_accounts' })
            .then(accounts => {
                if (accounts.length > 0) connectWallet();
            });
    }
});

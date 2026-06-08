// ═══════════════════════════════════════════════
// OIKONO - Data-Driven Game Economy Agent
// Premium Design + Full Functionality
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
// PARTICLE BACKGROUND
// ══════════════════════════════════════════════

function initParticles() {
    const canvas = document.getElementById('particleCanvas');
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    let w, h;
    const particles = [];
    const PARTICLE_COUNT = 60;
    const COLORS = ['rgba(0,240,255,', 'rgba(168,85,247,', 'rgba(255,215,0,'];

    function resize() {
        w = canvas.width = window.innerWidth;
        h = canvas.height = window.innerHeight;
    }
    resize();
    window.addEventListener('resize', resize);

    for (let i = 0; i < PARTICLE_COUNT; i++) {
        particles.push({
            x: Math.random() * w,
            y: Math.random() * h,
            vx: (Math.random() - 0.5) * 0.3,
            vy: (Math.random() - 0.5) * 0.3,
            r: Math.random() * 2 + 0.5,
            color: COLORS[Math.floor(Math.random() * COLORS.length)],
            opacity: Math.random() * 0.4 + 0.1,
            pulse: Math.random() * Math.PI * 2,
            pulseSpeed: Math.random() * 0.02 + 0.005,
        });
    }

    function draw() {
        ctx.clearRect(0, 0, w, h);
        for (const p of particles) {
            p.x += p.vx;
            p.y += p.vy;
            p.pulse += p.pulseSpeed;
            if (p.x < 0) p.x = w;
            if (p.x > w) p.x = 0;
            if (p.y < 0) p.y = h;
            if (p.y > h) p.y = 0;

            const alpha = p.opacity * (0.6 + 0.4 * Math.sin(p.pulse));
            ctx.beginPath();
            ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
            ctx.fillStyle = p.color + alpha + ')';
            ctx.fill();

            // Glow
            ctx.beginPath();
            ctx.arc(p.x, p.y, p.r * 3, 0, Math.PI * 2);
            ctx.fillStyle = p.color + (alpha * 0.15) + ')';
            ctx.fill();
        }
        requestAnimationFrame(draw);
    }
    draw();
}

// ══════════════════════════════════════════════
// TYPEWRITER EFFECT
// ══════════════════════════════════════════════

function initTypewriter() {
    const desc = document.querySelector('.hero__desc');
    if (!desc) return;
    const fullText = desc.textContent.trim();
    desc.textContent = '';
    desc.innerHTML = '<span class="hero__tagline"></span><span class="hero__cursor"></span>';
    const tagline = desc.querySelector('.hero__tagline');
    let i = 0;

    function type() {
        if (i < fullText.length) {
            tagline.textContent += fullText[i];
            i++;
            setTimeout(type, 18 + Math.random() * 22);
        }
    }
    setTimeout(type, 800);
}

// ══════════════════════════════════════════════
// INTERSECTION OBSERVER (Scroll Animations)
// ══════════════════════════════════════════════

function initScrollAnimations() {
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('visible');
            }
        });
    }, { threshold: 0.1, rootMargin: '0px 0px -40px 0px' });

    document.querySelectorAll('.reveal, .reveal-left, .reveal-scale, .timeline-step').forEach(el => {
        observer.observe(el);
    });
}

// ══════════════════════════════════════════════
// ANIMATED COUNTERS
// ══════════════════════════════════════════════

function initCounters() {
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting && !entry.target.dataset.counted) {
                entry.target.dataset.counted = 'true';
                animateCounter(entry.target);
            }
        });
    }, { threshold: 0.5 });

    document.querySelectorAll('[data-count]').forEach(el => observer.observe(el));
}

function animateCounter(el) {
    const target = parseInt(el.dataset.count);
    const suffix = el.dataset.suffix || '';
    const duration = 1500;
    const start = performance.now();

    function update(now) {
        const elapsed = now - start;
        const progress = Math.min(elapsed / duration, 1);
        const eased = 1 - Math.pow(1 - progress, 3); // ease-out cubic
        const current = Math.round(target * eased);
        el.textContent = current + suffix;
        if (progress < 1) requestAnimationFrame(update);
    }
    requestAnimationFrame(update);
}

// ══════════════════════════════════════════════
// GAME TYPE TABS
// ══════════════════════════════════════════════

function initGameTypeTabs() {
    const tabs = document.querySelectorAll('.game-types__tab');
    const panels = document.querySelectorAll('.game-type-panel');

    tabs.forEach(tab => {
        tab.addEventListener('click', () => {
            const target = tab.dataset.tab;
            tabs.forEach(t => t.classList.remove('active'));
            tab.classList.add('active');
            panels.forEach(p => {
                p.classList.remove('active');
                if (p.id === 'tab-' + target) p.classList.add('active');
            });
        });
    });
}

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

        startPatternAutoDetection();

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
    window.location.hash = '#/register';
    showRegisterPageDirect();
}

function switchView(view) {
    currentView = view;
    document.querySelectorAll('.sidebar__link').forEach(link => {
        link.classList.toggle('sidebar__link--active', link.dataset.view === view);
    });
    document.querySelectorAll('.view').forEach(v => {
        const isActive = v.id === `view-${view}`;
        v.classList.toggle('view--active', isActive);
        v.style.display = isActive ? 'flex' : 'none';
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

function handleRoute() {
    const hash = window.location.hash || '#/';

    if (hash === '#/register') {
        showRegisterPageDirect();
    } else if (hash.startsWith('#/dashboard')) {
        if (!userAddress) {
            window.location.hash = '#/';
            return;
        }
        const view = hash.split('/')[2] || 'overview';
        document.getElementById('dashboard').style.display = 'grid';
        document.getElementById('developers').style.display = 'none';
        document.querySelectorAll('body > section:not(#dashboard):not(#developers)').forEach(el => {
            el.style.display = 'none';
        });
        const nav = document.querySelector('.nav');
        const footer = document.querySelector('.footer');
        if (nav) nav.style.display = 'none';
        if (footer) footer.style.display = 'none';
        switchView(view);
    } else {
        showLandingDirect();
    }
}

function showRegisterPageDirect() {
    const dashboard = document.getElementById('dashboard');
    if (dashboard) dashboard.style.display = 'none';
    document.querySelectorAll('body > section:not(#dashboard):not(#developers)').forEach(el => {
        el.style.display = 'none';
    });
    const developers = document.getElementById('developers');
    if (developers) developers.style.display = 'block';
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
                    const gameObj = {
                        id: Number(id),
                        gameAddress: game.gameAddress || game[0],
                        owner: game.owner || game[1],
                        name: game.name || game[2],
                        gameType: game.gameType || game[3],
                        description: game.description || game[4],
                        metadata: game.metadata || game[5],
                        isActive: game.isActive ?? game[6],
                        isVerified: game.isVerified ?? game[7],
                        totalEvents: Number(game.totalEvents ?? game[8]),
                        totalActions: Number(game.totalActions ?? game[9])
                    };
                    // Skip invalid/empty game entries
                    if (!gameObj.name || gameObj.name.trim() === '' || gameObj.name === '0x0000000000000000000000000000000000000000') continue;
                    if (gameObj.gameAddress === '0x0000000000000000000000000000000000000000' && !gameObj.isActive) continue;
                    registeredGames.push(gameObj);
                } catch (e) {
                    // Skip games that fail to load (possibly from failed registration)
                    console.warn('Skipping game ' + id + ': failed to load', e);
                }
            }
        }

        document.getElementById('statGames').textContent = registeredGames.length;

        if (contracts.PatternDetector && registeredGames.length > 0) {
            try {
                const count = await contracts.PatternDetector.getPatternCount(registeredGames[0].id);
                document.getElementById('statPatterns').textContent = count.toString();
            } catch (e) {}
        }

        if (contracts.SuggestionEngine && registeredGames.length > 0) {
            try {
                const count = await contracts.SuggestionEngine.getSuggestionCount(registeredGames[0].id);
                document.getElementById('statSuggestions').textContent = count.toString();
            } catch (e) {}
        }

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

        updateActivityFeed();
        updateGamesList();

    } catch (err) {
        showNotification('Failed to load dashboard', 'error');
    }
}

function loadViewData(view) {
    switch (view) {
        case 'overview': loadDashboardData(); break;
        case 'metrics': loadMetrics(); break;
        case 'patterns': loadPatterns(); break;
        case 'suggestions': loadSuggestions(); break;
        case 'games': updateGamesList(); break;
    }
}

// ══════════════════════════════════════════════
// METRICS
// ══════════════════════════════════════════════

async function loadMetrics() {
    const grid = document.getElementById('metricsGrid');
    const select = document.getElementById('metricsGameSelect');

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
                showNotification('Failed to load metric', 'error');
            }
        }

        grid.innerHTML = html || '<div class="empty-state"><p>Failed to load metrics</p></div>';
    } catch (err) {
        showNotification('Error loading metrics', 'error');
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
        const tx = await contracts.MetricsRegistry.recordMetric(gameId, metricName, parseInt(metricValue));
        showNotification('TX sent: ' + tx.hash, 'info');
        await tx.wait();
        showNotification('Metric recorded: ' + metricName + ' = ' + metricValue, 'success');

        document.getElementById('recordMetricName').value = '';
        document.getElementById('recordMetricValue').value = '';

        if (contracts.PatternDetector && registeredGames.length > 0) {
            try {
                const tx2 = await contracts.PatternDetector.detectPatterns(gameId);
                await tx2.wait();
            } catch (e) {
                /* auto-detection optional */
            }
        }

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

    let allPatterns = [];
    for (const game of registeredGames) {
        try {
            const patterns = await contracts.PatternDetector.getActivePatterns(game.id);
            patterns.forEach(p => {
                // Map tuple fields to named properties
                allPatterns.push({
                    patternId: p.patternId ?? p[0],
                    gameId: game.id,
                    patternType: p.patternType ?? p[2] ?? 'Unknown',
                    metricName: p.metricName ?? p[4] ?? '-',
                    description: p.description ?? p[5] ?? 'No description',
                    severity: Number(p.severity ?? p[6] ?? 0),
                    confidence: Number(p.confidence ?? p[7] ?? 0),
                    detectedAt: p.detectedAt ?? p[8],
                    isActive: p.isActive ?? p[9],
                    gameName: game.name
                });
            });
        } catch (e) {
            // Skip games that fail pattern loading
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
                <span class="pattern-item__severity severity--${p.severity >= 7 ? 'high' : p.severity >= 4 ? 'medium' : 'low'}">Severity: ${p.severity}/10</span>
            </div>
            <p class="pattern-item__desc">${p.description}</p>
            <div class="pattern-item__meta">
                <span>Game: ${p.gameName}</span>
                <span>Confidence: ${(p.confidence / 100).toFixed(0)}%</span>
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
                showNotification('Pattern detection failed', 'error');
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

    let allSuggestions = [];
    for (const game of registeredGames) {
        try {
            const suggestions = await contracts.SuggestionEngine.getActiveSuggestions(game.id);
            suggestions.forEach(s => {
                // Map tuple fields to named properties
                allSuggestions.push({
                    suggestionId: s.suggestionId ?? s[0],
                    gameId: game.id,
                    patternId: s.patternId ?? s[2],
                    category: s.category ?? s[3] ?? 'General',
                    priority: s.priority ?? s[4] ?? 'medium',
                    description: s.description ?? s[5] ?? 'No description',
                    action: s.action ?? s[6] ?? 'No action specified',
                    confidence: Number(s.confidence ?? s[7] ?? 0),
                    expectedImpact: Number(s.expectedImpact ?? s[8] ?? 0),
                    implemented: s.implemented ?? s[9] ?? false,
                    implementedAt: s.implementedAt ?? s[10],
                    gameName: game.name
                });
            });
        } catch (e) {
            // Skip games that fail suggestion loading
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
                <span>Confidence: ${(s.confidence / 100).toFixed(0)}%</span>
                <span>Impact: ${(s.expectedImpact / 100).toFixed(0)}%</span>
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
                showNotification('Suggestion generation failed', 'error');
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
                    <span class="game-card__address">${game.gameAddress === '0x0000000000000000000000000000000000000000' ? 'Off-chain' : shortAddr(game.gameAddress)}</span>
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
        html += `<div class="empty-state" style="grid-column: 1/-1;"><p>No games registered yet.</p></div>`;
    }

    list.innerHTML = html;

    list.querySelectorAll('[data-action="view"]').forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.preventDefault();
            e.stopPropagation();
            viewGameDetails(parseInt(btn.dataset.gameId));
        });
    });

    list.querySelectorAll('[data-action="toggle"]').forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.preventDefault();
            e.stopPropagation();
            toggleGameStatus(parseInt(btn.dataset.gameId), btn.dataset.active === 'true');
        });
    });
}

async function toggleGameStatus(gameId, currentlyActive) {
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

const GAME_TYPE_TEMPLATES = CONFIG.GAME_TYPE_TEMPLATES || {};
let gameContracts = [];

async function addGameContract(btnElement) {
    const addressInput = document.getElementById('contractAddress');
    const roleSelect = document.getElementById('contractRole');
    const address = addressInput.value.trim();
    const role = roleSelect.value;

    if (!address || !address.startsWith('0x') || address.length !== 42) {
        showNotification('Invalid! Contract address must be a valid 42-character hex address', 'error');
        return;
    }
    if (gameContracts.find(c => c.address.toLowerCase() === address.toLowerCase())) {
        showNotification('Contract already added', 'error');
        return;
    }

    if (btnElement) btnElement.disabled = true;
    try {
        if (provider) {
            const code = await provider.getCode(address);
            if (code === '0x') {
                showNotification(`Warning: Address ${shortAddr(address)} does not have deployed contract code.`, 'warning');
                // Continue without returning
            }
        }
        
        gameContracts.push({ address, role });
        updateContractList();
        addressInput.value = '';
        showNotification(`Contract analyzed and added successfully: ${role}`, 'success');
    } catch (err) {
        showNotification('Failed to analyze contract: ' + parseError(err), 'error');
    } finally {
        if (btnElement) btnElement.disabled = false;
    }
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
        const icon = roleInfo.icon || '📄';
        return `
            <div class="contract-item">
                <span class="contract-item__icon">${icon}</span>
                <span class="contract-item__role">${roleInfo.label}</span>
                <span class="contract-item__address">${shortAddr(c.address)}</span>
                <button type="button" class="btn btn--ghost btn--sm" onclick="removeGameContract(${i})">Remove</button>
            </div>
        `;
    }).join('');
}

window.fillExampleData = function() {
    // Step 1
    const nameInput = document.getElementById('gameName');
    if (nameInput) nameInput.value = "Battle Arena";
    
    const typeInput = document.getElementById('gameType');
    if (typeInput) {
        typeInput.value = "rpg";
        // Trigger change to update template preview
        typeInput.dispatchEvent(new Event('change'));
    }
    
    const descInput = document.getElementById('gameDesc');
    if (descInput) descInput.value = "On-chain battle arena with NFT enemies, token rewards, and AI-powered game master";
    
    const primaryInput = document.getElementById('primaryContract');
    if (primaryInput) primaryInput.value = "0xA247bFd1F0951071849EB47264185bb2047db39b";

    // Step 2
    gameContracts = [
        { address: "0xA03916C493cc00869FBd1D56cb89ba0d14A12116", role: "token" },
        { address: "0x8B0E52280c2E5047B8fd7AffD20333f36463b037", role: "nft" },
        { address: "0xA530dbDB02f46F4A1B7c18cEE8eA57148fC470Ae", role: "game_logic" }
    ];
    updateContractList();

    // Step 3
    if(document.getElementById('targetWinRate')) document.getElementById('targetWinRate').value = "55";
    if(document.getElementById('targetRetention')) document.getElementById('targetRetention').value = "30";
    if(document.getElementById('inflationTolerance')) document.getElementById('inflationTolerance').value = "medium";
    if(document.getElementById('economyStyle')) document.getElementById('economyStyle').value = "balanced";
    if(document.getElementById('maxChange')) document.getElementById('maxChange').value = "20";
    if(document.getElementById('epochLength')) document.getElementById('epochLength').value = "6500";

    // Step 4
    if(document.getElementById('permSpawn')) document.getElementById('permSpawn').checked = true;
    if(document.getElementById('permEconomy')) document.getElementById('permEconomy').checked = true;
    if(document.getElementById('permNarrative')) document.getElementById('permNarrative').checked = false;
    if(document.getElementById('permDifficulty')) document.getElementById('permDifficulty').checked = true;
    if(document.getElementById('autonomyLevel')) document.getElementById('autonomyLevel').value = "semi-auto";

    // Step 5
    if(document.getElementById('tokenName')) document.getElementById('tokenName').value = "OIK Token";
    if(document.getElementById('tokenSymbol')) document.getElementById('tokenSymbol').value = "OIK";
    if(document.getElementById('totalSupply')) document.getElementById('totalSupply').value = "1000000000";
    if(document.getElementById('circSupply')) document.getElementById('circSupply').value = "250000000";
    if(document.getElementById('tokenUtility')) document.getElementById('tokenUtility').value = "mixed";
    
    if(document.getElementById('sinkEntry')) document.getElementById('sinkEntry').checked = true;
    if(document.getElementById('sinkCraft')) document.getElementById('sinkCraft').checked = true;
    if(document.getElementById('sinkMarket')) document.getElementById('sinkMarket').checked = true;
    if(document.getElementById('sinkStaking')) document.getElementById('sinkStaking').checked = true;
    
    if(document.getElementById('srcBattle')) document.getElementById('srcBattle').checked = true;
    if(document.getElementById('srcQuest')) document.getElementById('srcQuest').checked = true;
    if(document.getElementById('srcStaking')) document.getElementById('srcStaking').checked = true;

    showNotification('Example data filled successfully! Proceed to verify all steps.', 'success');
}

function updateRangeDisplay(input, displayId) {
    const display = document.getElementById(displayId);
    if (display) display.textContent = input.value + '%';
}

function updateTemplatePreview() {
    const gameType = document.getElementById('gameType').value;
    const preview = document.getElementById('templatePreview');

    if (!gameType || !GAME_TYPE_TEMPLATES[gameType]) {
        preview.innerHTML = '<p class="form-section-desc">Select a game type to see included metrics</p>';
        return;
    }

    const template = GAME_TYPE_TEMPLATES[gameType];
    const targetWinRate = document.getElementById('targetWinRate')?.value || 55;
    const targetRetention = document.getElementById('targetRetention')?.value || 30;
    const inflationTolerance = document.getElementById('inflationTolerance')?.value || 'medium';
    const economyStyle = document.getElementById('economyStyle')?.value || 'balanced';
    const maxChange = document.getElementById('maxChange')?.value || 20;
    const checkFrequency = document.getElementById('checkFrequency')?.value || 'hourly';
    const autonomyLevel = document.getElementById('autonomyLevel')?.value || 'semi-auto';
    const entryModel = document.querySelector('input[name="entryModel"]:checked')?.value || 'free';
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
                    <div class="template-config__item"><span class="template-config__label">Target Win Rate</span><span class="template-config__value">${targetWinRate}%</span></div>
                    <div class="template-config__item"><span class="template-config__label">Target D7 Retention</span><span class="template-config__value">${targetRetention}%</span></div>
                    <div class="template-config__item"><span class="template-config__label">Inflation Tolerance</span><span class="template-config__value">${inflationTolerance}</span></div>
                    <div class="template-config__item"><span class="template-config__label">Economy Style</span><span class="template-config__value">${economyStyle}</span></div>
                    <div class="template-config__item"><span class="template-config__label">Max Change/Epoch</span><span class="template-config__value">${maxChange}%</span></div>
                    <div class="template-config__item"><span class="template-config__label">Entry Model</span><span class="template-config__value">${entryModel}</span></div>
                </div>
            </div>
            <div class="template-config">
                <h6>Agent Permissions:</h6>
                <div class="template-config__grid">
                    <div class="template-config__item"><span class="template-config__label">Spawn Entities</span><span class="template-config__value">${permSpawn ? 'Yes' : 'No'}</span></div>
                    <div class="template-config__item"><span class="template-config__label">Adjust Economy</span><span class="template-config__value">${permEconomy ? 'Yes' : 'No'}</span></div>
                    <div class="template-config__item"><span class="template-config__label">Generate Narrative</span><span class="template-config__value">${permNarrative ? 'Yes' : 'No'}</span></div>
                    <div class="template-config__item"><span class="template-config__label">Adjust Difficulty</span><span class="template-config__value">${permDifficulty ? 'Yes' : 'No'}</span></div>
                </div>
            </div>
            <div class="template-config">
                <h6>Integration:</h6>
                <div class="template-config__grid">
                    <div class="template-config__item"><span class="template-config__label">Check Frequency</span><span class="template-config__value">${checkFrequency}</span></div>
                    <div class="template-config__item"><span class="template-config__label">Autonomy Level</span><span class="template-config__value">${autonomyLevel}</span></div>
                </div>
            </div>
            <div class="template-metrics__list">
                <h6>Metrics Tracked:</h6>
                ${template.metrics.map(m => `<div class="template-metric-item"><span class="template-metric-name">${m.name}</span><span class="template-metric-healthy">${m.healthy}</span></div>`).join('')}
            </div>
            <div class="template-rules">
                <h6>Detection Rules:</h6>
                ${template.rules.map(r => `<div class="template-rule-item"><span class="template-rule-type">${r.type}</span><span class="template-rule-metric">${r.metric}</span><span class="template-rule-threshold">${r.threshold}</span></div>`).join('')}
            </div>
        </div>
    `;
}

// ══════════════════════════════════════════════
// FORM STEP NAVIGATION
// ══════════════════════════════════════════════

function nextStep(step) {
    document.querySelectorAll('.form-step').forEach(s => s.classList.remove('active'));
    const target = document.querySelector(`.form-step[data-step="${step}"]`);
    if (target) target.classList.add('active');
    document.querySelectorAll('.form-progress__step').forEach(s => {
        const sStep = parseInt(s.dataset.step);
        s.classList.remove('active', 'done');
        if (sStep === step) s.classList.add('active');
        else if (sStep < step) s.classList.add('done');
    });
}

function prevStep(step) {
    nextStep(step);
}

async function registerGame() {
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
    const primaryGameAddress = document.getElementById('primaryContract')?.value?.trim();

    if (!name || name.trim() === '') {
        showNotification('Please enter a game name', 'error');
        nextStep(1);
        return;
    }
    if (!gameType) {
        showNotification('Please select a game type', 'error');
        nextStep(1);
        return;
    }
    if (!primaryGameAddress || !primaryGameAddress.startsWith('0x') || primaryGameAddress.length !== 42) {
        showNotification('Please enter a valid primary game contract address', 'error');
        nextStep(1);
        return;
    }

    // Check if game address is actually a deployed contract and already registered
    if (primaryGameAddress !== '0x0000000000000000000000000000000000000000') {
        try {
            if (provider) {
                const code = await provider.getCode(primaryGameAddress);
                if (code === '0x') {
                    showNotification(`Warning: Primary address ${shortAddr(primaryGameAddress)} does not have deployed contract code. Proceeding anyway...`, 'warning');
                    // Continue without returning
                }
            }

            if (typeof contracts.GameRegistry.gameByAddress === 'function') {
                const existingGameId = await contracts.GameRegistry.gameByAddress(primaryGameAddress);
                if (Number(existingGameId) !== 0) {
                    showNotification(`Contract ${shortAddr(primaryGameAddress)} is already registered (Game ID: ${existingGameId})`, 'error');
                    nextStep(1);
                    return;
                }
            } else {
                console.warn('gameByAddress function not found in ABI. Please hard refresh the page.');
            }
        } catch (err) {
            console.warn('Failed to check existing game address', err);
        }
    }

    const btn = document.querySelector('#registerForm button[type="submit"]');
    if (!btn) return;
    setButtonLoading(btn, true, 'Registering...');

    try {
        showNotification('Preparing transaction...', 'info');

        let gameId;

        const metadata = JSON.stringify({
            website: document.getElementById('gameWebsite')?.value || '',
            primaryAddress: primaryGameAddress,
            contracts: gameContracts.map(c => ({ address: c.address, role: c.role })),
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
            player: {
                entryModel: document.querySelector('input[name="entryModel"]:checked')?.value || 'free',
                segments: {
                    casual: document.getElementById('segCasual')?.checked ?? false,
                    hardcore: document.getElementById('segHardcore')?.checked ?? false,
                    whale: document.getElementById('segWhale')?.checked ?? false,
                    trader: document.getElementById('segTrader')?.checked ?? false,
                }
            },
            economy: {
                targetWinRate: parseInt(document.getElementById('targetWinRate')?.value || 55),
                targetRetention: parseInt(document.getElementById('targetRetention')?.value || 30),
                inflationTolerance: document.getElementById('inflationTolerance')?.value || 'medium',
                economyStyle: document.getElementById('economyStyle')?.value || 'balanced',
                maxChangePerEpoch: parseInt(document.getElementById('maxChange')?.value || 20),
            },
            permissions: {
                canSpawn: document.getElementById('permSpawn')?.checked ?? true,
                canAdjustEconomy: document.getElementById('permEconomy')?.checked ?? true,
                canGenerateNarrative: document.getElementById('permNarrative')?.checked ?? false,
                canAdjustDifficulty: document.getElementById('permDifficulty')?.checked ?? true,
            },
            alerts: {
                winRateLow: parseInt(document.getElementById('winRateLow')?.value || 40),
                winRateHigh: parseInt(document.getElementById('winRateHigh')?.value || 70),
                velocityAlert: parseInt(document.getElementById('velocityAlert')?.value || 50000),
                retentionDrop: parseInt(document.getElementById('retentionDrop')?.value || 15),
                inflationAlert: parseInt(document.getElementById('inflationAlert')?.value || 10),
            },
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

        const agentConfig = {
            canSpawn: document.getElementById('permSpawn')?.checked ?? true,
            canAdjustEconomy: document.getElementById('permEconomy')?.checked ?? true,
            canGenerateNarrative: document.getElementById('permNarrative')?.checked ?? false,
            canAdjustDifficulty: document.getElementById('permDifficulty')?.checked ?? true,
            maxChangePerEpoch: parseInt(document.getElementById('maxChange')?.value || 20),
            epochLength: parseInt(document.getElementById('epochLength')?.value || 6500),
        };

        const tx = await contracts.GameRegistry.registerGame(
            name.trim(), gameType, description || 'No description provided',
            primaryGameAddress, metadata, agentConfig
        );

        showNotification('TX sent: ' + tx.hash, 'info');
        const receipt = await tx.wait();

        if (receipt.status === 0 || receipt.status === 0n) {
            throw new Error('Transaction failed and reverted on the blockchain.');
        }

        const log = receipt.logs.find(l => {
            try { return contracts.GameRegistry.interface.parseLog(l)?.name === 'GameRegistered'; }
            catch { return false; }
        });

        if (log) {
            gameId = contracts.GameRegistry.interface.parseLog(log).args.gameId;
            showNotification('Game registered! ID: ' + gameId, 'success');

            try {
                // Skip redundant primary contract linking since it's passed in registerGame
                // const addPrimaryTx = await contracts.GameRegistry.addContract(gameId, primaryGameAddress, 'game_logic', []);
                // const primaryReceipt = await addPrimaryTx.wait();
                // if (primaryReceipt.status === 0 || primaryReceipt.status === 0n) throw new Error('Primary contract link reverted');
                // showNotification('Primary contract linked', 'success');
            } catch (e) {
                showNotification('Contract link failed', 'warning');
                showNotification('Failed to link primary contract: ' + parseError(e), 'error');
            }

            for (const c of gameContracts) {
                try {
                    const addTx = await contracts.GameRegistry.addContract(gameId, c.address, c.role, []);
                    const addReceipt = await addTx.wait();
                    if (addReceipt.status === 0 || addReceipt.status === 0n) throw new Error('Contract add reverted');
                    showNotification('Contract added: ' + c.role, 'success');
                } catch (e) {
                    showNotification('Contract add failed', 'warning');
                    showNotification('Failed to add contract ' + c.role + ': ' + parseError(e), 'error');
                }
            }

            try {
                showNotification('Applying game type template...', 'info');
                if (!contracts.GameTypeManager) {
                    showNotification('Template skipped - GameTypeManager not loaded', 'warning');
                } else {
                    const templateTx = await contracts.GameTypeManager.applyTemplate(gameId, gameType);
                    const templateReceipt = await templateTx.wait();
                    if (templateReceipt.status === 0 || templateReceipt.status === 0n) throw new Error('Template transaction reverted');
                    showNotification('Template applied! Metrics and rules configured.', 'success');
                }
            } catch (e) {
                showNotification('Template application failed: ' + parseError(e), 'warning');
            }
        } else {
            throw new Error('Game registered but could not parse event to get gameId');
        }

        const form = document.getElementById('registerForm');
        if (form) form.reset();
        const preview = document.getElementById('templatePreview');
        if (preview) preview.innerHTML = '<p class="form-section-desc">Select a game type to see included metrics</p>';
        gameContracts = [];
        updateContractList();

        await loadDashboardData();
        // Skip optional reactivity setup to reduce MetaMask popups during registration
        // await autoSubscribeReactivity(gameId, primaryGameAddress);
        showDashboard('games');

    } catch (err) {
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
                return;
    }

    try {
        showNotification('Setting up on-chain reactivity...', 'info');
        const playerMovedSig = ethers.id('PlayerMoved(address,uint256,uint256,uint256,uint256)');

        try {
            const subscriptionDeposit = ethers.parseEther('0.01');
            const tx = await contracts.GameMaster.subscribeToPlayerMoved(playerMovedSig, { value: subscriptionDeposit });
            const gmReceipt = await tx.wait();
            if (gmReceipt.status === 0 || gmReceipt.status === 0n) throw new Error('GameMaster subscription reverted');
            showNotification('GameMaster subscribed to PlayerMoved events', 'success');
        } catch (e) {
;
            showNotification('GameMaster subscription failed: ' + parseError(e), 'warning');
        }

        try {
            if (contracts.SpawnPlugin) {
                const pluginAddr = contracts.SpawnPlugin.target;
                const regTx = await contracts.AgentRuntime.registerGame(
                    document.getElementById('gameName')?.value || 'Game ' + gameId, pluginAddr
                );
                const regReceipt = await regTx.wait();
                if (regReceipt.status === 0 || regReceipt.status === 0n) throw new Error('AgentRuntime registration reverted');
                showNotification('Game registered with AgentRuntime', 'success');
            }
        } catch (e) {
;
        }

        try {
            const subscriptionDeposit = ethers.parseEther('0.01');
            const playerMovedSig2 = ethers.id('PlayerMoved(address,uint256,uint256,uint256,uint256)');
            const subTx = await contracts.AgentRuntime.subscribeToEvent(playerMovedSig2, subscriptionDeposit, { value: subscriptionDeposit });
            const subReceipt = await subTx.wait();
            if (subReceipt.status === 0 || subReceipt.status === 0n) throw new Error('AgentRuntime subscription reverted');
            showNotification('AgentRuntime subscribed to game events', 'success');
        } catch (e) {
;
        }

        showNotification('On-chain reactivity configured!', 'success');
    } catch (err) {
;
        showNotification('Reactivity setup failed: ' + parseError(err), 'warning');
    }
}

// ══════════════════════════════════════════════
// PATTERN DETECTOR AUTO-RUN
// ══════════════════════════════════════════════

let patternDetectionInterval = null;
const PATTERN_DETECTION_INTERVAL = 5 * 60 * 1000;

function startPatternAutoDetection() {
    if (patternDetectionInterval) return;

    patternDetectionInterval = setInterval(async () => {
        if (!contracts.PatternDetector || registeredGames.length === 0) return;
        try {
            for (const game of registeredGames) {
                if (!game.isActive) continue;
                try {
                    const tx = await contracts.PatternDetector.detectPatterns(game.id);
                    await tx.wait();
                                    } catch (e) {
;
                }
            }
        } catch (e) {
;
        }
    }, PATTERN_DETECTION_INTERVAL);

    }

function stopPatternAutoDetection() {
    if (patternDetectionInterval) {
        clearInterval(patternDetectionInterval);
        patternDetectionInterval = null;
    }
}

// ══════════════════════════════════════════════
// GAME DETAILS VIEW
// ══════════════════════════════════════════════

async function viewGameDetails(gameId) {
    const game = registeredGames.find(g => g.id === gameId);
    if (!game) {
        showNotification('Game not found', 'error');
        return;
    }

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
                            <div class="detail-item"><span class="detail-label">Game ID</span><span class="detail-value">${game.id}</span></div>
                            <div class="detail-item"><span class="detail-label">Type</span><span class="detail-value">${game.gameType}</span></div>
                            <div class="detail-item"><span class="detail-label">Description</span><span class="detail-value">${game.description}</span></div>
                            <div class="detail-item"><span class="detail-label">Verified</span><span class="detail-value">${game.isVerified ? '✅ Yes' : '❌ No'}</span></div>
                        </div>
                    </div>
                    <div class="detail-section">
                        <h4>📊 Activity Stats</h4>
                        <div class="detail-grid">
                            <div class="detail-item"><span class="detail-label">Total Events</span><span class="detail-value detail-value--lg">${game.totalEvents}</span></div>
                            <div class="detail-item"><span class="detail-label">Total Actions</span><span class="detail-value detail-value--lg">${game.totalActions}</span></div>
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
                                    if (meta.primaryAddress) html += `<div class="detail-item"><span class="detail-label">Primary</span><span class="detail-value detail-value--mono">${shortAddr(meta.primaryAddress)}</span></div>`;
                                    if (meta.contracts && meta.contracts.length > 0) {
                                        meta.contracts.forEach(c => {
                                            const roleInfo = CONFIG.CONTRACT_ROLES[c.role] || { label: c.role };
                                            html += `<div class="detail-item"><span class="detail-label">${roleInfo.label}</span><span class="detail-value detail-value--mono">${shortAddr(c.address)}</span></div>`;
                                        });
                                    }
                                    return html;
                                } catch (e) { return '<div class="detail-item"><span class="detail-value">No contract info</span></div>'; }
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
                            <button class="btn btn--ghost btn--sm" onclick="detectPatterns(); closeGameDetails();">🔍 Scan Patterns</button>
                            <button class="btn btn--ghost btn--sm" onclick="generateSuggestions(); closeGameDetails();">💡 Generate Suggestions</button>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    `;

    document.body.insertAdjacentHTML('beforeend', detailHtml);
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
        for (const name of metricNames.slice(0, 10)) {
            try {
                const stats = await contracts.MetricsRegistry.getStats(gameId, name);
                const isHealthy = await contracts.MetricsRegistry.isHealthy(gameId, name);
                html += `<div class="detail-item"><span class="detail-label">${name} ${isHealthy ? '🟢' : '🟡'}</span><span class="detail-value">${stats[0]} <small>(avg: ${stats[3]})</small></span></div>`;
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
            const severity = Number(p.severity ?? p[6] ?? 0);
            const patternType = p.patternType ?? p[2] ?? 'Unknown';
            const description = p.description ?? p[5] ?? 'No description';
            const confidence = Number(p.confidence ?? p[7] ?? 0);
            const sev = severity >= 7 ? 'high' : severity >= 4 ? 'medium' : 'low';
            html += `<div class="detail-pattern-item"><span class="severity severity--${sev}">${patternType}</span> — ${description} <small>(severity: ${severity}/10, confidence: ${(confidence/100).toFixed(0)}%)</small></div>`;
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
            const category = s.category ?? s[3] ?? 'General';
            const priority = s.priority ?? s[4] ?? 'medium';
            const description = s.description ?? s[5] ?? 'No description';
            const action = s.action ?? s[6] ?? 'No action specified';
            html += `<div class="detail-suggestion-item"><strong>${category}</strong> <span class="badge badge--sm">${priority}</span> — ${description}<br><small>💡 ${action}</small></div>`;
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
        const canSpawn = config.canSpawn ?? config[0] ?? false;
        const canAdjustEconomy = config.canAdjustEconomy ?? config[1] ?? false;
        const canGenerateNarrative = config.canGenerateNarrative ?? config[2] ?? false;
        const canAdjustDifficulty = config.canAdjustDifficulty ?? config[3] ?? false;
        const maxChangePerEpoch = Number(config.maxChangePerEpoch ?? config[4] ?? 0);
        const epochLength = Number(config.epochLength ?? config[5] ?? 0);
        container.innerHTML = `
            <div class="detail-item"><span class="detail-label">Spawn Entities</span><span class="detail-value">${canSpawn ? '✅' : '❌'}</span></div>
            <div class="detail-item"><span class="detail-label">Adjust Economy</span><span class="detail-value">${canAdjustEconomy ? '✅' : '❌'}</span></div>
            <div class="detail-item"><span class="detail-label">Generate Narrative</span><span class="detail-value">${canGenerateNarrative ? '✅' : '❌'}</span></div>
            <div class="detail-item"><span class="detail-label">Adjust Difficulty</span><span class="detail-value">${canAdjustDifficulty ? '✅' : '❌'}</span></div>
            <div class="detail-item"><span class="detail-label">Max Change/Epoch</span><span class="detail-value">${maxChangePerEpoch / 100}%</span></div>
            <div class="detail-item"><span class="detail-label">Epoch Length</span><span class="detail-value">${epochLength} blocks</span></div>
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
        if (err.message.includes('reverted') || err.message.includes('revert')) {
            const revertMatch = err.message.match(/reverted with reason "([^"]+)"/) || err.message.match(/revert: ([^"]+)/);
            if (revertMatch) return revertMatch[1];
        }
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
    // Premium animations
    initParticles();
    initTypewriter();
    initScrollAnimations();
    initCounters();
    initGameTypeTabs();

    // Connect wallet button
    const connectBtn = document.getElementById('connectBtn');
    if (connectBtn) connectBtn.addEventListener('click', connectWallet);

    // Launch dashboard button
    const launchBtn = document.getElementById('launchBtn');
    if (launchBtn) launchBtn.addEventListener('click', () => showDashboard());

    // Dashboard register button
    const viewAddGameBtn = document.getElementById('viewAddGameBtn');
    if (viewAddGameBtn) {
        viewAddGameBtn.addEventListener('click', (e) => {
            e.preventDefault();
            showRegisterPage();
        });
    }

    // Hero register button
    const heroRegisterBtn = document.getElementById('heroRegisterBtn');
    if (heroRegisterBtn) {
        heroRegisterBtn.addEventListener('click', (e) => {
            e.preventDefault();
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

    // Back to home buttons
    const backBtn = document.getElementById('backToHomeBtn');
    if (backBtn) backBtn.addEventListener('click', showLanding);
    const backBtn2 = document.getElementById('backToHomeBtn2');
    if (backBtn2) backBtn2.addEventListener('click', showLanding);

    // CTA register button
    const ctaRegisterBtn = document.getElementById('ctaRegisterBtn');
    if (ctaRegisterBtn) ctaRegisterBtn.addEventListener('click', (e) => {
        e.preventDefault();
        showRegisterPage();
    });

    // Register form submit
    const registerForm = document.getElementById('registerForm');
    if (registerForm) registerForm.addEventListener('submit', (e) => {
        e.preventDefault();
        registerGame();
    });

    // Template preview on game type change
    const gameTypeSelect = document.getElementById('gameType');
    if (gameTypeSelect) gameTypeSelect.addEventListener('change', updateTemplatePreview);

    // Sidebar navigation
    document.querySelectorAll('.sidebar__link').forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            switchView(link.dataset.view);
        });
    });

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

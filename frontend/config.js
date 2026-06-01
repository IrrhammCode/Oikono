/**
 * OIKONO Frontend Configuration
 * Deployed on Somnia Testnet - 2026-06-01
 */

const CONFIG = {
    CHAIN_ID: '0xC488',
    RPC_URL: 'https://dream-rpc.somnia.network',
    WS_URL: 'wss://dream-rpc.somnia.network/ws',

    CONTRACTS: {
        // Agent Intelligence
        OikonoAgent: '0x8292B838ce0C0eB2303e4eE3e8dc256eD8d39E74',
        AgentRuntime: '0x42D284771C77bBAbC487a029e081b5504bCA41CA',
        AgentMemory: '0x9798995ad174dc01Bd1C6f7177e7EE220937b098',
        GameKnowledgeBase: '0x2038D5f321Cd8A9eC2cAbf9CC61Ce77d982585C6',
        AgentRegistry: '0x9E3eB05a2131472F457Ab951D404Aa737E4e6FeC',
        AgentVault: '0x232A33D72A88836db88DEE4b8f06e379eBC43f7a',

        // Game Registry
        GameRegistry: '0xDcDD689932DD7026C1cDC723F6E49A17953b332f',

        // Metrics & Analysis
        MetricsRegistry: '0xd43e055198f9eeca623249CB7115Ba90537AE6C5',
        PatternDetector: '0x3288A2545Df449E1565506a059635b920dfa2E57',
        SuggestionEngine: '0x261857a7aC8cB48A40069863774b7ff99EEBF0a2',
        GameTypeManager: '0x20c3dc3eA21bdd79C087775dD23b38290962C7B6',

        // LLM Integration
        LLMInvoker: '0xdA11A6Cc18bA511F0265283d5082adf85C20e69D',

        // Plugins
        SpawnPlugin: '0x1362B3a42B7d1d1382f02b597b4f1aeB992547f0',
        EconomyPlugin: '0x24D14B259Ac93283e29d4E3536c7fe03aaA0Ae12',
        NarrativePlugin: '0xdAAbc5d9Bb026F83D54E9E08F235205a7e5331C1',
        BalancePlugin: '0xC8341A97371Cf58B3e57f815B392c9267F7e7C85',

        // Game
        PlayerRegistry: '0x11ec0E392b455212347D44b3B383C7D6B71571bB',
        GameMaster: '0x2A59DE2fe88C0cDB36687f0C8056f132D0FE5c42',
        EnemyNFT: '0xdC42BEe9FcFB056eaB5A6654Bd86B3FD8aEdeEdf',
        BattleArena: '0x3b4D12cCcb9d72Ae40551bc3A3f0eb93ae916683',
        RewardDistributor: '0xD151BFc16B340E98A56E03B0663Bda6904F24996',

        // Economy
        OIKToken: '0x265661d7D4df3bdE1F374086CA5e2D23cf37Beb9',
        EconomyParams: '0xca43CAaaBAF7167A204eb8E97b60a7B93baBE2d5',
        Treasury: '0x1cD055B1159bD6C4d1098e5Bb7b70c44aA0aeF3c',

        // Utils
        CircuitBreaker: '0xa4176d4Eeee28fa3a3c0efA2678Fbaff053975aD',
        AntiSybil: '0x6ed39eF55C2408749a2b11ECE8a87D993332C4C4',
    },

    ABI: {
        GameRegistry: [
            'function registerGame(string name, string gameType, string description, string metadata) external returns (uint256)',
            'function addContract(uint256 gameId, address contractAddress, string role, bytes32[] eventHashes) external',
            'function getGame(uint256 gameId) external view returns (address owner, string name, string gameType, string description, string metadata, bool isActive, bool isVerified, uint256 totalEvents, uint256 totalActions)',
            'function getGameContracts(uint256 gameId) external view returns (address[] addresses, string[] roles, bool[] active)',
            'function getGamesByOwner(address owner) external view returns (uint256[])',
            'function applyTemplate(uint256 gameId, string typeName) external',
            'function deactivateGame(uint256 gameId) external',
            'function activateGame(uint256 gameId) external',
            'event GameRegistered(uint256 indexed gameId, address indexed owner, string name, string gameType)',
        ],
        MetricsRegistry: [
            'function defineMetric(uint256 gameId, string name, string dataType, string source, uint256 healthyMin, uint256 healthyMax, bool isHigherBetter) external',
            'function recordMetric(uint256 gameId, string name, uint256 value) external',
            'function getLatest(uint256 gameId, string name) external view returns (uint256)',
            'function getStats(uint256 gameId, string name) external view returns (uint256 latest, uint256 min, uint256 max, uint256 avg, uint256 count, uint256 lastUpdated)',
            'function getMetricNames(uint256 gameId) external view returns (string[] memory)',
            'function isHealthy(uint256 gameId, string name) external view returns (bool)',
            'function getChange(uint256 gameId, string name) external view returns (int256)',
            'event MetricDefined(uint256 indexed gameId, string metricName, string dataType, string source)',
            'event MetricRecorded(uint256 indexed gameId, string metricName, uint256 value, uint256 timestamp)',
        ],
        PatternDetector: [
            'function addRule(uint256 gameId, string ruleType, string metricName, uint256 threshold, uint256 period) external',
            'function addDefaultRules(uint256 gameId, string gameType) external',
            'function detectPatterns(uint256 gameId) external',
            'function getActivePatterns(uint256 gameId) external view returns (tuple(uint256 patternId, uint256 gameId, string patternType, string metricName, string metricName2, string description, uint256 severity, uint256 confidence, uint256 detectedAt, bool isActive, bytes data)[] memory)',
            'function getPatternCount(uint256 gameId) external view returns (uint256)',
            'event PatternDetected(uint256 indexed gameId, uint256 indexed patternId, string patternType, string description, uint256 severity)',
        ],
        SuggestionEngine: [
            'function generateSuggestions(uint256 gameId) external',
            'function markImplemented(uint256 gameId, uint256 suggestionId) external',
            'function getActiveSuggestions(uint256 gameId) external view returns (tuple(uint256 suggestionId, uint256 gameId, uint256 patternId, string category, string priority, string description, string action, uint256 confidence, uint256 expectedImpact, bool implemented, uint256 implementedAt, bytes outcomeData)[] memory)',
            'function getSuggestionCount(uint256 gameId) external view returns (uint256)',
            'event SuggestionCreated(uint256 indexed gameId, uint256 indexed suggestionId, string category, string priority, string description)',
        ],
        GameTypeManager: [
            'function applyTemplate(uint256 gameId, string typeName) external',
            'function getRegisteredTypes() external view returns (string[] memory)',
            'function getConfig(string typeName) external view returns (string description, uint256 metricCount, uint256 ruleCount)',
        ],
        OikonoAgent: [
            'function requestAction(uint256 gameId, string actionType, bytes gameData) external returns (uint256 decisionId)',
            'function reportOutcome(uint256 decisionId, bool success, bytes resultData) external',
            'function getStats() external view returns (uint256 decisions, uint256 llmCalls, uint256 autoActions)',
        ],
        AgentMemory: [
            'function getGameStats(address game) external view returns (uint256 totalDecisions, uint256 successfulDecisions, uint256 failedDecisions, uint256 successRate)',
            'function getPatterns(address game) external view returns (string[] patternTypes, uint256[] confidences, uint256[] occurrences)',
        ],
    },

    GAME_TYPE_TEMPLATES: {
        rpg: {
            name: 'RPG',
            description: 'Role-Playing Games',
            metrics: [
                { name: 'win_rate', healthy: '45-65%', description: 'Player win rate' },
                { name: 'token_velocity', healthy: '5-20', description: 'Token circulation speed' },
                { name: 'gold_inflation', healthy: '0-5%/day', description: 'Gold inflation rate' },
                { name: 'retention_d7', healthy: '20-40%', description: '7-day retention' },
                { name: 'avg_session_length', healthy: '15-60 min', description: 'Session duration' },
            ],
            rules: [
                { type: 'spike', metric: 'win_rate', threshold: '20%', description: 'Win rate spike' },
                { type: 'drop', metric: 'retention_d7', threshold: '15%', description: 'Retention drop' },
            ]
        },
        card: {
            name: 'Card Game',
            description: 'Card Games (TCG/CCG)',
            metrics: [
                { name: 'pack_ev', healthy: '0.9-1.1', description: 'Pack expected value' },
                { name: 'meta_diversity', healthy: '>65%', description: 'Meta diversity index' },
                { name: 'collection_rate', healthy: '30-50%', description: 'Collection progress' },
            ],
            rules: [
                { type: 'drop', metric: 'pack_ev', threshold: '20%', description: 'Pack EV dropped' },
            ]
        },
        pvp: {
            name: 'PvP',
            description: 'PvP Games',
            metrics: [
                { name: 'queue_time', healthy: '<30 sec', description: 'Queue wait time' },
                { name: 'match_balance', healthy: '<200', description: 'ELO difference' },
            ],
            rules: [
                { type: 'trend_up', metric: 'queue_time', threshold: '50% over 7d', description: 'Queue time increasing' },
            ]
        },
    },

    CONTRACT_ROLES: {
        token: { label: 'Token', description: 'Game token contract' },
        nft: { label: 'NFT', description: 'NFT collection contract' },
        marketplace: { label: 'Marketplace', description: 'Trading marketplace' },
        staking: { label: 'Staking', description: 'Staking/yield contract' },
        game_logic: { label: 'Game Logic', description: 'Core game mechanics' },
    },
};

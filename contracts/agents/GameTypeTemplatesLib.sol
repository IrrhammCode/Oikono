// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title GameTypeTemplatesLib
 * @notice Library for game type templates
 * @dev Separated from GameRegistryV2 to reduce contract size
 */
library GameTypeTemplatesLib {

    struct MetricTemplate {
        string name;
        string dataType;
        string source;
        string contractRole;
        uint256 healthyMin;
        uint256 healthyMax;
        bool isHigherBetter;
    }

    struct RuleTemplate {
        string ruleType;
        string metricName;
        uint256 threshold;
        uint256 period;
    }

    function rpgMetrics() internal pure returns (MetricTemplate[] memory) {
        MetricTemplate[] memory m = new MetricTemplate[](12);
        m[0] = MetricTemplate("win_rate", "bps", "on_chain", "game_logic", 4500, 6500, false);
        m[1] = MetricTemplate("token_velocity", "uint256", "on_chain", "token", 5, 20, false);
        m[2] = MetricTemplate("gold_inflation", "bps", "calculated", "token", 0, 500, false);
        m[3] = MetricTemplate("sink_source_ratio", "bps", "calculated", "token", 7000, 10000, true);
        m[4] = MetricTemplate("level_speed", "uint256", "calculated", "game_logic", 50, 200, true);
        m[5] = MetricTemplate("retention_d7", "bps", "off_chain", "", 2000, 4000, true);
        m[6] = MetricTemplate("retention_d30", "bps", "off_chain", "", 1000, 2000, true);
        m[7] = MetricTemplate("avg_session_length", "duration", "off_chain", "", 900, 3600, true);
        m[8] = MetricTemplate("dau_mau_ratio", "bps", "off_chain", "", 2000, 4000, true);
        m[9] = MetricTemplate("quest_completion", "bps", "on_chain", "game_logic", 3000, 7000, true);
        m[10] = MetricTemplate("item_drop_rate", "bps", "on_chain", "game_logic", 500, 2000, true);
        m[11] = MetricTemplate("daily_active_users", "uint256", "off_chain", "", 100, 0, true);
        return m;
    }

    function rpgRules() internal pure returns (RuleTemplate[] memory) {
        RuleTemplate[] memory r = new RuleTemplate[](6);
        r[0] = RuleTemplate("spike", "win_rate", 2000, 1);
        r[1] = RuleTemplate("drop", "retention_d7", 1500, 1);
        r[2] = RuleTemplate("trend_up", "token_velocity", 5000, 7);
        r[3] = RuleTemplate("trend_up", "gold_inflation", 3000, 7);
        r[4] = RuleTemplate("drop", "sink_source_ratio", 2000, 1);
        r[5] = RuleTemplate("trend_up", "level_speed", 5000, 7);
        return r;
    }

    function cardMetrics() internal pure returns (MetricTemplate[] memory) {
        MetricTemplate[] memory m = new MetricTemplate[](10);
        m[0] = MetricTemplate("pack_ev", "bps", "calculated", "marketplace", 9000, 11000, true);
        m[1] = MetricTemplate("meta_diversity", "bps", "calculated", "game_logic", 6500, 10000, true);
        m[2] = MetricTemplate("card_price_stability", "bps", "calculated", "marketplace", 0, 3000, false);
        m[3] = MetricTemplate("collection_rate", "bps", "on_chain", "nft", 3000, 5000, true);
        m[4] = MetricTemplate("market_volume", "uint256", "on_chain", "marketplace", 1000, 0, true);
        m[5] = MetricTemplate("match_duration", "duration", "on_chain", "game_logic", 300, 900, false);
        m[6] = MetricTemplate("daily_matches", "uint256", "on_chain", "game_logic", 3, 20, true);
        m[7] = MetricTemplate("deck_diversity", "bps", "on_chain", "game_logic", 5000, 8000, true);
        m[8] = MetricTemplate("retention_d7", "bps", "off_chain", "", 2000, 4000, true);
        m[9] = MetricTemplate("daily_active_users", "uint256", "off_chain", "", 100, 0, true);
        return m;
    }

    function cardRules() internal pure returns (RuleTemplate[] memory) {
        RuleTemplate[] memory r = new RuleTemplate[](5);
        r[0] = RuleTemplate("drop", "pack_ev", 2000, 1);
        r[1] = RuleTemplate("drop", "meta_diversity", 1500, 1);
        r[2] = RuleTemplate("spike", "card_price_stability", 3000, 1);
        r[3] = RuleTemplate("drop", "retention_d7", 1500, 7);
        r[4] = RuleTemplate("drop", "collection_rate", 2000, 7);
        return r;
    }

    function pvpMetrics() internal pure returns (MetricTemplate[] memory) {
        MetricTemplate[] memory m = new MetricTemplate[](10);
        m[0] = MetricTemplate("win_rate_avg", "bps", "on_chain", "game_logic", 4000, 6000, false);
        m[1] = MetricTemplate("win_rate_spread", "bps", "calculated", "game_logic", 1000, 1500, false);
        m[2] = MetricTemplate("elo_spread", "uint256", "calculated", "game_logic", 1000, 2000, false);
        m[3] = MetricTemplate("match_balance", "uint256", "calculated", "game_logic", 0, 200, false);
        m[4] = MetricTemplate("queue_time", "duration", "off_chain", "", 0, 30, false);
        m[5] = MetricTemplate("match_duration", "duration", "on_chain", "game_logic", 300, 900, false);
        m[6] = MetricTemplate("character_usage", "bps", "on_chain", "nft", 500, 2000, false);
        m[7] = MetricTemplate("rank_distribution", "bps", "on_chain", "game_logic", 3000, 5000, true);
        m[8] = MetricTemplate("retention_d7", "bps", "off_chain", "", 2000, 4000, true);
        m[9] = MetricTemplate("daily_active_users", "uint256", "off_chain", "", 100, 0, true);
        return m;
    }

    function pvpRules() internal pure returns (RuleTemplate[] memory) {
        RuleTemplate[] memory r = new RuleTemplate[](5);
        r[0] = RuleTemplate("trend_up", "queue_time", 5000, 7);
        r[1] = RuleTemplate("spike", "elo_spread", 2000, 1);
        r[2] = RuleTemplate("drop", "match_balance", 3000, 1);
        r[3] = RuleTemplate("spike", "character_usage", 3000, 1);
        r[4] = RuleTemplate("drop", "retention_d7", 1500, 7);
        return r;
    }

    function strategyMetrics() internal pure returns (MetricTemplate[] memory) {
        MetricTemplate[] memory m = new MetricTemplate[](8);
        m[0] = MetricTemplate("resource_balance", "bps", "calculated", "token", 4000, 6000, true);
        m[1] = MetricTemplate("build_time_avg", "duration", "on_chain", "game_logic", 60, 600, false);
        m[2] = MetricTemplate("unit_win_rate", "bps", "on_chain", "game_logic", 4500, 5500, false);
        m[3] = MetricTemplate("territory_control", "bps", "on_chain", "game_logic", 2000, 5000, true);
        m[4] = MetricTemplate("alliance_participation", "bps", "on_chain", "game_logic", 3000, 6000, true);
        m[5] = MetricTemplate("match_duration", "duration", "on_chain", "game_logic", 600, 1800, false);
        m[6] = MetricTemplate("retention_d7", "bps", "off_chain", "", 2500, 5000, true);
        m[7] = MetricTemplate("resource_inflation", "bps", "calculated", "token", 0, 1500, false);
        return m;
    }

    function strategyRules() internal pure returns (RuleTemplate[] memory) {
        RuleTemplate[] memory r = new RuleTemplate[](3);
        r[0] = RuleTemplate("trend_up", "resource_inflation", 3000, 7);
        r[1] = RuleTemplate("spike", "unit_win_rate", 1500, 1);
        r[2] = RuleTemplate("drop", "alliance_participation", 2000, 1);
        return r;
    }

    function defiMetrics() internal pure returns (MetricTemplate[] memory) {
        MetricTemplate[] memory m = new MetricTemplate[](6);
        m[0] = MetricTemplate("apy", "bps", "on_chain", "staking", 500, 50000, true);
        m[1] = MetricTemplate("tvl", "uint256", "on_chain", "staking", 10000, 0, true);
        m[2] = MetricTemplate("token_price", "uint256", "on_chain", "token", 0, 0, true);
        m[3] = MetricTemplate("liquidity_depth", "uint256", "on_chain", "marketplace", 10000, 0, true);
        m[4] = MetricTemplate("deposit_withdraw_ratio", "bps", "on_chain", "staking", 8000, 12000, true);
        m[5] = MetricTemplate("retention_d7", "bps", "off_chain", "", 2000, 5000, true);
        return m;
    }

    function defiRules() internal pure returns (RuleTemplate[] memory) {
        RuleTemplate[] memory r = new RuleTemplate[](3);
        r[0] = RuleTemplate("drop", "tvl", 2000, 1);
        r[1] = RuleTemplate("drop", "liquidity_depth", 3000, 1);
        r[2] = RuleTemplate("trend_down", "deposit_withdraw_ratio", 2000, 7);
        return r;
    }

    function simulationMetrics() internal pure returns (MetricTemplate[] memory) {
        MetricTemplate[] memory m = new MetricTemplate[](6);
        m[0] = MetricTemplate("resource_production", "uint256", "on_chain", "game_logic", 100, 10000, true);
        m[1] = MetricTemplate("trade_volume", "uint256", "on_chain", "marketplace", 1000, 100000, true);
        m[2] = MetricTemplate("land_utilization", "bps", "on_chain", "game_logic", 3000, 7000, true);
        m[3] = MetricTemplate("creator_earnings", "uint256", "on_chain", "marketplace", 100, 10000, true);
        m[4] = MetricTemplate("visitor_count", "uint256", "off_chain", "", 50, 5000, true);
        m[5] = MetricTemplate("retention_d7", "bps", "off_chain", "", 2500, 5000, true);
        return m;
    }

    function simulationRules() internal pure returns (RuleTemplate[] memory) {
        RuleTemplate[] memory r = new RuleTemplate[](2);
        r[0] = RuleTemplate("drop", "trade_volume", 3000, 7);
        r[1] = RuleTemplate("drop", "visitor_count", 4000, 7);
        return r;
    }

    function puzzleMetrics() internal pure returns (MetricTemplate[] memory) {
        MetricTemplate[] memory m = new MetricTemplate[](5);
        m[0] = MetricTemplate("level_completion", "bps", "on_chain", "game_logic", 5000, 8000, true);
        m[1] = MetricTemplate("move_efficiency", "bps", "on_chain", "game_logic", 3000, 7000, true);
        m[2] = MetricTemplate("streak_length", "uint256", "on_chain", "game_logic", 3, 50, true);
        m[3] = MetricTemplate("lives_purchased", "uint256", "on_chain", "token", 0, 10, false);
        m[4] = MetricTemplate("retention_d7", "bps", "off_chain", "", 3000, 6000, true);
        return m;
    }

    function puzzleRules() internal pure returns (RuleTemplate[] memory) {
        RuleTemplate[] memory r = new RuleTemplate[](2);
        r[0] = RuleTemplate("drop", "level_completion", 2000, 1);
        r[1] = RuleTemplate("trend_up", "lives_purchased", 5000, 7);
        return r;
    }

    function racingMetrics() internal pure returns (MetricTemplate[] memory) {
        MetricTemplate[] memory m = new MetricTemplate[](5);
        m[0] = MetricTemplate("win_rate", "bps", "on_chain", "game_logic", 4000, 6000, false);
        m[1] = MetricTemplate("lap_time_avg", "duration", "on_chain", "game_logic", 60, 300, false);
        m[2] = MetricTemplate("vehicle_upgrades", "uint256", "on_chain", "nft", 1, 20, true);
        m[3] = MetricTemplate("tournament_participation", "bps", "on_chain", "game_logic", 2000, 5000, true);
        m[4] = MetricTemplate("retention_d7", "bps", "off_chain", "", 2500, 5000, true);
        return m;
    }

    function racingRules() internal pure returns (RuleTemplate[] memory) {
        RuleTemplate[] memory r = new RuleTemplate[](2);
        r[0] = RuleTemplate("spike", "win_rate", 2000, 1);
        r[1] = RuleTemplate("drop", "tournament_participation", 3000, 1);
        return r;
    }

    function idleMetrics() internal pure returns (MetricTemplate[] memory) {
        MetricTemplate[] memory m = new MetricTemplate[](5);
        m[0] = MetricTemplate("income_per_hour", "uint256", "on_chain", "token", 10, 10000, true);
        m[1] = MetricTemplate("upgrade_frequency", "uint256", "on_chain", "game_logic", 1, 50, true);
        m[2] = MetricTemplate("session_length", "duration", "off_chain", "", 60, 600, true);
        m[3] = MetricTemplate("return_frequency", "uint256", "off_chain", "", 1, 10, true);
        m[4] = MetricTemplate("retention_d7", "bps", "off_chain", "", 2000, 4000, true);
        return m;
    }

    function idleRules() internal pure returns (RuleTemplate[] memory) {
        RuleTemplate[] memory r = new RuleTemplate[](2);
        r[0] = RuleTemplate("trend_up", "income_per_hour", 10000, 7);
        r[1] = RuleTemplate("drop", "return_frequency", 3000, 7);
        return r;
    }

    function sandboxMetrics() internal pure returns (MetricTemplate[] memory) {
        MetricTemplate[] memory m = new MetricTemplate[](6);
        m[0] = MetricTemplate("content_creation", "uint256", "on_chain", "game_logic", 1, 100, true);
        m[1] = MetricTemplate("user_engagement", "bps", "off_chain", "", 3000, 7000, true);
        m[2] = MetricTemplate("land_utilization", "bps", "on_chain", "nft", 2000, 6000, true);
        m[3] = MetricTemplate("creator_earnings", "uint256", "on_chain", "marketplace", 100, 10000, true);
        m[4] = MetricTemplate("platform_fees", "bps", "on_chain", "token", 200, 1000, false);
        m[5] = MetricTemplate("retention_d7", "bps", "off_chain", "", 2000, 5000, true);
        return m;
    }

    function sandboxRules() internal pure returns (RuleTemplate[] memory) {
        RuleTemplate[] memory r = new RuleTemplate[](2);
        r[0] = RuleTemplate("drop", "content_creation", 3000, 7);
        r[1] = RuleTemplate("drop", "creator_earnings", 4000, 7);
        return r;
    }
}

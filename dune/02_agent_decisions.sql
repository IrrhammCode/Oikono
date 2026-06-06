-- ═══════════════════════════════════════════════
-- OIKONO: Agent Decisions
-- Track all AI agent decisions and their outcomes
-- ═══════════════════════════════════════════════

-- Event: DecisionExecuted(uint256 indexed decisionId, address indexed game, string action, bool success)
WITH decisions AS (
    SELECT
        block_time,
        tx_hash,
        CAST(
            bytearray_to_uint256(SUBSTRING(topic1, 1, 32))
        AS INT) AS decision_id,
        CONCAT('0x', SUBSTRING(topic2, 13, 20)) AS game_address,
        VARBINARY_TO_STRING(SUBSTRING(data, 65, 32)) AS action,
        CASE WHEN SUBSTRING(data, 97, 1) = 0x01 THEN true ELSE false END AS success
    FROM ethereum.somnia_testnet.logs
    WHERE contract_address = 0x586e9ACF26D76A1aD52054b3EF3e9c72A9917b05  -- OikonoAgent
        AND topic0 = 0x  -- DecisionExecuted event signature
)

SELECT
    decision_id,
    game_address,
    action,
    success,
    block_time,
    tx_hash
FROM decisions
ORDER BY block_time DESC
LIMIT 100;

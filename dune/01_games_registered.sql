-- ═══════════════════════════════════════════════
-- OIKONO: Games Registered
-- Track all games registered in the OIKONO platform
-- ═══════════════════════════════════════════════

-- Event: GameRegistered(uint256 indexed gameId, address indexed gameAddress, address indexed owner, string name, string gameType)
-- Topic0: keccak256("GameRegistered(uint256,address,address,string,string)")

WITH games AS (
    SELECT
        block_time,
        block_number,
        tx_hash,
        CAST(
            bytearray_to_uint256(SUBSTRING(topic1, 1, 32))
        AS INT) AS game_id,
        CONCAT('0x', SUBSTRING(topic2, 13, 20)) AS game_address,
        CONCAT('0x', SUBSTRING(topic3, 13, 20)) AS owner,
        -- Decode name and gameType from data
        VARBINARY_TO_STRING(SUBSTRING(data, 65, 32)) AS name,
        VARBINARY_TO_STRING(SUBSTRING(data, 129, 32)) AS game_type
    FROM ethereum.somnia_testnet.logs
    WHERE contract_address = 0x6eB1d23419629901F78947B1207024f7F28380a6  -- GameRegistry
        AND topic0 = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef  -- Replace with actual event signature
)

SELECT
    game_id,
    game_address,
    owner,
    name,
    game_type,
    block_time,
    tx_hash
FROM games
ORDER BY block_time DESC
LIMIT 100;

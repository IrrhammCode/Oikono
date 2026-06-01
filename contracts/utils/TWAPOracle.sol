// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title IPriceFeed
 * @notice Interface for external price feed oracles (DIA, Protofire, etc.)
 */
interface IPriceFeed {
    function getPrice(string calldata pair) external view returns (
        uint256 price,
        uint256 timestamp
    );
}

/**
 * @title TWAPOracle
 * @notice Time-Weighted Average Price oracle for OIKONO economy
 * @dev Integrates with DIA or Protofire price feeds for Somnia
 *      Used to prevent flash loan manipulation in economy calculations
 */
contract TWAPOracle is Ownable {
    struct PriceData {
        uint256 price;
        uint256 timestamp;
    }

    // TWAP calculation window
    uint256 public constant TWAP_WINDOW = 100;
    uint256 public constant MAX_PRICE_AGE = 3600; // 1 hour in seconds

    PriceData[] public priceHistory;
    uint256 public latestPrice;
    uint256 public latestTimestamp;

    // External oracle integration
    address public externalOracle;
    string public pricePair; // e.g., "OIK/USDT"

    event PriceUpdated(uint256 price, uint256 timestamp);
    event OracleUpdated(address newOracle);

    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     * @notice Update price (called by oracle or keeper)
     */
    function updatePrice(uint256 price) external onlyOwner {
        require(price > 0, "Invalid price");

        priceHistory.push(PriceData({
            price: price,
            timestamp: block.timestamp
        }));

        // Keep only last 200 entries
        if (priceHistory.length > 200) {
            _removeOldest();
        }

        latestPrice = price;
        latestTimestamp = block.timestamp;

        emit PriceUpdated(price, block.timestamp);
    }

    /**
     * @notice Get TWAP over the window
     */
    function getTWAP() external view returns (uint256) {
        if (priceHistory.length == 0) return 0;

        uint256 totalWeightedPrice = 0;
        uint256 totalWeight = 0;

        for (uint256 i = 1; i < priceHistory.length; i++) {
            uint256 timeDelta = priceHistory[i].timestamp - priceHistory[i-1].timestamp;
            totalWeightedPrice += priceHistory[i-1].price * timeDelta;
            totalWeight += timeDelta;
        }

        if (totalWeight == 0) return latestPrice;
        return totalWeightedPrice / totalWeight;
    }

    /**
     * @notice Get current spot price
     */
    function getSpotPrice() external view returns (uint256) {
        require(
            block.timestamp - latestTimestamp <= MAX_PRICE_AGE,
            "Price data stale"
        );
        return latestPrice;
    }

    /**
     * @notice Check if price data is fresh
     */
    function isPriceFresh() external view returns (bool) {
        if (latestTimestamp == 0) return false;
        return block.timestamp - latestTimestamp <= MAX_PRICE_AGE;
    }

    function setExternalOracle(address _oracle) external onlyOwner {
        externalOracle = _oracle;
        emit OracleUpdated(_oracle);
    }

    /**
     * @notice Set price pair for external oracle
     * @param _pair Price pair string (e.g., "OIK/USDT")
     */
    function setPricePair(string calldata _pair) external onlyOwner {
        pricePair = _pair;
    }

    /**
     * @notice Update price from external oracle
     * @dev Can be called by anyone to update price from DIA/Protofire
     */
    function updatePriceFromOracle() external {
        require(externalOracle != address(0), "No external oracle set");
        require(bytes(pricePair).length > 0, "Price pair not set");

        (uint256 price, uint256 timestamp) = IPriceFeed(externalOracle).getPrice(pricePair);

        require(price > 0, "Invalid oracle price");
        require(block.timestamp - timestamp <= MAX_PRICE_AGE, "Oracle price stale");

        priceHistory.push(PriceData({
            price: price,
            timestamp: block.timestamp
        }));

        // Keep only last 200 entries
        if (priceHistory.length > 200) {
            _removeOldest();
        }

        latestPrice = price;
        latestTimestamp = block.timestamp;

        emit PriceUpdated(price, block.timestamp);
    }

    function _removeOldest() internal {
        for (uint256 i = 0; i < priceHistory.length - 1; i++) {
            priceHistory[i] = priceHistory[i + 1];
        }
        priceHistory.pop();
    }
}

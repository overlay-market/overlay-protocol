// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

contract OverlayV1PricePoint {

    // mapping from price point index to realized historical prices
    uint[] public pricePoints;

    constructor() {

        pricePoints.push(0);

    }

    /// @notice Get the current price point index
    function pricePointCurrentIndex() external view returns (uint) {

        return pricePoints.length;

    }

    /// @notice Allows inheriting contracts to add the latest realized price
    function setPricePointCurrent(uint256 price) internal {
        pricePoints.push(price);
    }

    // TODO: collapse updatePricePoints and fetchPricePoints into one function 
    // where inherited function uses super. Check that SOLC 0.8.2 still uses
    // super as such.

    /// @notice Fetches last price from oracle and sets in pricePoints
    /// @dev Override for each specific market feed to also fetch from oracle value for T+1
    function fetchPricePoint() internal virtual returns (bool success) {
        return true;
    }

    /// @notice Forwards price point index for next update period
    /// @dev Override fetchPricePoint for each specific market feed
    function updatePricePoints() internal {
        fetchPricePoint();
    }
}

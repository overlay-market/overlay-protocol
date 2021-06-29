// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./OverlayV1MirinMarket.sol";

contract OverlayV1MirinDeployer {

    /// @notice Creates a new market contract for given mirin pool address
    function deployMarket(
        address ovl,
        address mirinPool,
        uint256 updatePeriod,
        uint8 leverageMax,
        uint16 marginAdjustment,
        uint144 oiCap,
        uint112 fundingKNumerator,
        uint112 fundingKDenominator,
        bool isPrice0,
        uint256 windowSize,
        uint256 amountIn
    ) external returns (OverlayV1MirinMarket marketContract) {
        marketContract = new OverlayV1MirinMarket(
            ovl,
            mirinPool,
            updatePeriod,
            leverageMax,
            marginAdjustment,
            oiCap,
            fundingKNumerator,
            fundingKDenominator,
            isPrice0,
            windowSize,
            amountIn
        );
    }
}

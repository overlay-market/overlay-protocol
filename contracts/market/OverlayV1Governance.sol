// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../interfaces/IOverlayV1Factory.sol";
import "../interfaces/IOverlayToken.sol";

contract OverlayV1Governance {
    // ovl erc20 token
    IOverlayToken public immutable ovl;
    // OverlayFactory address
    IOverlayV1Factory public immutable factory;

    // leverage max allowed for a position: leverages are assumed to be discrete increments of 1
    uint8 public leverageMax;
    // percentage of factory maintenance margin requirement to adjust for due to risk of feed
    uint16 public marginAdjustment;
    // open interest cap on each side long/short
    uint144 public oiCap;
    // period size for calls to update
    uint256 public updatePeriod;

    // open interest funding constant factor, charged per updatePeriod
    // 1/d = 1 - 2k; 0 < k < 1/2, 1 < d < infty
    uint112 public fundingKNumerator;
    uint112 public fundingKDenominator;

    modifier onlyFactory() {
        require(msg.sender == address(factory), "OverlayV1: !factory");
        _;
    }

    modifier enabled() {
        require(factory.isMarket(address(this)), "OverlayV1: !enabled");
        _;
    }

    constructor(
        address _ovl,
        uint256 _updatePeriod,
        uint8 _leverageMax,
        uint16 _marginAdjustment,
        uint144 _oiCap,
        uint112 _fundingKNumerator,
        uint112 _fundingKDenominator
    ) {
        // immutables
        factory = IOverlayV1Factory(msg.sender);
        ovl = IOverlayToken(_ovl);

        // per-market adjustable params
        require(_updatePeriod >= 1, "OverlayV1: invalid update period");
        updatePeriod = _updatePeriod;
        leverageMax = _leverageMax;
        marginAdjustment = _marginAdjustment;
        oiCap = _oiCap;

        require(_fundingKDenominator > 2 * _fundingKNumerator, "OverlayV1: invalid k");
        fundingKNumerator = _fundingKNumerator;
        fundingKDenominator = _fundingKDenominator;
    }

    /// @notice Adjusts params associated with this market
    function adjustParams(
        uint256 _updatePeriod,
        uint8 _leverageMax,
        uint16 _marginAdjustment,
        uint144 _oiCap,
        uint112 _fundingKNumerator,
        uint112 _fundingKDenominator
    ) external onlyFactory {
        // TODO: requires on params; particularly leverageMax wrt MAX_FEE and cap
        require(_updatePeriod >= 1, "OverlayV1: invalid update period");
        updatePeriod = _updatePeriod;
        leverageMax = _leverageMax;
        marginAdjustment = _marginAdjustment;
        oiCap = _oiCap;

        require(_fundingKDenominator > 2 * _fundingKNumerator, "OverlayV1: invalid k");
        fundingKNumerator = _fundingKNumerator;
        fundingKDenominator = _fundingKDenominator;
    }
}

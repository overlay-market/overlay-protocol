// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../libraries/Position.sol";
import "../interfaces/IOverlayV1Factory.sol";
import "./OverlayV1Governance.sol";
import "./OverlayV1OI.sol";
import "./OverlayV1Position.sol";
import "../OverlayToken.sol";

contract OverlayV1Market is OverlayV1Position, OverlayV1Governance, OverlayV1Oi {
    using Position for Position.Info;

    uint256 public fees;
    uint256 public liquidations;

    uint constant RESOLUTION = 1e4;

    event Update(
        address indexed rewarded,
        uint256 reward,
        uint256 feesCollected,
        uint256 feeBurned,
        uint256 liquidationsCollected,
        uint256 liquidationsBurned,
        uint256 fundingBurned
    );
    event Build(uint256 positionId, uint256 oi, uint256 debt);
    event Unwind(uint256 positionId, uint256 oi, uint256 debt);
    event Liquidate(address indexed rewarded, uint256 reward);

    uint16 public constant MIN_COLLATERAL_AMOUNT = 10**4;

    // block at which market update was last called: includes funding payment, fees, price fetching
    uint256 public updateBlockLast;

    uint256 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "OverlayV1: !unlocked");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor(
        string memory _uri,
        address _ovl,
        uint256 _updatePeriod,
        uint8 _leverageMax,
        uint16 _marginAdjustment,
        uint144 _oiCap,
        uint112 _fundingKNumerator,
        uint112 _fundingKDenominator
    ) OverlayV1Position(_uri) OverlayV1Governance(
        _ovl,
        _updatePeriod,
        _leverageMax,
        _marginAdjustment,
        _oiCap,
        _fundingKNumerator,
        _fundingKDenominator
    ) {

        updateBlockLast = block.number;

    }

    /// @notice Updates funding payments, cumulative fees, queued position builds, and price points
    function update(address rewardsTo) public {
        uint256 blockNumber = block.number;
        uint256 elapsed = (blockNumber - updateBlockLast) / updatePeriod;
        if (elapsed > 0) {

            (   uint256 marginBurnRate,
                uint256 feeBurnRate,
                uint256 feeRewardsRate,
                address feeTo ) = factory.getUpdateParams();

            uint feesForward = fees;
            uint feesBurn = ( feesForward * feeBurnRate ) / RESOLUTION;
            uint feesReward = ( feesForward * feeRewardsRate ) / RESOLUTION;
            feesForward = feesForward - feesBurn - feesReward;

            uint liquidationForward = liquidations;
            uint liquidationBurn = ( liquidationForward * marginBurnRate ) / RESOLUTION;
            liquidationForward -= liquidationBurn;

            // zero cumulative fees and liquidations since last update
            fees = 0;
            liquidations = 0;

            // Funding payment changes at T+1
            uint fundingBurn = updateFunding(fundingKNumerator, fundingKDenominator, elapsed);

            // Settle T < t < T+1 built positions at T+1 update
            // WARNING: Must come after funding to prevent funding harvesting w zero price risk
            updatePricePoints();
            updateOi();

            // Increment update block
            updateBlockLast = blockNumber;

            emit Update(
                rewardsTo,
                feesReward,
                feesForward,
                feesBurn,
                liquidationForward,
                liquidationBurn,
                fundingBurn
            );

            ovl.burn(address(this), feesBurn + liquidationBurn + fundingBurn);
            ovl.transfer(feeTo, feesForward + liquidationForward);
            ovl.transfer(rewardsTo, feesReward);

        }
    }

    /// @notice Builds a new position
    function build(
        uint256 collateralAmount,
        bool isLong,
        uint256 leverage,
        address rewardsTo
    ) external lock enabled {
        require(collateralAmount >= MIN_COLLATERAL_AMOUNT, "OverlayV1: invalid collateral amount");
        require(leverage >= 1 && leverage <= leverageMax, "OverlayV1: invalid leverage");

        // update market for funding, price points, fees before all else
        update(rewardsTo);

        (   Position.Info storage position,
            uint256 positionId )= getQueuedPosition(isLong, leverage);
        uint256 oi = collateralAmount * leverage;

        // adjust for fees
        uint feeAmount = ( oi * factory.fee() ) / RESOLUTION;
        uint oiAdjusted = oi - feeAmount;
        uint256 collateralAmountAdjusted = oiAdjusted / leverage;
        uint256 debtAdjusted = oiAdjusted - collateralAmountAdjusted;

        // effects
        fees += feeAmount; // adds to fee pot, which is transferred on update
        position.oiShares += oiAdjusted;
        position.debt += debtAdjusted;
        position.cost += collateralAmountAdjusted;
        queueOi(isLong, oiAdjusted, oiCap);

        // events
        emit Build(positionId, oiAdjusted, debtAdjusted);

        // interactions
        ovl.transferFrom(msg.sender, address(this), collateralAmount);
        // mint the debt, before fees, to accomodate funding payment burns (edge case: oiLong == 0 || oiShort == 0)
        if (leverage > 1) ovl.mint(address(this), oi - collateralAmount);
        // WARNING: _mint shares should be last given erc1155 callback; mint shares based on OI contribution
        mint(msg.sender, positionId, oiAdjusted, "");
    }

    /// @notice Unwinds shares of an existing position
    function unwind(
        uint256 positionId,
        uint256 shares,
        address rewardsTo
    ) external lock enabled {
        require(shares > 0 && shares <= balanceOf(msg.sender, positionId), "OverlayV1: invalid position shares");

        Position.Info storage position = positions[positionId];

        require(position.pricePoint < pricePoints.length, "OverlayV1: position has not settled");

        // update market for funding, price point, fees before all else
        update(rewardsTo);

        uint valueAdjusted;

        {
        bool isLong = position.isLong;
        uint256 totalShares = totalPositionShares[positionId];
        uint256 posOiShares = shares * position.oiShares / totalShares;

        uint256 oi = isLong ? oiLong : oiShort;
        uint256 oiShares = isLong ? oiLongShares : oiShortShares;

        // TODO: more reads from storage here
        uint256 posOi = shares * position.openInterest(oi, oiShares ) / totalShares;

        uint256 debt = shares * position.debt / totalShares; // TODO: read from storage here
        uint256 cost = shares * position.cost / totalShares; // TODO: read from storage here

        uint256 _notional = shares * position.notional(pricePoints, oi, oiShares) / totalShares;

        // adjust for fees
        // TODO: think through edge case of underwater position ... and fee adjustments ...
        uint feeAmount = ( _notional * factory.fee() ) / RESOLUTION;
        valueAdjusted = _notional - feeAmount;
        valueAdjusted = valueAdjusted > debt ? valueAdjusted - debt : 0; // floor in case underwater, and protocol loses out on any maintenance margin

        // effects
        fees += feeAmount; // adds to fee pot, which is transferred on update
        position.oiShares -= posOiShares;
        position.debt -= debt;
        position.cost -= cost;

        if (isLong) ( oiLong = oi - posOi, oiLongShares = oiShares - posOiShares );
        else ( oiShort = oi - posOi, oiShortShares = oiShares - posOiShares );

        // events
        emit Unwind(positionId, posOi, debt);

        // interactions
        // mint/burn excess PnL = valueAdjusted - cost, accounting for need to also burn debt
        if (debt + cost < valueAdjusted) ovl.mint(address(this), valueAdjusted - cost - debt);
        else ovl.burn(address(this), debt + cost - valueAdjusted);
        }

        burn(msg.sender, positionId, shares);
        ovl.transfer(msg.sender, valueAdjusted);

    }

    /// @notice Liquidates an existing position
    function liquidate(
        uint256 positionId,
        address rewardsTo
    ) external lock enabled {

        Position.Info storage position = positions[positionId];

        require(position.pricePoint < pricePoints.length, "OverlayV1: position has not settled");

        update(rewardsTo);

        (   uint marginMaintenance,
            uint marginRewardRate   ) = factory.getMarginParams();

        uint oi;
        uint oiShares;

        if (position.isLong) ( oi = oiLong, oiShares = oiLongShares );
        else ( oi = oiShort, oiShares = oiShortShares );

        require(position.isLiquidatable(
            pricePoints,
            oi,
            oiShares,
            marginMaintenance
        ), "OverlayV1: position not liquidatable");

        oi -= position.openInterest(oi, oiShares);
        oiShares -= position.oiShares;

        if (position.isLong) ( oiLong = oi, oiLongShares = oiShares );
        else ( oiShort = oi, oiShortShares = oiShares );

        positions[positionId].oiShares = 0;

        uint toForward = position.cost;
        uint toReward = ( toForward * marginRewardRate ) / RESOLUTION;

        liquidations += toForward - toReward;

        ovl.transfer(rewardsTo, toReward);

    }

}

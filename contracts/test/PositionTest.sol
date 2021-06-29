// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../libraries/FixedPoint.sol";
import "../libraries/Position.sol";

contract PositionTest {
    using FixedPoint for FixedPoint.uq112x112;
    using FixedPoint for FixedPoint.uq144x112;
    using Position for Position.Info;

    Position.Info[] public positions;
    uint[] public pricePoints;

    function push(
        bool _isLong,
        uint256 _leverage,
        uint256 _pricePoint,
        uint256 _oiShares,
        uint256 _debt,
        uint256 _cost
    ) public {
        positions.push(Position.Info({
            isLong: _isLong,
            leverage: _leverage,
            pricePoint: _pricePoint,
            oiShares: _oiShares,
            debt: _debt,
            cost: _cost
        }));
    }

    function len() public view returns (uint256) {
        return positions.length;
    }

    function value(
        uint256 positionId,
        uint256 totalOi,
        uint256 totalOiShares
    ) external view returns (uint256) {

        Position.Info storage position = positions[positionId];

        return position.value(
            pricePoints, 
            totalOi, 
            totalOiShares
        );

    }

    function isUnderwater(
        uint256 positionId,
        uint256 totalOi,
        uint256 totalOiShares
    ) external view returns (bool) {
        Position.Info storage position = positions[positionId];
        return position.isUnderwater(pricePoints, totalOi, totalOiShares);
    }

    function notional(
        uint256 positionId,
        uint256 totalOi,
        uint256 totalOiShares,
        uint256 priceEntry,
        uint256 priceExit
    ) external view returns (uint256) {
        Position.Info storage position = positions[positionId];
        return position.notional(pricePoints, totalOi, totalOiShares);
    }

    function openLeverage(
        uint256 positionId,
        uint256 totalOi,
        uint256 totalOiShares
    ) external view returns (FixedPoint.uq144x112 memory) {
        Position.Info storage position = positions[positionId];
        return position.openLeverage(pricePoints, totalOi, totalOiShares);
    }

    function openMargin(
        uint256 positionId,
        uint256 totalOi,
        uint256 totalOiShares
    ) external view returns (FixedPoint.uq144x112 memory) {
        Position.Info storage position = positions[positionId];
        return position.openMargin(pricePoints, totalOi, totalOiShares);
    }

    function isLiquidatable(
        uint256 positionId,
        uint256 totalOi,
        uint256 totalOiShares,
        uint16 maintenanceFactor
    ) external view returns (bool) {
        Position.Info storage position = positions[positionId];
        return position.isLiquidatable(
            pricePoints,
            totalOi,
            totalOiShares,
            maintenanceFactor
        );
    }
}

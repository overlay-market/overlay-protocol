// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

interface IOverlayV1Factory {

    function isMarket(
        address
    ) external view returns (
        bool
    );

    function getGlobalParams() external view returns (
        uint16 fee_, 
        uint16 feeBurnRate_, 
        uint16 feeUpdateRewardsRate_, 
        address feeTo_, 
        uint8 marginMaintenance_, 
        uint8 marginBurnRate_, 
        address marginTo_
    );

    function getFeeParams() external view returns (
        uint16 fee_, 
        uint16 feeBurnRate_, 
        uint16 feeUpdateRewardsRate_, 
        address feeTo_
    );

    function getMarginParams() external view returns (
        uint8 marginMaintenance_, 
        uint8 marginBurnRate_, 
        address marginTo_
    );

    function fee() external view returns (uint256);

    function updateMarket(
        address _market, 
        address _rewardsTo
    ) external;

    function massUpdateMarkets(
        address _rewardsTo
    ) external;
}

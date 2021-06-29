// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./interfaces/IMirinFactory.sol";
import "./market/OverlayV1Factory.sol";
import "./OverlayV1MirinDeployer.sol";

contract OverlayV1MirinFactory is OverlayV1Factory {

    address public immutable deployer;
    address public immutable mirinFactory;

    constructor(
        address _ovl,
        address _deployer,
        address _mirinFactory,
        uint16 _fee,
        uint16 _feeBurnRate,
        uint16 _feeUpdateRewardsRate,
        address _feeTo,
        uint16 _marginMaintenance,
        uint16 _marginBurnRate,
        uint16 _marginRewardRate
    ) OverlayV1Factory (
        _ovl,
        _fee,
        _feeBurnRate,
        _feeUpdateRewardsRate,
        _feeTo,
        _marginMaintenance,
        _marginBurnRate,
        _marginRewardRate
    ) {
    
        // immutables
        deployer = _deployer;
        mirinFactory = _mirinFactory;

    }

    /// @notice Creates a new market contract for given mirin pool address
    function createMarket(
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
    ) external onlyOwner returns (OverlayV1MirinMarket marketContract) {
        require(IMirinFactory(mirinFactory).isPool(mirinPool), "OverlayV1: !MirinPool");

        (bool success, bytes memory result) = deployer.delegatecall(
            abi.encodeWithSignature("deployMarket(address,address,uint256,uint8,uint16,uint144,uint112,uint112,bool,uint256,uint256)",
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
        ));
        
        marketContract = abi.decode(result, (OverlayV1MirinMarket));

        initializeMarket(address(marketContract));
        
    }
}

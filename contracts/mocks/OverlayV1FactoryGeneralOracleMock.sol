// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./OverlayV1MarketGeneralOracleMock.sol";
import "../OverlayToken.sol";

contract OverlayV1FactoryGeneralOracleMock is Ownable {

    uint16 public constant MIN_FEE = 1; // 0.01%
    uint16 public constant MAX_FEE = 100; // 1.00%

    uint16 public constant MIN_MARGIN_MAINTENANCE = 100; // 1% maintenance
    uint16 public constant MAX_MARGIN_MAINTENANCE = 6000; // 60% maintenance

    uint16 public constant RESOLUTION = 10**4; // bps

    // ovl erc20 token
    address public immutable ovl;

    // global params adjustable by gov
    // build/unwind trading fee
    uint16 public fee;
    // portion of build/unwind fee burnt
    uint16 public feeBurnRate;
    // portion of non-burned fees to reward market updaters with (funding + price)
    uint16 public feeRewardsRate;
    // address to send fees to
    address public feeTo;
    // maintenance margin requirement
    uint16 public marginMaintenance;
    // maintenance margin burn rate on liquidations
    uint16 public marginBurnRate;
    // maintenance margin reward rate on liquidations
    uint16 public marginRewardRate;

    // whether is a market AND is enabled
    mapping(address => bool) public isMarket;
    // whether is an already created market: for easy access instead of looping through allMarkets
    mapping(address => bool) public marketExists;
    address[] public allMarkets;

    constructor(
        address _ovl,
        uint16 _fee,
        uint16 _feeBurnRate,
        uint16 _feeRewardsRate,
        address _feeTo,
        uint16 _marginMaintenance,
        uint16 _marginBurnRate
    ) {
        // immutables
        ovl = _ovl;

        // global params
        fee = _fee;
        feeBurnRate = _feeBurnRate;
        feeRewardsRate = _feeRewardsRate;
        feeTo = _feeTo;
        marginMaintenance = _marginMaintenance;
        marginBurnRate = _marginBurnRate;
    }

    /// @notice Creates a new market contract with spoofed prices
    function createMarket(
        bool isPrice0,
        uint256[] memory prices,
        uint256 updatePeriod,
        uint8 leverageMax,
        uint16 marginAdjustment,
        uint144 oiCap,
        uint112 fundingKNumerator,
        uint112 fundingKDenominator
    ) external onlyOwner returns (OverlayV1MarketGeneralOracleMock marketContract) {
        marketContract = new OverlayV1MarketGeneralOracleMock(
            ovl,
            isPrice0,
            prices,
            updatePeriod,
            leverageMax,
            marginAdjustment,
            oiCap,
            fundingKNumerator,
            fundingKDenominator
        );

        marketExists[address(marketContract)] = true;
        isMarket[address(marketContract)] = true;
        allMarkets.push(address(marketContract));

        // Give market contract mint/burn priveleges for OVL
        OverlayToken(ovl).grantRole(OverlayToken(ovl).MINTER_ROLE(), address(marketContract));
        OverlayToken(ovl).grantRole(OverlayToken(ovl).BURNER_ROLE(), address(marketContract));
    }

    /// @notice Disables an existing market contract 
    function disableMarket(address market) external onlyOwner {
        require(isMarket[market], "OverlayV1: !enabled");
        isMarket[market] = false;

        // Revoke mint/burn roles for the market
        OverlayToken(ovl).revokeRole(OverlayToken(ovl).MINTER_ROLE(), market);
        OverlayToken(ovl).revokeRole(OverlayToken(ovl).BURNER_ROLE(), market);
    }

    /// @notice Enables an existing market contract 
    function enableMarket(address market) external onlyOwner {
        require(marketExists[market], "OverlayV1: !exists");
        require(!isMarket[market], "OverlayV1: !disabled");
        isMarket[market] = true;

        // Give market contract mint/burn priveleges for OVL token
        OverlayToken(ovl).grantRole(OverlayToken(ovl).MINTER_ROLE(), market);
        OverlayToken(ovl).grantRole(OverlayToken(ovl).BURNER_ROLE(), market);
    }

    /// @notice Calls the update function on a market
    function updateMarket(address market, address rewardsTo) external {
        OverlayV1MarketGeneralOracleMock(market).update(rewardsTo);
    }

    /// @notice Mass calls update functions on all markets
    function massUpdateMarkets(address rewardsTo) external {
        for (uint256 i=0; i < allMarkets.length; ++i) {
            OverlayV1MarketGeneralOracleMock(allMarkets[i]).update(rewardsTo);
        }
    }

    /// @notice Allows gov to adjust per market params
    function adjustPerMarketParams(
        address market,
        uint256 updatePeriod,
        uint8 leverageMax,
        uint16 marginAdjustment,
        uint144 oiCap,
        uint112 fundingKNumerator,
        uint112 fundingKDenominator
    ) external onlyOwner {
        OverlayV1MarketGeneralOracleMock(market).adjustParams(
            updatePeriod,
            leverageMax,
            marginAdjustment,
            oiCap,
            fundingKNumerator,
            fundingKDenominator
        );
    }

    /// @notice Allows gov to adjust global params
    function adjustGlobalParams(
        uint16 _fee,
        uint16 _feeBurnRate,
        uint16 _feeRewardsRate,
        address _feeTo,
        uint16 _marginMaintenance,
        uint16 _marginBurnRate
    ) external onlyOwner {
        fee = _fee;
        feeBurnRate = _feeBurnRate;
        feeRewardsRate = _feeRewardsRate;
        feeTo = _feeTo;
        marginMaintenance = _marginMaintenance;
        marginBurnRate = _marginBurnRate;
    }

    function getUpdateParams () external view returns (
        uint16,
        uint16,
        uint16,
        address
    ) { 
        return (
            marginBurnRate,
            feeBurnRate,
            feeRewardsRate,
            feeTo
        );
    }

    function getMarginParams () external view returns (
        uint16,
        uint16
    ) {
        return (
            marginMaintenance,
            marginRewardRate
        );
    }
}

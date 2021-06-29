// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IOverlayV1Market.sol";
import "../OverlayToken.sol";

contract OverlayV1Factory is Ownable {

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
    uint16 public feeUpdateRewardsRate;
    // address to send fees to
    address public feeTo;
    // maintenance margin requirement
    uint16 public marginMaintenance;
    // maintenance margin reward rate on liquidations
    uint16 public marginRewardRate;
    // maintenance margin burn rate on liquidations
    uint16 public marginBurnRate;

    // whether is a market AND is enabled
    mapping(address => bool) public isMarket;
    // whether is an already created market: for easy access instead of looping through allMarkets
    mapping(address => bool) public marketExists;
    address[] public allMarkets;

    constructor(
        address _ovl,
        uint16 _fee,
        uint16 _feeBurnRate,
        uint16 _feeUpdateRewardsRate,
        address _feeTo,
        uint16 _marginMaintenance,
        uint16 _marginBurnRate,
        uint16 _marginRewardRate
    ) {
        // immutables
        ovl = _ovl;

        // global params
        fee = _fee;
        feeBurnRate = _feeBurnRate;
        feeUpdateRewardsRate = _feeUpdateRewardsRate;
        feeTo = _feeTo;
        marginMaintenance = _marginMaintenance;
        marginBurnRate = _marginBurnRate;
        marginRewardRate = _marginRewardRate;
    }

    /// @notice Initializes an existing market contract after deployment
    /// @dev Should be called after contract deployment in specific market factory.createMarket
    function initializeMarket(address market) internal {
        marketExists[market] = true;
        isMarket[market] = true;
        allMarkets.push(market);

        // Give market contract mint/burn priveleges for OVL
        OverlayToken(ovl).grantRole(OverlayToken(ovl).MINTER_ROLE(), market);
        OverlayToken(ovl).grantRole(OverlayToken(ovl).BURNER_ROLE(), market);
    }

    /// @notice Disables an existing market contract for a mirin market
    function disableMarket(address market) external onlyOwner {
        require(isMarket[market], "OverlayV1: !enabled");
        isMarket[market] = false;

        // Revoke mint/burn roles for the market
        OverlayToken(ovl).revokeRole(OverlayToken(ovl).MINTER_ROLE(), market);
        OverlayToken(ovl).revokeRole(OverlayToken(ovl).BURNER_ROLE(), market);
    }

    /// @notice Enables an existing market contract for a mirin market
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
        IOverlayV1Market(market).update(rewardsTo);
    }

    /// @notice Mass calls update functions on all markets
    function massUpdateMarkets(address rewardsTo) external {
        for (uint256 i=0; i < allMarkets.length; ++i) {
            IOverlayV1Market(allMarkets[i]).update(rewardsTo);
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
        IOverlayV1Market(market).adjustParams(
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
        uint16 _feeUpdateRewardsRate,
        address _feeTo,
        uint16 _marginMaintenance,
        uint16 _marginBurnRate,
        uint16 _marginRewardRate
    ) external onlyOwner {
        fee = _fee;
        feeBurnRate = _feeBurnRate;
        feeUpdateRewardsRate = _feeUpdateRewardsRate;
        feeTo = _feeTo;
        marginMaintenance = _marginMaintenance;
        marginBurnRate = _marginBurnRate;
        marginRewardRate = _marginRewardRate;
    }

    function getUpdateParams() external view returns (
        uint16,
        uint16,
        uint16,
        address
    ) {
        return (
            marginBurnRate,
            feeBurnRate,
            feeUpdateRewardsRate,
            feeTo
        );
    }

    function getMarginParams() external view returns (
        uint16,
        uint16
    ) {
        return (
            marginMaintenance,
            marginRewardRate
        );
    }
}

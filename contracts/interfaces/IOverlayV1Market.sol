// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "../libraries/Position.sol";

interface IOverlayV1Market is IERC1155 {
    event Build(uint256 positionId, uint256 oi, uint256 debt);
    event Unwind(uint256 positionId, uint256 oi, uint256 debt);
    event Update(
        address indexed rewarded,
        uint256 reward,
        uint256 feesCollected,
        uint256 feesBurned,
        uint256 liquidationsCollected,
        uint256 liquidationsBurned,
        uint256 fundingBurned
    );
    event Liquidate(address indexed rewarded, uint256 reward);

    function ovl() external view returns (address);
    function factory() external view returns (address);

    function updatePeriod() external view returns (uint256);
    function leverageMax() external view returns (uint8);
    function marginAdjustment() external view returns (uint16);
    function oiCap() external view returns (uint256);
    function fundingKNumerator() external view returns (uint256);
    function fundingKDenominator() external view returns (uint256);
    function adjustParams(uint256, uint8, uint16, uint144, uint112, uint112) external view;
    function updateBlockLast() external view returns (uint256);
    function MAX_FUNDING_COMPOUND() external view returns (uint16);

    function fees() external view returns (uint256);
    function queuedOiLong() external view returns (uint256);
    function queuedOiShort() external view returns (uint256);
    function oiLong() external view returns (uint256);
    function oiShort() external view returns (uint256);

    function positions(uint256) external view returns (Position.Info memory);
    function uri(uint256) external view returns (string memory);

    function update(address) external;
    function build(uint256, bool, uint256, address) external;
    function unwind(uint256, uint256, address) external;
    function liquidatable(uint256) external;
    function liquidate(uint256, address) external;

    function pricePointCurrentIndex() external view returns (uint256);
    function pricePointIndexes(uint256) external view returns (uint256);
    function pricePoints(uint256) external view returns (uint256);
}

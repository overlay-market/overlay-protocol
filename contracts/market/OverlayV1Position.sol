// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import "../libraries/Position.sol";
import "./OverlayV1PricePoint.sol";

contract OverlayV1Position is ERC1155, OverlayV1PricePoint {
    using Position for Position.Info;

    // array of pos attributes; id is index in array
    Position.Info[] public positions;

    // mapping from position (erc1155) id to total shares issued of position
    mapping(uint256 => uint256) public totalPositionShares;

    // mapping from leverage to index in positions array of queued position; queued can still be built on while updatePeriod elapses
    mapping(uint256 => uint256) private queuedPositionLongIds;
    mapping(uint256 => uint256) private queuedPositionShortIds;

    constructor(string memory _uri) ERC1155(_uri) {

        positions.push(Position.Info({
            isLong: false,
            leverage: 0,
            pricePoint: 0,
            oiShares: 0,
            debt: 0,
            cost: 0
        }));

    }

    /// @notice Mint overrides erc1155 _mint to track total shares issued for given position id
    function mint(address account, uint256 id, uint256 shares, bytes memory data) internal {
        totalPositionShares[id] += shares;
        _mint(account, id, shares, data);
    }

    /// @notice Burn overrides erc1155 _burn to track total shares issued for given position id
    function burn(address account, uint256 id, uint256 shares) internal {
        uint256 totalShares = totalPositionShares[id];
        require(totalShares >= shares, "OverlayV1: burn shares exceeds total");
        totalPositionShares[id] = totalShares - shares;
        _burn(account, id, shares);
    }

    /// @notice Updates position queue for T+1 price settlement
    function getQueuedPosition(
        bool isLong, 
        uint256 leverage
    ) internal returns (
        Position.Info storage position,
        uint256 queuedPositionId
    ) {
        
        mapping(uint256 => uint256) storage queuedPositionIds = (
            isLong ? queuedPositionLongIds : queuedPositionShortIds
        );

        position = positions[queuedPositionId];
        queuedPositionId = queuedPositionIds[leverage];
        uint pricePointCurrentIndex = pricePoints.length;

        if (position.pricePoint < pricePointCurrentIndex) {
            // prior update window for this queued position has passed
            positions.push(Position.Info({
                isLong: isLong,
                leverage: leverage,
                pricePoint: pricePointCurrentIndex,
                oiShares: 0,
                debt: 0,
                cost: 0
            }));
            queuedPositionId = positions.length - 1;
            queuedPositionIds[leverage] = queuedPositionId;
        }

    }
}

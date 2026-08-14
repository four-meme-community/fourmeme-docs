// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ITaxToken} from "./ITaxToken.sol";

/// @title Classic Four.Meme New TaxToken / token8 lite interface (creator type 8)
/// @notice Extends TaxToken with separate buy/sell tax rates.
/// @dev Identify via TokenManager2 `_tokenInfos(token).template`:
///      `creatorType = (template >> 10) & 0x3F`; type `8` is token8.
///      Off-chain API marker: token `version == "V9"`.
///      Tax also applies during bonding-curve trading before migration.
///      Prefer `feeRateBuy` / `feeRateSell` over deprecated `feeRate`.
interface ITaxToken8 is ITaxToken {
    /// @notice Buy-side tax rate as a percentage (e.g. `3` = 3%), applied as `amount * feeRateBuy / 100`.
    function feeRateBuy() external view returns (uint256);

    /// @notice Sell-side tax rate as a percentage (e.g. `5` = 5%), applied as `amount * feeRateSell / 100`.
    function feeRateSell() external view returns (uint256);
}

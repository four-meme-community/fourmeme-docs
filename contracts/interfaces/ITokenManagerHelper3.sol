// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Classic Four.Meme TokenManagerHelper3 lite interface
/// @notice Unified helper for token info, buy/sell estimates, V1/V2 routing, and BNB wrappers
///         for ERC20-quote pairs.
/// @dev Recommended first hop for wallets and aggregators: call `getTokenInfo` then `tryBuy`/`trySell`.
interface ITokenManagerHelper3 {
    /// @notice V1 TokenManager address.
    function TOKEN_MANAGER() external view returns (address);

    /// @notice V2 TokenManager2 address.
    function TOKEN_MANAGER_2() external view returns (address);

    /// @notice Alias of `TOKEN_MANAGER`.
    function TM() external view returns (address);

    /// @notice Alias of `TOKEN_MANAGER_2`.
    function TM2() external view returns (address);

    /// @notice Wrapped native token (WBNB / WETH depending on chain).
    function WETH() external view returns (address);

    /// @notice Returns manager version and live bonding-curve state for a token.
    /// @param token Token address
    /// @return version `1` = trade via V1 methods; `2` = trade via V2 methods
    /// @return tokenManager Canonical manager for that version
    /// @return quote Quote asset; `address(0)` means native BNB
    /// @return lastPrice Last observed price
    /// @return tradingFeeRate Fee rate numerator; divide by 10000 for the actual rate
    /// @return minTradingFee Minimum trading fee amount
    /// @return launchTime Launch timestamp
    /// @return offers Remaining tokens for sale on the curve
    /// @return maxOffers Max tokens sellable before migration. V1 uses a Helper constant
    /// @return funds Raised quote amount so far
    /// @return maxFunds Max raise amount. V1 uses a Helper constant
    /// @return liquidityAdded True if migrated (`status == COMPLETED` on V2)
    function getTokenInfo(address token)
        external
        view
        returns (
            uint256 version,
            address tokenManager,
            address quote,
            uint256 lastPrice,
            uint256 tradingFeeRate,
            uint256 minTradingFee,
            uint256 launchTime,
            uint256 offers,
            uint256 maxOffers,
            uint256 funds,
            uint256 maxFunds,
            bool liquidityAdded
        );

    /// @notice Estimates a buy. Pass either `amount` or `funds` (the other as 0).
    /// @param token Token to buy
    /// @param amount Desired token amount; `0` if using budget mode
    /// @param funds Desired quote budget; `0` if using fixed-amount mode
    /// @return tokenManager Manager to call for the real trade
    /// @return quote Quote asset (`address(0)` = native)
    /// @return estimatedAmount Estimated tokens out
    /// @return estimatedCost Estimated gross curve quote cost
    /// @return estimatedFee Estimated protocol trading fee (AntiSniper may include base+extra)
    /// @return amountMsgValue Suggested `msg.value` for the trade call
    /// @return amountApproval Suggested ERC20 quote approval amount when quote != 0
    /// @return amountFunds Suggested `funds` argument for AMAP buys
    function tryBuy(address token, uint256 amount, uint256 funds)
        external
        view
        returns (
            address tokenManager,
            address quote,
            uint256 estimatedAmount,
            uint256 estimatedCost,
            uint256 estimatedFee,
            uint256 amountMsgValue,
            uint256 amountApproval,
            uint256 amountFunds
        );

    /// @notice Estimates a sell of `amount` tokens.
    /// @param token Token to sell
    /// @param amount Token amount to sell
    /// @return tokenManager Manager to call for the real trade
    /// @return quote Quote asset (`address(0)` = native BNB)
    /// @return funds Estimated net quote to the seller: `curveGross - protocolFee - token8SellTax`.
    /// Does not subtract third-party router `feeRate` cuts. Token8 tax is removed here but not included in `fee`.
    /// @return fee Protocol trading fee only (not TaxToken8 tax, not router cut)
    function trySell(address token, uint256 amount)
        external
        view
        returns (address tokenManager, address quote, uint256 funds, uint256 fee);

    /// @notice Utility to display an initial price from launch parameters.
    /// @param maxRaising Max raise amount
    /// @param totalSupply Total supply
    /// @param offers Tokens offered for sale
    /// @param reserves Reserved tokens
    /// @return priceWei Initial price in wei units
    function calcInitialPrice(uint256 maxRaising, uint256 totalSupply, uint256 offers, uint256 reserves)
        external
        pure
        returns (uint256 priceWei);

    /// @notice Buy an ERC20-quote token by paying native BNB (auto-wraps/swaps into quote).
    /// @dev Only for pairs where `quote != address(0)`. Not for native BNB bonding-curve pairs.
    /// @param origin Pass `0`
    /// @param to Recipient; `address(0)` means `msg.sender`
    /// @param funds BNB amount to spend
    /// @param minAmount Minimum meme tokens to receive
    function buyWithEth(uint256 origin, address token, address to, uint256 funds, uint256 minAmount)
        external
        payable;

    /// @notice Sell an ERC20-quote token and receive native BNB, with optional router fee.
    /// @dev Only for `quote != address(0)`. Router fee is taken in the quote ERC20, not in BNB.
    /// @param origin Pass `0`
    /// @param token Token to sell
    /// @param amount Token amount to sell
    /// @param minFunds Minimum **final BNB** out after quote→BNB swap; uses `amountEth > minFunds` (not `>=`).
    /// Differs from TokenManager2.sellToken `minFunds`, which compares gross curve quote.
    /// @param feeRate Router fee rate; `100` = 1%, max 5%
    /// @param feeRecipient Address receiving the router fee in quote tokens
    function sellForEth(
        uint256 origin,
        address token,
        uint256 amount,
        uint256 minFunds,
        uint256 feeRate,
        address feeRecipient
    ) external;

    /// @notice Router sell-for-BNB path; requires `tx.origin == from`.
    /// @param minFunds Same meaning as the overload above: final BNB out, not gross curve quote
    function sellForEth(
        uint256 origin,
        address token,
        address from,
        uint256 amount,
        uint256 minFunds,
        uint256 feeRate,
        address feeRecipient
    ) external;

    /// @notice Sell for BNB and send proceeds to a different `to` recipient.
    /// @param minFunds Same meaning as the overload above: final BNB out, not gross curve quote
    function sellForEth(
        uint256 origin,
        address token,
        address from,
        address to,
        uint256 amount,
        uint256 minFunds
    ) external;
}

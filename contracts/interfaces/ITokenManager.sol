// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Classic Four.Meme TokenManager (V1) lite interface
/// @notice Integration surface for trading tokens created before 2024-09-05.
/// @dev New launches use TokenManager2. Prefer TokenManagerHelper3.getTokenInfo to resolve
///      version and the canonical manager address before calling these methods.
interface ITokenManager {
    /// @notice Emitted when a V1 token is created.
    /// @param creator Token creator
    /// @param token Created token address
    /// @param requestId Off-chain / platform request id
    /// @param name Token name
    /// @param symbol Token symbol
    /// @param totalSupply Total supply
    /// @param launchTime Launch timestamp
    /// @param launchFee Launch fee paid at creation
    event TokenCreate(
        address creator,
        address token,
        uint256 requestId,
        string name,
        string symbol,
        uint256 totalSupply,
        uint256 launchTime,
        uint256 launchFee
    );

    /// @notice Emitted on a successful buy.
    /// @param token Token purchased
    /// @param account Buyer / recipient
    /// @param tokenAmount Tokens received
    /// @param etherAmount BNB spent
    event TokenPurchase(address token, address account, uint256 tokenAmount, uint256 etherAmount);

    /// @notice Emitted on a successful sell.
    /// @param token Token sold
    /// @param account Seller
    /// @param tokenAmount Tokens sold
    /// @param etherAmount BNB received
    event TokenSale(address token, address account, uint256 tokenAmount, uint256 etherAmount);

    /// @notice Emitted when bonding-curve trading for a token is stopped (e.g. after migration).
    /// @param token Token whose internal trading stopped
    event TradeStop(address token);

    /// @notice Buy tokens by spending a fixed BNB budget (AMAP) to `msg.sender`.
    /// @param token Token to buy
    /// @param funds BNB amount to spend
    /// @param minAmount Minimum tokens to receive (slippage protection)
    function purchaseTokenAMAP(address token, uint256 funds, uint256 minAmount) external payable;

    /// @notice Buy a fixed token amount for `msg.sender`.
    /// @param token Token to buy
    /// @param amount Exact token amount to buy
    /// @param maxFunds Maximum BNB to spend (slippage protection)
    function purchaseToken(address token, uint256 amount, uint256 maxFunds) external payable;

    /// @notice Buy tokens by spending a fixed BNB budget to a specific recipient.
    /// @param origin Pass `0` for third-party integrations
    /// @param token Token to buy
    /// @param to Recipient of purchased tokens
    /// @param funds BNB amount to spend
    /// @param minAmount Minimum tokens to receive
    function purchaseTokenAMAP(uint256 origin, address token, address to, uint256 funds, uint256 minAmount)
        external
        payable;

    /// @notice Buy a fixed token amount for a specific recipient.
    /// @param origin Pass `0` for third-party integrations
    /// @param token Token to buy
    /// @param to Recipient of purchased tokens
    /// @param amount Exact token amount to buy
    /// @param maxFunds Maximum BNB to spend
    function purchaseToken(uint256 origin, address token, address to, uint256 amount, uint256 maxFunds)
        external
        payable;

    /// @notice Sell tokens for BNB. Caller must `approve` this manager first.
    /// @param token Token to sell
    /// @param amount Token amount to sell
    function saleToken(address token, uint256 amount) external;
}

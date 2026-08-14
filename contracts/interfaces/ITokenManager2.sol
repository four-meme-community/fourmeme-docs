// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Classic Four.Meme TokenManager2 (V2) lite interface
/// @notice Integration surface for creating and trading tokens launched on/after 2024-09-05.
/// @dev Supports BNB pairs (`quote == address(0)`) and BEP20 quote pairs. Prefer
///      TokenManagerHelper3 for routing and estimates before submitting trades.
interface ITokenManager2 {
    /// @notice On-chain runtime info for a managed token.
    /// @dev `quote == address(0)` means the bonding curve uses native BNB.
    ///      `template` packs creator-type and fee-plan flags used for identification.
    struct TokenInfo {
        address base;
        address quote;
        uint256 template;
        uint256 totalSupply;
        uint256 maxOffers;
        uint256 maxRaising;
        uint256 launchTime;
        uint256 offers;
        uint256 funds;
        uint256 lastPrice;
        uint256 K;
        uint256 T;
        uint256 status;
    }

    /// @notice Extended per-token fields used by fee-plan / anti-sniper identification.
    /// @dev `feeSetting > 0` indicates AntiSniperFeeMode is enabled.
    struct TokenInfoEx1 {
        uint256 launchFee;
        uint256 pcFee;
        uint256 feeSetting;
        uint256 blockNumber;
        uint256 extraFee;
    }

    /// @notice Emitted when a V2 token is created.
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

    /// @notice Emitted on a successful V2 buy.
    /// @param account Token recipient (`to`), not necessarily `msg.sender`
    /// @param price `lastPrice` after the trade updates curve state
    /// @param amount Tokens purchased
    /// @param cost Gross curve quote (excludes protocol fee)
    /// @param fee Protocol base trading fee only (AntiSniper `extraFee` is not included here)
    /// @param offers Remaining offers after the trade
    /// @param funds Cumulative raised funds after the trade
    event TokenPurchase(
        address token,
        address account,
        uint256 price,
        uint256 amount,
        uint256 cost,
        uint256 fee,
        uint256 offers,
        uint256 funds
    );

    /// @notice Emitted on a successful V2 sell.
    /// @param account Seller (`from`)
    /// @param price `lastPrice` after the trade updates curve state
    /// @param cost Gross curve quote before protocol fee / router cut
    /// @param fee Protocol trading fee only
    event TokenSale(
        address token,
        address account,
        uint256 price,
        uint256 amount,
        uint256 cost,
        uint256 fee,
        uint256 offers,
        uint256 funds
    );

    /// @notice Emitted when bonding-curve trading stops for a token.
    event TradeStop(address token);

    /// @notice Emitted when liquidity is added / migration completes.
    /// @param offers Token amount added to LP (`amountTokenDesired`), not remaining curve offers
    /// @param quote Quote asset of the migrated pool; `address(0)` means BNB
    event LiquidityAdded(address base, uint256 offers, address quote, uint256 funds);

    /// @notice Reads runtime token info used for routing and mode identification.
    /// @param token Token address
    function _tokenInfos(address token) external view returns (TokenInfo memory);

    /// @notice Reads extended token info (including AntiSniperFeeMode `feeSetting`).
    /// @param token Token address
    function _tokenInfoEx1s(address token) external view returns (TokenInfoEx1 memory);

    /// @notice Buy by spending a fixed quote budget to `msg.sender`.
    /// @param token Token to buy
    /// @param funds Quote amount to spend
    /// @param minAmount Minimum tokens to receive
    function buyTokenAMAP(address token, uint256 funds, uint256 minAmount) external payable;

    /// @notice Buy by spending a fixed quote budget to `to`.
    function buyTokenAMAP(address token, address to, uint256 funds, uint256 minAmount) external payable;

    /// @notice Buy a fixed token amount for `msg.sender`.
    /// @param amount Exact token amount
    /// @param maxFunds Maximum quote to spend (compared to gross curve cost)
    function buyToken(address token, uint256 amount, uint256 maxFunds) external payable;

    /// @notice Buy a fixed token amount for `to`.
    function buyToken(address token, address to, uint256 amount, uint256 maxFunds) external payable;

    /// @notice Sell tokens. Caller must `approve` this manager first.
    function sellToken(address token, uint256 amount) external;

    /// @notice Sell with an optional third-party router fee.
    /// @param origin Pass `0`
    /// @param minFunds Minimum **gross** curve quote (`calcSellCost`); not net proceeds after fees
    /// @param feeRate Router fee rate; `100` = 1%, `10` = 0.1%, max 5% (`cut = funds * feeRate / 10000`)
    /// @param feeRecipient Address receiving the router fee
    function sellToken(
        uint256 origin,
        address token,
        uint256 amount,
        uint256 minFunds,
        uint256 feeRate,
        address feeRecipient
    ) external;

    /// @notice Router sell path where `tx.origin` must equal `from`.
    /// @param from Token owner / original sender
    function sellToken(
        uint256 origin,
        address token,
        address from,
        uint256 amount,
        uint256 minFunds,
        uint256 feeRate,
        address feeRecipient
    ) external;

    /// @notice Create a token using backend-signed `createArg` / `signature` from the create API.
    /// @param args `createArg` bytes from Four.Meme create API
    /// @param signature Backend signature from Four.Meme create API
    function createToken(bytes calldata args, bytes calldata signature) external payable;
}

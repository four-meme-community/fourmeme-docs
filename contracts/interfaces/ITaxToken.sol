// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Classic Four.Meme TaxToken lite interface (creator type 5)
/// @notice Public tax configuration, holder reward accounting, and claim surface.
/// @dev Identify via TokenManager2 `_tokenInfos(token).template`:
///      `creatorType = (template >> 10) & 0x3F`; type `5` is TaxToken.
///      Transfer modes: `0` NORMAL, `1` TRANSFER_RESTRICTED, `2` TRANSFER_CONTROLLED.
interface ITaxToken {
    /// @notice Emitted when accumulated tax is dispatched to allocation buckets.
    /// @param amountFounder Token amount allocated to founder
    /// @param amountHolder Token amount allocated to holders
    /// @param amountBurn Token amount burned
    /// @param amountLiquidity Token amount sent to liquidity
    /// @param quoteFounder Quote amount allocated to founder this dispatch
    /// @param quoteHolder Quote amount allocated to holders this dispatch
    event FeeDispatched(
        uint256 amountFounder,
        uint256 amountHolder,
        uint256 amountBurn,
        uint256 amountLiquidity,
        uint256 quoteFounder,
        uint256 quoteHolder
    );

    /// @notice Emitted when a user claims quote rewards.
    /// @param account Claimer
    /// @param amount Quote amount claimed
    event FeeClaimed(address account, uint256 amount);

    /// @notice Current transfer mode (`0`/`1`/`2`).
    function _mode() external view returns (uint256);

    /// @notice Quote token used for rewards (BNB raises typically use WETH here).
    function quote() external view returns (address);

    /// @notice Pancake V2 pair address (lazy-initialized when mode becomes NORMAL).
    function pair() external view returns (address);

    /// @notice Founder address receiving founder allocation.
    function founder() external view returns (address);

    /// @notice Trade tax rate in basis points (`10000 = 100%`), applied as `amount * feeRate / 10000`.
    function feeRate() external view returns (uint256);

    /// @notice Founder allocation rate (percent; sum of rates must be 100).
    function rateFounder() external view returns (uint256);

    /// @notice Holder allocation rate (percent).
    function rateHolder() external view returns (uint256);

    /// @notice Burn allocation rate (percent).
    function rateBurn() external view returns (uint256);

    /// @notice Liquidity allocation rate (percent).
    function rateLiquidity() external view returns (uint256);

    /// @notice Minimum accumulated fee before a dispatch runs.
    function minDispatch() external view returns (uint256);

    /// @notice Minimum token balance (wei) required to participate in holder rewards.
    function minShare() external view returns (uint256);

    /// @notice Per-account reward accounting snapshot.
    /// @return share Current reward share (`0` if balance below `minShare`)
    /// @return rewardDebt Internal reward debt
    /// @return claimable Stored claimable quote amount
    /// @return claimed Cumulative claimed quote amount
    function userInfo(address account)
        external
        view
        returns (uint256 share, uint256 rewardDebt, uint256 claimable, uint256 claimed);

    /// @notice Sum of all eligible holder shares.
    function totalShares() external view returns (uint256);

    /// @notice Cumulative reward-per-share accumulator.
    function feePerShare() external view returns (uint256);

    /// @notice Fees accumulated but not yet fully dispatched (may retain rounding dust).
    function feeAccumulated() external view returns (uint256);

    /// @notice Total fees dispatched so far.
    function feeDispatched() external view returns (uint256);

    /// @notice Total fees allocated to founder.
    function feeFounder() external view returns (uint256);

    /// @notice Total fees allocated to holders.
    function feeHolder() external view returns (uint256);

    /// @notice Quote amount currently claimable by `account` (stored + newly accrued).
    function claimableFee(address account) external view returns (uint256);

    /// @notice Quote amount already claimed by `account`.
    function claimedFee(address account) external view returns (uint256);

    /// @notice Claim accrued quote rewards to `msg.sender`.
    /// @dev Reverts or no-ops for blacklisted accounts / zero claimable amounts per token rules.
    function claimFee() external;

    /// @notice Claim accrued quote rewards **for other accounts** (or a batch including self).
    /// @dev Anyone may call this; each account still receives its own quote rewards.
    /// Blacklisted accounts are skipped. Useful for keepers / helpers claiming on behalf of holders.
    /// @param accounts Addresses to claim for
    function claimFee(address[] calldata accounts) external;

    /// @notice Number of addresses recorded in the internal `_users` list.
    /// @dev Only addresses that have had a share update (`newShare != curShare`) are appended.
    /// This is not necessarily equal to the count of all token holders.
    function userCount() external view returns (uint256);

    /// @notice Paginated read of the `_users` list, with optional claimable filter.
    /// @param index Start index in `_users`
    /// @param count Number of slots to return (array length is always `count`)
    /// @param minClaimable Minimum `claimableFee`; `0` disables the filter.
    /// Addresses below the threshold are replaced with `0xdEaD`. Out-of-range slots are `address(0)`.
    /// @return User addresses for this page
    function users(uint256 index, uint256 count, uint256 minClaimable)
        external
        view
        returns (address[] memory);

    /// @notice Owner-only transfer mode update.
    /// @param v Target mode: `0` NORMAL, `1` RESTRICTED, `2` CONTROLLED.
    /// @dev Once `_mode` is NORMAL, further changes are ignored.
    function setMode(uint256 v) external;
}

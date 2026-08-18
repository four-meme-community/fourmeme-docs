// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Classic Four.Meme TaxToken9 lite interface (creator type 9)
/// @notice Public tax configuration, charity accounting, holder rewards, and claims.
/// @dev Identify authoritatively via TokenManager2 `_tokenInfos(token).template`:
///      `creatorType = (template >> 10) & 0x3F`; type `9` is TaxToken9.
interface ITaxToken9 {
    /// @notice Emitted when accumulated quote tax is allocated.
    /// @dev The final two fields are charity amounts, unlike TaxToken8 where they are quoteFounder/quoteHolder.
    event FeeDispatched(
        uint256 amountFounder,
        uint256 amountHolder,
        uint256 amountBurn,
        uint256 amountLiquidity,
        uint256 amountGiggleCharity,
        uint256 amountBinanceCharity
    );

    event FeeClaimed(address account, uint256 amount);
    event FeeInsufficient(address account, uint256 claimable, uint256 balance);

    function _mode() external view returns (uint256);
    function quote() external view returns (address);
    function pair() external view returns (address);
    function founder() external view returns (address);
    function charityHelper() external view returns (address);

    /// @notice Deprecated compatibility getter; use feeRateBuy/feeRateSell.
    function feeRate() external view returns (uint256);
    function feeRateBuy() external view returns (uint256);
    function feeRateSell() external view returns (uint256);

    function rateFounder() external view returns (uint256);
    function rateHolder() external view returns (uint256);
    function rateBurn() external view returns (uint256);
    function rateLiquidity() external view returns (uint256);
    function rateGiggleCharity() external view returns (uint256);
    function rateBinanceCharity() external view returns (uint256);
    function minDispatch() external view returns (uint256);
    function minShare() external view returns (uint256);

    function userInfo(address account)
        external
        view
        returns (
            uint256 share,
            uint256 rewardDebt,
            uint256 claimable,
            uint256 claimed,
            bool exists
        );

    function totalShares() external view returns (uint256);
    function feePerShare() external view returns (uint256);
    function feeAccumulated() external view returns (uint256);
    function feeToFounder() external view returns (uint256);
    function feeToBurn() external view returns (uint256);
    function feeToLiquidity() external view returns (uint256);
    function feeToGiggleCharity() external view returns (uint256);
    function feeToBinanceCharity() external view returns (uint256);
    function feeDispatched() external view returns (uint256);
    function feeFounder() external view returns (uint256);
    function feeHolder() external view returns (uint256);
    function feeBurned() external view returns (uint256);
    function feeLiquidity() external view returns (uint256);
    function feeGiggleCharity() external view returns (uint256);
    function feeBinanceCharity() external view returns (uint256);
    function feeClaimed() external view returns (uint256);
    function tokenAccumulated() external view returns (uint256);
    function tokenBurned() external view returns (uint256);

    function claimableFee(address account) external view returns (uint256);
    function claimedFee(address account) external view returns (uint256);
    function claimFee() external;
    function claimFee(address[] calldata accounts) external;

    function userCount() external view returns (uint256);
    function users(uint256 index, uint256 count, uint256 minClaimable)
        external
        view
        returns (address[] memory);

    function setMode(uint256 v) external;
}

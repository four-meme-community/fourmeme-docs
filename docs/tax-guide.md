# Four.Meme Classic Tax Integration

This guide covers TaxToken (creator type 5) and New TaxToken / token8 (creator type 8): how to identify them, read public tax state, claim holder rewards, and monitor fee events.

See also:

- [Integration Guide](./integration-guide.md)
- [Trade Integration](./trade-guide.md)
- [Create Integration](./create-guide.md) — `tokenTaxInfo` at creation time

Lite artifacts:

- ABI: [`../abi/TaxToken.lite.json`](../abi/TaxToken.lite.json), [`../abi/TaxToken8.lite.json`](../abi/TaxToken8.lite.json)
- Interfaces: [`../contracts/interfaces/ITaxToken.sol`](../contracts/interfaces/ITaxToken.sol), [`../contracts/interfaces/ITaxToken8.sol`](../contracts/interfaces/ITaxToken8.sol)

Bonding-curve trading still goes through TokenManager2 / Helper3. This guide only covers the **token contract** tax/reward surface.

## 1. What Is a Tax Token

Tax tokens are ERC20s with:

- Transfer tax on buy/sell (and for token8, also during bonding-curve trading)
- Allocation of tax to founder / holders / burn / liquidity
- Holder reward claims in the quote asset

Two generations:

| Kind | Creator type | Notes |
|------|--------------|-------|
| TaxToken | `5` | Single on-chain `feeRate` in **basis points** (`/ 10000`) |
| New TaxToken (token8) | `8` | Separate `feeRateBuy` / `feeRateSell` in **percent** (`/ 100`). Curve phase: quote-side tax in TokenManager; after migration: token transfer tax on the pair |

token8 verified source/ABI example on BscScan: https://bscscan.com/token/0x77c4206fab7dc2e18501bf5bed3fb82d453effff#code

## 2. Identification

### 2.1 On-chain (both generations)

```solidity
TokenInfo memory ti = ITokenManager2(tm2)._tokenInfos(token);
uint256 creatorType = (ti.template >> 10) & 0x3F;

if (creatorType == 5) {
    // TaxToken
} else if (creatorType == 8) {
    // New TaxToken (token8)
}
```

`ITokenManager2` / `_tokenInfos` live under [`../contracts/interfaces/ITokenManager2.sol`](../contracts/interfaces/ITokenManager2.sol).

### 2.2 Off-chain

Query:

- `https://four.meme/meme-api/v1/private/token/get/v2?address={token}`
- or `.../getById?id={requestId}`

| Signal | Meaning |
|--------|---------|
| `data.taxInfo` present | Tax-type token (classic TaxToken family) |
| `data.version == "V9"` | New TaxToken (token8) |
| `taxInfo.feeRate` | Create/API percentage for TaxToken buy/sell tax (type 5) or token8 buy tax |
| `taxInfo.feeRateSell` | token8 sell tax percentage |

Example token8 payload:

```json
{
  "code": "0",
  "data": {
    "version": "V9",
    "taxInfo": {
      "feeRate": 3,
      "feeRateSell": 5,
      "recipientRate": 100,
      "burnRate": 0,
      "divideRate": 0,
      "liquidityRate": 0,
      "recipientAddress": "0xB1E3F988667Dc313BB2D11285610630825c0dbc7",
      "minSharing": 0,
      "m": 0,
      "e": 0,
      "version": 1
    }
  }
}
```

Classic TaxToken `taxInfo` uses a single `feeRate` (API percentage options `1`/`3`/`5`/`10`) plus allocation fields (`burnRate`, `divideRate`, `liquidityRate`, `recipientRate`, `minSharing`, `recipientAddress`). Allocation rates must sum to 100. On-chain, type-5 `feeRate` is stored/applied as basis points (`amount * feeRate / 10000`); `divideRate` maps to holder allocation (`rateHolder`).

## 3. Transfer Modes

| Name | Value | Meaning |
|------|-------|---------|
| `MODE_NORMAL` | `0` | Normal transfers |
| `MODE_TRANSFER_RESTRICTED` | `1` | All transfers revert |
| `MODE_TRANSFER_CONTROLLED` | `2` | Only transfers where `from` or `to` is `owner()` |

```solidity
function _mode() external view returns (uint256);
function setMode(uint256 v) external; // owner only
```

Once `_mode` is `MODE_NORMAL`, it cannot be changed (including after DEX migration).

## 4. Public Configuration (TaxToken)

| Getter | Meaning |
|--------|---------|
| `quote` | Quote token used for rewards (for BNB raises this is typically WETH, not `address(0)`) |
| `pair` | Pancake V2 pair (lazy-init via `getPair(token, quote)` when mode is NORMAL) |
| `founder` | Founder reward recipient |
| `feeRate` | On-chain trade tax in **basis points** (`10000 = 100%`). Applied as `amount * feeRate / 10000` on pair buys/sells |
| `rateFounder` / `rateHolder` / `rateBurn` / `rateLiquidity` | Allocation percentages; sum must be 100 |
| `minDispatch` | Minimum accumulated fee before dispatch |
| `minShare` | Minimum token balance (wei) to participate in holder rewards |

Reward accounting getters commonly used by UIs:

- `userInfo(account) -> (share, rewardDebt, claimable, claimed)`
- `totalShares`, `feePerShare`, `feeAccumulated`, `feeDispatched`
- `feeFounder`, `feeHolder`

## 5. New TaxToken (token8) Differences

Same claim / mode / allocation surface as TaxToken, plus:

```solidity
function feeRateBuy() external view returns (uint256);
function feeRateSell() external view returns (uint256);
function feeRate() external view returns (uint256); // deprecated compatibility field
```

- `feeRateBuy` / `feeRateSell` are **percentages** (`3` = 3%), applied as `amount * rate / 100` on post-migration pair transfers
- Max documented on-chain bound is `<= 10`
- During bonding-curve trading (before migration), token8 tax is taken in **quote** by TokenManager (`curveGross * rate / 100` via `sendFee`), not via ERC20 transfer tax
- Prefer `feeRateBuy` / `feeRateSell` over deprecated `feeRate`

## 6. Claims

### Read

```solidity
function claimableFee(address account) external view returns (uint256);
function claimedFee(address account) external view returns (uint256);
```

`claimableFee` includes stored `claimable` plus newly accrued rewards from `share` and `feePerShare`.

### Write

```solidity
function claimFee() external;
function claimFee(address[] calldata accounts) external;
```

| Method | Who can call | Who receives rewards |
|--------|--------------|----------------------|
| `claimFee()` | Any holder | `msg.sender` only |
| `claimFee(accounts)` | **Anyone** (third party / keeper / helper) | Each address in `accounts` receives its own claimable quote |

`claimFee(accounts)` is the path to **claim on behalf of others**: the caller does not take the rewards; quote tokens are transferred to each listed account. Blacklisted accounts are skipped. Zero-claimable accounts are no-ops.

Effects per claimed account:

1. Refresh share accounting
2. Transfer claimable quote tokens **to that account**
3. Update claimed counters
4. Emit `FeeClaimed(account, amount)`

Requirements per account:

- Account not blacklisted for claims
- Claimable amount > 0

Addresses below `minShare` have `share == 0` and do not accrue holder rewards.

### User list queries

For UIs or keepers that need to scan holders with pending rewards:

```solidity
function userCount() external view returns (uint256);
function users(uint256 index, uint256 count, uint256 minClaimable)
    external
    view
    returns (address[] memory);
```

| Item | Meaning |
|------|---------|
| `userCount()` | Length of the internal `_users` array |
| `index` | Start offset in `_users` |
| `count` | Page size; return array length is always `count` |
| `minClaimable` | If `> 0`, filter by `claimableFee`; entries below threshold become `0xdEaD`. `0` disables filtering |
| Out of range | Slots past `userCount` are `address(0)` |

Notes:

- `_users` only appends addresses when their share actually changes (`newShare != curShare`). It is **not** a complete holder census.
- Skip `address(0)` and `0xdEaD` when consuming a page.
- Typical helper/keeper loop: page with `users(i, pageSize, minClaimable)` → collect non-sentinel addresses → `claimFee(accounts)` to claim **on behalf of those holders** (rewards still go to each holder, not to the caller).

```typescript
const DEAD = "0x000000000000000000000000000000000000dEaD";
const pageSize = 100n;
const total = await token.userCount();

for (let i = 0n; i < total; i += pageSize) {
  const page: string[] = await token.users(i, pageSize, minClaimable);
  const accounts = page.filter(
    (a) => a !== ethers.ZeroAddress && a.toLowerCase() !== DEAD.toLowerCase()
  );
  if (accounts.length > 0) {
    await token.claimFee(accounts);
  }
}
```

## 7. Events

```solidity
event FeeDispatched(
    uint256 amountFounder,
    uint256 amountHolder,
    uint256 amountBurn,
    uint256 amountLiquidity,
    uint256 quoteFounder,
    uint256 quoteHolder
);

event FeeClaimed(address account, uint256 amount);
```

Indexers should watch these on each tax token address (not on TokenManager).

## 8. Example Usage

```typescript
const token = new Contract(tokenAddress, TaxToken8Abi, signer);

const creatorType = /* from TokenManager2._tokenInfos(token).template bits */;
const abi = creatorType === 8n ? TaxToken8Abi : TaxTokenAbi;

const claimable = await token.claimableFee(user);
const claimed = await token.claimedFee(user);
const info = await token.userInfo(user);

if (claimable > 0n) {
  await token.claimFee();
}

// Optional: enumerate users with pending rewards
const n = await token.userCount();
const page = await token.users(0n, 50n, 0n);
```

Monitor distribution:

```typescript
token.on("FeeDispatched", (amountFounder, amountHolder, amountBurn, amountLiquidity, quoteFounder, quoteHolder) => {
  // update UI / indexer
});
```

## 9. Integration Notes

1. `rateFounder + rateHolder + rateBurn + rateLiquidity == 100`.
2. Blacklisted addresses cannot claim even if `claimableFee` appears positive.
3. `feeAccumulated` may retain a small remainder after dispatch due to rounding.
4. Creation-time `tokenTaxInfo` rules are documented in [Create Integration](./create-guide.md#34-tokentaxinfo).
5. `userCount` / `users` cover share-updated accounts only; do not treat them as a full holder list.
6. `claimFee(accounts)` lets a third party claim **for** holders; rewards are paid to each account, not the caller.
7. Do not publish or rely on internal tax-swap helper algorithms; use the public getters, claims, and events above.

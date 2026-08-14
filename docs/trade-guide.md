# Four.Meme Classic Trade Integration

This guide covers buying, selling, estimates, events, errors, and token-mode identification for classic Four.Meme.

See also:

- [Integration Guide](./integration-guide.md) — addresses and V1/V2 overview
- [Create Integration](./create-guide.md)
- [Tax Integration](./tax-guide.md)

Lite artifacts:

- ABI: [`../abi/TokenManager.lite.json`](../abi/TokenManager.lite.json), [`../abi/TokenManager2.lite.json`](../abi/TokenManager2.lite.json), [`../abi/TokenManagerHelper3.lite.json`](../abi/TokenManagerHelper3.lite.json)
- Interfaces: [`../contracts/interfaces/ITokenManager.sol`](../contracts/interfaces/ITokenManager.sol), [`../contracts/interfaces/ITokenManager2.sol`](../contracts/interfaces/ITokenManager2.sol), [`../contracts/interfaces/ITokenManagerHelper3.sol`](../contracts/interfaces/ITokenManagerHelper3.sol)

## 1. Recommended Trade Flow

```text
token address
    -> Helper3.getTokenInfo(token)
    -> read version / tokenManager / quote / liquidityAdded
    -> if liquidityAdded: route externally (Pancake / DEX)
    -> else Helper3.tryBuy / trySell
    -> approve if needed
    -> call V1 or V2 trade method on tokenManager
    -> index TokenPurchase / TokenSale (and TradeStop / LiquidityAdded)
```

`getTokenInfo.tokenManager` returns the canonical V1 or V2 manager address for that version (same as the published constants on BSC). Prefer it when selecting which ABI/methods to call.

## 2. TokenManagerHelper3

**Addresses**

- BSC: `0xF251F83e40a78868FcfA3FA4599Dad6494E46034`
- Arbitrum One: `0x02287dc3CcA964a025DAaB1111135A46C10D3A57`
- Base: `0x1172FABbAc4Fe05f5a5Cebd8EBBC593A76c42399`

### 2.1 `getTokenInfo`

```solidity
function getTokenInfo(address token) returns (
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
```

| Field | Meaning |
|-------|---------|
| `version` | `1` → trade via V1 methods; `2` → trade via V2 methods |
| `tokenManager` | Canonical manager for that version (`TOKEN_MANAGER` or `TOKEN_MANAGER_2`) |
| `quote` | `address(0)` = BNB pair; otherwise BEP20 quote |
| `tradingFeeRate` | Protocol trading-fee numerator; actual rate is `tradingFeeRate / 10000` |
| `minTradingFee` | Minimum protocol trading fee amount |
| `offers` / `maxOffers` | Remaining / max tokens for sale on the curve. For V1, Helper returns fixed `maxOffers` / `maxFunds` constants rather than per-token storage |
| `funds` / `maxFunds` | Raised / max raise in quote units |
| `liquidityAdded` | V2: `true` when token `status == COMPLETED (3)`. V1: from V1 liquidity flag |

### 2.2 `tryBuy`

```solidity
function tryBuy(address token, uint256 amount, uint256 funds) view returns (
    address tokenManager,
    address quote,
    uint256 estimatedAmount,
    uint256 estimatedCost,
    uint256 estimatedFee,
    uint256 amountMsgValue,
    uint256 amountApproval,
    uint256 amountFunds
);
```

Examples:

- Buy a fixed token amount: `tryBuy(token, 10000e18, 0)`
- Spend a fixed quote budget: `tryBuy(token, 0, 10e18)`

Return usage:

| Field | Meaning |
|-------|---------|
| `estimatedCost` | Curve quote cost (before protocol fee) |
| `estimatedFee` | Estimated protocol trading fee. Under AntiSniperFeeMode this can include base+extra; the buy event `fee` field only records base fee |
| `amountMsgValue` | Suggested `msg.value` for the trade call (may include pending `launchFee`) |
| `amountApproval` | Suggested ERC20 quote approval when `quote != 0` |
| `amountFunds` | Suggested `funds` argument for AMAP buys |

For TaxToken8, Helper also folds estimated buy tax into `amountMsgValue` / `amountApproval` where applicable.

### 2.3 `trySell`

```solidity
function trySell(address token, uint256 amount) returns (
    address tokenManager,
    address quote,
    uint256 funds,
    uint256 fee
);
```

| Field | Meaning |
|-------|---------|
| `tokenManager` | Manager to call for the real trade |
| `quote` | Quote asset (`address(0)` = native BNB) |
| `funds` | Estimated **net** quote to the seller: `curveGross - protocolFee - token8SellTax`. Does **not** subtract any third-party router `feeRate` cut. Token8 tax is deducted here but **not** included in `fee` |
| `fee` | Protocol trading fee only (not token8 tax, not router cut) |

### 2.4 `calcInitialPrice`

```solidity
function calcInitialPrice(
    uint256 maxRaising,
    uint256 totalSupply,
    uint256 offers,
    uint256 reserves
) returns (uint256 priceWei);
```

Utility for displaying an initial price from launch parameters. Not required for every swap UI.

### 2.5 `buyWithEth` / `sellForEth`

Only for **ERC20/ERC20** pairs (`quote != address(0)`). Not supported for native BNB pairs.

```solidity
buyWithEth(uint256 origin, address token, address to, uint256 funds, uint256 minAmount) payable
```

- `origin`: pass `0`
- `to`: recipient; `address(0)` means `msg.sender`
- Spends BNB, swaps into the quote asset internally, then buys the meme token

```solidity
sellForEth(uint256 origin, address token, uint256 amount, uint256 minFunds, uint256 feeRate, address feeRecipient)
sellForEth(uint256 origin, address token, address from, uint256 amount, uint256 minFunds, uint256 feeRate, address feeRecipient)
sellForEth(uint256 origin, address token, address from, address to, uint256 amount, uint256 minFunds)
```

Notes:

- Router fee (`feeRate`) max is 5%. `100` = 1%, `10` = 0.1% (`feeRate / 10000`).
- Router fee is collected in the **quote ERC20**, not in BNB.
- For the `from` overload, `tx.origin` must equal `from`.
- `minFunds` here is checked against the **final BNB amount out** after selling to quote and swapping to BNB (`require(amountEth > minFunds)`). This differs from `TokenManager2.sellToken`’s `minFunds`, which compares the **gross curve quote**.

Before sell: `ERC20(token).approve(helperOrManager, amount)` as required by the call path.

## 3. TokenManager (V1)

**BSC address:** `0xEC4549caDcE5DA21Df6E6422d448034B5233bFbC`

Supports trading for tokens created before 2024-09-05.

### Methods

| Method | Use |
|--------|-----|
| `purchaseTokenAMAP(token, funds, minAmount)` | Spend fixed BNB for tokens (to `msg.sender`) |
| `purchaseToken(token, amount, maxFunds)` | Buy fixed token amount |
| `purchaseTokenAMAP(origin, token, to, funds, minAmount)` | AMAP buy to `to` (`origin` = 0) |
| `purchaseToken(origin, token, to, amount, maxFunds)` | Fixed-amount buy to `to` (`origin` = 0) |
| `saleToken(token, amount)` | Sell tokens |

Before `saleToken`, approve the V1 TokenManager.

### Events

```solidity
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
event TokenPurchase(address token, address account, uint256 tokenAmount, uint256 etherAmount);
event TokenSale(address token, address account, uint256 tokenAmount, uint256 etherAmount);
event TradeStop(address token);
```

## 4. TokenManager2 (V2)

**BSC address:** `0x5c952063c7fc8610FFDB798152D69F0B9550762b`

Supports tokens created on/after 2024-09-05. Quote may be BNB (`quote == 0`) or BEP20.

### 4.1 Buy

| Method | Use |
|--------|-----|
| `buyTokenAMAP(token, funds, minAmount)` | Spend fixed quote for tokens |
| `buyTokenAMAP(token, to, funds, minAmount)` | AMAP buy to `to` |
| `buyToken(token, amount, maxFunds)` | Buy fixed token amount |
| `buyToken(token, to, amount, maxFunds)` | Fixed-amount buy to `to` |

For BNB pairs, send `msg.value`. For ERC20 quote pairs, approve quote to TokenManager2 first. Prefer filling `msg.value` / approvals from Helper3 `tryBuy`.

### 4.2 Sell

| Method | Use |
|--------|-----|
| `sellToken(token, amount)` | Simple sell |
| `sellToken(origin, token, amount, minFunds, feeRate, feeRecipient)` | Sell with router fee |
| `sellToken(origin, token, from, amount, minFunds, feeRate, feeRecipient)` | Router path; `tx.origin == from` |

- `origin`: set `0`
- `feeRate`: max 5%; `100` = 1%, `10` = 0.1% (`cut = funds * feeRate / 10000`)
- `minFunds`: compared against the **gross curve quote** (`calcSellCost`) **before** protocol fee and router cut. Net proceeds to the seller are lower.
- Before sell: `ERC20(token).approve(tokenManager, amount)`

### 4.3 Events

```solidity
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

event TradeStop(address token);

event LiquidityAdded(address base, uint256 offers, address quote, uint256 funds);
```

Field notes:

| Field | Meaning |
|-------|---------|
| `TokenPurchase.account` | Token recipient (`to`), not necessarily `msg.sender` |
| `TokenSale.account` | Seller (`from`) |
| `price` | `lastPrice` **after** the trade updates curve state |
| `cost` | Gross curve quote for the trade (excludes protocol fee) |
| `fee` | Protocol `baseFee` only. Under AntiSniperFeeMode, any `extraFee` is tracked in `_tokenInfoEx1s.extraFee` and is **not** included in this event field |
| `offers` / `funds` (trade events) | Remaining offers / cumulative raised funds after the trade |
| `LiquidityAdded.offers` | Token amount added to LP (`amountTokenDesired`), **not** bonding-curve remaining offers |
| `LiquidityAdded.quote` | `address(0)` means BNB quote |

## 5. Error Codes

### buyToken

| Code | Meaning |
|------|---------|
| `GW` | Amount precision not aligned to GWEI |
| `ZA` | `to` must not be `address(0)` |
| `TO` | `to` must not be the Pancake pair |
| `Slippage` | Fixed-amount buy: curve cost exceeds `maxFunds`. AMAP buy: purchased amount below `minAmount` |
| `More BNB` | Insufficient `msg.value` |

### sellToken

| Code | Meaning |
|------|---------|
| `GW` | Amount precision not aligned to GWEI |
| `FR` | Fee rate exceeds 5% (`feeRate > 500`) |
| `SO` | Order amount too small (`funds <= protocol fee`) |
| `Slippage` | Gross curve quote is below `minFunds` (not net proceeds) |

## 6. AntiSniperFeeMode Tokens

AntiSniperFeeMode applies a dynamic fee that decreases block-by-block after creation. Indicated by `feeSetting > 0` in `TokenInfoEx1`.

### On-chain

```solidity
TokenInfoEx1 memory tix1 = TokenManager2._tokenInfoEx1s(token);
bool antiSniper = tix1.feeSetting > 0;
```

### Off-chain

In token info API response, `feePlan == true` means AntiSniperFeeMode is enabled.

Block-by-block fee schedule may change for future launches. Product reference: [Product Update 25-10-30](https://four-meme.gitbook.io/four.meme/product-update/6-product-update-25-10-30).

## 7. Minimal TypeScript Sketch

```typescript
const helper = new Contract(HELPER3, Helper3Abi, provider);
const info = await helper.getTokenInfo(token);

if (info.liquidityAdded) {
  // route externally via DEX
  return;
}

const estimate = await helper.tryBuy(token, 0n, funds); // budget buy
const manager = new Contract(info.tokenManager, info.version === 1n ? Tm1Abi : Tm2Abi, signer);

if (info.version === 2n) {
  if (info.quote !== ZeroAddress) {
    await erc20(info.quote).approve(info.tokenManager, estimate.amountApproval);
  }
  await manager.buyTokenAMAP(token, estimate.amountFunds, minAmount, {
    value: estimate.amountMsgValue,
  });
} else {
  await manager.purchaseTokenAMAP(token, estimate.amountFunds, minAmount, {
    value: estimate.amountMsgValue,
  });
}
```

## 8. Tax Tokens While Trading

TaxToken / TaxToken8 identification and claim flows are documented in the [Tax Integration](./tax-guide.md). Trading still goes through TokenManager2 / Helper3; tax accounting lives on the token contract after fees are taken.

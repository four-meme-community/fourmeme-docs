# Four.Meme Classic Integration Guide

This guide is the overview for third-party integrators of the **classic** Four.Meme protocol on BNB Smart Chain (and Helper deployments on other chains where noted).

It explains how to discover addresses, choose V1 vs V2, identify token modes, and route to the detail guides for trading, creation, and tax tokens.

This guide does **not** cover OpenFour. For OpenFour, use the OpenFour documentation set.

Detail guides:

- [Trade Integration](./trade-guide.md)
- [Create Integration](./create-guide.md)
- [Tax Integration](./tax-guide.md)

## 1. Integration Targets

Classic Four.Meme integrations usually work with these contracts:

| Contract | Role |
|----------|------|
| `TokenManager` (V1) | Trade tokens created **before** 2024-09-05. Creation is no longer used for new launches. |
| `TokenManager2` (V2) | Create and trade tokens created **on/after** 2024-09-05. Supports BNB and BEP20 quote pairs. |
| `TokenManagerHelper3` (Helper V3) | Unified token info, buy/sell estimates, V1/V2 routing helper, and BNB↔ERC20 quote helpers. |

Recommended approach:

1. Always call Helper3 `getTokenInfo(token)` first.
2. Use the returned `version` and `tokenManager` to select V1 or V2 trade methods.
3. Prefer the returned `tokenManager` when choosing which manager ABI to call (on BSC it matches the published V1/V2 constants).

## 2. Address Discovery

### 2.1 BNB Smart Chain (mainnet)

| Contract | Address |
|----------|---------|
| TokenManager (V1) | `0xEC4549caDcE5DA21Df6E6422d448034B5233bFbC` |
| TokenManager2 (V2) | `0x5c952063c7fc8610FFDB798152D69F0B9550762b` |
| TokenManagerHelper3 | `0xF251F83e40a78868FcfA3FA4599Dad6494E46034` |

ABI / interfaces:

- [`../abi/TokenManager.lite.json`](../abi/TokenManager.lite.json) · [`../contracts/interfaces/ITokenManager.sol`](../contracts/interfaces/ITokenManager.sol)
- [`../abi/TokenManager2.lite.json`](../abi/TokenManager2.lite.json) · [`../contracts/interfaces/ITokenManager2.sol`](../contracts/interfaces/ITokenManager2.sol)
- [`../abi/TokenManagerHelper3.lite.json`](../abi/TokenManagerHelper3.lite.json) · [`../contracts/interfaces/ITokenManagerHelper3.sol`](../contracts/interfaces/ITokenManagerHelper3.sol)

### 2.2 Helper3 on other chains

| Chain | TokenManagerHelper3 |
|-------|---------------------|
| Arbitrum One | `0x02287dc3CcA964a025DAaB1111135A46C10D3A57` |
| Base | `0x1172FABbAc4Fe05f5a5Cebd8EBBC593A76c42399` |

Helper V1/V2 should be upgraded to Helper3. Helper3 unifies info queries for tokens created by both TokenManager V1 and V2.

### 2.3 Resolve managers from Helper3

```typescript
const helper = new Contract(helper3Address, Helper3Abi, provider);
const tm1 = await helper.TOKEN_MANAGER(); // or helper.TM()
const tm2 = await helper.TOKEN_MANAGER_2(); // or helper.TM2()
```

For a specific token, prefer:

```typescript
const info = await helper.getTokenInfo(token);
// info.version === 1n -> use V1 methods on info.tokenManager
// info.version === 2n -> use V2 methods on info.tokenManager
```

## 3. V1 / V2 Support Policy

- Full classic Four.Meme support requires **both** V1 and V2.
- If you only need tokens created after 2024-09-05, V2 alone is enough.
- V1 still works for trading older tokens, but is not used for new creation.

Routing recipe:

1. `getTokenInfo(token)` via Helper3.
2. If `version == 1`, call V1 `purchaseToken*` / `saleToken` on `tokenManager`.
3. If `version == 2`, call V2 `buyToken*` / `sellToken` on `tokenManager`.
4. If estimates are needed, use Helper3 `tryBuy` / `trySell` first.

## 4. Quote Asset Rules

From `getTokenInfo` / events:

- `quote == address(0)` → the token trades against native BNB on the bonding curve.
- `quote != address(0)` → the token trades against a BEP20 quote (for example USDT).

Implications:

- BNB pairs: send `msg.value` on buys; sells return BNB.
- ERC20 quote pairs: approve quote to TokenManager2 before buy; approve the meme token before sell.
- Helper3 `buyWithEth` / `sellForEth` only apply to **ERC20/ERC20** pairs (quote ≠ 0). They are not for native BNB pairs.

## 5. Token Identification (Overview)

Given a token address, integrators commonly need to know:

| Question | Where |
|----------|--------|
| Is it classic Four.Meme? V1 or V2? | Helper3 `getTokenInfo` |
| Has it migrated to Pancake? | `liquidityAdded` / `TradeStop` / `LiquidityAdded` |
| Is AntiSniperFeeMode enabled? | [Trade guide](./trade-guide.md#6-antisniperfeemode-tokens) |
| Is it TaxToken / TaxToken8? | [Tax guide](./tax-guide.md) |

Off-chain token metadata (optional):

- `https://four.meme/meme-api/v1/private/token/get/v2?address={token}`
- `https://four.meme/meme-api/v1/private/token/getById?id={requestId}`

`requestId` comes from the `TokenCreate` event.

## 6. Migration and External Market Routing

While the bonding curve is active:

- Route buys/sells through TokenManager V1/V2 (or Helper3 wrappers where applicable).

After migration:

- `getTokenInfo(...).liquidityAdded == true`
- V2 emits `TradeStop(token)` and `LiquidityAdded(base, tokenAmountToLp, quote, funds)`
- Internal curve trading stops; route via the external DEX pool for that token/quote

Note: `LiquidityAdded`’s second parameter is the **token amount added to LP**, not remaining bonding-curve offers. See [Trade guide events](./trade-guide.md#43-events).

## 7. What to Read Next

| Integrator type | Start here |
|-----------------|------------|
| Wallet / swap UI / aggregator | [Trade Integration](./trade-guide.md) |
| Launch platform / create bot | [Create Integration](./create-guide.md) |
| Tax token UI / indexer / claim flow | [Tax Integration](./tax-guide.md) |

## 8. Scope Boundaries

Included:

- Public trade, create, estimate, and tax claim surfaces documented for third parties.
- Lite ABIs under `abi/` and interfaces under `contracts/interfaces/`.

Not included:

- Bonding-curve math internals and proprietary libraries.
- Admin / operator / upgrade / fee-collector privileged APIs.
- OpenFour modular protocol (separate docs).

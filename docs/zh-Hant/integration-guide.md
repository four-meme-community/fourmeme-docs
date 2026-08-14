# Four.Meme Classic 接入總覽

本指南是經典版 Four.Meme 協議在 BNB Smart Chain（以及文中註明的其他鏈上 Helper）的第三方接入總覽。

說明如何發現地址、選擇 V1 / V2、識別代幣模式，以及導向交易、創建、稅收代幣的細節指南。

本指南**不**涵蓋 OpenFour。OpenFour 請使用其獨立文檔集。

細節指南：

- [交易接入](./trade-guide.md)
- [創建接入](./create-guide.md)
- [稅收代幣接入](./tax-guide.md)

## 1. 接入目標

經典版 Four.Meme 接入通常會用到這些合約：

| 合約 | 角色 |
|------|------|
| `TokenManager`（V1） | 交易 **2024-09-05 之前** 創建的代幣。新發射已不再使用創建。 |
| `TokenManager2`（V2） | 創建並交易 **2024-09-05 當日及之後** 創建的代幣。支援 BNB 與 BEP20 計價對。 |
| `TokenManagerHelper3`（Helper V3） | 統一代幣資訊、買賣預估、V1/V2 路由輔助，以及 BNB↔ERC20 計價輔助。 |

建議做法：

1. 一律先呼叫 Helper3 `getTokenInfo(token)`。
2. 依回傳的 `version` 與 `tokenManager` 選擇 V1 或 V2 交易方法。
3. 選 manager ABI 時優先使用回傳的 `tokenManager`（在 BSC 上與公開的 V1/V2 常數一致）。

## 2. 地址發現

### 2.1 BNB Smart Chain（主網）

| 合約 | 地址 |
|------|------|
| TokenManager（V1） | `0xEC4549caDcE5DA21Df6E6422d448034B5233bFbC` |
| TokenManager2（V2） | `0x5c952063c7fc8610FFDB798152D69F0B9550762b` |
| TokenManagerHelper3 | `0xF251F83e40a78868FcfA3FA4599Dad6494E46034` |

ABI / 介面：

- [`../../abi/TokenManager.lite.json`](../../abi/TokenManager.lite.json) · [`../../contracts/interfaces/ITokenManager.sol`](../../contracts/interfaces/ITokenManager.sol)
- [`../../abi/TokenManager2.lite.json`](../../abi/TokenManager2.lite.json) · [`../../contracts/interfaces/ITokenManager2.sol`](../../contracts/interfaces/ITokenManager2.sol)
- [`../../abi/TokenManagerHelper3.lite.json`](../../abi/TokenManagerHelper3.lite.json) · [`../../contracts/interfaces/ITokenManagerHelper3.sol`](../../contracts/interfaces/ITokenManagerHelper3.sol)

### 2.2 其他鏈上的 Helper3

| 鏈 | TokenManagerHelper3 |
|----|---------------------|
| Arbitrum One | `0x02287dc3CcA964a025DAaB1111135A46C10D3A57` |
| Base | `0x1172FABbAc4Fe05f5a5Cebd8EBBC593A76c42399` |

Helper V1/V2 應升級至 Helper3。Helper3 可統一查詢由 TokenManager V1 與 V2 創建的代幣資訊。

### 2.3 從 Helper3 解析 manager

```typescript
const helper = new Contract(helper3Address, Helper3Abi, provider);
const tm1 = await helper.TOKEN_MANAGER(); // 或 helper.TM()
const tm2 = await helper.TOKEN_MANAGER_2(); // 或 helper.TM2()
```

針對特定代幣，優先：

```typescript
const info = await helper.getTokenInfo(token);
// info.version === 1n -> 在 info.tokenManager 上使用 V1 方法
// info.version === 2n -> 在 info.tokenManager 上使用 V2 方法
```

## 3. V1 / V2 支援策略

- 完整支援經典版 Four.Meme 需要 **同時** 支援 V1 與 V2。
- 若只需要 2024-09-05 之後創建的代幣，僅 V2 即可。
- V1 仍可用於交易舊代幣，但不再用於新創建。

路由步驟：

1. 透過 Helper3 呼叫 `getTokenInfo(token)`。
2. 若 `version == 1`，在 `tokenManager` 上呼叫 V1 `purchaseToken*` / `saleToken`。
3. 若 `version == 2`，在 `tokenManager` 上呼叫 V2 `buyToken*` / `sellToken`。
4. 若需要預估，先用 Helper3 `tryBuy` / `trySell`。

## 4. 計價資產規則

來自 `getTokenInfo` / 事件：

- `quote == address(0)` → 代幣在曲線上以原生 BNB 交易。
- `quote != address(0)` → 代幣以某 BEP20 計價（例如 USDT）。

影響：

- BNB 交易對：買入需送 `msg.value`；賣出返還 BNB。
- ERC20 計價對：買入前向 TokenManager2 approve 計價幣；賣出前 approve meme 代幣。
- Helper3 `buyWithEth` / `sellForEth` **僅**適用於 **ERC20/ERC20** 對（quote ≠ 0），不適用於原生 BNB 對。

## 5. 代幣識別（總覽）

給定代幣地址，接入方通常需要知道：

| 問題 | 來源 |
|------|------|
| 是否經典版 Four.Meme？V1 還是 V2？ | Helper3 `getTokenInfo` |
| 是否已遷移至 Pancake？ | `liquidityAdded` / `TradeStop` / `LiquidityAdded` |
| 是否啟用 AntiSniperFeeMode？ | [交易指南](./trade-guide.md#6-antisniperfeemode-代幣) |
| 是否 TaxToken / TaxToken8？ | [稅收代幣指南](./tax-guide.md) |

鏈下代幣元資料（可選）：

- `https://four.meme/meme-api/v1/private/token/get/v2?address={token}`
- `https://four.meme/meme-api/v1/private/token/getById?id={requestId}`

`requestId` 來自 `TokenCreate` 事件。

## 6. 遷移與外部市場路由

曲線仍活躍時：

- 買賣走 TokenManager V1/V2（或適用的 Helper3 包裝）。

遷移之後：

- `getTokenInfo(...).liquidityAdded == true`
- V2 會發出 `TradeStop(token)` 與 `LiquidityAdded(base, tokenAmountToLp, quote, funds)`
- 內部曲線交易停止；改走該 token/quote 的外部 DEX 池

注意：`LiquidityAdded` 的第二個參數是 **加入 LP 的代幣數量**，不是曲線剩餘可售量。見 [交易指南事件](./trade-guide.md#43-事件)。

## 7. 接下來讀什麼

| 接入類型 | 從此開始 |
|----------|----------|
| 錢包 / 兌換 UI / 聚合器 | [交易接入](./trade-guide.md) |
| 發射平台 / 創建 bot | [創建接入](./create-guide.md) |
| 稅收代幣 UI / 索引器 / 領取流程 | [稅收代幣接入](./tax-guide.md) |

## 8. 範圍邊界

包含：

- 面向第三方的公開交易、創建、預估與稅收領取介面。
- `abi/` 下的精簡 ABI 與 `contracts/interfaces/` 下的介面。

不包含：

- Bonding curve 數學內部與專有函式庫。
- 管理員 / 運營 / 升級 / 收費方特權 API。
- OpenFour 模組化協議（另有文檔）。

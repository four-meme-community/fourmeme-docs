# Four.Meme Classic 交易接入

本指南涵蓋經典版 Four.Meme 的買入、賣出、預估、事件、錯誤碼與代幣模式識別。

另見：

- [接入總覽](./integration-guide.md) — 地址與 V1/V2 總覽
- [創建接入](./create-guide.md)
- [稅收代幣接入](./tax-guide.md)

精簡產物：

- ABI：[`../../abi/TokenManager.lite.json`](../../abi/TokenManager.lite.json)、[`../../abi/TokenManager2.lite.json`](../../abi/TokenManager2.lite.json)、[`../../abi/TokenManagerHelper3.lite.json`](../../abi/TokenManagerHelper3.lite.json)
- 介面：[`../../contracts/interfaces/ITokenManager.sol`](../../contracts/interfaces/ITokenManager.sol)、[`../../contracts/interfaces/ITokenManager2.sol`](../../contracts/interfaces/ITokenManager2.sol)、[`../../contracts/interfaces/ITokenManagerHelper3.sol`](../../contracts/interfaces/ITokenManagerHelper3.sol)

## 1. 建議交易流程

```text
token address
    -> Helper3.getTokenInfo(token)
    -> 讀取 version / tokenManager / quote / liquidityAdded
    -> 若 liquidityAdded：走外部路由（Pancake / DEX）
    -> 否則 Helper3.tryBuy / trySell
    -> 必要時 approve
    -> 在 tokenManager 上呼叫 V1 或 V2 交易方法
    -> 索引 TokenPurchase / TokenSale（以及 TradeStop / LiquidityAdded）
```

`getTokenInfo.tokenManager` 回傳該版本的規範 V1 或 V2 manager 地址（在 BSC 上與公開常數相同）。選擇 ABI/方法時請優先使用它。

## 2. TokenManagerHelper3

**地址**

- BSC：`0xF251F83e40a78868FcfA3FA4599Dad6494E46034`
- Arbitrum One：`0x02287dc3CcA964a025DAaB1111135A46C10D3A57`
- Base：`0x1172FABbAc4Fe05f5a5Cebd8EBBC593A76c42399`

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

| 欄位 | 含義 |
|------|------|
| `version` | `1` → 走 V1 方法；`2` → 走 V2 方法 |
| `tokenManager` | 該版本的規範 manager（`TOKEN_MANAGER` 或 `TOKEN_MANAGER_2`） |
| `quote` | `address(0)` = BNB 對；否則為 BEP20 計價 |
| `tradingFeeRate` | 協議交易費分子；實際費率為 `tradingFeeRate / 10000` |
| `minTradingFee` | 協議交易費最低額 |
| `offers` / `maxOffers` | 曲線剩餘 / 最大可售代幣量。V1 上 Helper 回傳固定的 `maxOffers` / `maxFunds` 常數，而非逐代幣儲存 |
| `funds` / `maxFunds` | 已募集 / 最大募集（計價單位） |
| `liquidityAdded` | V2：代幣 `status == COMPLETED (3)` 時為 `true`。V1：來自 V1 流動性旗標 |

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

範例：

- 買固定數量：`tryBuy(token, 10000e18, 0)`
- 花固定預算：`tryBuy(token, 0, 10e18)`

回傳用法：

| 欄位 | 含義 |
|------|------|
| `estimatedCost` | 曲線計價成本（協議費之前） |
| `estimatedFee` | 預估協議交易費。AntiSniperFeeMode 下可能含 base+extra；買入事件的 `fee` 欄位只記錄 base fee |
| `amountMsgValue` | 建議的交易呼叫 `msg.value`（可能含待付 `launchFee`） |
| `amountApproval` | 當 `quote != 0` 時建議的 ERC20 計價 approve 額度 |
| `amountFunds` | AMAP 買入建議的 `funds` 參數 |

對 TaxToken8 與 TaxToken9，Helper 在適用時也會把預估買入稅折入 `amountMsgValue` / `amountApproval`。

### 2.3 `trySell`

```solidity
function trySell(address token, uint256 amount) returns (
    address tokenManager,
    address quote,
    uint256 funds,
    uint256 fee
);
```

| 欄位 | 含義 |
|------|------|
| `tokenManager` | 實際交易應呼叫的 manager |
| `quote` | 計價資產（`address(0)` = 原生 BNB） |
| `funds` | 預估賣方 **淨** 計價收入：`curveGross - protocolFee - taxTokenSellTax`。**不**扣除第三方 router `feeRate` 抽成。Token8／TaxToken9 稅在此扣除，但**不**計入 `fee` |
| `fee` | 僅協議交易費（不含 TaxToken8／TaxToken9 稅、不含 router 抽成） |

### 2.4 `calcInitialPrice`

```solidity
function calcInitialPrice(
    uint256 maxRaising,
    uint256 totalSupply,
    uint256 offers,
    uint256 reserves
) returns (uint256 priceWei);
```

用於依發射參數顯示初始價格的工具方法。並非每個兌換 UI 都需要。

### 2.5 `buyWithEth` / `sellForEth`

僅適用於 **ERC20/ERC20** 對（`quote != address(0)`）。原生 BNB 對不支援。

```solidity
buyWithEth(uint256 origin, address token, address to, uint256 funds, uint256 minAmount) payable
```

- `origin`：傳 `0`
- `to`：收款人；`address(0)` 表示 `msg.sender`
- 花費 BNB，內部換成計價資產，再買入 meme 代幣

```solidity
sellForEth(uint256 origin, address token, uint256 amount, uint256 minFunds, uint256 feeRate, address feeRecipient)
sellForEth(uint256 origin, address token, address from, uint256 amount, uint256 minFunds, uint256 feeRate, address feeRecipient)
sellForEth(uint256 origin, address token, address from, address to, uint256 amount, uint256 minFunds)
```

說明：

- Router 手續費（`feeRate`）上限 5%。`100` = 1%，`10` = 0.1%（`feeRate / 10000`）。
- Router 手續費以 **計價 ERC20** 收取，不是 BNB。
- 含 `from` 的重載要求 `tx.origin` 等於 `from`。
- 此處的 `minFunds` 對照的是賣到計價再換成 BNB 後的 **最終 BNB 出金**（`require(amountEth > minFunds)`）。這與 `TokenManager2.sellToken` 的 `minFunds`（對照 **曲線毛估計價**）不同。

賣出前：依呼叫路徑對 `helperOrManager` 執行 `ERC20(token).approve(..., amount)`。

## 3. TokenManager（V1）

**BSC 地址：** `0xEC4549caDcE5DA21Df6E6422d448034B5233bFbC`

支援交易 2024-09-05 之前創建的代幣。

### 方法

| 方法 | 用途 |
|------|------|
| `purchaseTokenAMAP(token, funds, minAmount)` | 以固定 BNB 買入代幣（給 `msg.sender`） |
| `purchaseToken(token, amount, maxFunds)` | 買固定數量 |
| `purchaseTokenAMAP(origin, token, to, funds, minAmount)` | AMAP 買給 `to`（`origin` = 0） |
| `purchaseToken(origin, token, to, amount, maxFunds)` | 固定數量買給 `to`（`origin` = 0） |
| `saleToken(token, amount)` | 賣出代幣 |

`saleToken` 前需向 V1 TokenManager approve。

### 事件

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

## 4. TokenManager2（V2）

**BSC 地址：** `0x5c952063c7fc8610FFDB798152D69F0B9550762b`

支援 2024-09-05 當日及之後創建的代幣。計價可為 BNB（`quote == 0`）或 BEP20。

### 4.1 買入

| 方法 | 用途 |
|------|------|
| `buyTokenAMAP(token, funds, minAmount)` | 以固定計價額買入代幣 |
| `buyTokenAMAP(token, to, funds, minAmount)` | AMAP 買給 `to` |
| `buyToken(token, amount, maxFunds)` | 買固定數量 |
| `buyToken(token, to, amount, maxFunds)` | 固定數量買給 `to` |

BNB 對需送 `msg.value`。ERC20 計價對需先向 TokenManager2 approve 計價幣。建議用 Helper3 `tryBuy` 填寫 `msg.value` / approve。

### 4.2 賣出

| 方法 | 用途 |
|------|------|
| `sellToken(token, amount)` | 簡易賣出 |
| `sellToken(origin, token, amount, minFunds, feeRate, feeRecipient)` | 帶 router 手續費的賣出 |
| `sellToken(origin, token, from, amount, minFunds, feeRate, feeRecipient)` | Router 路徑；`tx.origin == from` |

- `origin`：設為 `0`
- `feeRate`：上限 5%；`100` = 1%，`10` = 0.1%（`cut = funds * feeRate / 10000`）
- `minFunds`：與 **協議費與 router 抽成之前** 的 **曲線毛估計價**（`calcSellCost`）比較。賣方淨收入會更低。
- 賣出前：`ERC20(token).approve(tokenManager, amount)`

### 4.3 事件

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

欄位說明：

| 欄位 | 含義 |
|------|------|
| `TokenPurchase.account` | 代幣收款人（`to`），不一定是 `msg.sender` |
| `TokenSale.account` | 賣方（`from`） |
| `price` | 交易更新曲線狀態 **之後** 的 `lastPrice` |
| `cost` | 該筆交易的曲線毛估計價（不含協議費） |
| `fee` | 僅協議 `baseFee`。AntiSniperFeeMode 下任何 `extraFee` 記在 `_tokenInfoEx1s.extraFee`，**不**含於本事件欄位 |
| `offers` / `funds`（交易事件） | 交易後剩餘可售量 / 累計募集資金 |
| `LiquidityAdded.offers` | 加入 LP 的代幣數量（`amountTokenDesired`），**不是**曲線剩餘可售量 |
| `LiquidityAdded.quote` | `address(0)` 表示 BNB 計價 |

## 5. 錯誤碼

### buyToken

| 代碼 | 含義 |
|------|------|
| `GW` | 數量精度未對齊 GWEI |
| `ZA` | `to` 不得為 `address(0)` |
| `TO` | `to` 不得為 Pancake pair |
| `Slippage` | 固定數量買入：曲線成本超過 `maxFunds`。AMAP 買入：買到數量低於 `minAmount` |
| `More BNB` | `msg.value` 不足 |

### sellToken

| 代碼 | 含義 |
|------|------|
| `GW` | 數量精度未對齊 GWEI |
| `FR` | 手續費率超過 5%（`feeRate > 500`） |
| `SO` | 訂單金額過小（`funds <= protocol fee`） |
| `Slippage` | 曲線毛估計價低於 `minFunds`（不是淨收入） |

## 6. AntiSniperFeeMode 代幣

AntiSniperFeeMode 在創建後按區塊遞減動態手續費。由 `TokenInfoEx1` 中 `feeSetting > 0` 表示。

### 鏈上

```solidity
TokenInfoEx1 memory tix1 = TokenManager2._tokenInfoEx1s(token);
bool antiSniper = tix1.feeSetting > 0;
```

### 鏈下

代幣資訊 API 回應中，`feePlan == true` 表示已啟用 AntiSniperFeeMode。

逐塊手續費表未來發射可能調整。產品參考：[Product Update 25-10-30](https://four-meme.gitbook.io/four.meme/product-update/6-product-update-25-10-30)。

## 7. 最小 TypeScript 示意

```typescript
const helper = new Contract(HELPER3, Helper3Abi, provider);
const info = await helper.getTokenInfo(token);

if (info.liquidityAdded) {
  // 走外部 DEX 路由
  return;
}

const estimate = await helper.tryBuy(token, 0n, funds); // 預算買入
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

## 8. 交易中的稅收代幣

TaxToken / TaxToken8 / TaxToken9 的識別與領取流程見[稅收代幣接入](./tax-guide.md)。TaxToken9 在曲線階段使用與 TaxToken8 相同的計價側扣稅路由。交易仍走 TokenManager2 / Helper3；稅費入帳後，稅務會計在代幣合約上。

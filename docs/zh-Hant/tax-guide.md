# Four.Meme Classic 稅收代幣接入

本指南涵蓋 TaxToken（creator type 5）與 New TaxToken / token8（creator type 8）：如何識別、讀取公開稅收狀態、領取持有人獎勵，以及監聽手續費事件。

另見：

- [接入總覽](./integration-guide.md)
- [交易接入](./trade-guide.md)
- [創建接入](./create-guide.md) — 創建時的 `tokenTaxInfo`

精簡產物：

- ABI：[`../../abi/TaxToken.lite.json`](../../abi/TaxToken.lite.json)、[`../../abi/TaxToken8.lite.json`](../../abi/TaxToken8.lite.json)
- 介面：[`../../contracts/interfaces/ITaxToken.sol`](../../contracts/interfaces/ITaxToken.sol)、[`../../contracts/interfaces/ITaxToken8.sol`](../../contracts/interfaces/ITaxToken8.sol)

Bonding curve 交易仍走 TokenManager2 / Helper3。本指南只涵蓋 **代幣合約** 上的稅收／獎勵介面。

## 1. 什麼是稅收代幣

稅收代幣是具備以下特性的 ERC20：

- 買賣轉帳稅（token8 在曲線交易階段也有稅）
- 稅金分配給創始人／持有人／銷毀／流動性
- 持有人以計價資產領取獎勵

兩代：

| 種類 | Creator type | 說明 |
|------|--------------|------|
| TaxToken | `5` | 單一鏈上 `feeRate`，單位為 **basis points**（`/ 10000`） |
| New TaxToken（token8） | `8` | 分開的 `feeRateBuy` / `feeRateSell`，單位為 **百分比**（`/ 100`）。曲線階段：由 TokenManager 在計價側扣稅；遷移後：在 pair 上對轉帳課稅 |

token8 已驗證源碼／ABI 範例（BscScan）：https://bscscan.com/token/0x77c4206fab7dc2e18501bf5bed3fb82d453effff#code

## 2. 識別

### 2.1 鏈上（兩代皆可）

```solidity
TokenInfo memory ti = ITokenManager2(tm2)._tokenInfos(token);
uint256 creatorType = (ti.template >> 10) & 0x3F;

if (creatorType == 5) {
    // TaxToken
} else if (creatorType == 8) {
    // New TaxToken (token8)
}
```

`ITokenManager2` / `_tokenInfos` 見 [`../../contracts/interfaces/ITokenManager2.sol`](../../contracts/interfaces/ITokenManager2.sol)。

### 2.2 鏈下

查詢：

- `https://four.meme/meme-api/v1/private/token/get/v2?address={token}`
- 或 `.../getById?id={requestId}`

| 訊號 | 含義 |
|------|------|
| 存在 `data.taxInfo` | 稅收類代幣（經典 TaxToken 家族） |
| `data.version == "V9"` | New TaxToken（token8） |
| `taxInfo.feeRate` | TaxToken（type 5）買賣稅的創建／API 百分比，或 token8 買入稅 |
| `taxInfo.feeRateSell` | token8 賣出稅百分比 |

token8 負載範例：

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

經典 TaxToken 的 `taxInfo` 使用單一 `feeRate`（API 百分比選項 `1`/`3`/`5`/`10`）加上分配欄位（`burnRate`、`divideRate`、`liquidityRate`、`recipientRate`、`minSharing`、`recipientAddress`）。分配比例總和須為 100。鏈上 type-5 `feeRate` 以 basis points 儲存／套用（`amount * feeRate / 10000`）；`divideRate` 對應持有人分配（`rateHolder`）。

## 3. 轉帳模式

| 名稱 | 值 | 含義 |
|------|----|------|
| `MODE_NORMAL` | `0` | 正常轉帳 |
| `MODE_TRANSFER_RESTRICTED` | `1` | 所有轉帳 revert |
| `MODE_TRANSFER_CONTROLLED` | `2` | 僅允許 `from` 或 `to` 為 `owner()` 的轉帳 |

```solidity
function _mode() external view returns (uint256);
function setMode(uint256 v) external; // 僅 owner
```

一旦 `_mode` 為 `MODE_NORMAL`，即不可再改（含 DEX 遷移之後）。

## 4. 公開配置（TaxToken）

| Getter | 含義 |
|--------|------|
| `quote` | 獎勵所用計價代幣（BNB 募集時通常為 WETH，不是 `address(0)`） |
| `pair` | Pancake V2 pair（模式為 NORMAL 時透過 `getPair(token, quote)` 惰性初始化） |
| `founder` | 創始人獎勵收款人 |
| `feeRate` | 鏈上交易稅，**basis points**（`10000 = 100%`）。在 pair 買賣上按 `amount * feeRate / 10000` 套用 |
| `rateFounder` / `rateHolder` / `rateBurn` / `rateLiquidity` | 分配百分比；總和須為 100 |
| `minDispatch` | 累計手續費達此值才派發 |
| `minShare` | 參與持有人獎勵的最低代幣餘額（wei） |

UI 常用的獎勵會計 getter：

- `userInfo(account) -> (share, rewardDebt, claimable, claimed)`
- `totalShares`、`feePerShare`、`feeAccumulated`、`feeDispatched`
- `feeFounder`、`feeHolder`

## 5. New TaxToken（token8）差異

與 TaxToken 相同的領取／模式／分配介面，外加：

```solidity
function feeRateBuy() external view returns (uint256);
function feeRateSell() external view returns (uint256);
function feeRate() external view returns (uint256); // 已棄用的相容欄位
```

- `feeRateBuy` / `feeRateSell` 為 **百分比**（`3` = 3%），遷移後在 pair 轉帳上按 `amount * rate / 100` 套用
- 文件記載的鏈上上限為 `<= 10`
- 曲線交易階段（遷移前），token8 稅由 TokenManager 在 **計價** 側收取（`curveGross * rate / 100`，經 `sendFee`），不是 ERC20 轉帳稅
- 請優先使用 `feeRateBuy` / `feeRateSell`，而非已棄用的 `feeRate`

## 6. 領取

### 讀取

```solidity
function claimableFee(address account) external view returns (uint256);
function claimedFee(address account) external view returns (uint256);
```

`claimableFee` 含已存的 `claimable`，以及由 `share` 與 `feePerShare` 新累計的獎勵。

### 寫入

```solidity
function claimFee() external;
function claimFee(address[] calldata accounts) external;
```

| 方法 | 誰可呼叫 | 誰收到獎勵 |
|------|----------|------------|
| `claimFee()` | 任意持有人 | 僅 `msg.sender` |
| `claimFee(accounts)` | **任何人**（第三方／keeper／助手） | `accounts` 中各地址各自收到其可領計價 |

`claimFee(accounts)` 是 **代他人領取** 的路徑：呼叫方不會拿走獎勵；計價代幣轉給列表中的各帳戶。黑名單帳戶會被跳過。可領為零的帳戶為 no-op。

每個被領取帳戶的效果：

1. 刷新 share 會計
2. 將可領計價代幣轉給 **該帳戶**
3. 更新已領計數
4. 發出 `FeeClaimed(account, amount)`

每個帳戶的要求：

- 帳戶未被禁止領取
- 可領金額 > 0

低於 `minShare` 的地址 `share == 0`，不會累計持有人獎勵。

### 使用者列表查詢

供需要掃描待領獎勵持有人的 UI 或 keeper：

```solidity
function userCount() external view returns (uint256);
function users(uint256 index, uint256 count, uint256 minClaimable)
    external
    view
    returns (address[] memory);
```

| 項目 | 含義 |
|------|------|
| `userCount()` | 內部 `_users` 陣列長度 |
| `index` | `_users` 起始偏移 |
| `count` | 分頁大小；回傳陣列長度恆為 `count` |
| `minClaimable` | 若 `> 0`，依 `claimableFee` 過濾；低於門檻的項變為 `0xdEaD`。`0` 關閉過濾 |
| 超出範圍 | 超過 `userCount` 的槽位為 `address(0)` |

說明：

- `_users` 僅在 share 實際變更時（`newShare != curShare`）附加地址。**不是**完整持有人普查。
- 消費分頁時跳過 `address(0)` 與 `0xdEaD`。
- 典型助手／keeper 迴圈：用 `users(i, pageSize, minClaimable)` 分頁 → 收集非哨兵地址 → `claimFee(accounts)` **代這些持有人領取**（獎勵仍打給各持有人，不是呼叫方）。

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

## 7. 事件

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

索引器應在各稅收代幣地址上監聽這些事件（不是 TokenManager）。

## 8. 使用範例

```typescript
const token = new Contract(tokenAddress, TaxToken8Abi, signer);

const creatorType = /* 來自 TokenManager2._tokenInfos(token).template bits */;
const abi = creatorType === 8n ? TaxToken8Abi : TaxTokenAbi;

const claimable = await token.claimableFee(user);
const claimed = await token.claimedFee(user);
const info = await token.userInfo(user);

if (claimable > 0n) {
  await token.claimFee();
}

// 可選：列舉有待領獎勵的使用者
const n = await token.userCount();
const page = await token.users(0n, 50n, 0n);
```

監聽派發：

```typescript
token.on("FeeDispatched", (amountFounder, amountHolder, amountBurn, amountLiquidity, quoteFounder, quoteHolder) => {
  // 更新 UI / 索引器
});
```

## 9. 接入注意事項

1. `rateFounder + rateHolder + rateBurn + rateLiquidity == 100`。
2. 黑名單地址即使 `claimableFee` 看起來為正也無法領取。
3. 派發後因捨入，`feeAccumulated` 可能留下少量餘額。
4. 創建時 `tokenTaxInfo` 規則見 [創建接入](./create-guide.md#34-tokentaxinfo)。
5. `userCount` / `users` 僅覆蓋 share 曾更新的帳戶；勿當成完整持有人列表。
6. `claimFee(accounts)` 允許第三方 **代** 持有人領取；獎勵付給各帳戶，不是呼叫方。
7. 勿公開或依賴內部稅換輔助演算法；請使用上述公開 getter、領取與事件。

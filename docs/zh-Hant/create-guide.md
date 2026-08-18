# Four.Meme Classic 創建接入

本指南說明如何透過後端 API 創建經典版 Four.Meme 代幣，並在鏈上提交 `TokenManager2.createToken`。

另見：

- [接入總覽](./integration-guide.md)
- [交易接入](./trade-guide.md)
- [稅收代幣接入](./tax-guide.md)

精簡產物：

- ABI：[`../../abi/TokenManager2.lite.json`](../../abi/TokenManager2.lite.json)（`createToken` + 交易面）
- 介面：[`../../contracts/interfaces/ITokenManager2.sol`](../../contracts/interfaces/ITokenManager2.sol)

**TokenManager2（BSC）：** `0x5c952063c7fc8610FFDB798152D69F0B9550762b`

新代幣僅在 V2 上創建。V1 TokenManager 不用於新發射。

## 1. 端到端流程

```text
1. POST /v1/private/user/nonce/generate
2. 簽署登入訊息，POST /v1/private/user/login/dex  -> access_token
3. POST /v1/private/token/upload                         -> imgUrl
4. POST /v1/private/token/create                         -> createArg + signature
5. TokenManager2.createToken(createArg, signature)       -> TokenCreate 事件
```

基礎主機：`https://four.meme/meme-api`

## 2. API 端點

| 端點 | 方法 | 說明 |
|------|------|------|
| `/v1/private/user/nonce/generate` | POST | 產生登入 nonce |
| `/v1/private/user/login/dex` | POST | 登入並取得 access token |
| `/v1/private/token/upload` | POST | 上傳代幣圖片 |
| `/v1/private/token/create` | POST | 產生已簽名的創建負載 |

### 2.1 取得 nonce

`POST https://four.meme/meme-api/v1/private/user/nonce/generate`

```json
{
  "accountAddress": "user wallet address",
  "verifyType": "LOGIN",
  "networkCode": "BSC"
}
```

回應：

```json
{
  "code": "0",
  "data": "generated nonce value"
}
```

### 2.2 登入

`POST https://four.meme/meme-api/v1/private/user/login/dex`

用使用者錢包私鑰簽署訊息 `You are sign in Meme {nonce}`。

```json
{
  "region": "WEB",
  "langType": "EN",
  "loginIp": "",
  "inviteCode": "",
  "verifyInfo": {
    "address": "user wallet address",
    "networkCode": "BSC",
    "signature": "signature of 'You are sign in Meme {nonce}'",
    "verifyType": "LOGIN"
  },
  "walletName": "MetaMask"
}
```

回應 `data` 為 `access_token` 字串。

### 2.3 上傳圖片

`POST https://four.meme/meme-api/v1/private/token/upload`

Headers：

- `Content-Type: multipart/form-data`
- `meme-web-access: {access_token}`

Body：`file` 圖片（jpeg、png、gif、bmp、webp）。

回應 `data` 為託管圖片 URL。圖片必須上傳至 Four.Meme 平台；任意外部 URL 不可作為 `imgUrl`。

### 2.4 創建代幣（取得簽名）

`POST https://four.meme/meme-api/v1/private/token/create`

Headers：

- `meme-web-access: {access_token}`
- `Content-Type: application/json`

請求體範例：

```json
{
  "name": "RELEASE",
  "shortName": "RELS",
  "desc": "RELEASE DESC",
  "imgUrl": "https://static.four.meme/market/...",
  "launchTime": 1740708849097,
  "label": "AI",
  "lpTradingFee": 0.0025,
  "webUrl": "https://example.com",
  "twitterUrl": "https://x.com/example",
  "telegramUrl": "https://telegram.com/example",
  "preSale": "0.1",
  "feePlan": false,
  "tokenTaxInfo": {
    "burnRate": 20,
    "divideRate": 30,
    "feeRate": 5,
    "liquidityRate": 40,
    "minSharing": 100000,
    "recipientAddress": "0x1234567890123456789012345678901234567890",
    "recipientRate": 10
  },
  "raisedToken": {
    "symbol": "BNB",
    "nativeSymbol": "BNB",
    "symbolAddress": "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c",
    "deployCost": "0",
    "buyFee": "0.01",
    "sellFee": "0.01",
    "minTradeFee": "0",
    "b0Amount": "8",
    "totalBAmount": "24",
    "totalAmount": "1000000000",
    "logoUrl": "https://static.four.meme/market/68b871b6-96f7-408c-b8d0-388d804b34275092658264263839640.png",
    "tradeLevel": ["0.1", "0.5", "1"],
    "status": "PUBLISH",
    "buyTokenLink": "https://pancakeswap.finance/swap",
    "reservedNumber": 10,
    "saleRate": "0.8",
    "networkCode": "BSC",
    "platform": "MEME"
  }
}
```

回應：

```json
{
  "code": "0",
  "data": {
    "createArg": "encoded parameters for blockchain",
    "signature": "signature for blockchain transaction"
  }
}
```

## 3. 請求參數

### 3.1 可自訂

| 參數 | 說明 | 備註 |
|------|------|------|
| `name` | 代幣名稱 | 自訂 |
| `shortName` | 代號 | 自訂 |
| `desc` | 描述 | 自訂 |
| `imgUrl` | 圖片 URL | 必須來自平台上傳 |
| `launchTime` | 發射時間戳（毫秒） | 自訂 |
| `label` | 分類 | 其一：Meme / AI / Defi / Games / Infra / De-Sci / Social / Depin / Charity / Others |
| `lpTradingFee` | LP 交易費 | 固定為 `0.0025` |
| `webUrl` / `twitterUrl` / `telegramUrl` | 連結 | 自訂 |
| `preSale` | 創建者預買計價額 | 無則 `"0"` |
| `feePlan` | AntiSniperFeeMode | `true` 啟用動態開盤手續費 |
| `tokenTaxInfo` | 稅收代幣設定 | 非稅收代幣則省略 |

### 3.2 固定／第三方不可自訂

| 參數 | 固定值 | 備註 |
|------|--------|------|
| 總供應量 | `1000000000` | 10 億 |
| 募集額 | `24` | BNB 募集為 24 BNB |
| 銷售比例 | `0.8` | 80% |
| 保留比例 | `0` | |
| 代號／募集資產 | 平台配置 | 預設 BNB 募集 |

募集代幣預設可從以下讀取：

`https://four.meme/meme-api/v1/public/config`

第三方不得自創內部募集參數；請複製所選計價的公開 `raisedToken` 配置。

### 3.3 `feePlan`（AntiSniperFeeMode）

當 `feePlan` 為 `true` 時，代幣使用開盤區塊較高、之後逐塊遞減的動態手續費。見 [Product Update 25-10-30](https://four-meme.gitbook.io/four.meme/product-update/6-product-update-25-10-30)。未來發射的手續費表可能調整。

### 3.4 `tokenTaxInfo`

費率為百分比（例如 `5` = 5%）。

| 欄位 | 備註 |
|------|------|
| `feeRate` | 創建 API 百分比選項：必須為 `1`、`3`、`5`、`10` 之一。後端在組裝 `createArg` 時轉為鏈上 TaxToken（type 5）的 **basis points**（例如 API `5` → 鏈上 `500`），稅金按 `amount * feeRate / 10000` 計算 |
| `burnRate` / `divideRate` / `liquidityRate` / `recipientRate` | 自訂百分比；**總和必須為 100** |
| `giggleCharityRate` / `binanceCharityRate` | TaxToken9 慈善分配百分比。任一可為 `0`；支援時須將兩者計入分配總和 |
| `recipientAddress` | `recipientRate` 的收款地址；未使用時用 `""` 且 `recipientRate: 0` |
| `minSharing` | 參與分紅的最低持倉（ether 單位）。形式 `d × 10ⁿ`，且 `n ≥ 5`、`1 ≤ d ≤ 9` |

約束範例：

`burnRate(20) + divideRate(30) + liquidityRate(40) + recipientRate(10) = 100`

TaxToken8／TaxToken9 創建後的識別、買賣稅欄位與 TaxToken9 慈善限制，見[稅收代幣接入](./tax-guide.md)。

## 4. 鏈上提交

API 回傳 `createArg` 與 `signature` 後：

```solidity
function createToken(bytes calldata args, bytes calldata signature) external payable;
```

```typescript
const tm2 = new Contract(TOKEN_MANAGER_2, CreateAbi, signer);
const tx = await tm2.createToken(createArgBytes, signatureBytes, {
  // 依當前平台規則納入創建費 / preSale 的 value
  value: creationValue,
});
const receipt = await tx.wait();
```

從 receipt 解碼 `TokenCreate`：

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
```

說明：

1. 創建需要足夠 BNB。文件中最新創建費參考：**0.01 BNB**（平台費用可能變更；提交時以 API / `msg.value` 要求為準）。
2. 多數技術發射參數由平台固定。
3. 展示欄位（名稱、代號、描述、圖片、連結、分類）是主要自訂面。
4. `lpTradingFee` 必須保持 `0.0025`。

## 5. 創建之後

1. 索引 `TokenCreate` 取得 `token` + `requestId`。
2. 用 Helper3 `getTokenInfo(token)` 做交易路由發現。
3. 若配置了稅收，依 [稅收代幣接入](./tax-guide.md) 做識別與領取。

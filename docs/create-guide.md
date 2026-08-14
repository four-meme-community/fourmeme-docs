# Four.Meme Classic Create Integration

This guide covers creating classic Four.Meme tokens via the backend API and submitting `TokenManager2.createToken` on-chain.

See also:

- [Integration Guide](./integration-guide.md)
- [Trade Integration](./trade-guide.md)
- [Tax Integration](./tax-guide.md)

Lite artifacts:

- ABI: [`../abi/TokenManager2.lite.json`](../abi/TokenManager2.lite.json) (`createToken` + trade surface)
- Interface: [`../contracts/interfaces/ITokenManager2.sol`](../contracts/interfaces/ITokenManager2.sol)

**TokenManager2 (BSC):** `0x5c952063c7fc8610FFDB798152D69F0B9550762b`

New tokens are created on V2 only. V1 TokenManager is not used for new launches.

## 1. End-to-End Flow

```text
1. POST /v1/private/user/nonce/generate
2. Sign login message, POST /v1/private/user/login/dex  -> access_token
3. POST /v1/private/token/upload                         -> imgUrl
4. POST /v1/private/token/create                         -> createArg + signature
5. TokenManager2.createToken(createArg, signature)       -> TokenCreate event
```

Base host: `https://four.meme/meme-api`

## 2. API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v1/private/user/nonce/generate` | POST | Generate login nonce |
| `/v1/private/user/login/dex` | POST | Login and receive access token |
| `/v1/private/token/upload` | POST | Upload token image |
| `/v1/private/token/create` | POST | Build signed create payload |

### 2.1 Get nonce

`POST https://four.meme/meme-api/v1/private/user/nonce/generate`

```json
{
  "accountAddress": "user wallet address",
  "verifyType": "LOGIN",
  "networkCode": "BSC"
}
```

Response:

```json
{
  "code": "0",
  "data": "generated nonce value"
}
```

### 2.2 Login

`POST https://four.meme/meme-api/v1/private/user/login/dex`

Sign the message `You are sign in Meme {nonce}` with the user wallet private key.

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

Response `data` is the `access_token` string.

### 2.3 Upload image

`POST https://four.meme/meme-api/v1/private/token/upload`

Headers:

- `Content-Type: multipart/form-data`
- `meme-web-access: {access_token}`

Body: `file` image (jpeg, png, gif, bmp, webp).

Response `data` is the hosted image URL. Images must be uploaded to the Four.Meme platform; arbitrary external URLs are not accepted as `imgUrl`.

### 2.4 Create token (get signature)

`POST https://four.meme/meme-api/v1/private/token/create`

Headers:

- `meme-web-access: {access_token}`
- `Content-Type: application/json`

Example body:

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

Response:

```json
{
  "code": "0",
  "data": {
    "createArg": "encoded parameters for blockchain",
    "signature": "signature for blockchain transaction"
  }
}
```

## 3. Request Parameters

### 3.1 Customizable

| Parameter | Description | Notes |
|-----------|-------------|-------|
| `name` | Token name | Custom |
| `shortName` | Symbol | Custom |
| `desc` | Description | Custom |
| `imgUrl` | Image URL | Must come from platform upload |
| `launchTime` | Launch timestamp (ms) | Custom |
| `label` | Category | One of: Meme / AI / Defi / Games / Infra / De-Sci / Social / Depin / Charity / Others |
| `lpTradingFee` | LP trading fee | Fixed at `0.0025` |
| `webUrl` / `twitterUrl` / `telegramUrl` | Links | Custom |
| `preSale` | Creator pre-buy quote amount | `"0"` if none |
| `feePlan` | AntiSniperFeeMode | `true` enables dynamic opening fees |
| `tokenTaxInfo` | Tax token config | Omit for non-tax tokens |

### 3.2 Fixed / non-customizable by third parties

| Parameter | Fixed value | Notes |
|-----------|-------------|-------|
| total supply | `1000000000` | 1B |
| raised amount | `24` | 24 BNB for BNB raises |
| sale rate | `0.8` | 80% |
| reserve rate | `0` | |
| symbol / raise asset | platform config | Default BNB raise |

Raised-token presets can be read from:

`https://four.meme/meme-api/v1/public/config`

Third parties must not invent custom internal raise parameters; copy the published `raisedToken` config for the chosen quote.

### 3.3 `feePlan` (AntiSniperFeeMode)

When `feePlan` is `true`, the token uses a dynamic fee that starts higher at opening blocks and decreases block by block. See [Product Update 25-10-30](https://four-meme.gitbook.io/four.meme/product-update/6-product-update-25-10-30). Fee schedules may be adjusted for future launches.

### 3.4 `tokenTaxInfo`

Rates are percentages (for example `5` = 5%).

| Field | Notes |
|-------|-------|
| `feeRate` | Create-API percentage option: must be one of `1`, `3`, `5`, `10`. Backend converts to on-chain TaxToken (type 5) **basis points** when building `createArg` (e.g. API `5` → on-chain `500`), then tax is applied as `amount * feeRate / 10000` |
| `burnRate` / `divideRate` / `liquidityRate` / `recipientRate` | Custom percentages; **sum must equal 100** |
| `recipientAddress` | Recipient for `recipientRate`; use `""` and `recipientRate: 0` if unused |
| `minSharing` | Min holder balance (ether units) to join dividends. Form `d × 10ⁿ` with `n ≥ 5`, `1 ≤ d ≤ 9` |

Example constraint:

`burnRate(20) + divideRate(30) + liquidityRate(40) + recipientRate(10) = 100`

For New TaxToken (token8) identification and buy/sell tax fields after creation, see the [Tax Integration](./tax-guide.md).

## 4. On-chain Submission

After the API returns `createArg` and `signature`:

```solidity
function createToken(bytes calldata args, bytes calldata signature) external payable;
```

```typescript
const tm2 = new Contract(TOKEN_MANAGER_2, CreateAbi, signer);
const tx = await tm2.createToken(createArgBytes, signatureBytes, {
  // include creation fee / preSale value as required by current platform rules
  value: creationValue,
});
const receipt = await tx.wait();
```

Decode `TokenCreate` from the receipt:

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

Notes:

1. Creation requires sufficient BNB balance. Latest documented creation fee reference: **0.00 BNB** (platform fees may change; treat API/`msg.value` requirements as source of truth at submit time).
2. Most technical launch parameters are platform-fixed.
3. Display fields (name, symbol, description, image, links, label) are the main custom surface.
4. `lpTradingFee` must remain `0.0025`.

## 5. After Creation

1. Index `TokenCreate` for `token` + `requestId`.
2. Use Helper3 `getTokenInfo(token)` for trading route discovery.
3. If tax was configured, follow [Tax Integration](./tax-guide.md) for identification and claims.

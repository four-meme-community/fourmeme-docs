# Four.Meme Classic 文檔

語言：[English](../../README.md) | 繁體中文

經典版 Four.Meme 發射協議（TokenManager / TokenManager2 / Helper）的第三方接入文檔，與 [OpenFour](https://github.com/four-meme/openfour-docs) 分開維護。

面向錢包、交易 UI、DEX 聚合器、索引器、資料後端與發射平台。僅涵蓋已部署協議的公開使用方式，不包含協議內部實作、bonding curve 演算法、管理員操作或自訂模組開發。

## 文件

- [接入總覽](./integration-guide.md)：地址、V1/V2 路由、代幣識別、遷移後路由，以及各細節指南連結。
- [交易接入](./trade-guide.md)：買賣、預估、Helper3、事件、錯誤碼、AntiSniper 識別。
- [創建接入](./create-guide.md)：後端創建 API 流程與鏈上 `createToken` 提交。
- [稅收代幣接入](./tax-guide.md)：TaxToken / TaxToken8 識別、領取與公開稅收狀態。

## 合約與 ABI

| 路徑 | 內容 |
|------|------|
| [`../../contracts/interfaces/`](../../contracts/interfaces/) | 面向接入的精簡 Solidity 介面 |
| [`../../abi/`](../../abi/) | 精簡 JSON ABI（僅公開方法與事件） |

管理員、升級與內部運營介面已省略。

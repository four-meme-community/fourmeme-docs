# Four.Meme Classic Documentation

Language: English | [繁體中文](./docs/zh-Hant/README.md)

English integration docs for the classic Four.Meme launch protocol (TokenManager / TokenManager2 / Helper), separate from [OpenFour](https://github.com/four-meme/openfour-docs).

These docs are for third-party integrators: wallets, trading UIs, DEX aggregators, indexers, data backends, and launch platforms. They cover deployed protocol usage only. They do not cover protocol internals, bonding-curve algorithms, admin operations, or custom module development.

## Documents

- [Integration Guide](./docs/integration-guide.md): overview — addresses, V1/V2 routing, token identification, migration routing, and links to detail guides.
- [Trade Integration](./docs/trade-guide.md): buy/sell, estimates, Helper3, events, errors, AntiSniper identification.
- [Create Integration](./docs/create-guide.md): backend create API flow and on-chain `createToken` submission.
- [Tax Integration](./docs/tax-guide.md): TaxToken / TaxToken8 identification, claims, and public tax state.

## Contracts and ABI

| Path | Contents |
|------|----------|
| [`contracts/interfaces/`](./contracts/interfaces/) | Lite Solidity interfaces for integration |
| [`abi/`](./abi/) | Lite JSON ABIs (integration-facing methods and events only) |

Admin, upgrade, and internal operator surfaces are omitted.

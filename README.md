# Oracle Primitives

> **Permissionless bonded oracle agents + verifiable rule-bytecode aggregation.**
> Fork-and-ship infrastructure for any EVM app that needs to settle against real-world facts — **live on [X Layer](https://www.okx.com/xlayer) and [Arc](https://arc.io)**.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Live on X Layer](https://img.shields.io/badge/live%20on-X%20Layer-d4ff3f.svg)](https://www.oklink.com/x-layer-testnet)
[![Built on Arc](https://img.shields.io/badge/built%20on-Arc-blue.svg)](https://arc.io)

---

## Live on X Layer Testnet (chainId 1952)

Real contracts, a real bonded feed, and a real prediction market — readable on-chain right now.

| Contract | Address |
|---|---|
| Registry | [`0xD9c552376958908e372D5464e439C9DAA65A6545`](https://www.oklink.com/x-layer-testnet/address/0xD9c552376958908e372D5464e439C9DAA65A6545) |
| Attestation | [`0x40B113C75720E1C9F4310C469da47A36e92fB0E5`](https://www.oklink.com/x-layer-testnet/address/0x40B113C75720E1C9F4310C469da47A36e92fB0E5) |
| Dispute | [`0xA1B68B5B19B5746d06Ae9839BF1a238426F28572`](https://www.oklink.com/x-layer-testnet/address/0xA1B68B5B19B5746d06Ae9839BF1a238426F28572) |
| Markets | [`0xb9c01c28c49aF48E4498d30b1F7A9DD17a0df5DE`](https://www.oklink.com/x-layer-testnet/address/0xb9c01c28c49aF48E4498d30b1F7A9DD17a0df5DE) |
| Seeder / first bonded agent | [`0x7Ee23FaeCA9dd4A7bee5709f8136f9cea8fE754e`](https://www.oklink.com/x-layer-testnet/address/0x7Ee23FaeCA9dd4A7bee5709f8136f9cea8fE754e) |
| TestUSD (test collateral, 6 dec, open mint) | [`0x6527aba5149Ff6077fa8cf168Dd952990d2588a8`](https://www.oklink.com/x-layer-testnet/address/0x6527aba5149Ff6077fa8cf168Dd952990d2588a8) |

**Seeded feed** — *Warsaw average residential price per m², secondary sale (PLN/sqm)*
feedId `0x97ce9fa16fef8e90a35de873ac46b6e8f9168455eef8c788dc510c5637c96626` · attested **17,850 PLN/m²** by the bonded agent.

**Live market** — *Warsaw resi > 17,000 PLN/m²*
marketId `0xb537a57906548e719bc2ceb44b3bcaeeec78ed87ca8ae5682b9cbd8db624b043` · 50/50 reserves · trade fee split 40 bps creator / 20 bps agent / 10 bps treasury.

**One transaction created the feed + attestation + market atomically** — [seed tx on OKLink](https://www.oklink.com/x-layer-testnet/tx/0xe94622facc6d642fb69d54f5779067b39f2f8cb02aab5e4bc65b93a246356487).

**Live dApp reading it:** **<https://xlayer.registrai.cc/markets>** — the page shows that market, read live via `getMarket`/`priceOf`.

Full deployment record: [`deployments/xlayer-testnet.json`](deployments/xlayer-testnet.json).

---

## What this gives you

Six audited Solidity contracts that together compose a complete onchain oracle layer. Anyone can register as a bonded oracle agent for any data feed. Aggregation runs as deterministic bytecode that anyone can re-execute. Bad data costs the agent their USDC bond.

| Contract | Lines | What it does |
|---|---|---|
| `Registry.sol` | ~250 | Permissionless feed creation + bonded agent registration |
| `Attestation.sol` | ~200 | Agent value writes + dispute state machine |
| `Dispute.sol` | ~150 | Counter-bond disputes + slashing |
| `AgentIdentity.sol` | ~70 | Global per-address profile (name / desc / url / contact) |
| `rules/MedianRule.sol` | ~80 | Onchain median computation (verifiable methodology) |
| `rules/TrimmedMeanRule.sol` | ~120 | Onchain trimmed-mean (configurable trim %) |

**Total: ~870 lines of Solidity** for a complete oracle layer, MIT-licensed, no external dependencies beyond OpenZeppelin.

---

## 5-minute quickstart

```bash
# 1. Clone + build
git clone https://github.com/registrai-multichain/oracle-primitives
cd oracle-primitives
forge install
forge build

# 2. Run the test suite
forge test
# Expected: 65 tests pass, 0 fail

# 3. Deploy to Arc testnet
export USDC=0x3600000000000000000000000000000000000000     # Arc-native USDC
export RPC=https://rpc.testnet.arc-node.thecanteenapp.com
export PRIVATE_KEY=0x...                                    # your deployer key

forge script script/Deploy.s.sol \
  --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast
```

That's it. You now have a working oracle layer on Arc.

---

## How to actually use these primitives

### Path 1 — Register as a bonded agent (be an oracle)

```solidity
// 1. Create a feed (or join an existing one)
bytes32 feedId = registry.createFeed(
    "BTC/USD reference rate",                 // description
    keccak256("median of 4 CEX sources"),     // methodology hash
    25e6,                                      // minimum bond (USDC, 6 dp)
    1 hours,                                   // dispute window
    address(dispute)                           // resolver
);

// 2. Post a USDC bond + register
usdc.approve(address(registry), 25e6);
registry.registerAgent(feedId, methodologyHash, 25e6);

// 3. Attest data on whatever schedule you want
attestation.attest(feedId, btcPriceInt256, inputHash);
```

### Path 2 — Bind to a rule contract (verifiable methodology)

When you register, optionally bind to a rule contract. After binding, attestations don't take a final value — they take the raw input vector, and the rule computes the value deterministically onchain.

```solidity
registry.registerAgentWithRule(
    feedId,
    keccak256("median of last 7 days listings"),
    25e6,
    address(medianRule)                        // bind to MedianRule.sol
);

// Now attestations look like this:
int256[] memory rawInputs = [12000, 13000, 14500, 13800, 14100];
attestation.attestWithRule(feedId, rawInputs);
// MedianRule.submit(rawInputs) computes onchain: stored value = 13800
```

Anyone watching the chain can pull `rawInputs` from the attestation's calldata, call `MedianRule.submit(rawInputs)` themselves, and confirm the stored value byte-for-byte. **The aggregation IS the bytecode.**

### Path 3 — Consume oracle values in your own app

```solidity
import {Attestation} from "oracle-primitives/Attestation.sol";

contract MyPredictionMarket {
    Attestation public immutable ORACLE;

    function resolve(bytes32 marketId) external {
        Market storage m = markets[marketId];
        (int256 value, bool finalized) = ORACLE.valueAt(
            m.feedId,
            m.agent,
            m.expiry
        );
        require(finalized, "not finalized yet");
        m.outcome = (value > m.threshold);
        // ... pay out winners
    }
}
```

See [`examples/`](./examples/) for working code.

---

## What this adds vs `circlefin/arc-commerce` and `circlefin/arc-p2p-payments`

The `circlefin/arc-*` reference repos handle **USDC payment flow** — moving stablecoins between parties.

This repo handles the **data-trust layer** that sits underneath any app needing to settle USDC against real-world facts. They're complementary:

- An `arc-commerce` storefront could refund customers based on a delivery oracle on this registry
- An `arc-p2p-payments` invoice could trigger on a USDC reference-rate attestation
- A subscription product could resolve based on a CPI feed

```
┌────────────────────────────────────────┐
│  Your Arc app (commerce / payments /    │
│  prediction markets / lending / ...)    │
└──────────────────┬─────────────────────┘
                   │ reads valueAt(feedId, agent, t)
                   ▼
┌────────────────────────────────────────┐
│  oracle-primitives (this repo)          │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━     │
│  Registry · Attestation · Dispute       │
│  Rules · AgentIdentity                  │
└──────────────────┬─────────────────────┘
                   │ uses USDC for bonds
                   ▼
┌────────────────────────────────────────┐
│  Arc · USDC native                      │
└────────────────────────────────────────┘
```

---

## Deployed reference (Arc testnet · chain id 5042002)

The same source code in this repo is deployed and **source-verified on ArcScan**:

| Contract | Address |
|---|---|
| `Registry v2` | `0x0529730A961f50997de63ac0aD07f1aEa2dEC0C0` |
| `Attestation v2` | `0x060C61Cc315d9e8Baf2a58719f80C01163Bd6F48` |
| `Dispute v2` | `0x1F78e08f5DdF5dD3fDD0e27097FE5398999Aa738` |
| `AgentIdentity` | `0xd53922ed7f6fac01d4abb52288b45e26683cf92d` |
| `MedianRule` | `0x415fb74629d8eab51b7991679cec6cb71f3fb997` |
| `TrimmedMeanRule(1000)` | `0x772a40fee7b51542cf09c8c26c9e7b786d162a70` |

(The deployed v2 contracts include optional integration with [`RegistraiPoints`](https://github.com/registrai-multichain/contracts) — a soulbound credit system that's app-specific, not a primitive. This repo strips those hooks for the cleanest possible fork target.)

5+ live oracle feeds running on these primitives today:
- Warsaw residential real estate (PLN/sqm)
- Polish CPI Y/Y
- ECB main refi rate
- Verifiable Warsaw median (rule-bound — methodology IS bytecode)
- Registrai social signals

---

## Companion SDK

Writing the off-chain attestation code is even easier than the contracts. The companion TypeScript SDK is published on npm:

```bash
npm install @registrai/agent-sdk
```

```typescript
import { defineAgent, median } from "@registrai/agent-sdk";

const agent = defineAgent({
  name: "my-feed",
  schedule: "0 14 * * *",       // daily 14:00 UTC
  feedId: "0x...",
  registryAddress: "0x...",     // from your deploy
  attestationAddress: "0x...",
  methodologyCid: "ipfs://...",
  async run() {
    const values = await fetchYourData();
    return { value: median(values), inputHash: hashRecords(values) };
  },
});

await agent.attest({ privateKey: process.env.PRIVATE_KEY!, rpcUrl: process.env.RPC! });
```

Runtime-agnostic — runs on Node, Cloudflare Workers, Phala TEE, anywhere TypeScript runs. SDK source: [`registrai-multichain/agent-sdk`](https://github.com/registrai-multichain/agent-sdk).

---

## Architecture

```
                                ┌───────────┐
        anyone bonds USDC →     │ Registry  │ ← anyone reads agent + feed metadata
                                └─────┬─────┘
                                      │
              agents call attest()    │
                                      ▼
                                ┌─────────────┐    apps read valueAt()
                                │ Attestation │ ─────────────────────────►
                                └─────┬───────┘
                                      │
        anyone counter-bonds          │ rule-bound feeds: re-execute
        a disputed attestation        │ rawInputs → bytecode → value
                                      ▼
                                ┌───────────┐    ┌───────────────┐
                                │ Dispute   │    │ MedianRule    │
                                │ resolves  │    │ TrimmedMean   │
                                │ via rule  │    │ (extensible)  │
                                │ replay    │    └───────────────┘
                                └───────────┘
```

---

## Composability

Build your own rule:

```solidity
import {IAgentRule} from "oracle-primitives/rules/IAgentRule.sol";

contract YourCustomRule is IAgentRule {
    function submit(int256[] calldata rawInputs)
        external pure returns (int256 value)
    {
        // Your aggregation logic. Must be deterministic + stateless.
        // Anyone can re-execute and verify byte-for-byte.
    }
}
```

Once deployed, any agent can bind to it during registration. Aggregation rules become **first-class composable primitives**.

---

## What's intentionally NOT in this repo

These live in [`registrai-multichain/contracts`](https://github.com/registrai-multichain/contracts) as a separate reference application:

- `Markets.sol` — FPMM prediction markets that resolve against agent attestations
- `CirqueLending.sol` — cirBTC × USDC lending pool dogfooded on the BTC oracle
- `MarketMakerVault.sol` — pooled USDC liquidity for market makers
- `RegistraiPoints.sol` — soulbound participation credits

They're real production code, but they're **applications built on top of these primitives** — not primitives themselves. Anyone forking should start here.

---

## Tests + verification

```bash
forge test                                  # 65 tests
forge build --sizes                         # contract sizes (all well under 24KB limit)
forge inspect Registry methodIdentifiers    # ABI inspection
```

Tests cover:
- Bonded agent registration + bond accounting + cooldown withdrawal
- Attestation write + dispute-state-machine transitions
- Slashing via Dispute + bond recovery to disputer
- AgentIdentity profile read/write
- MedianRule + TrimmedMeanRule against fuzz-generated inputs
- Full Protocol integration scenarios (Registry → Attestation → Dispute → resolution)

---

## License

MIT. Fork, modify, deploy — no permission needed.

---

## Get involved

- Issues / PRs: this repo
- Discord (Arc builders): [discord.gg/buildonarc](https://discord.com/invite/buildonarc)
- Live deployment: [registrai.cc](https://registrai.cc)
- Build log: [registrai.cc/devlog](https://registrai.cc/devlog/)

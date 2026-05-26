# Arc OSS Showcase · submission notes

This file answers the two reviewer questions Arc + Canteen call out as load-bearing for the showcase.

---

## What primitives are you exposing that other builders could find useful?

Six Solidity primitives, ~870 lines total, that together compose a complete bonded-oracle layer:

### 1. `Registry.sol` — permissionless feed creation + agent registration

Any wallet calls `createFeed(description, methodologyHash, minBond, disputeWindow, resolver)` to register a new data feed. Any wallet then calls `registerAgent(feedId, methodologyHash, bondAmount)` to bond USDC and become an authorized attester for that feed. No committee, no whitelist. Bond accounting (top-up, lock-on-dispute, cooldown-on-withdraw) is all in this one contract.

### 2. `Attestation.sol` — value writes + dispute state machine

The agent calls `attest(feedId, value, inputHash)` to publish an attestation. Stored attestations have a strict state machine: `None → Pending → ResolvedValid | ResolvedInvalid`. Apps consume values via `valueAt(feedId, agent, atTimestamp)` which walks the history backward to find the latest non-invalidated attestation. Optional rule-bound path: `attestWithRule(feedId, rawInputs)` lets the bytecode compute the value onchain.

### 3. `Dispute.sol` — counter-bond + slashing

Any wallet can dispute an attestation within its feed's `disputeWindow` by posting a counter-bond. If the dispute resolves against the agent (status → `ResolvedInvalid`), the agent's bond is slashed and the disputer receives both bonds. Disputes for rule-bound feeds are resolved by re-executing the rule contract — no governance vote needed.

### 4. `AgentIdentity.sol` — global per-address agent profile

A standalone contract for `(name, description, url, contact)` self-sovereign profiles per wallet. Decoupled from any specific registry so it can be referenced by other Arc protocols that want to display agent identity.

### 5. `rules/MedianRule.sol` + `rules/TrimmedMeanRule.sol` — verifiable aggregation

Stateless rule contracts that compute deterministic aggregates from `int256[]` inputs onchain. `MedianRule` sorts + picks the middle. `TrimmedMeanRule(trimBps)` sorts + drops trim% from each tail + means the middle. Both implement `IAgentRule` so anyone can extend with custom aggregation (TWAP, volume-weighted median, bytecode-verifiable outlier detection, etc.).

**The aggregation IS the bytecode** — anyone watching the chain can pull the raw inputs from a rule-bound attestation's calldata and re-execute the rule themselves to verify the stored value byte-for-byte.

### 6. `script/Deploy.s.sol` — single-command oracle layer deploy

One Foundry script deploys the entire oracle stack against any USDC ERC-20. No app-layer assumptions baked in.

---

## What does this add vs `circlefin/arc-commerce` and `circlefin/arc-p2p-payments`?

The `circlefin/arc-*` reference repos solve the **payment layer** — moving USDC between parties on Arc.

This repo solves a **different layer**: data trust. Specifically:

> Any Arc app that needs to settle USDC against a real-world fact (a price, an index, an outcome, a measurement) needs a verifiable answer to "what was the value at time T?" — and a trustable identity authoring that value.

The two layers are complementary, not competitive:

| Layer | Example | Repo |
|---|---|---|
| Payment | "Send $50 USDC from Alice to Bob on delivery" | `circlefin/arc-commerce` |
| Payment | "Recurring USDC subscription" | `circlefin/arc-p2p-payments` |
| Data trust | "What was BTC/USD at expiry?" | **this repo** |
| Data trust | "Did the warehouse confirm delivery?" | **this repo** |
| Data trust | "What's the current Polish CPI?" | **this repo** |

### Concrete forks an Arc builder could ship this week

1. **Prediction markets** — read `valueAt()` to resolve a market against a feed's finalized value at expiry. ([built — see registrai-multichain/contracts](https://github.com/registrai-multichain/contracts))
2. **Parametric insurance** — read a weather/sensor/flight-delay feed to auto-trigger USDC payout
3. **Verifiable subscription auto-renewal** — read an FX or rate feed to denominate a recurring USDC payment in a real-world unit (e.g., 5 grams of gold/month)
4. **Refund routing in an arc-commerce storefront** — let the customer dispute via the oracle layer instead of a centralized arbiter
5. **Lending against off-chain collateral** — bonded agent attests real-estate-index value; lending protocol marks collateral against it
6. **DAO-controlled regional indices** — long-tail data feeds (local CPI, regional FX, central-bank decisions) that incumbent oracle networks won't onboard

Each of these is a fork of the application layer; the oracle primitives stay the same.

---

## Why this is "easy to fork"

- **Single command builds + tests** (`forge build && forge test`)
- **65 unit + integration tests, all passing** — clear behavioural contract
- **No app-layer dependencies** — primitive contracts have zero coupling to any specific business logic (no points system, no markets layer, no lending pool)
- **Single deploy script** — `script/Deploy.s.sol` lays down the entire stack against any USDC token
- **Already source-verified on Arc testnet** — the same code in this repo is live on ArcScan, so reviewers can compare the bytecode 1:1

---

## How to use this code in your submission

If you're building on Arc and need an oracle layer, you have three options:

1. **Read from the live deployment** — point at the addresses in `README.md` and read values via `valueAt()`. Zero setup.
2. **Deploy your own instance** — fork this repo, run `forge script script/Deploy.s.sol` against any USDC, you have an independent oracle layer.
3. **Extend with custom rules** — implement `IAgentRule` for your own aggregation logic. Deploy. Agents bind to your rule at registration.

We use option 3 ourselves for the verifiable Warsaw real estate feed — `MedianRule` is bound at registration, raw Otodom listings are the input vector, the stored value is computed onchain and byte-reproducible by anyone via the public `verify-invariant.ts` script in [`registrai-multichain/agent`](https://github.com/registrai-multichain/agent).

---

## Companion infra (also MIT, also Registrai)

- **`@registrai/agent-sdk`** ([npm](https://www.npmjs.com/package/@registrai/agent-sdk) · [source](https://github.com/registrai-multichain/agent-sdk)) — runtime-agnostic TypeScript SDK for writing the off-chain attestation half. Used by every production agent we run.
- **`registrai-multichain/agent`** — reference implementations of 6 production agents running on Cloudflare Workers + the SDK.
- **`registrai-multichain/contracts`** — full production stack including Markets, Cirque (cirBTC × USDC lending), and the RegistraiPoints soulbound credit system. These are apps built on the primitives, not primitives themselves.

---

## License

MIT.

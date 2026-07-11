# Proof of Pulse — Idea-Level Design Review

Date: 2026-07-11.

Scope: this reviews the product idea and trust model, not the implementation. It was produced by a multi-agent review across six lenses — data provenance, Sybil economics, privacy/regulatory/platform policy, market and competition, protocol/identity architecture, and product strategy — each grounded in independent web research, followed by an adversarial verification pass that refuted, weakened, or sharpened individual findings. The provenance, market, and strategy lenses were fully adversarially verified; the Sybil-economics, privacy, and protocol lenses were reviewed but their challenge pass did not complete, so treat their external citations with slightly lower confidence.

The repo's own docs are unusually honest about known limits (unsigned HealthKit data, App Attest scope, ZK input-truth gap, liveness ≠ uniqueness). This review deliberately goes past those documented limits; where a finding merely restated them, it was cut or downgraded.

## Verdict

The layered architecture (liveness / integrity / uniqueness kept separate) is sound and the epistemic discipline of the docs is a real asset. But as a **proof-of-personhood product**, the idea fails on four independent axes at once: the trust root cannot support the claim, the economics invert (honest users pay more than attackers), Apple's HealthKit rules structurally prohibit the business model for non-health verifiers, and the market is being commoditized from below (Private Access Tokens) and above (World ID, EUDI Wallet) simultaneously.

The same technology stack has one commercially and policy-durable lane: **wearable activity-data integrity for incentivized health/fitness programs**, where the verifier's purpose is itself health/fitness (satisfying Apple 5.1.3), the fraud is documented and quantified, attacker cost only needs to exceed per-unit reward value, and the ZK layer becomes a genuine selling point ("we provably never receive members' health data"). The proof-of-unique-humanity ambition should live on as a standards/research contribution and vision narrative — not as a shipped product claim until a signed trust root exists.

There is also one significant architectural upgrade the current roadmap misses entirely: an **App Attest-attested watchOS app measuring live heart rate in-process** (see S1 below), which is the strongest provenance improvement reachable without any Apple policy change.

---

## Part 1 — Weaknesses

Ranked by how directly each can kill the idea.

### W1. The real residual attack is physical spoofing of a genuine Apple Watch — and no layer in the design even addresses it (critical, adversarially confirmed)

The docs frame the provenance threat as synthetic *data injection* and mitigate with source/metadata filtering. The cheaper, undetectable attack injects nothing: it makes a real Watch emit genuine samples with no living account-holder attached. Shaker rigs, pendulums, and phone-on-bicycle-crank setups are a commoditized economy from move-to-earn cheating (Sweatcoin/STEPN); Apple Watch PPG famously registers "heart rate" from bananas and toilet-paper rolls because the sensor cannot distinguish skin-like reflective surfaces. When samples come from a real rigged or borrowed-wrist Watch, **every defensive layer passes honestly**: the source really is Apple, `WasUserEntered` really is false, App Attest really attests a genuine app, and the ZK proof really is valid. Nothing is forged, so nothing is detectable.

The threat model lists "device-farm attacker using real or borrowed Apple Watches" as an adversary, but none of its ~17 mitigations touches this attack — the entire mitigation stack targets data injection. Sharpening from the verification pass: background HR logging requires Wrist Detection to pass, so a farm unit needs a warm skin-like sleeve or rotation across real wrists, plus a paired iPhone and Apple ID — per-unit cost is low hundreds of dollars on the used market, fully resellable, amortized across every account the unit refreshes per epoch. This attack also poisons the endgame: a farm of once-enrolled watches supplies indefinite "liveness refresh" to *sold* unique-humanity credentials, which is exactly the account-resale threat the freshness layer exists to counter.

**Consequence:** the security of a Pulse Proof is purely economic, never cryptographic. It holds only while the value gated per account stays below roughly the amortized cost of a rigged watch — and the moment tokens or rewards attach to it, the Sweatcoin/STEPN anti-fraud arms race is the operating model, not the exception.

### W2. Apple's HealthKit rules structurally prohibit the business model for non-health verifiers (critical, adversarially confirmed)

The README calls App Review risk "material"; it is worse than that — it is a purpose conflict written into three guidelines, and it cannot be fixed with careful copy because **the disclosure to a third-party verifier is the product**:

- **2.5.1**: HealthKit "should be used for health and fitness purposes and integrate with the Health app." Account verification is neither.
- **5.1.3(i)**: prohibits using or disclosing health-context data to third parties for purposes "other than improving health management… or health research." A liveness tier derived from heart-rate/activity samples, delivered to a dating app or an airdrop, is exactly the prohibited disclosure. The ZK layer does not help: the rule is purpose-based, not granularity-based — a derived attestation is still health-context data used for a non-health purpose. The verification pass confirmed 5.1.3 also covers Motion & Fitness data, closing the "just use CoreMotion instead" escape hatch.
- **5.1.2(vi)**: bars HealthKit data from use-based data mining including by third parties — a fair description of an anti-bot scoring service.

The three possible framings all fail for non-health verticals: the honest framing ("health data becomes an access credential") fails 2.5.1/5.1.3 on its face; the wellness-app-on-the-surface framing is a concealed-functionality risk (2.3.1) that endangers the entire developer account; the research framing (TestFlight + ethics board) is honest and available but caps the product at research scale. There is no web/sideload fallback that preserves an App Attest + HealthKit trust story (the EU DMA path is untested for HealthKit-entitled apps and irrelevant to the primary market). And Apple is not a neutral gatekeeper here — it ships its own humanity-adjacent primitives (Private Access Tokens, App Attest, passkeys), so rejection can be strategic, not just procedural.

**Consequence:** every pivot in which HealthKit-derived output gates a non-health service carries platform-termination risk as a permanent overhang. The only claim-shapes safely inside the fence are ones where the verifier's own purpose is health/fitness management.

### W3. Sybil economics invert: the honest user pays more than the attacker (critical)

Sound Sybil resistance needs attacker-cost-per-identity to exceed both the per-identity reward and, ideally, the honest user's cost. Proof of Pulse inverts both. An honest participant needs an iPhone plus an Apple Watch (≥$239 new). An attacker buys used ($60–120 per watch), resells afterward, and amortizes across accounts. In the airdrop/UBI scenarios the vision gestures at, per-account rewards routinely exceed farming cost; the World ID precedent shows where personhood markets actually clear — verified credentials resold for ~$30. Because nothing binds a human *body* to a credential, one wrist rotating through a rack of watches backs unlimited genuine, non-replayed proofs; recurring liveness refresh converts that into a small recurring tax (the rent-a-wrist clearing price), not a barrier.

Two dominance problems compound it:

- The one real economic floor — genuine Apple hardware — is created by **App Attest, not HealthKit**. App Attest + DeviceCheck alone deliver most of the attacker cost with none of the health-data regulatory exposure or the second-device tax on honest users.
- On top of a World ID-style uniqueness root, the marginal value of watch-backed liveness is dominated by cheaper signals: periodic re-liveness at the root (World ID 4.0's Face Auth binds the refresher to the *enrolled* human — Pulse structurally cannot), device-recency signals, and free behavioral Sybil clustering.

**Consequence:** for high-value distribution, the proof is security theater. The economically coherent regime is narrow: mid-value bot friction where per-account value sits below the rent-a-wrist price, layered on someone else's uniqueness root — or fraud contexts priced in cents per unit (see S2).

### W4. The health-derived proof is special-category data everywhere, and its legal basis collapses exactly when the product succeeds (critical, challenge pass incomplete)

Keeping raw data on-device is necessary but does not exit GDPR Art. 9. CJEU case law (OT C-184/20; Lindenapotheke C-21/23) treats any data "liable indirectly to reveal" health status — including by deduction — as special-category. A pass/fail liveness tier deduced from cardiac/activity data qualifies; a "fail" plausibly reveals arrhythmia or disability. The structural trap: the realistic Art. 9 basis is explicit consent, and under Art. 7(4)/EDPB guidance consent is not freely given when service access is conditioned on unnecessary processing. So a relying party *requiring* a Pulse Proof invalidates the consent the scheme depends on — **the legal basis is inversely correlated with adoption**: viable as an optional badge, likely unlawful in the EU as a mandatory gate.

US exposure is faster-moving than the docs assume: Washington's My Health My Data Act covers derived vital-sign data with a private right of action and treble damages; transmitting proof status to a relying party is "sharing," and verifier fees around that sharing may constitute "sale," requiring per-sale authorization. Nevada, Connecticut, and New York have analogs; the FTC's Health Breach Notification Rule covers health apps drawing on HealthKit. The server-mediated "public proof lookup" endpoint in the current architecture looks like sharing; a holder-presents credential model (user presents directly to the verifier) is the defensible shape. Add the category's base rate: the World ID enforcement record (orders or bans in Spain, Germany, Kenya, Brazil, Indonesia, Philippines, Thailand) is the predictor for how "app reads your body before you may log in" is received, regardless of how much better the cryptography is.

### W5. The market is squeezed from both ends, coverage math forbids the "require it" case, and the natural pivot was just pre-empted (critical, adversarially confirmed)

- **Coverage:** ~170M active Apple Watches against ~4.5–5B smartphone users puts the global ceiling under ~4% of any verifier's audience, before subtracting users who refuse a HealthKit prompt from a non-health app. No verifier can ever gate on it; it can only be an optional positive stamp — and at that role it competes with Apple Private Access Tokens, which already attest "legitimate Apple device and account" invisibly and free on every iOS 16+ device.
- **Both ends commoditized:** below, PATs and Play Integrity give "real device, probably human" at zero cost; above, World ID sells verified uniqueness with ~18M holders and 2026 marquee integrations (Zoom, Tinder, DocuSign, Okta), and EUDI Wallet rollout is mandated across the EU from Nov 2026.
- **Two-sided cold start:** every surviving personhood system had either massive subsidy (World) or a captive demand side (Gitcoin Grants). The current architecture (own registry, own verifier spec, bespoke envelope) assumes exactly the standalone position where solo projects die; no repo document names a first relying party.
- **Pre-emption:** the most natural pivot — liveness-refresh layer for a personhood network — was substantially foreclosed in April 2026 when World ID 4.0 shipped device-side Face Auth with three-way matching to the *enrolled* human, and simultaneously open-sourced its SDK and Semaphore-style presentation layer, commoditizing Pulse's ZK differentiation at the same time. Pulse's refresh cannot detect credential resale (the farmer wears the watch); World's can.
- **No moat:** the mechanism uses only public APIs and public cryptography; Nymi has sold heartbeat authentication since 2013 with a *stronger* claim (ECG biometric, own sensor) and never escaped an enterprise niche. The parties best positioned to copy this (Apple, World) are also the platform owner and the incumbent.

### W6. The V1 protocol spends complexity in the wrong places (major, challenge pass incomplete)

Idea-level protocol problems, in decreasing order:

1. **The ZK score circuit is theater in its current configuration.** It hides a handful of low-entropy, self-computed buckets — while the draft envelope transmits the same `features` block in cleartext alongside the proof. Conditional on trusting the attested app (the only reason to believe the witness at all), a plain signed claim is exactly as sound. ZK at the scoring layer earns its keep only over *authenticated* inputs (signed samples as witnesses), which don't exist on this platform today.
2. **The issuer sits in the presentation path.** Proof-ID lookup plus verifier-named nullifier scopes gives the server the user's verifier-visit graph — the phone-home anti-pattern the VC/EUDI community has spent years eliminating — and at launch the anonymity set is so small that timing correlation deanonymizes most presentations anyway. App Attest assertion tracking (per-device, server-side) coexisting with "anonymous" membership verification on the same service is a structural tension the docs don't confront.
3. **No audience binding.** The challenge binds to the Pulse API, not the relying party's session, so within its window a valid proof is a bearer token replayable across verifiers. This is the gap OpenID4VP closes with client_id + nonce binding.
4. **Recovery is an unpriced Sybil channel and anonymity blocks revocation.** Device wipe → re-enroll mints a fresh commitment with no dedup, so the group is a set of *enrollments*, not humans; and when a farm enrolls 500 commitments, none can be individually revoked without identifying it. World ID 4.0's answer (biometric-anchored recovery that revokes prior authenticators, OPRF-based nullifiers surviving key rotation) shows what solving this actually costs — far beyond a small team, and only meaningful with a uniqueness root Pulse doesn't have.
5. **Verifier-chosen scope strings repeat World ID v3's known correlation mistake**, and monthly epochs make each nullifier a stable month-long pseudonym per verifier — epoch granularity is a privacy parameter the docs never analyze.
6. **Composition semantics invite over-reading.** The envelope has no machine-readable assurance level and no holder-binding field; a verifier seeing "zkVerified + membership valid + pass_high" will read the conjunction as stronger than its weakest layer.

### W7. Roadmap hopes that are dead ends, and two structural gaps nobody had priced (major)

- `HKMetadataKeyDigitalSignature` is a CMS path for pre-registered tamper-resistant *medical* devices whose keys the verifier holds; Apple publishes no Watch signing key and consumer Watch samples don't carry signatures. It is architecturally the wrong mechanism, not a pending upgrade. **SensorKit** is entitlement-gated to IRB-approved research studies and explicitly unavailable to commercial apps. Neither backlog item will ever upgrade the trust root; the roadmap should record both as closed.
- **iCloud Health sync is a Sybil multiplier no doc mentions:** Health data syncs to every device on the same Apple ID and restores onto new devices, so one real person's Watch history can back proofs from several distinct App-Attested devices simultaneously — no spoofing, no jailbreak, undetectable by a store-read architecture.
- Per-field metadata trust is lumped together: `HKSource` is bundle-bound by the system at save time (an App Store app genuinely cannot forge the Apple source — this filter has real teeth on stock iOS, more than the docs credit), while `HKDevice` and `WasUserEntered` are attacker-supplied strings/booleans (worthless as evidence). Scoring should weight only the bundle-bound signal. The simulator is not a clean bypass (App Attest is unsupported there) — *unless* the planned "unsupported-device fallback path" accepts unattested submissions, which is the actual design decision to flag. Jailbroken devices minting Apple-sourced samples remain the cheapest scalable injection path.
- Exclusion is an equity problem, not an "assurance level": failure states correlate with poverty (no Watch), disability (arrhythmia, pacemakers, beta-blockers, limb difference), and documented PPG reliability gaps (darker skin tones, tremor). A verifier-visible "fail" is itself a sensitive inference. Nothing currently stops the most harmful deployment (sole gate), which is also the most commercially attractive one.

---

## Part 2 — Ways to make the product stronger

### S1. Attested watchOS live measurement — the strongest reachable trust upgrade (missing from the roadmap)

App Attest works in watchOS 9+ app extensions. A companion watchOS app can run an `HKWorkoutSession`, read live heart-rate **in-process on genuine Watch hardware**, and sign challenge-bound measurements it took itself — upgrading the claim from "the phone's HealthKit store contained plausible samples" to "an Apple-attested binary on a genuine Watch measured this live." That eliminates the entire store-injection / third-party-writer / jailbroken-store / iCloud-sync attack class in one move, leaving only physical PPG spoofing (W1). It costs watch-app adoption friction and battery, and 5.1.3 still applies — but it is the single biggest provenance improvement available without any Apple roadmap change, and it should replace the closed digital-signature/SensorKit backlog items as the provenance workstream.

### S2. Pivot the commercial wedge to activity-data integrity for incentivized fitness/wellness

This is the one lane that survives every weakness above simultaneously:

- **Apple-durable:** the verifier's purpose is itself health/fitness management, so 5.1.3 is satisfied rather than fought (W2 dissolves).
- **Economically coherent:** insurer-linked programs (Vitality-style premium discounts) and cash-stakes games (StepBet, HealthyWage) lose real dollars to documented cheating (phone cradles, shaker rigs, user-entered data); the proof only needs to raise attacker cost above per-unit reward value, which coarse provenance + continuity + plausibility scoring genuinely does (W1/W3 become manageable instead of fatal).
- **Cold start dissolves:** wellness platforms already distribute their own iOS apps to reward-eligible users and already hold the HealthKit relationship. The deliverable becomes an **SDK/spec plus verification service** embedded in the platform's app — one B2B contract creates both sides of the market (W5's two-sided problem disappears; the consumer app becomes a reference client).
- **ZK finally earns its keep:** "we filter fraud while provably never receiving members' health data" is a real differentiator for insurer privacy postures, and it strengthens the GDPR position instead of fighting it (W4 cuts *for* this wedge).
- **Honest claim:** "on-device, privacy-preserving activity integrity: recent, continuous, wearable-consistent, free of user-entered or implausible data — proven without uploading raw health data." Every word is deliverable by the current architecture.

Caveat from the verification pass: stratify discovery calls by whether the payer loses real dollars (insurer-linked, cash-stakes) versus treats payouts as marketing spend — otherwise the "fraud isn't material" kill signal fires spuriously from the wrong segment.

### S3. Ship the minimal sound V1 protocol; cut what doesn't earn its complexity

- **Cut the score-threshold circuit from V1** (keep as a research spike). Baseline: server challenge with **RP audience + nonce mixed into the challenge hash** → on-device scoring → signed envelope with three new mandatory fields — `audience`, `assuranceLevel` (the Milestone-0 enum, machine-readable), `holderBinding` (`none | device | biometric-root`) → App Attest assertion over the envelope hash → **direct presentation to the verifier** (full envelope, no proof-ID phone-home) → DeviceCheck rate limiting. One signature chain to audit.
- Decide now whether the `features` block is public (then never build the circuit) or private (then never transmit it). Currently the design pays SNARK proving cost to hide data it ships in the same JSON.
- Defer Semaphore membership until verification is verifier-local (published signed group roots), the anonymity set has a floor (explicit launch gate, e.g. N thousand members), App Attest state is organizationally separated from presentation processing, and nullifier scopes are protocol-assigned (`H(registered_rp_id, action, epoch)`) rather than verifier-chosen strings. Until a uniqueness root exists, per-verifier pseudonyms beat full anonymity because abusive credentials can be revoked.
- Publish a **verifier reasoning guide** as a first-class artifact: per assurance level, what may be concluded, the composition rule (effective assurance = minimum of layers; liveness refresh never upgrades holder binding), the estimated attacker cost in dollars, and worked examples of what NOT to gate. This converts the project's honesty discipline into a market differentiator no competitor has.

### S4. Fix the claim language and publish the attacker-cost model

- The envelope claim string `recent-wearable-backed-liveness-signal` asserts "wearable-backed" as fact while the envelope's own `sourceConfidence` is only `watch_likely` — an internal inconsistency. Rename to something like `recent-apple-sourced-wearable-activity-observed`, and keep `human`/`living`/`personhood` out of the liveness layer everywhere.
- Run the red-team bypass experiment now, but test the right ladder: jailbroken health-DB writes and physical watch spoofing, **not** naive app injection (source filtering already blocks that on stock iOS — a naive test would produce false confidence). Publish the resulting per-fake-account cost as the pricing floor, and define a **stakes ceiling** in verifier terms: the proof may only gate decisions worth less than that number. Publishing the red-team results is itself credibility the identity/fraud community rewards.

### S5. Governance commitments that double as compliance shields

- **Never a sole gate** — hard product rule in verifier ToS, technically encouraged (verifiers must declare an alternative path; failure states surface only to the user, never as a distinct verifier-visible state).
- **No enrollment incentives or token rewards attached to health-data collection, ever** — stated as a governance commitment, not a deferred decision (the Brazil/ANPD Worldcoin precedent is specifically about incentivized biometric consent).
- Move the **DPIA and data-classification to Milestone 0** (it determines architecture — holder-presents vs. server lookup — so doing it at Milestone 7 risks rebuilding), adopt the holder-presents model for MHMDA defensibility, keep scoring deterministic and publicly versioned for EU deployments (also sidesteps the EU AI Act "AI system" definition), and rank uniqueness roots by regulatory cost: document/credential-backed first, in-person second, biometric dedup last and only via a partner who owns the Annex III conformity burden.
- Run the TestFlight pilot as an IRB-reviewed study that **measures exclusion/failure rates** across demographics, devices, and medical conditions, and publish the results — turning W7's equity liability into the credibility the personhood field lacks.

### S6. Keep the humanity ambition alive as standards work, priced for Apple risk

Publish the layered architecture — issuer-agnostic liveness refresh over an external uniqueness root, protocol-scoped nullifiers, the assurance-level taxonomy — as a paper/reference design into the personhood-credentials community (the arXiv:2408.07892 lineage, W3C VC/BBS, IIW). File the Apple Feedback request for signed activity provenance and ask at a WWDC lab. But price both hedges honestly: if wearable-backed personhood ever matters, Apple — which owns wrist detection, PATs, passkeys, and the sensor — is more likely to ship it first-party than to partner; and World has shown it vertically integrates the freshness layer when it wants one. The standards track is the only version of "partner-ready component" with defensible upside (citation-of-record, obvious hire/acquirer target), which is exactly why it should be the parallel track rather than the main bet.

### 90-day sequence

1. Red-team bypass experiment on the *correct* attack ladder (jailbreak DB writes, physical spoof) — 1 week, one engineer; publishes the pricing floor.
2. TestFlight external-beta review probe with honest health-integrity framing — near-zero cost; a rejection is decisive evidence, not a setback.
3. 10–15 discovery calls with wellness/insurer/cash-stakes program operators, stratified by real-dollar fraud exposure; three willing design partners = go, uniform "fraud isn't material" from the real-dollar segment = kill the commercial track.
4. Draft the standards/reference-design writeup from existing docs (they are ~80% written).
5. Go/no-go on the activity-integrity SDK based on design-partner interest.

---

## Appendix — What the adversarial pass corrected

Findings the challenge agents refuted, weakened, or materially sharpened (kept here so future readers don't re-derive them):

- "The unsigned trust root makes the claim unsupportable" was **downgraded**: the repo already documents this position thoroughly; the surviving delta is the claim-string inconsistency (S4) and the README's opening sentence.
- "Simulator is a cheap bypass" was **corrected**: App Attest is unsupported on the simulator, so it only becomes a vector if the unsupported-device fallback accepts unattested submissions — that fallback policy is the real decision.
- "Any app can forge watch-labeled samples in an afternoon (~$0)" was **corrected**: `HKSource` is system-assigned and cannot be forged by App Store apps; the realistic cheap paths are jailbroken store writes and physical spoofing, which is why the bypass experiment must test those.
- "Wallet mdoc gives Sybil resistance for free" was **weakened**: mdoc has selective disclosure but no per-verifier nullifiers or unlinkable dedup; using it for one-account-per-person requires retaining a stable government identifier — the privacy regression this project exists to avoid — unless ZK-over-mdoc (which Google ships, Apple doesn't) arrives.
- "Passkey UV is the silent killer competitor" was **corrected in shape**: consumer synced passkeys ship attestation `none`, so they prove nothing against first-party fraud (farms); the closer free competitor for the anti-bot lane is Apple Private Access Tokens. The verifier-by-verifier "why not a passkey / why not a PAT?" table remains the right exercise.
- "The market is voting that personhood doesn't monetize" was **weakened**: World's 2026 fee-plus-marquee-verifier turn is evidence *for* monetization at scale; the defensible claim is that sub-scale standalone personhood doesn't monetize — which is the cold-start finding, not an independent one.

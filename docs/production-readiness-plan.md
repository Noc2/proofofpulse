# Production Readiness Plan

Last reviewed: 2026-07-10.

## Readiness Verdict

Proof of Pulse is a useful local PoC, not a production proof-of-humanity system yet. The current app can demonstrate the user experience, collect or simulate coarse HealthKit-derived signals, create a challenge-bound envelope, and submit it to a local verifier. It should not yet be used for access control, rewards, token distribution, account uniqueness, or any relying-party decision that assumes a verified human.

The production path is still viable, but it must keep three claims separate:

- Liveness: recent physiological or activity signal exists.
- Integrity: the request came from a legitimate app instance on Apple hardware.
- Uniqueness: a Sybil-resistant issuer admitted at most one credential per human.

HealthKit and Apple Watch data can support a liveness signal. They do not, by themselves, prove unique humanity or cryptographic Apple Watch sensor provenance.

## Current System Snapshot

The repo currently contains:

- A SwiftUI iPhone app shell with the Proof of Pulse visual language.
- A read-only HealthKit collector that extracts coarse feature buckets and excludes user-entered samples when metadata allows it.
- A development API with challenge issuance, proof submission, replay checks, mock app-integrity registration, and mock ZK verification.
- A proof-envelope model shared across Swift and JavaScript.
- A Noir-style score-threshold circuit spike over synthetic coarse features.
- Threat-model, ZK, and local-PoC docs that correctly label the remaining trust gaps.

The biggest current gaps are:

- App Attest is still represented by `development-app-attest`, not real Apple attestation/assertion validation.
- ZK verification still accepts `mock-score-threshold-v0`, and the circuit uses a toy commitment.
- API state is in memory, so replay protection disappears on restart and cannot support multi-instance deployment.
- The iOS app still exposes development settings such as local HTTP API configuration.
- Release signing, App Store metadata, privacy policy, privacy labels, production bundle ID, app icon, and review notes are not in place.
- No real-device HealthKit/Apple Watch validation matrix is checked into the repo.

## Production Milestones

### Milestone 0: Claim, Policy, And Review Positioning

Goal: make the product claim precise enough that engineering, legal, and App Review all point in the same direction.

Required work:

- Decide whether the first public release is a TestFlight research alpha, an App Store utility, or a relying-party verification product.
- Use modest copy in the app: "local liveness summary" or "pulse liveness check" until real App Attest and real ZK are shipped.
- Avoid medical or diagnostic language. The app should not claim to measure health status or diagnose anything.
- Write a privacy policy before collecting or transmitting any HealthKit-derived proof material.
- Write App Store review notes explaining the non-obvious proof flow, why HealthKit access is requested, what stays on device, and what is sent to the backend.
- Define explicit assurance levels:
  - `demo`: simulator or synthetic data.
  - `local-liveness`: HealthKit-derived coarse signal, no production attestation.
  - `app-attested-liveness`: HealthKit-derived coarse signal plus real App Attest.
  - `zk-private-liveness`: real ZK proof over committed coarse features.
  - `unique-humanity`: liveness refreshed credential issued by a separate Sybil-resistant process.

Exit criteria:

- Product copy, docs, and API responses never imply Apple Watch sensor-level attestation or unique humanity unless those layers are actually present.
- Privacy policy and App Store privacy answers are drafted and reviewed.
- TestFlight/App Store positioning is decided.

### Milestone 1: iOS Release Hardening

Goal: make the iPhone app safe to distribute to external testers.

Required work:

- Split Debug and Release behavior.
  - Debug can keep local API settings and demo signal controls.
  - Release must use HTTPS production API configuration.
  - Release should not request local-network access unless local-network access is a real user-facing feature.
- Add Apple Developer signing:
  - real bundle ID;
  - `DEVELOPMENT_TEAM`;
  - HealthKit capability;
  - App Attest environment entitlement;
  - release provisioning profile;
  - app icon and launch assets.
- Add App Attest client support:
  - generate an App Attest key with `DCAppAttestService`;
  - store the key ID in Keychain;
  - request a server challenge;
  - attest the key during registration;
  - generate assertions for proof submissions;
  - include method, path, challenge, body hash, and proof envelope hash in the signed client-data hash.
- Add user-facing privacy controls:
  - clear HealthKit consent explanation;
  - proof history deletion;
  - account/device reset;
  - export of the server-visible proof envelope;
  - "insufficient signal" state for denied, sparse, stale, or limited HealthKit visibility.
- Add test coverage:
  - Swift unit tests for scoring and envelope parity;
  - UI tests for demo, permission denied, backend offline, and successful proof states;
  - a real-device test matrix for iPhone only, iPhone plus Apple Watch, stale data, third-party-written samples, and user-entered samples.

Exit criteria:

- `npm run ios:build` passes for simulator and a Release archive can be produced locally.
- App can be installed on a physical device from the correct Apple Developer team.
- Real-device test results are captured in the repo with device class, iOS/watchOS version, and observed source metadata patterns.

### Milestone 2: Production Backend Foundation

Goal: turn the local API into a durable verifier service.

Required work:

- Move state from memory to Postgres.
- Add migrations for:
  - accounts or anonymous install records;
  - devices;
  - challenges;
  - App Attest keys;
  - App Attest assertion counters;
  - proof envelopes;
  - nullifiers;
  - ZK verification keys;
  - audit events;
  - deletion requests.
- Make challenge consumption atomic.
- Add unique constraints for challenge IDs, proof IDs, App Attest key IDs, and nullifiers.
- Add TTL cleanup for challenges and short-lived proof status.
- Add schema validation for every endpoint.
- Reject malformed JSON instead of treating it as an empty object.
- Add body-size limits, rate limits, CORS policy, security headers, and structured errors.
- Add privacy-safe structured logging.
- Add service health checks:
  - process alive;
  - database reachable;
  - migrations current;
  - App Attest root material loaded;
  - ZK verifier keys loaded.
- Add deployment artifacts:
  - Dockerfile or platform-specific build config;
  - environment variable template;
  - database migration command;
  - backup/restore notes;
  - runbook for incident response.

Exit criteria:

- Restarting the API does not allow challenge replay or nullifier reuse.
- Running two API instances against one database preserves the same replay guarantees.
- Production deploy has TLS, logs, metrics, backups, and a rollback path.

### Milestone 3: Real App Attest Verification

Goal: make fake clients materially harder.

Required work:

- Add server-side App Attest registration endpoint:
  - issue a one-time registration challenge;
  - verify the attestation certificate chain against Apple App Attest root material;
  - verify the nonce generated from authenticator data and client-data hash;
  - verify the app identifier hash against Team ID plus Bundle ID;
  - verify development versus production AAGUID based on environment;
  - verify credential ID/key ID binding;
  - store the public key, receipt, environment, bundle version, and counter.
- Add server-side assertion verification:
  - bind each assertion to method, path, proof challenge, and request body hash;
  - verify the signature using the stored public key;
  - verify App ID hash and monotonic counter;
  - reject replayed or regressed counters;
  - support key revocation and re-registration.
- Define unsupported-device behavior:
  - fail closed for production proofs;
  - optionally allow "unsupported/test" assurance only in TestFlight or development.
- Keep development and production App Attest environments separate.

Exit criteria:

- A proof submitted without a valid App Attest assertion is rejected.
- A replayed assertion is rejected.
- An assertion from the wrong bundle ID, team ID, environment, or body hash is rejected.
- The API reports App Attest failures without logging sensitive proof material.

### Milestone 4: Real ZK Score Proof

Goal: replace mock ZK with a real proof over coarse private features.

Recommended direction:

- Continue with Noir first because the repo already contains a Noir-style circuit.
- Use Barretenberg for the first local prover/verifier workflow.
- Keep Semaphore separate for membership/nullifier proofs.

Required work:

- Pin exact versions of `nargo` and `bb`.
- Replace the toy additive commitment with a circuit-friendly hash such as Poseidon or Pedersen.
- Make scoring deterministic and shared across Swift, JavaScript, and Noir.
- Add golden vectors:
  - valid threshold pass;
  - valid threshold fail;
  - stale challenge;
  - mismatched policy;
  - mismatched commitment;
  - malformed public inputs.
- Add invalid-witness and mutation tests before any real HealthKit data is wired in.
- Generate and version verification keys.
- Verify real proofs in the backend.
- Benchmark proof generation on target iPhones and measure battery/runtime impact.
- Decide whether proof generation happens on device, server-side for early testing, or in a hybrid dev mode.

Exit criteria:

- Backend no longer accepts `mock-score-threshold-v0` in production mode.
- Public inputs are bound to the server challenge, policy version, feature commitment, freshness window, and nullifier scope.
- A verifier can validate proof correctness without seeing raw HealthKit samples or exact physiological values.

### Milestone 5: Unique-Humanity Layer

Goal: avoid pretending that liveness is uniqueness.

Required work:

- Choose a uniqueness issuer strategy:
  - integrate an existing proof-of-human credential;
  - document-backed credential with privacy-preserving presentation;
  - in-person or community issuance;
  - privacy-preserving biometric deduplication with strong governance;
  - multi-issuer model where relying parties select acceptable assurance policies.
- Define issuance rules, appeals, revocation, recovery, and exclusion handling.
- Use scoped nullifiers so a user can prove once per relying-party action without creating a global tracking handle.
- Consider Semaphore for anonymous group membership and scoped nullifiers.
- Keep Pulse as a freshness/liveness refresh layer on top of the uniqueness credential.

Exit criteria:

- A relying party can distinguish "fresh liveness" from "unique-human credential".
- One-proof-per-scope behavior is enforced without exposing a global user identifier.
- The uniqueness issuer process is documented, auditable, and separate from HealthKit scoring.

### Milestone 6: App Store And TestFlight Readiness

Goal: make distribution boring.

Required work:

- Apple Developer Program membership.
- Registered bundle ID and capabilities.
- App Store Connect app record.
- App icon, screenshots, subtitle, description, age rating, categories, support URL, marketing URL, and privacy policy URL.
- App Privacy details for Health/Fitness, identifiers, diagnostics, IP address/logs, retention, and deletion.
- Privacy manifest / required-reason API audit before upload.
- TestFlight review notes, demo account or fully-featured demo mode, and live backend.
- Crash reporting and diagnostics plan that avoids raw health data.
- Accessibility pass for Dynamic Type, VoiceOver labels, contrast, and reduced motion.

Exit criteria:

- Archive upload succeeds.
- TestFlight App Review has enough context to exercise the app.
- External testers can create a proof on a real device without local developer tools.

### Milestone 7: Operations, Abuse, And Security

Goal: be ready for adversarial use.

Required work:

- Add metrics:
  - challenge issuance/submission rate;
  - App Attest registration failures;
  - assertion counter regressions;
  - ZK verification failures;
  - nullifier collisions/reuse;
  - HealthKit insufficient-signal rates;
  - proof success funnel by app version.
- Add alerts for abuse and system health.
- Add rate limits by IP, install, App Attest key, account, verifier, and scope.
- Add data retention schedule and deletion pipeline.
- Add abuse-response runbook.
- Conduct security review of App Attest verification and ZK constraints before any production reliance.
- Conduct privacy impact assessment for EU/GDPR use, including lawful basis, data minimization, retention, deletion, and processor/subprocessor list.

Exit criteria:

- The team can detect replay attempts, fake-client attempts, anomalous proof volume, and verifier abuse.
- A user can delete their account/proof records according to the published policy.
- A security reviewer can reproduce the trust model from docs, tests, and code.

## Suggested Sequence

### Sprint 1: TestFlight-Safe Foundation

- Split Debug/Release configuration.
- Remove editable LAN API settings from Release.
- Add signing placeholders and App Attest entitlement wiring.
- Add privacy policy draft and App Store privacy answer draft.
- Add real-device HealthKit test matrix doc.
- Add UI copy guardrails for mock proofs.

### Sprint 2: Durable Verifier API

- Add Postgres migrations and persistent store.
- Add endpoint schema validation and structured errors.
- Add atomic challenge consumption and nullifier constraints.
- Add production env template and Docker/platform deploy path.

### Sprint 3: Real App Attest

- Implement iOS App Attest key generation, attestation registration, and assertions.
- Implement server attestation and assertion validation.
- Add replay, wrong-bundle, wrong-team, wrong-environment, and counter-regression tests.

### Sprint 4: ZK Proof Hardening

- Install and pin Noir/Barretenberg tooling.
- Replace toy commitment.
- Add circuit tests and golden vectors.
- Verify real proofs in the backend.
- Benchmark proving on real devices.

### Sprint 5: Privacy-Preserving Membership

- Prototype Semaphore membership and scoped nullifier flow.
- Define group admission policy and relying-party scope format.
- Add server-side nullifier enforcement per verifier/action/epoch.

### Sprint 6: External Pilot

- Ship TestFlight to a small group with real iPhone/Apple Watch users.
- Collect failure modes without collecting raw HealthKit samples.
- Tune scoring thresholds and unsupported-device states.
- Perform security/privacy review before any production relying-party use.

## Tooling And Installation Notes

Already available locally on this machine:

- Xcode 26.6.
- Swift 6.3.3.
- Node 24.14.0.
- npm 11.9.0.
- Docker.
- `psql`.

Not currently found on PATH:

- `nargo`.
- `bb`.
- `circom`.
- `snarkjs`.

Recommended installs when starting ZK work:

```bash
curl -L https://raw.githubusercontent.com/noir-lang/noirup/refs/heads/main/install | bash
noirup

curl -L https://raw.githubusercontent.com/AztecProtocol/aztec-packages/refs/heads/next/barretenberg/bbup/install | bash
bbup
```

Recommended optional local tools:

```bash
brew install xcbeautify swiftlint swiftformat
npm install --save-dev typescript tsx vitest zod
```

Recommended production services:

- Postgres for replay-critical state.
- Redis only for cache/rate limiting, not as the source of truth for proof replay.
- Secret manager or platform-managed environment variables.
- Hosted logs and metrics with redaction.
- Error/crash reporting configured to avoid raw health data.

## Production Definition Of Done

Proof of Pulse can be called production-ready only when:

- Release iOS builds use real signing, real entitlements, and HTTPS-only backend configuration.
- HealthKit access is minimal, explained, and backed by a public privacy policy.
- No raw HealthKit samples, exact heart-rate values, exact workout details, source names, UDIs, or stable device identifiers are uploaded.
- Backend state is durable and replay-resistant across restarts and multiple instances.
- Real App Attest attestation/assertion verification is enforced for production proof submissions.
- Real ZK proofs replace mock proof material, or ZK claims are removed from production UI/API responses.
- Unique-humanity claims are backed by a separate issuer/deduplication process, not only Apple Watch liveness.
- App Store metadata, review notes, privacy labels, support URL, and deletion/export flows are complete.
- Security and privacy reviews have been completed for App Attest validation, ZK constraints, proof metadata, and retention.

## Sources Checked

- Apple App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Apple App Privacy Details: https://developer.apple.com/app-store/app-privacy-details/
- Apple HealthKit privacy documentation: https://developer.apple.com/documentation/healthkit/protecting-user-privacy
- Apple App Attest overview: https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity
- Apple App Attest server validation: https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server
- Apple App Attest entitlement: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.devicecheck.appattest-environment
- Noir manual getting started: https://noir-lang.org/docs/getting_started_manually
- Barretenberg getting started: https://barretenberg.aztec.network/docs/getting_started/
- Semaphore overview: https://docs.semaphore.pse.dev/
- Semaphore proof guide: https://docs.semaphore.pse.dev/guides/proofs
- Semaphore mobile SDKs: https://docs.semaphore.pse.dev/mobile

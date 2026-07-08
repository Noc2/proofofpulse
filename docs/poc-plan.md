# Initial POC Plan

## POC Question

Can Proof of Pulse generate a short-lived, privacy-preserving proof that a request is backed by recent wearable physiology or activity data from a real Apple device, without uploading raw Apple Health data?

## Hypothesis

Apple Health data alone is not a secure proof of humanity because apps and users can write data into HealthKit. A useful first POC is still possible if it combines:

- HealthKit source and metadata filtering.
- Recent Apple Watch-oriented signals.
- On-device scoring and data minimization.
- Server-issued one-time challenges.
- App Attest validation for client integrity.
- Explicitly modest claims about liveness, not uniqueness.

## Target Claim

The first Pulse Proof should claim:

```text
At time T, this legitimate app instance evaluated local HealthKit samples for a server challenge C and found enough recent, non-user-entered, plausibly wearable-backed signals to pass the configured liveness threshold.
```

This does not prove that the user is unique, that they own the watch, or that every sample was sensor-authenticated.

## MVP User Flow

1. User installs the iOS app.
2. App explains the proof claim and asks for the minimum HealthKit permissions.
3. User taps "Create Pulse Proof."
4. App requests a one-time challenge from the API.
5. App reads a recent window of HealthKit samples.
6. App filters out samples marked as user-entered and prioritizes samples with Apple Watch-like source/device metadata.
7. App computes a local score and creates a proof envelope.
8. App signs or submits the envelope with App Attest-backed assertions.
9. API verifies challenge freshness, App Attest state, envelope schema, score threshold, and replay state.
10. API returns a short-lived proof ID.

V0 should request read permissions only. Writing data to HealthKit creates avoidable App Review and trust risk, and it is not needed for proof generation.

## Suggested Signals For POC

Start with low-risk, non-diagnostic features:

- Recent step-count distribution.
- Recent active-energy or exercise-minute presence.
- Heart-rate sample presence and rough variability buckets, if available.
- Resting-heart-rate or walking-heart-rate-average presence, only as coarse availability/recency features.
- Source/device metadata, such as HealthKit source revision and product type, when available.
- `HKMetadataKeyWasUserEntered` exclusion when present and true.

Avoid collecting reproductive, clinical, medication, diagnosis, or mental-health data.

Treat missing samples carefully. HealthKit intentionally hides whether read permission was denied for a data type, and users may grant only a limited recent history window. A sparse result should produce an "insufficient signal" state, not a claim that no data exists.

Treat source and device metadata as confidence input only. Some HealthKit device fields are arbitrary strings, and app-created samples can include device and metadata values. High-confidence V0 scoring should prefer Apple/system sources and reject third-party-written samples, but it must not claim cryptographic Apple Watch sample provenance.

## Scoring Model V0

Keep V0 deterministic and explainable:

```text
score =
  recency_points
  + source_confidence_points
  + continuity_points
  + multimodal_points
  - user_entered_penalty
  - sparse_or_implausible_penalty
```

The app should emit only:

- Score tier.
- Passed/failed threshold.
- Coarse feature buckets.
- Source-confidence summary.
- Sample time window.
- Challenge hash.
- App Attest key ID/assertion reference.
- Scoring algorithm version.

## Backend V0

The first API can be intentionally small:

- `POST /v1/challenges`
  - returns a nonce, challenge ID, and expiration.
- `POST /v1/app-attest/register`
  - stores App Attest public-key state after attestation verification.
- `POST /v1/pulse-proofs`
  - verifies challenge, App Attest assertion, proof schema, score threshold, and replay state.
- `GET /v1/pulse-proofs/:id`
  - returns public proof status, expiration, and claim summary.

For local development, SQLite is enough. Production should use a proper database and secret management.

Store only proof metadata:

- Proof ID and envelope hash.
- Challenge ID and replay status.
- Account or wallet hash, if the POC binds proofs to accounts.
- App Attest key state and assertion counter.
- Coarse score tier, source-confidence tier, algorithm version, and expiration.
- Abuse counters.

Do not store raw HealthKit samples, exact heart-rate values, exact workout details, routes, source device names, or stable HealthKit device identifiers.

## Milestones

### Milestone 0: Repo and Research Baseline

- Initialize repository.
- Document feasibility, threat model, and privacy posture.
- Draft proof envelope.
- Decide first iOS and API stack.

### Milestone 1: HealthKit Local Prototype

- Create SwiftUI iOS app.
- Request HealthKit permissions.
- Read recent step count, active energy, workouts, and heart-rate availability.
- Show local score and source summary on device.
- No backend yet.

### Milestone 2: Challenge-Bound Proof

- Add API challenge endpoint.
- Bind local score output to the challenge.
- Return a local proof envelope preview.
- Reject stale or replayed challenges.
- Handle HealthKit limited-authorization windows as an explicit scoring input.

### Milestone 3: App Attest Integration

- Generate App Attest key per install/account.
- Verify attestation server-side.
- Require assertions for proof submissions.
- Track assertion counters and challenge binding.
- Define the fallback behavior when App Attest is unavailable on a device.

### Milestone 4: Privacy Review And Red-Team Pass

- Confirm no raw health samples leave the device.
- Add explicit in-app consent copy.
- Add HealthKit usage descriptions and a privacy policy draft.
- Review App Store health-data rules.
- Document attack paths and what the proof does not claim.

### Milestone 5: Credential Path Decision

- Decide whether a Pulse Proof should remain an API lookup or become a signed credential.
- Evaluate short-lived SD-JWT or verifiable-credential style presentation.
- Defer BBS or zero-knowledge proofs until the input features and provenance limits are well understood.

## Acceptance Criteria For Initial POC

- A tester with an iPhone and Apple Watch can create a proof from recent HealthKit data.
- A tester without enough recent wearable-backed data receives a clear local failure state.
- Server rejects replayed challenges.
- Server rejects proof submissions without valid app integrity evidence.
- Public verifier sees only proof status and a coarse claim, not health samples.
- README and docs clearly state the limits of the proof.
- Replayed proofs and multiple proofs per account/device/epoch are detectable.

## Key Risks

- HealthKit samples are not sensor-attested at the sample level.
- Some source metadata may be insufficient or inconsistent across OS/device versions.
- HealthKit authorization can make denied, limited, and absent data difficult to distinguish.
- A determined attacker may synthesize plausible HealthKit history.
- App Attest raises the cost of fake clients but does not prove the health data came from a body.
- DeviceCheck can support repeat-device flags and rate limits, but it is not an identity primitive.
- Strong Sybil resistance needs more than one device-local health signal.
- Health data is highly sensitive and creates GDPR/App Store risk if mishandled.
- App Review risk increases if the product is framed as a generic proof-of-human gate rather than a clear health/fitness user benefit.

## Open Questions

- Which HealthKit sample types reliably expose enough source/device metadata?
- Can Apple Watch-origin samples be confidently distinguished from iPhone or third-party app samples for the selected data types?
- What minimum data window balances freshness, reliability, privacy, and inclusion?
- Should V1 require Apple Watch, or allow lower-confidence iPhone-only proofs?
- What verifier API shape is useful without becoming a tracking identifier?
- Should V0 expose only score tiers instead of exact scores?
- What nullifier design prevents replay without becoming a cross-site tracking handle?
- Is there a user-facing health/fitness benefit strong enough to satisfy HealthKit policy when the proof is used by external verifiers?

# Proof of Pulse

Proof of Pulse explores whether Apple Health and Apple Watch physiology signals can become a privacy-preserving proof that an account is backed by a real human body, and eventually one component of a broader proof of unique humanity.

The project starts as a liveness and personhood signal, not a solved proof of unique humanity. HealthKit can expose rich time-series data with user permission, but the hard problem is provenance: proving the signal came from real wearable sensors and was not user-entered, app-written, replayed, or synthesized.

Important caveat: Proof of Pulse should avoid becoming a generic "health data for access control" gate. Apple's HealthKit rules require clear health or fitness purpose, explicit consent, a privacy policy, and strict limits on disclosure or secondary use.

## Vision

Build a proof flow that lets a user generate a short-lived "Pulse Proof" from their own device without uploading raw health data.

The first proof should answer a narrow claim:

> This request came from a legitimate app instance on Apple hardware, and the local HealthKit store contains recent, plausible, wearable-backed physiology or activity signals consistent with a living human.

The long-term proof should answer a stronger, composable claim:

> This presenter is a member of a privacy-preserving set of unique humans, and they recently refreshed that status with a wearable-backed liveness signal, without revealing raw health data or a stable cross-site identity.

## POC Goals

- Read recent HealthKit samples on-device with explicit user consent.
- Request read access only in V0; do not write anything into HealthKit.
- Prefer Apple Watch-backed samples and exclude user-entered samples where HealthKit metadata allows it.
- Compute a local liveness score from coarse, non-diagnostic features.
- Add a zero-knowledge proof path that proves score-threshold and membership claims without revealing the private feature vector or the user's stable identity.
- Bind each proof to a server challenge to prevent replay.
- Use Apple App Attest to make proof submissions harder to fake from modified clients.
- Send only proof claims, feature summaries, and cryptographic material to the backend.

## Non-Goals

- No medical diagnosis or health recommendations.
- No raw health-data upload in the initial POC.
- No claim of perfect one-person-one-account Sybil resistance.
- No universal proof of humanity for users without compatible Apple devices.
- No production token, reward, or identity system until privacy and abuse risks are better understood.
- No claim that zero-knowledge proofs solve HealthKit input provenance by themselves.

## Starting Architecture

```text
iOS app
  - HealthKit permission and sample reads
  - source and metadata filtering
  - local feature extraction
  - optional ZK witness generation
  - challenge-bound proof envelope
  - App Attest key generation and assertions

API service
  - challenge issuance
  - App Attest validation
  - ZK proof verification
  - anonymous membership registry
  - proof envelope validation
  - short-lived proof status

Verifier
  - accepts proof ID or signed proof envelope
  - checks expiration, score threshold, anonymous membership, and replay/nullifier state
```

## Repository Map

- `docs/poc-plan.md` - initial proof-of-concept plan and milestones.
- `docs/research-notes.md` - current platform and privacy constraints.
- `docs/proof-envelope.md` - draft proof payload shape.
- `docs/threat-model.md` - first-pass abuse cases and mitigations.
- `docs/zk-uniqueness-plan.md` - ZK and unique-humanity roadmap.

## Status

Initialized on 2026-07-08. This repository currently contains planning and architecture notes for the first POC.

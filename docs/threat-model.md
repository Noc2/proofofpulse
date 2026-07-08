# Threat Model

Proof of Pulse should start with a modest claim and a clear threat model. The POC is not a complete Sybil-resistance system.

## Assets

- Raw HealthKit samples.
- Local proof-scoring logic.
- Server challenge state.
- App Attest key and assertion state.
- Public proof status.
- User trust in what a Pulse Proof means.

## Adversaries

- A casual user trying to create a proof without recent health data.
- A script or bot submitting fake proof payloads.
- A modified app client trying to bypass local scoring.
- A user or app that writes synthetic data into HealthKit.
- A third-party HealthKit writer that supplies plausible device and metadata fields.
- A replay attacker reusing an old proof or challenge.
- A privacy attacker trying to infer health details from proof metadata.
- A Sybil attacker using one person, device, or data history for many accounts.
- A device-farm attacker using real or borrowed Apple Watches at scale.

## Initial Mitigations

- Keep raw HealthKit samples on-device.
- Request only the minimum HealthKit read permissions.
- Exclude samples marked as user-entered when metadata is present.
- Prefer recent, multi-signal, Apple Watch-like source/device metadata.
- Reject third-party-written samples from high-confidence scoring until tested.
- Use deterministic, explainable scoring for V0.
- Bind proof envelopes to one-time server challenges.
- Expire challenges and proofs quickly.
- Verify App Attest attestation and assertions server-side.
- Track App Attest assertion counters and proof replay state.
- Add account/device/epoch-scoped nullifiers where the verifier needs one-proof-per-window behavior.
- Publish only coarse proof status and confidence labels.

## Known Limits

- HealthKit source and device metadata are trust signals, not sensor attestations.
- Some HealthKit device/source fields can be supplied by sample-writing apps.
- App Attest verifies app integrity, not the physical origin of HealthKit samples.
- A valid proof can at best say that a compatible device has enough plausible recent signal.
- A person may lend or sell access to a device or proof.
- A person may generate more than one account unless the system adds separate uniqueness controls.
- Stronger privacy, such as zero-knowledge proofs, is future work after the feature set stabilizes.
- Zero-knowledge proofs cannot solve sensor provenance unless the inputs are themselves trustworthy.

## Red-Team Tests For POC

- Submit a proof with a replayed challenge.
- Submit a proof after challenge expiration.
- Submit a proof with no App Attest assertion.
- Submit a proof with a mismatched challenge hash.
- Try to generate a proof from user-entered-only samples.
- Try to generate a proof from sparse or stale samples.
- Try multiple proof submissions for the same account/device/epoch.
- Confirm public verifier responses do not reveal raw health data or stable device identifiers.

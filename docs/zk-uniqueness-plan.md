# ZK And Unique Humanity Plan

This document updates the Proof of Pulse roadmap toward the end goal of proof of unique humanity.

## Core Position

Zero-knowledge proofs should be part of the POC, but they solve privacy and replay/linkability problems, not HealthKit provenance by themselves.

The right architecture is layered:

1. Pulse liveness: recent wearable-backed physiology or activity signal.
2. App integrity: App Attest-backed client integrity and challenge binding.
3. ZK privacy: threshold, membership, and nullifier proofs without revealing raw data.
4. Unique-humanity issuance: a separate Sybil-resistant process that admits at most one credential per human.

## What ZK Can Prove In The POC

### Score Threshold

The device can compute a private coarse feature vector from HealthKit and prove:

```text
hash(private_features) = feature_commitment
score(private_features, policy_version) >= threshold
challenge_hash = server_challenge_hash
expires_at is within the proof window
```

Public outputs:

- Challenge hash.
- Policy version.
- Score tier or pass/fail result.
- Feature commitment.
- Expiration.

Private witness:

- Coarse recency buckets.
- Coarse continuity buckets.
- Source-confidence flags.
- User-entered exclusion flags.

Raw HealthKit samples should not be circuit witnesses for the POC.

### Anonymous Membership

After a user passes a high-confidence Pulse issuance check, the server can admit a local identity commitment to a group. The user later proves:

```text
I know a secret identity whose commitment is in the accepted Pulse group,
and this presentation produces a nullifier for this verifier/action scope.
```

This hides the user's group member index and prevents duplicate presentations for the same scope.

### Selective Disclosure Credential

Later, an issuer can issue a credential such as:

```text
credential_type = PulseHumanityCredential
assurance = pulse_liveness_high
issued_at = coarse_date
expires_at = coarse_date
issuer = Proof of Pulse
```

The holder can selectively disclose only the fields a verifier needs. BBS-style derived proofs and SD-JWT are candidate presentation formats.

## What ZK Cannot Prove Alone

- That HealthKit samples came from Apple Watch sensors.
- That a person did not lend their watch or phone to someone else.
- That one person has only one device or one account.
- That a private feature vector was honestly computed unless app integrity and source checks are also enforced.
- That an issuer admitted only one credential per human.

## Unique-Humanity Endgame

The end goal should be:

```text
One living human can privately prove membership in a unique-human set,
refresh that membership with recent Pulse liveness,
and present unlinkable scoped proofs to verifiers.
```

HealthKit can help with freshness and liveness. It should not be the only uniqueness root.

Candidate uniqueness roots:

- Existing proof-of-human credential, such as a World ID-style credential.
- Document-backed credential with privacy-preserving presentation.
- In-person or community verification.
- Privacy-preserving biometric deduplication with strong governance.
- Multi-issuer model where verifiers choose acceptable assurance policies.

## Recommended POC Sequence

### Phase A: ZK Score Spike

- Implement a tiny `pulse-score-v0` circuit over synthetic coarse features.
- Use either Noir or Circom.
- Publicly verify `score_tier`, `policy_version`, `challenge_hash`, and expiration.
- Write invalid-witness tests before connecting to HealthKit.

### Phase B: Semaphore Membership Spike

- Generate a local identity commitment.
- Admit commitments after simulated high-confidence Pulse issuance.
- Generate and verify membership proofs.
- Use verifier/action-scoped nullifiers to prevent duplicate use without global tracking.
- Evaluate SemaphoreSwift or another mobile path for native iOS proving.

### Phase C: HealthKit Integration

- Connect real local HealthKit feature extraction to the scoring inputs.
- Keep App Attest in the submission path.
- Compare exact local scores against ZK public outputs.
- Measure proving time and battery impact on real devices.

### Phase D: Unique-Humanity Integration

- Decide whether to integrate an existing proof-of-human credential or prototype a small issuer.
- Keep Pulse liveness as a freshness layer on top of the unique-humanity credential.
- Support multiple assurance levels instead of a single universal human/not-human bit.

## Candidate Technical Stack

- Semaphore for anonymous group membership and nullifier proofs.
- Noir for readable custom score-threshold circuits.
- Circom/snarkjs for mature circuit tooling and test infrastructure.
- RISC Zero or another zkVM later if the scoring algorithm becomes too complex for a small circuit.
- SD-JWT for pragmatic selective disclosure.
- BBS-derived proofs for unlinkable verifiable-credential presentations once implementation maturity is acceptable.

## Design Principle

Keep three claims separate in code and UI:

- Liveness: recent physiological or activity signal exists.
- Integrity: the proof came from a legitimate app instance.
- Uniqueness: an issuer or deduplication process admitted this credential as one-per-human.

Blurring those claims would make the system easier to market and much easier to get wrong.

## References

- Semaphore docs: https://docs.semaphore.pse.dev/
- Semaphore proof guide: https://docs.semaphore.pse.dev/guides/proofs
- Semaphore mobile SDKs: https://docs.semaphore.pse.dev/mobile
- Noir docs: https://noir-lang.org/docs/
- Circom docs: https://docs.circom.io/
- RISC Zero zkVM overview: https://dev.risczero.com/api/zkvm/
- World ID overview: https://docs.world.org/world-id/overview
- World ID core concepts: https://docs.world.org/world-id/concepts
- World ID Proof of Human: https://docs.world.org/world-id/credentials/1
- W3C BBS Cryptosuites: https://www.w3.org/TR/vc-di-bbs/
- IETF SD-JWT RFC 9901: https://datatracker.ietf.org/doc/rfc9901/
- Personhood credentials paper: https://arxiv.org/abs/2408.07892

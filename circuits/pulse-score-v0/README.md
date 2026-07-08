# pulse-score-v0 ZK Circuit Spike

This directory is a source-controlled spike for a small Proof of Pulse score-threshold proof. It is intentionally scoped to synthetic, coarse feature buckets so the circuit shape can be reviewed before real HealthKit feature extraction or mobile proving is connected.

## Claim

The proof shows that a private coarse feature vector:

- is range-constrained to the expected bucket contract,
- is bound to the public challenge and policy by a placeholder feature commitment,
- produces a score at or above the public threshold,
- matches the public score tier.

It does not prove HealthKit provenance, Apple Watch sensor origin, app integrity, uniqueness, or honest local feature extraction. Those remain separate layers handled by HealthKit collection rules, App Attest, server challenge state, and later membership/nullifier proofs.

## Public Inputs

The public inputs are ordered as declared in `src/main.nr`:

| Input | Meaning |
| --- | --- |
| `challenge_hash` | Field representation of the server challenge hash. |
| `policy_version` | Versioned scoring policy. This spike only accepts `0`. |
| `expires_at_epoch_minutes` | Coarse proof expiration time in epoch minutes. |
| `min_expires_at_epoch_minutes` | Lower bound accepted by the verifier for this challenge. |
| `max_expires_at_epoch_minutes` | Upper bound accepted by the verifier for this challenge. |
| `threshold_score` | Minimum score needed for a passing proof. |
| `high_threshold_score` | Minimum score needed for a high-confidence tier. |
| `claimed_score_tier` | `0 = fail`, `1 = pass`, `2 = pass_high`. Passing proofs must be `1` or `2`. |
| `feature_commitment` | Placeholder commitment binding the private buckets to the challenge and policy. |

## Private Witness Inputs

| Input | Accepted values |
| --- | --- |
| `recency_bucket` | `0..3`, where higher means more recent signal. |
| `continuity_bucket` | `0..3`, where higher means more continuous signal. |
| `source_confidence_bucket` | `0..2`, where `2` means watch-like confidence. |
| `signal_count_bucket` | `0..3`, where higher means more distinct signal categories. |
| `user_entered_samples_excluded` | Boolean. Must be true to receive exclusion points. |

Raw heart-rate, workout, sleep, source identifiers, device identifiers, and exact sample totals should not be circuit witnesses for this POC.

## Scoring Model

The spike score is deliberately simple:

```text
score =
  recency_bucket * 30
  + continuity_bucket * 25
  + source_confidence_bucket * 20
  + signal_count_bucket * 15
  + (user_entered_samples_excluded ? 10 : 0)
```

The public score tier is derived inside the circuit:

- `0` when `score < threshold_score`
- `1` when `threshold_score <= score < high_threshold_score`
- `2` when `score >= high_threshold_score`

The circuit asserts that the tier is passing, so a fail-tier witness cannot produce a valid proof.

## Placeholder Commitment

`src/main.nr` currently uses a toy arithmetic commitment:

```text
challenge_hash
  + policy_version * 17
  + recency_bucket * 101
  + continuity_bucket * 1009
  + source_confidence_bucket * 10007
  + signal_count_bucket * 100003
  + excluded_flag * 1000003
```

This is only a review aid. Replace it with a real circuit-friendly hash, such as Poseidon or Pedersen over a pinned Noir/Barretenberg stack, before treating `feature_commitment` as privacy-preserving or collision-resistant.

## Running Later With Nargo

Noir/Circom tools are not assumed to be installed in this repo. Once `nargo` and the matching proving backend are installed:

```sh
cd circuits/pulse-score-v0
nargo check
nargo execute
```

Then generate and verify a proof using the commands for the pinned Noir and Barretenberg versions. Common flows use `nargo prove` / `nargo verify` or a `bb` backend invocation against the compiled artifact and witness. Pin exact tool versions before adding CI, because Noir backend commands and standard-library hash APIs can shift across releases.

To sanity-check constraints, change `claimed_score_tier`, lower one of the bucket values, set `policy_version` to a nonzero value, or move `expires_at_epoch_minutes` outside the public bounds; the circuit should reject those witnesses.

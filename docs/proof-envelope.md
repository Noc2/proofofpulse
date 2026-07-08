# Pulse Proof Envelope Draft

The POC proof envelope should be small, challenge-bound, and free of raw health samples.

## Draft JSON Shape

```json
{
  "version": "pop-proof-v0",
  "challengeId": "ch_...",
  "challengeHash": "base64url_sha256_challenge",
  "issuedAt": "2026-07-08T00:00:00Z",
  "expiresAt": "2026-07-08T00:05:00Z",
  "claim": "recent-wearable-backed-liveness-signal",
  "algorithmVersion": "pulse-score-v0",
  "score": {
    "tier": "pass_high",
    "thresholdTier": "pass",
    "passed": true
  },
  "window": {
    "startedAt": "2026-07-07T00:00:00Z",
    "endedAt": "2026-07-08T00:00:00Z",
    "granularity": "coarse"
  },
  "features": {
    "recencyBucket": "under_24h",
    "sourceConfidence": "watch_likely",
    "signalCount": 3,
    "continuityBucket": "moderate",
    "userEnteredSamplesExcluded": true,
    "authorizationWindow": "full_or_unknown"
  },
  "appIntegrity": {
    "provider": "apple-app-attest",
    "keyId": "app_attest_key_id",
    "assertionId": "server_side_reference"
  },
  "zk": {
    "scheme": "none",
    "proofId": null,
    "publicInputs": {
      "algorithmVersion": "pulse-score-v0",
      "challengeHash": "base64url_sha256_challenge",
      "scoreTier": "pass_high"
    }
  },
  "replayProtection": {
    "epoch": "2026-07-08T00:00Z",
    "nullifierHash": "server_or_account_scoped_hash"
  }
}
```

## Rules

- Do not include raw heart-rate, step, workout, or sleep samples.
- Do not include exact daily totals unless needed for debugging in a local-only developer mode.
- Do not include stable device identifiers in public verifier responses.
- Do not include HealthKit `localIdentifier`, UDI, exact source names, or raw source metadata in public verifier responses.
- Prefer score tiers over exact numeric scores outside local developer mode.
- Bind every proof to a server challenge.
- Expire proofs quickly.
- Treat `sourceConfidence` as a confidence label, not a guarantee.
- Treat `zk.scheme = none` as the baseline and upgrade to `score-threshold-v0`, `semaphore-membership-v0`, or another explicit scheme when proofs are enabled.

## ZK Public Inputs

The first custom score proof should expose only:

- Challenge hash.
- Scoring algorithm version.
- Score tier or pass/fail flag.
- Feature commitment.
- Proof expiration.

Private witness values should include only coarse feature buckets and source-confidence inputs. Raw HealthKit samples should never become circuit witnesses unless there is a compelling privacy review showing that witness generation and local storage are safe.

## Public Verifier Response

```json
{
  "id": "pp_...",
  "status": "valid",
  "claim": "recent-wearable-backed-liveness-signal",
  "issuedAt": "2026-07-08T00:00:00Z",
  "expiresAt": "2026-07-08T00:05:00Z",
  "scorePassed": true,
  "scoreTier": "pass_high",
  "sourceConfidence": "watch_likely",
  "zkVerified": true,
  "nullifierScope": "example.com/signup/2026-07"
}
```

# Local POC

This guide runs the current Proof of Pulse vertical slice without an iPhone or real HealthKit data. It uses synthetic coarse feature buckets so the proof-envelope, challenge, replay, and verifier surfaces can be exercised safely.

## What Runs Today

- Shared `pulse-score-v0` scoring in `packages/core`.
- Challenge issuance through `POST /v1/challenges`.
- Development-only app-integrity key registration through `POST /v1/app-attest/register`.
- Challenge-bound proof-envelope submission through `POST /v1/pulse-proofs`.
- Replay detection for used challenges and nullifiers.
- Public proof-status lookup through `GET /v1/pulse-proofs/:id`.
- Mock ZK verification for the simulator path.

## What Is Still A Stub

- `development-app-attest` is not Apple App Attest validation.
- `mock-score-threshold-v0` is not a real zero-knowledge proof.
- Synthetic fixture data is not HealthKit data.
- Apple Watch source confidence is not sensor-level attestation.
- This PoC does not prove unique humanity.

## Run The Tests

```sh
npm test
```

## Run The Local Simulator

```sh
npm run simulate
```

The simulator:

1. registers a development app-integrity key;
2. requests a challenge;
3. loads `packages/core/fixtures/synthetic-pulse-features.json`;
4. creates a `pop-proof-v0` envelope;
5. submits it to the local API handler;
6. fetches the public verifier status.

The output intentionally contains only proof metadata and coarse claim fields, not raw health data.

## Run The API Server

```sh
npm run api
```

Then call it from another shell:

```sh
curl -s -X POST http://127.0.0.1:8787/v1/challenges
```

For manual proof submission, use the simulator flow as the reference implementation because it handles challenge hashing and envelope shape.

## iOS Collector Skeleton

`apps/ios/ProofOfPulseKit` is a Swift package for an eventual iOS app. It requests read-only HealthKit access to:

- step count;
- active energy;
- workouts;
- heart rate;
- resting heart rate.

It excludes user-entered samples when HealthKit metadata permits, reduces source/device details to coarse classes, and emits `PulseFeatures` values shaped for `pulse-score-v0`.

Validation used during this PoC:

```sh
swift package --package-path apps/ios/ProofOfPulseKit describe
xcrun --sdk iphonesimulator swiftc -target arm64-apple-ios15.0-simulator -parse-as-library -typecheck apps/ios/ProofOfPulseKit/Sources/ProofOfPulseKit/PulseFeatureTypes.swift apps/ios/ProofOfPulseKit/Sources/ProofOfPulseKit/HealthKitPulseCollector.swift
```

## ZK Circuit Spike

`circuits/pulse-score-v0` contains a Noir-style threshold circuit over private coarse buckets. It is source-controlled for review, but `nargo` was not installed in the local environment used for this implementation.

The circuit currently uses a toy arithmetic commitment. Replace it with a real circuit-friendly hash and pin the Noir/backend versions before production use.

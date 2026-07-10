# Real Device Test Matrix

Last reviewed: 2026-07-10.

This matrix records the evidence needed before TestFlight and before any production reliance on Pulse Proofs. Do not paste raw HealthKit samples into this document.

## Test Rules

- Use physical iPhones for HealthKit tests.
- Include at least one iPhone paired with an Apple Watch.
- Do not record raw heart-rate values, workout details, routes, HealthKit local identifiers, UDIs, exact source names, or stable device identifiers.
- Record coarse outcomes only.
- Keep screenshots free of sensitive health data.
- Mark whether the build used demo signal, local API, development App Attest, or mock ZK.

## Required Coverage

| ID | Scenario | Device Setup | Expected Result | Evidence To Capture | Status |
| --- | --- | --- | --- | --- | --- |
| RD-001 | Simulator demo proof | iPhone simulator, demo signal enabled | Proof succeeds against local API and is labeled as demo/mock | App version, API mode, proof status, no real HealthKit claim | Not run |
| RD-002 | iPhone without Apple Watch | Physical iPhone, no paired watch, recent phone activity | App either produces lower-confidence proof or insufficient-signal state | iOS version, source-confidence class, score tier, final state | Not run |
| RD-003 | iPhone with Apple Watch | Physical iPhone paired with Apple Watch, recent watch activity | App produces higher-confidence local liveness summary when enough signals exist | iOS/watchOS versions, source-confidence class, signal count bucket, final state | Not run |
| RD-004 | HealthKit denied | Physical iPhone, user denies HealthKit read access | App shows insufficient-signal or permission recovery state | Permission state, final state, no crash | Not run |
| RD-005 | Limited/sparse history | Physical iPhone with sparse or newly reset Health data | App shows insufficient-signal or lower-confidence state | Recency bucket, signal count bucket, final state | Not run |
| RD-006 | Stale data | Physical iPhone with no recent eligible samples | App fails freshness threshold | Recency bucket, final state | Not run |
| RD-007 | User-entered-only data | Physical iPhone with manually entered eligible-looking samples | User-entered samples are excluded where metadata allows; proof should fail or downgrade | User-entered exclusion flag, score tier, final state | Not run |
| RD-008 | Third-party-written samples | Physical iPhone with data written by a non-Apple HealthKit app | App downgrades or rejects high-confidence source classification | Source-confidence class, score tier, final state | Not run |
| RD-009 | Backend offline | Physical iPhone with valid signal, API unreachable | App shows submit failure without losing local privacy posture | Error state, retry behavior | Not run |
| RD-010 | Local API over LAN | Physical iPhone, Debug build, `HOST=0.0.0.0 npm run api` | Debug build can reach local API when URL points to Mac LAN address | API host, phone network, proof status | Not run |
| RD-011 | Release config | Physical iPhone, Release build | Demo signal and editable local API controls are hidden; HTTPS API is used | Build config, API label, settings screen | Not run |
| RD-012 | App Attest unsupported/failure path | Physical device or simulated server failure | Production build fails closed or shows unsupported assurance state | Failure state, server response class | Not run |

## Per-Run Template

```text
Run ID:
Date:
Tester:
Build commit:
Build configuration:
App version:
iPhone model class:
iOS version:
Apple Watch model class:
watchOS version:
API URL class: local LAN / staging HTTPS / production HTTPS
Proof mode: demo / local-liveness / app-attested-liveness / zk-private-liveness
ZK mode: none / mock / real
App Attest mode: development stub / development App Attest / production App Attest
Scenario IDs:
Outcome:
Observed source-confidence class:
Observed recency bucket:
Observed signal-count bucket:
Observed score tier:
Raw HealthKit uploaded: no
Notes:
```

## Promotion Gates

Before external TestFlight:

- RD-001, RD-003, RD-004, RD-009, RD-010, and RD-011 pass.
- Testers understand whether the build is using development App Attest and mock ZK.
- Privacy policy draft and review notes are updated for the actual build.

Before production relying-party use:

- RD-002 through RD-012 pass on multiple devices.
- Production App Attest is enforced server-side.
- Mock ZK is disabled in production.
- Real ZK proof verification has golden-vector and invalid-witness tests.
- Data retention and deletion workflows are implemented.

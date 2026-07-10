# Privacy Policy Draft

Last reviewed: 2026-07-10.

This draft is for the first Proof of Pulse TestFlight pilot. It is not legal advice and should be reviewed before public App Store release.

## Product Summary

Proof of Pulse creates a short-lived liveness summary from recent, permissioned Apple Health data on the user's iPhone. The app is designed to keep raw HealthKit samples on device and send only coarse proof material to the verifier API.

Proof of Pulse is not a medical device, does not provide diagnosis or treatment advice, and should not be used for emergency, clinical, or insurance decisions.

## Data We Request From HealthKit

The app requests read-only access to the minimum HealthKit types needed for the liveness experiment:

- heart-rate samples;
- resting-heart-rate samples;
- heart-rate-variability samples;
- step count;
- active energy burned;
- workouts.

The app does not request HealthKit write access in the current pilot.

## Data That Stays On Device

The app should keep the following data on device:

- raw HealthKit samples;
- exact heart-rate values;
- exact HRV values;
- exact step totals;
- exact active-energy values;
- workout details;
- route/location data;
- HealthKit source names;
- HealthKit local identifiers;
- device UDIs or stable HealthKit device identifiers.

The app reduces recent HealthKit data into coarse feature buckets before proof submission.

## Data Sent To The API

The current proof envelope can send:

- server challenge ID and challenge hash;
- proof version and scoring algorithm version;
- issued-at and expires-at timestamps;
- coarse score tier and threshold result;
- coarse time window boundaries;
- coarse feature buckets, such as recency, source-confidence class, signal count, continuity class, and whether user-entered samples were excluded;
- app-integrity evidence metadata;
- ZK proof metadata or public inputs when enabled;
- replay/nullifier material for the proof scope;
- request metadata naturally processed by the server, such as IP address and HTTP headers.

The current local PoC uses `development-app-attest` and `mock-score-threshold-v0`. Public production claims must not use those stubs.

## How We Use Data

We use proof data to:

- create and verify short-lived liveness summaries;
- prevent replay of the same proof;
- debug the proof flow during the pilot;
- measure aggregate reliability and failure modes without collecting raw HealthKit samples.

We do not use HealthKit-derived data for advertising, marketing, data brokerage, or unrelated analytics.

## Sharing

During the pilot, Proof of Pulse should not sell or share HealthKit-derived proof data with advertisers or data brokers.

If proof status is shared with a relying party, the relying party should receive only the public proof status required for that action, such as validity, expiration, score tier, and assurance level. Raw HealthKit data should not be shared.

## Retention

Recommended pilot retention:

- raw HealthKit samples: never uploaded;
- server challenges: delete after expiration plus a short abuse-investigation window;
- proof envelopes and nullifiers: retain only as long as needed for replay prevention, audit, and pilot debugging;
- logs: redact proof contents where possible and delete on a fixed schedule.

Before public launch, choose exact retention windows and publish them here.

## Deletion

Users should be able to request deletion of server-side proof records associated with their account or install, subject to retention needed for fraud prevention, legal compliance, or security logs.

Before public launch, add:

- support email;
- deletion request URL or in-app flow;
- expected deletion response time;
- identity verification process for deletion requests.

## Security

Production readiness requires:

- HTTPS-only API traffic;
- durable replay protection;
- real Apple App Attest validation;
- real ZK proof verification before making ZK claims;
- privacy-safe logs;
- least-privilege access to stored proof records;
- incident-response and breach-notification process.

## App Store Privacy Details Draft

Likely disclosures to review in App Store Connect:

- Health and Fitness: coarse derived proof features from HealthKit.
- Identifiers: proof IDs, install/device records, App Attest key IDs, and scoped nullifiers if stored.
- Usage Data: proof creation success/failure events if collected.
- Diagnostics: crash logs and performance data if enabled.
- Contact Info: only if accounts/support flows collect email or other contact data.

Mark data as linked to the user only if the production account model or server storage makes it linkable. Mark tracking as no unless the app shares data across companies for tracking as Apple defines it.

## Open Legal/Product Decisions

- Public privacy policy URL.
- Support email or support URL.
- Exact retention periods.
- Whether the first release is TestFlight-only research or public App Store.
- Whether proof records are account-linked, pseudonymous-install-linked, or anonymous.
- GDPR lawful basis and processor/subprocessor list for EU users.

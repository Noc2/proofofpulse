# App Store And TestFlight Review Notes Draft

Last reviewed: 2026-07-10.

Use this as the starting point for App Store Connect review notes. Update placeholders before submission.

## Reviewer Summary

Proof of Pulse is an experimental liveness app. It reads recent Apple Health data with user permission, reduces it on device into coarse feature buckets, and submits a short-lived proof envelope to the Proof of Pulse API.

The app does not upload raw HealthKit samples, exact heart-rate values, exact workout details, routes, source names, HealthKit local identifiers, or device UDIs.

The app is not a medical device and does not provide diagnosis, treatment advice, insurance decisions, or emergency functionality.

## HealthKit Purpose

The HealthKit access is used to create a privacy-preserving liveness summary from recent activity and heart-signal availability. The app requests read-only access and does not write data into HealthKit.

The proof is intentionally narrow: it is a short-lived liveness signal. It is not a guarantee of unique humanity, Apple Watch sensor-level attestation, or medical status.

## How To Test

Before review:

- Replace the Release `PROOF_OF_PULSE_API_BASE_URL` with the live HTTPS API.
- Make sure the API is live and reachable without local developer tools.
- Disable or clearly label any development-only proof path in the submitted build.
- Provide a demo mode only if it is fully labeled as demo data.

Suggested review path:

1. Install the app on an iPhone.
2. Open Proof of Pulse.
3. Grant read-only HealthKit permissions when prompted.
4. Tap `Create Pulse Proof`.
5. Confirm the proof status appears in the Proofs tab.

If the reviewer has no Apple Watch or recent HealthKit history, the app may show an insufficient-signal state. For TestFlight, provide a labeled demo build or reviewer instructions only if App Review allows the selected release type.

## Current Development Stubs

The local PoC still uses:

- `development-app-attest` for app-integrity evidence;
- `mock-score-threshold-v0` for ZK proof metadata.

These must not be presented as production Apple App Attest or real ZK verification in App Store copy. A production submission should either replace them or remove/lower the claim in UI and metadata.

## App Review Metadata Checklist

Required before upload:

- app name: Proof of Pulse;
- bundle ID;
- Apple Developer team ID;
- app icon;
- screenshots;
- support URL;
- privacy policy URL;
- age rating;
- category;
- review contact;
- review notes;
- demo account if the production flow requires authentication;
- live backend URL;
- App Privacy answers.

## Privacy Details Draft

Likely App Privacy categories to review:

- Health and Fitness: coarse liveness features derived from HealthKit.
- Identifiers: proof IDs, App Attest key IDs, install or account IDs, scoped nullifiers if retained.
- Diagnostics: crash or performance data if collected.
- Usage Data: proof creation success/failure analytics if collected.

The app should not use HealthKit-derived data for advertising, marketing, or data mining.

## Capability Checklist

In Apple Developer/App Store Connect:

- enable HealthKit for the App ID;
- enable App Attest/DeviceCheck for the App ID;
- ensure provisioning profiles include both capabilities;
- configure Release signing with a real `DEVELOPMENT_TEAM`;
- set Release `com.apple.developer.devicecheck.appattest-environment` to `production`;
- verify the uploaded binary does not include local-network permission unless it is needed by a real user-facing feature.

## Known Limitations To Disclose Internally

- HealthKit source metadata is a confidence signal, not sensor attestation.
- App Attest verifies the app instance, not the physical source of HealthKit samples.
- ZK proves computation over private inputs, not the truth of those inputs.
- Unique-humanity requires a separate issuer or deduplication process.
- Users without compatible Apple devices may be excluded from high-assurance proofs.

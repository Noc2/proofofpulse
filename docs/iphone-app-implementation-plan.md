# Proof of Pulse iPhone App Implementation Plan

This plan turns the current local Proof of Pulse POC into a testable iPhone app based on `design/proof-of-pulse-iphone-mockup.html`.

## Design Direction

- Use the mockup as the visual source of truth for V0:
  - dark `#333` app surface;
  - black iPhone frame only in the HTML mockup, not inside the real app;
  - six staggered pulsing dots from `hsl(160)` through blue;
  - compact proof panel with signal confidence, score ring, freshness, modality count, and ZK/private status;
  - tab-like bottom controls for Pulse, Proofs, and Keys.
- Keep the first screen as the usable proof screen, not a landing page.
- Avoid health-value disclosure in UI. Show buckets and confidence labels, not raw heart-rate or workout values.

## Architecture

### Existing Pieces

- `apps/ios/ProofOfPulseKit` already provides read-only HealthKit authorization and coarse feature extraction.
- `packages/core` already defines the Node scoring/envelope contract.
- `apps/api` already exposes challenge, development app-integrity registration, proof submission, replay checks, and public proof lookup.

### New Pieces

- `apps/ios/ProofOfPulseApp`
  - Xcode project and SwiftUI iPhone app target.
  - HealthKit entitlement and usage descriptions.
  - SwiftUI implementation of the mockup.
  - View model that requests HealthKit permission, collects features, scores locally, and submits to the local API.
  - Development settings for `http://127.0.0.1:8787` on simulator and configurable LAN host for real devices.

- `apps/ios/ProofOfPulseKit` additions
  - Swift mirror of `pulse-score-v0`.
  - Swift proof-envelope builder matching the backend JSON shape.
  - Small API client for the local POC endpoints.
  - Demo feature factory for simulator/UI fallback when HealthKit is unavailable.

## Implementation Steps

1. Commit the design mockup artifact.
2. Add this plan and double-check it against the repo/tooling.
3. Extend `ProofOfPulseKit` with scoring, challenge hashing, proof-envelope models, and API client.
4. Create `ProofOfPulseApp.xcodeproj` and app target.
5. Implement SwiftUI screens and animations matching the HTML mockup.
6. Wire the Create Pulse Proof action:
   - request read-only HealthKit authorization;
   - collect a 3-day feature window;
   - fall back to demo features when HealthKit is unavailable in simulator;
   - register a development app-integrity key;
   - request an API challenge;
   - build a challenge-bound proof envelope;
   - submit it to the local API;
   - show proof ID, score tier, and public status.
7. Add app testing documentation.
8. Verify with:
   - `npm test`;
   - `npm run simulate`;
   - Swift package type-check for `ProofOfPulseKit`;
   - Xcode build for `ProofOfPulseApp` against the iPhone Simulator SDK.

## Validation Notes

- `xcodegen` and `tuist` are not installed, so the app project will be checked in as a small manual `.xcodeproj`.
- Simulator runtime discovery can require access outside the repository sandbox. Prefer `xcodebuild` with a generic iOS Simulator destination and use elevated validation only when Xcode caches or CoreSimulator services require it.
- HealthKit cannot be meaningfully exercised in this environment without a real device and user authorization.
- Real Apple App Attest remains out of scope. The app will use the existing `development-app-attest` POC provider.
- Real ZK proof generation remains out of scope. The app will submit `mock-score-threshold-v0` proof metadata to match the existing backend.
- The app must not claim Apple Watch sensor attestation. It should label source confidence as heuristic.

## Done Criteria

- The app project opens/builds as an iPhone SwiftUI app.
- The Pulse screen visually follows the mockup and contains animated pulsing dots.
- The app can generate a demo proof against the local API on simulator.
- The app can request HealthKit read authorization and collect coarse features on a real device.
- The public proof status returned by the API is visible in the app.
- Docs describe simulator and real-device testing paths.
- All changes are committed in separate, reviewable steps and pushed to `main`.

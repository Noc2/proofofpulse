# ProofOfPulseKit

Dependency-free Swift package for the first iOS HealthKit collector skeleton.

The package requests read-only HealthKit access for:

- Step count
- Active energy burned
- Workouts
- Heart rate
- Resting heart rate

It does not request write access and does not emit raw health values. The public result is a coarse `PulseFeatures` value shaped for the repo's `pulse-score-v0` proof envelope: recency bucket, continuity bucket, signal count, signal buckets, source-confidence label, and source/device summaries.

## Usage

Add the local package from `apps/ios/ProofOfPulseKit`, enable the HealthKit capability for the app target, then call the collector from an async context:

```swift
import ProofOfPulseKit

let collector = HealthKitPulseCollector()

let authorization = try await collector.requestReadAuthorization()
guard authorization.requestSucceeded else {
    // Show an insufficient-signal or permission guidance state.
    return
}

let features = try await collector.collectPulseFeatures(
    window: .recent(days: 3)
)

// Submit only coarse features/proof material, not raw HealthKit samples.
print(features.sourceConfidence.rawValue)
```

HealthKit read authorization is intentionally opaque. A sparse result can mean no samples, denied permission, or a limited visible history window.

## Info.plist Guidance

The app target using this package needs a HealthKit share usage description:

```xml
<key>NSHealthShareUsageDescription</key>
<string>Proof of Pulse reads recent activity and heart signals to create a privacy-preserving liveness summary on this device. Raw health samples are not uploaded.</string>
```

Do not add `NSHealthUpdateUsageDescription` unless the app later writes HealthKit data. This collector is read-only.

Also enable the HealthKit capability in the app target so the app receives the HealthKit entitlement.

## Privacy Notes

- Samples marked with `HKMetadataKeyWasUserEntered == true` are excluded by query predicate and by an in-memory safety filter.
- Source and device details are reduced to coarse classes such as `apple_watch_likely`, `iphone_likely`, or `third_party_or_unknown`.
- The result does not include exact step totals, energy values, heart-rate values, workout details, source names, HealthKit local identifiers, UDIs, or stable device identifiers.

## Current Limitations

- HealthKit sample metadata is a trust signal, not sensor attestation.
- Apple Watch classification is heuristic and should be validated on real devices and OS versions.
- Bucket thresholds are POC defaults, not a calibrated liveness policy.
- The package does not include UI, App Attest, challenge binding, scoring thresholds, ZK proof generation, background delivery, or server submission.

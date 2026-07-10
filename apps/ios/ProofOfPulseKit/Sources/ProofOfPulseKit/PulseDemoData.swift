import Foundation

public enum PulseDemoData {
    public static func watchLikelyFeatures(now: Date = Date()) -> PulseFeatures {
        let window = PulseCollectionWindow.recent(days: 3, endingAt: now)
        return PulseFeatures(
            generatedAt: now,
            window: window,
            recencyBucket: .under6Hours,
            sourceConfidence: .watchLikely,
            signalCount: 4,
            continuityBucket: .moderate,
            signalBuckets: PulseSignalBuckets(
                steps: .moderate,
                activeEnergy: .moderate,
                workouts: .recent,
                heartRate: .sustained,
                restingHeartRate: .present,
                heartRateSpread: .moderate
            ),
            userEnteredSamplesExcluded: true,
            authorizationWindow: .fullOrUnknown,
            sourceSummary: PulseSourceSummary(
                appleWatchLikelySamples: .many,
                appleDeviceLikelySamples: .few,
                thirdPartyOrUnknownSamples: .none,
                observedModalities: [.stepCount, .activeEnergy, .workout, .heartRate]
            ),
            deviceSummary: PulseDeviceSummary(
                appleWatchLikelySamples: .many,
                iPhoneLikelySamples: .few,
                appleDeviceLikelySamples: .few,
                thirdPartyOrUnknownSamples: .none
            ),
            limitations: [
                "Demo signal for simulator and UI testing.",
                "This is not HealthKit data and cannot prove liveness."
            ]
        )
    }
}

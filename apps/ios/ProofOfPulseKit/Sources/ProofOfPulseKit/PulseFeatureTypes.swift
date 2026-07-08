import Foundation

public enum PulseAlgorithm {
    public static let scoreV0 = "pulse-score-v0"
}

public enum PulseKitError: Error, LocalizedError {
    case healthDataUnavailable
    case healthKitUnavailable
    case missingHealthKitObjectType(String)
    case invalidWindow

    public var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "Health data is not available on this device."
        case .healthKitUnavailable:
            return "HealthKit is not available for this build target."
        case let .missingHealthKitObjectType(identifier):
            return "HealthKit object type is unavailable: \(identifier)."
        case .invalidWindow:
            return "Pulse collection window must have a start date before its end date."
        }
    }
}

public struct PulseCollectionWindow: Codable, Equatable, Sendable {
    public var startedAt: Date
    public var endedAt: Date

    public init(startedAt: Date, endedAt: Date) {
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    public static func recent(seconds: TimeInterval, endingAt: Date = Date()) -> PulseCollectionWindow {
        PulseCollectionWindow(
            startedAt: endingAt.addingTimeInterval(-seconds),
            endedAt: endingAt
        )
    }

    public static func recent(days: Double, endingAt: Date = Date()) -> PulseCollectionWindow {
        recent(seconds: days * 24 * 60 * 60, endingAt: endingAt)
    }

    public var duration: TimeInterval {
        endedAt.timeIntervalSince(startedAt)
    }
}

public struct HealthKitAuthorizationResult: Codable, Equatable, Sendable {
    public var requestSucceeded: Bool
    public var requestedReadTypeIdentifiers: [String]
    public var readAuthorizationIsOpaque: Bool

    public init(
        requestSucceeded: Bool,
        requestedReadTypeIdentifiers: [String],
        readAuthorizationIsOpaque: Bool = true
    ) {
        self.requestSucceeded = requestSucceeded
        self.requestedReadTypeIdentifiers = requestedReadTypeIdentifiers
        self.readAuthorizationIsOpaque = readAuthorizationIsOpaque
    }
}

public enum PulseSignalModality: String, Codable, CaseIterable, Sendable {
    case stepCount = "step_count"
    case activeEnergy = "active_energy"
    case workout = "workout"
    case heartRate = "heart_rate"
    case restingHeartRate = "resting_heart_rate"
}

public enum PulseRecencyBucket: String, Codable, Sendable {
    case under6Hours = "under_6h"
    case under24Hours = "under_24h"
    case under72Hours = "under_72h"
    case stale = "stale"
    case none = "none"
}

public enum PulseContinuityBucket: String, Codable, Sendable {
    case none = "none"
    case weak = "weak"
    case moderate = "moderate"
    case strong = "strong"
}

public enum PulseSourceConfidence: String, Codable, Sendable {
    case watchLikely = "watch_likely"
    case appleDeviceLikely = "apple_device_likely"
    case healthKitMixed = "healthkit_mixed"
    case thirdPartyOnly = "third_party_only"
    case unknown = "unknown"
}

public enum PulseAuthorizationWindow: String, Codable, Sendable {
    case fullOrUnknown = "full_or_unknown"
    case limitedRecent = "limited_recent"
    case deniedOrEmpty = "denied_or_empty"
}

public enum PulseActivityBucket: String, Codable, Sendable {
    case none = "none"
    case low = "low"
    case moderate = "moderate"
    case high = "high"
}

public enum PulseWorkoutBucket: String, Codable, Sendable {
    case none = "none"
    case seenInWindow = "seen_in_window"
    case recent = "recent"
}

public enum PulseSamplePresenceBucket: String, Codable, Sendable {
    case none = "none"
    case sparse = "sparse"
    case present = "present"
    case sustained = "sustained"
}

public enum PulseHeartRateSpreadBucket: String, Codable, Sendable {
    case unavailable = "unavailable"
    case singleSample = "single_sample"
    case low = "low"
    case moderate = "moderate"
    case broad = "broad"
}

public enum PulseCountBucket: String, Codable, Sendable {
    case none = "none"
    case one = "one"
    case few = "few"
    case many = "many"
}

public enum PulseSourceClass: String, Codable, Sendable {
    case appleWatchLikely = "apple_watch_likely"
    case appleDeviceLikely = "apple_device_likely"
    case thirdPartyOrUnknown = "third_party_or_unknown"
}

public enum PulseDeviceClass: String, Codable, Sendable {
    case appleWatchLikely = "apple_watch_likely"
    case iPhoneLikely = "iphone_likely"
    case appleDeviceLikely = "apple_device_likely"
    case thirdPartyOrUnknown = "third_party_or_unknown"
}

public struct PulseSignalBuckets: Codable, Equatable, Sendable {
    public var steps: PulseActivityBucket
    public var activeEnergy: PulseActivityBucket
    public var workouts: PulseWorkoutBucket
    public var heartRate: PulseSamplePresenceBucket
    public var restingHeartRate: PulseSamplePresenceBucket
    public var heartRateSpread: PulseHeartRateSpreadBucket

    public init(
        steps: PulseActivityBucket,
        activeEnergy: PulseActivityBucket,
        workouts: PulseWorkoutBucket,
        heartRate: PulseSamplePresenceBucket,
        restingHeartRate: PulseSamplePresenceBucket,
        heartRateSpread: PulseHeartRateSpreadBucket
    ) {
        self.steps = steps
        self.activeEnergy = activeEnergy
        self.workouts = workouts
        self.heartRate = heartRate
        self.restingHeartRate = restingHeartRate
        self.heartRateSpread = heartRateSpread
    }
}

public struct PulseSourceSummary: Codable, Equatable, Sendable {
    public var appleWatchLikelySamples: PulseCountBucket
    public var appleDeviceLikelySamples: PulseCountBucket
    public var thirdPartyOrUnknownSamples: PulseCountBucket
    public var observedModalities: [PulseSignalModality]

    public init(
        appleWatchLikelySamples: PulseCountBucket,
        appleDeviceLikelySamples: PulseCountBucket,
        thirdPartyOrUnknownSamples: PulseCountBucket,
        observedModalities: [PulseSignalModality]
    ) {
        self.appleWatchLikelySamples = appleWatchLikelySamples
        self.appleDeviceLikelySamples = appleDeviceLikelySamples
        self.thirdPartyOrUnknownSamples = thirdPartyOrUnknownSamples
        self.observedModalities = observedModalities
    }
}

public struct PulseDeviceSummary: Codable, Equatable, Sendable {
    public var appleWatchLikelySamples: PulseCountBucket
    public var iPhoneLikelySamples: PulseCountBucket
    public var appleDeviceLikelySamples: PulseCountBucket
    public var thirdPartyOrUnknownSamples: PulseCountBucket

    public init(
        appleWatchLikelySamples: PulseCountBucket,
        iPhoneLikelySamples: PulseCountBucket,
        appleDeviceLikelySamples: PulseCountBucket,
        thirdPartyOrUnknownSamples: PulseCountBucket
    ) {
        self.appleWatchLikelySamples = appleWatchLikelySamples
        self.iPhoneLikelySamples = iPhoneLikelySamples
        self.appleDeviceLikelySamples = appleDeviceLikelySamples
        self.thirdPartyOrUnknownSamples = thirdPartyOrUnknownSamples
    }
}

public struct PulseFeatures: Codable, Equatable, Sendable {
    public var algorithmVersion: String
    public var generatedAt: Date
    public var window: PulseCollectionWindow
    public var recencyBucket: PulseRecencyBucket
    public var sourceConfidence: PulseSourceConfidence
    public var signalCount: Int
    public var continuityBucket: PulseContinuityBucket
    public var signalBuckets: PulseSignalBuckets
    public var userEnteredSamplesExcluded: Bool
    public var authorizationWindow: PulseAuthorizationWindow
    public var sourceSummary: PulseSourceSummary
    public var deviceSummary: PulseDeviceSummary
    public var limitations: [String]

    public init(
        algorithmVersion: String = PulseAlgorithm.scoreV0,
        generatedAt: Date = Date(),
        window: PulseCollectionWindow,
        recencyBucket: PulseRecencyBucket,
        sourceConfidence: PulseSourceConfidence,
        signalCount: Int,
        continuityBucket: PulseContinuityBucket,
        signalBuckets: PulseSignalBuckets,
        userEnteredSamplesExcluded: Bool,
        authorizationWindow: PulseAuthorizationWindow,
        sourceSummary: PulseSourceSummary,
        deviceSummary: PulseDeviceSummary,
        limitations: [String]
    ) {
        self.algorithmVersion = algorithmVersion
        self.generatedAt = generatedAt
        self.window = window
        self.recencyBucket = recencyBucket
        self.sourceConfidence = sourceConfidence
        self.signalCount = signalCount
        self.continuityBucket = continuityBucket
        self.signalBuckets = signalBuckets
        self.userEnteredSamplesExcluded = userEnteredSamplesExcluded
        self.authorizationWindow = authorizationWindow
        self.sourceSummary = sourceSummary
        self.deviceSummary = deviceSummary
        self.limitations = limitations
    }
}

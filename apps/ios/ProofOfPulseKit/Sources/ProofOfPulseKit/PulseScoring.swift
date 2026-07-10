import Foundation

public enum PulseScoreTier: String, Codable, Sendable {
    case passHigh = "pass_high"
    case pass = "pass"
    case review = "review"
    case fail = "fail"
}

public enum PulseThresholdTier: String, Codable, Sendable {
    case pass
    case fail
}

public struct PulseScoreBreakdown: Codable, Equatable, Sendable {
    public var recency: Int
    public var sourceConfidence: Int
    public var continuity: Int
    public var multimodal: Int
    public var userEntered: Int
    public var authorizationWindow: Int
    public var sparseOrImplausible: Int
}

public struct PulseScoreResult: Codable, Equatable, Sendable {
    public var algorithmVersion: String
    public var score: Int
    public var tier: PulseScoreTier
    public var thresholdTier: PulseThresholdTier
    public var passed: Bool
    public var breakdown: PulseScoreBreakdown
}

public enum PulseScoring {
    public static let passThreshold = 60
    public static let passHighThreshold = 80

    public static func score(_ features: PulseFeatures) -> PulseScoreResult {
        let breakdown = PulseScoreBreakdown(
            recency: recencyPoints(features.recencyBucket),
            sourceConfidence: sourceConfidencePoints(features.sourceConfidence),
            continuity: continuityPoints(features.continuityBucket),
            multimodal: min(max(features.signalCount, 0), 4) * 5,
            userEntered: features.userEnteredSamplesExcluded ? 0 : -25,
            authorizationWindow: authorizationPoints(features.authorizationWindow),
            sparseOrImplausible: features.signalCount == 0 ? -20 : 0
        )

        let rawScore = breakdown.recency
            + breakdown.sourceConfidence
            + breakdown.continuity
            + breakdown.multimodal
            + breakdown.userEntered
            + breakdown.authorizationWindow
            + breakdown.sparseOrImplausible
        let score = min(max(rawScore, 0), 100)

        return PulseScoreResult(
            algorithmVersion: PulseAlgorithm.scoreV0,
            score: score,
            tier: tier(for: score),
            thresholdTier: score >= passThreshold ? .pass : .fail,
            passed: score >= passThreshold,
            breakdown: breakdown
        )
    }

    public static func tier(for score: Int) -> PulseScoreTier {
        if score >= passHighThreshold {
            return .passHigh
        }

        if score >= passThreshold {
            return .pass
        }

        if score >= 40 {
            return .review
        }

        return .fail
    }

    private static func recencyPoints(_ bucket: PulseRecencyBucket) -> Int {
        switch bucket {
        case .under6Hours:
            return 35
        case .under24Hours:
            return 28
        case .under72Hours:
            return 14
        case .stale:
            return 0
        case .none:
            return -20
        }
    }

    private static func sourceConfidencePoints(_ bucket: PulseSourceConfidence) -> Int {
        switch bucket {
        case .watchLikely:
            return 35
        case .appleDeviceLikely:
            return 25
        case .healthKitMixed:
            return 12
        case .thirdPartyOnly:
            return -10
        case .unknown:
            return 0
        }
    }

    private static func continuityPoints(_ bucket: PulseContinuityBucket) -> Int {
        switch bucket {
        case .strong:
            return 20
        case .moderate:
            return 12
        case .weak:
            return 5
        case .none:
            return 0
        }
    }

    private static func authorizationPoints(_ bucket: PulseAuthorizationWindow) -> Int {
        switch bucket {
        case .fullOrUnknown:
            return 0
        case .limitedRecent:
            return -5
        case .deniedOrEmpty:
            return -15
        }
    }
}

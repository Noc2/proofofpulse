import Foundation

#if canImport(CryptoKit)
import CryptoKit
#endif

public enum PulseProof {
    public static let version = "pop-proof-v0"
    public static let claim = "recent-wearable-backed-liveness-signal"
    public static let defaultScope = "ios-app/local"
    public static let defaultProofTtl: TimeInterval = 5 * 60
}

public struct PulseChallenge: Codable, Equatable, Sendable {
    public var id: String
    public var nonce: String
    public var issuedAt: String?
    public var expiresAt: String
    public var usedAt: String?
}

public struct PulseAppIntegrityEvidence: Codable, Equatable, Sendable {
    public var provider: String
    public var keyId: String?
    public var assertionId: String?

    public init(
        provider: String = "development-app-attest",
        keyId: String?,
        assertionId: String?
    ) {
        self.provider = provider
        self.keyId = keyId
        self.assertionId = assertionId
    }
}

public struct PulseProofScore: Codable, Equatable, Sendable {
    public var tier: String
    public var thresholdTier: String
    public var passed: Bool
}

public struct PulseProofWindow: Codable, Equatable, Sendable {
    public var startedAt: String?
    public var endedAt: String?
    public var granularity: String
}

public struct PulseProofFeatures: Codable, Equatable, Sendable {
    public var recencyBucket: String
    public var sourceConfidence: String
    public var signalCount: Int
    public var continuityBucket: String
    public var userEnteredSamplesExcluded: Bool
    public var authorizationWindow: String
    public var digitalSignatureObserved: Bool
}

public struct PulseProofZK: Codable, Equatable, Sendable {
    public var scheme: String
    public var proofId: String?
    public var publicInputs: [String: String]
}

public struct PulseProofReplayProtection: Codable, Equatable, Sendable {
    public var epoch: String
    public var nullifierHash: String
}

public struct PulseProofEnvelope: Codable, Equatable, Sendable {
    public var version: String
    public var challengeId: String
    public var challengeHash: String
    public var issuedAt: String
    public var expiresAt: String
    public var claim: String
    public var algorithmVersion: String
    public var score: PulseProofScore
    public var window: PulseProofWindow
    public var features: PulseProofFeatures
    public var appIntegrity: PulseAppIntegrityEvidence
    public var zk: PulseProofZK
    public var replayProtection: PulseProofReplayProtection
}

public struct PulsePublicProofStatus: Codable, Equatable, Sendable {
    public var id: String
    public var status: String
    public var claim: String
    public var issuedAt: String
    public var expiresAt: String
    public var scorePassed: Bool
    public var scoreTier: String
    public var sourceConfidence: String
    public var zkVerified: Bool
    public var nullifierScope: String
}

public enum PulseProofEnvelopeFactory {
    public static func makeEnvelope(
        challenge: PulseChallenge,
        features: PulseFeatures,
        appIntegrity: PulseAppIntegrityEvidence,
        scope: String = PulseProof.defaultScope,
        now: Date = Date(),
        proofTtl: TimeInterval = PulseProof.defaultProofTtl,
        zkScheme: String = "mock-score-threshold-v0"
    ) throws -> PulseProofEnvelope {
        let challengeHash = try PulseHashing.hashChallenge(challenge)
        let issuedAt = PulseDateFormatting.iso8601String(from: now)
        let expiresAt = PulseDateFormatting.iso8601String(from: now.addingTimeInterval(proofTtl))
        let scored = PulseScoring.score(features)
        let nullifierHash = try PulseHashing.sha256Base64URL("\(scope):\(challenge.id):\(challengeHash)")

        return PulseProofEnvelope(
            version: PulseProof.version,
            challengeId: challenge.id,
            challengeHash: challengeHash,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            claim: PulseProof.claim,
            algorithmVersion: PulseAlgorithm.scoreV0,
            score: PulseProofScore(
                tier: scored.tier.rawValue,
                thresholdTier: scored.thresholdTier.rawValue,
                passed: scored.passed
            ),
            window: PulseProofWindow(
                startedAt: PulseDateFormatting.iso8601String(from: features.window.startedAt),
                endedAt: PulseDateFormatting.iso8601String(from: features.window.endedAt),
                granularity: "coarse"
            ),
            features: PulseProofFeatures(
                recencyBucket: features.recencyBucket.rawValue,
                sourceConfidence: features.sourceConfidence.rawValue,
                signalCount: features.signalCount,
                continuityBucket: features.continuityBucket.rawValue,
                userEnteredSamplesExcluded: features.userEnteredSamplesExcluded,
                authorizationWindow: features.authorizationWindow.rawValue,
                digitalSignatureObserved: false
            ),
            appIntegrity: appIntegrity,
            zk: zkEvidence(
                scheme: zkScheme,
                challengeHash: challengeHash,
                scoreTier: scored.tier.rawValue
            ),
            replayProtection: PulseProofReplayProtection(
                epoch: PulseDateFormatting.hourEpochString(from: now),
                nullifierHash: nullifierHash
            )
        )
    }

    private static func zkEvidence(
        scheme: String,
        challengeHash: String,
        scoreTier: String
    ) -> PulseProofZK {
        if scheme == "none" {
            return PulseProofZK(
                scheme: "none",
                proofId: nil,
                publicInputs: [
                    "algorithmVersion": PulseAlgorithm.scoreV0,
                    "challengeHash": challengeHash,
                    "scoreTier": scoreTier
                ]
            )
        }

        return PulseProofZK(
            scheme: scheme,
            proofId: "mock_zk_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))",
            publicInputs: [
                "algorithmVersion": PulseAlgorithm.scoreV0,
                "challengeHash": challengeHash,
                "scoreTier": scoreTier,
                "proofSystem": "development-mock"
            ]
        )
    }
}

public enum PulseHashing {
    public static func hashChallenge(_ challenge: PulseChallenge) throws -> String {
        let stableChallengeJson = "{\"expiresAt\":\"\(challenge.expiresAt)\",\"id\":\"\(challenge.id)\",\"nonce\":\"\(challenge.nonce)\"}"
        return try sha256Base64URL(stableChallengeJson)
    }

    public static func sha256Base64URL(_ string: String) throws -> String {
        guard let data = string.data(using: .utf8) else {
            throw PulseKitError.encodingFailed
        }

        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: data)
        return Data(digest).base64URLEncodedString()
        #else
        throw PulseKitError.cryptoUnavailable
        #endif
    }
}

public enum PulseDateFormatting {
    public static func iso8601String(from date: Date) -> String {
        isoFormatter.string(from: date)
    }

    public static func hourEpochString(from date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        return String(
            format: "%04d-%02d-%02dT%02d:00Z",
            components.year ?? 1970,
            components.month ?? 1,
            components.day ?? 1,
            components.hour ?? 0
        )
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        if let utc = TimeZone(secondsFromGMT: 0) {
            calendar.timeZone = utc
        }
        return calendar
    }()
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

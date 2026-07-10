import Foundation

@MainActor
final class PulseViewModel: ObservableObject {
    enum Tab: String, CaseIterable {
        case pulse = "Pulse"
        case proofs = "Proofs"
        case keys = "Keys"
    }

    enum RunState: Equatable {
        case idle
        case collecting
        case submitting
        case complete
        case failed
    }

    @Published var activeTab: Tab = .pulse
    @Published var apiBaseURLString: String {
        didSet {
            UserDefaults.standard.set(apiBaseURLString, forKey: Self.apiBaseURLDefaultsKey)
        }
    }
    @Published var useDemoSignal: Bool {
        didSet {
            UserDefaults.standard.set(useDemoSignal, forKey: Self.demoSignalDefaultsKey)
        }
    }
    @Published private(set) var features: PulseFeatures
    @Published private(set) var score: PulseScoreResult
    @Published private(set) var lastProof: PulsePublicProofStatus?
    @Published private(set) var envelopeHash: String?
    @Published private(set) var runState: RunState = .idle
    @Published private(set) var activityMessage = "Ready to create a short-lived proof."
    @Published var errorMessage: String?

    private let collector = HealthKitPulseCollector()

    init() {
        let initialFeatures = PulseDemoData.watchLikelyFeatures()
        self.features = initialFeatures
        self.score = PulseScoring.score(initialFeatures)
        if PulseRuntime.allowsDevelopmentSettings {
            self.apiBaseURLString = UserDefaults.standard.string(forKey: Self.apiBaseURLDefaultsKey)
                ?? PulseRuntime.defaultAPIBaseURLString
        } else {
            self.apiBaseURLString = PulseRuntime.defaultAPIBaseURLString
        }

        if !PulseRuntime.allowsDemoSignal {
            self.useDemoSignal = false
        } else if UserDefaults.standard.object(forKey: Self.demoSignalDefaultsKey) == nil {
            #if targetEnvironment(simulator)
            self.useDemoSignal = true
            #else
            self.useDemoSignal = false
            #endif
        } else {
            self.useDemoSignal = UserDefaults.standard.bool(forKey: Self.demoSignalDefaultsKey)
        }
    }

    var isRunning: Bool {
        runState == .collecting || runState == .submitting
    }

    var allowsDevelopmentSettings: Bool {
        PulseRuntime.allowsDevelopmentSettings
    }

    var runtimeModeLabel: String {
        PulseRuntime.modeLabel
    }

    var zkStatusLabel: String {
        guard lastProof?.zkVerified == true else {
            return "private"
        }

        return PulseRuntime.allowsDevelopmentSettings ? "mock" : "verified"
    }

    var sourceLabel: String {
        features.sourceConfidence.rawValue
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    var freshnessLabel: String {
        features.recencyBucket.rawValue
            .replacingOccurrences(of: "under_", with: "under ")
            .replacingOccurrences(of: "_", with: " ")
    }

    var proofButtonTitle: String {
        switch runState {
        case .collecting:
            return "Reading Signal"
        case .submitting:
            return "Submitting Proof"
        case .complete:
            return "Refresh Pulse Proof"
        case .failed, .idle:
            return "Create Pulse Proof"
        }
    }

    func createPulseProof() async {
        guard !isRunning else {
            return
        }

        errorMessage = nil
        lastProof = nil
        envelopeHash = nil
        runState = .collecting
        activityMessage = useDemoSignal ? "Preparing demo signal." : "Requesting HealthKit access."

        do {
            let collectedFeatures = try await collectFeatures()
            features = collectedFeatures
            score = PulseScoring.score(collectedFeatures)

            guard score.passed else {
                runState = .failed
                activityMessage = "Signal did not reach the liveness threshold."
                errorMessage = "The current feature buckets scored \(score.score), below the \(PulseScoring.passThreshold) point threshold."
                return
            }

            runState = .submitting
            activityMessage = "Submitting challenge-bound proof."

            guard let baseURL = URL(string: apiBaseURLString) else {
                throw PulseViewModelError.invalidAPIBaseURL
            }

            let client = PulseAPIClient(baseURL: baseURL)
            let keyId = Self.developmentKeyId()
            try await client.registerDevelopmentAppAttestKey(keyId: keyId)
            let challenge = try await client.issueChallenge()
            let envelope = try PulseProofEnvelopeFactory.makeEnvelope(
                challenge: challenge,
                features: collectedFeatures,
                appIntegrity: PulseAppIntegrityEvidence(
                    keyId: keyId,
                    assertionId: "ios_assertion_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
                ),
                scope: "proof-of-pulse-ios"
            )
            let response = try await client.submitProof(envelope: envelope)
            lastProof = response.proof
            envelopeHash = response.envelopeHash
            runState = .complete
            activityMessage = "Pulse proof accepted by the local API."
        } catch {
            runState = .failed
            activityMessage = "Proof creation failed."
            errorMessage = error.localizedDescription
        }
    }

    private func collectFeatures() async throws -> PulseFeatures {
        guard PulseRuntime.allowsDemoSignal || !useDemoSignal else {
            throw PulseViewModelError.demoSignalUnavailable
        }

        if useDemoSignal {
            return PulseDemoData.watchLikelyFeatures()
        }

        _ = try await collector.requestReadAuthorization()
        return try await collector.collectPulseFeatures(window: .recent(days: 3))
    }

    private static func developmentKeyId() -> String {
        if let existing = UserDefaults.standard.string(forKey: developmentKeyDefaultsKey) {
            return existing
        }

        let key = "ios-dev-\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        UserDefaults.standard.set(key, forKey: developmentKeyDefaultsKey)
        return key
    }

    private static let apiBaseURLDefaultsKey = "ProofOfPulse.APIBaseURL"
    private static let demoSignalDefaultsKey = "ProofOfPulse.UseDemoSignal"
    private static let developmentKeyDefaultsKey = "ProofOfPulse.DevelopmentKeyId"
}

enum PulseViewModelError: Error, LocalizedError {
    case invalidAPIBaseURL
    case demoSignalUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidAPIBaseURL:
            return "The API base URL is invalid."
        case .demoSignalUnavailable:
            return "Demo signal is unavailable in this build."
        }
    }
}

private enum PulseRuntime {
    #if DEBUG
    static let allowsDevelopmentSettings = true
    static let allowsDemoSignal = true
    static let modeLabel = "Debug POC"
    #else
    static let allowsDevelopmentSettings = false
    static let allowsDemoSignal = false
    static let modeLabel = "Release"
    #endif

    static var defaultAPIBaseURLString: String {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "ProofOfPulseAPIBaseURL") as? String,
           configured.contains("://") {
            return configured
        }

        #if DEBUG
        return "http://127.0.0.1:8787"
        #else
        return "https://api.proofofpulse.example"
        #endif
    }
}

import Foundation

#if canImport(HealthKit)
import HealthKit

public final class HealthKitPulseCollector {
    public static let requestedReadTypeIdentifiers = [
        "HKQuantityTypeIdentifierStepCount",
        "HKQuantityTypeIdentifierActiveEnergyBurned",
        "HKWorkoutTypeIdentifier",
        "HKQuantityTypeIdentifierHeartRate",
        "HKQuantityTypeIdentifierRestingHeartRate"
    ]

    private let healthStore: HKHealthStore
    private let calendar: Calendar
    private let sampleLimit: Int

    public init(
        healthStore: HKHealthStore = HKHealthStore(),
        calendar: Calendar = .autoupdatingCurrent,
        sampleLimit: Int = 1_000
    ) {
        self.healthStore = healthStore
        self.calendar = calendar
        self.sampleLimit = sampleLimit
    }

    public static func isHealthDataAvailable() -> Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    public func requestReadAuthorization() async throws -> HealthKitAuthorizationResult {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw PulseKitError.healthDataUnavailable
        }

        let readTypes = try Self.requiredReadTypes()
        let requestSucceeded = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            healthStore.requestAuthorization(toShare: Set<HKSampleType>(), read: readTypes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: success)
            }
        }

        return HealthKitAuthorizationResult(
            requestSucceeded: requestSucceeded,
            requestedReadTypeIdentifiers: Self.requestedReadTypeIdentifiers,
            readAuthorizationIsOpaque: true
        )
    }

    public func collectPulseFeatures(
        window: PulseCollectionWindow = .recent(days: 3)
    ) async throws -> PulseFeatures {
        guard window.startedAt < window.endedAt else {
            throw PulseKitError.invalidWindow
        }

        async let stepTotal = cumulativeSum(
            for: .stepCount,
            unit: .count(),
            window: window
        )
        async let activeEnergyTotal = cumulativeSum(
            for: .activeEnergyBurned,
            unit: .kilocalorie(),
            window: window
        )
        async let stepSamples = quantitySamples(
            for: .stepCount,
            window: window,
            limit: sampleLimit
        )
        async let activeEnergySamples = quantitySamples(
            for: .activeEnergyBurned,
            window: window,
            limit: sampleLimit
        )
        async let workouts = workoutSamples(
            window: window,
            limit: min(sampleLimit, 200)
        )
        async let heartRateSamples = quantitySamples(
            for: .heartRate,
            window: window,
            limit: sampleLimit
        )
        async let restingHeartRateSamples = quantitySamples(
            for: .restingHeartRate,
            window: window,
            limit: sampleLimit
        )

        let collectedStepTotal = try await stepTotal
        let collectedActiveEnergyTotal = try await activeEnergyTotal
        let collectedStepSamples = try await stepSamples
        let collectedActiveEnergySamples = try await activeEnergySamples
        let collectedWorkouts = try await workouts
        let collectedHeartRateSamples = try await heartRateSamples
        let collectedRestingHeartRateSamples = try await restingHeartRateSamples

        let facts = sampleFacts(
            stepSamples: collectedStepSamples,
            activeEnergySamples: collectedActiveEnergySamples,
            workouts: collectedWorkouts,
            heartRateSamples: collectedHeartRateSamples,
            restingHeartRateSamples: collectedRestingHeartRateSamples
        )

        return buildFeatures(
            window: window,
            stepTotal: collectedStepTotal,
            activeEnergyTotal: collectedActiveEnergyTotal,
            workouts: collectedWorkouts,
            heartRateSamples: collectedHeartRateSamples,
            restingHeartRateSamples: collectedRestingHeartRateSamples,
            facts: facts
        )
    }

    private static func requiredReadTypes() throws -> Set<HKObjectType> {
        [
            try quantityType(for: .stepCount),
            try quantityType(for: .activeEnergyBurned),
            HKObjectType.workoutType(),
            try quantityType(for: .heartRate),
            try quantityType(for: .restingHeartRate)
        ]
    }

    private static func quantityType(for identifier: HKQuantityTypeIdentifier) throws -> HKQuantityType {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw PulseKitError.missingHealthKitObjectType(identifier.rawValue)
        }

        return type
    }

    private func cumulativeSum(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        window: PulseCollectionWindow
    ) async throws -> Double {
        let type = try Self.quantityType(for: identifier)
        let predicate = samplePredicate(for: window)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double, Error>) in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }

            healthStore.execute(query)
        }
    }

    private func quantitySamples(
        for identifier: HKQuantityTypeIdentifier,
        window: PulseCollectionWindow,
        limit: Int
    ) async throws -> [HKQuantitySample] {
        let type = try Self.quantityType(for: identifier)
        let predicate = samplePredicate(for: window)
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: false
        )

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKQuantitySample], Error>) in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let quantitySamples = (samples ?? [])
                    .compactMap { $0 as? HKQuantitySample }
                    .filter { !$0.pulseWasUserEntered }
                continuation.resume(returning: quantitySamples)
            }

            healthStore.execute(query)
        }
    }

    private func workoutSamples(
        window: PulseCollectionWindow,
        limit: Int
    ) async throws -> [HKWorkout] {
        let predicate = samplePredicate(for: window)
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: false
        )

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkout], Error>) in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let workouts = (samples ?? [])
                    .compactMap { $0 as? HKWorkout }
                    .filter { !$0.pulseWasUserEntered }
                continuation.resume(returning: workouts)
            }

            healthStore.execute(query)
        }
    }

    private func samplePredicate(for window: PulseCollectionWindow) -> NSPredicate {
        let datePredicate = HKQuery.predicateForSamples(
            withStart: window.startedAt,
            end: window.endedAt,
            options: [.strictStartDate, .strictEndDate]
        )
        let notUserEnteredPredicate = HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeyWasUserEntered,
            operatorType: .notEqualTo,
            value: true
        )

        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            datePredicate,
            notUserEnteredPredicate
        ])
    }

    private func sampleFacts(
        stepSamples: [HKQuantitySample],
        activeEnergySamples: [HKQuantitySample],
        workouts: [HKWorkout],
        heartRateSamples: [HKQuantitySample],
        restingHeartRateSamples: [HKQuantitySample]
    ) -> [SampleFact] {
        var facts: [SampleFact] = []
        facts += stepSamples.map { SampleFact(sample: $0, modality: .stepCount) }
        facts += activeEnergySamples.map { SampleFact(sample: $0, modality: .activeEnergy) }
        facts += workouts.map { SampleFact(sample: $0, modality: .workout) }
        facts += heartRateSamples.map { SampleFact(sample: $0, modality: .heartRate) }
        facts += restingHeartRateSamples.map { SampleFact(sample: $0, modality: .restingHeartRate) }
        return facts
    }

    private func buildFeatures(
        window: PulseCollectionWindow,
        stepTotal: Double,
        activeEnergyTotal: Double,
        workouts: [HKWorkout],
        heartRateSamples: [HKQuantitySample],
        restingHeartRateSamples: [HKQuantitySample],
        facts: [SampleFact]
    ) -> PulseFeatures {
        let stepsBucket = activityBucket(
            total: stepTotal,
            window: window,
            lowPerDay: 1_000,
            highPerDay: 5_000
        )
        let activeEnergyBucket = activityBucket(
            total: activeEnergyTotal,
            window: window,
            lowPerDay: 50,
            highPerDay: 250
        )
        let workoutBucket = self.workoutBucket(workouts, window: window)
        let heartRateBucket = presenceBucket(heartRateSamples)
        let restingHeartRateBucket = presenceBucket(restingHeartRateSamples)
        let heartRateSpreadBucket = heartRateSpreadBucket(heartRateSamples)

        let signalBuckets = PulseSignalBuckets(
            steps: stepsBucket,
            activeEnergy: activeEnergyBucket,
            workouts: workoutBucket,
            heartRate: heartRateBucket,
            restingHeartRate: restingHeartRateBucket,
            heartRateSpread: heartRateSpreadBucket
        )

        let observedModalities = Set(facts.map(\.modality))
        let signalCount = [
            stepsBucket != .none,
            activeEnergyBucket != .none,
            workoutBucket != .none,
            heartRateBucket != .none,
            restingHeartRateBucket != .none
        ].filter { $0 }.count

        return PulseFeatures(
            window: window,
            recencyBucket: recencyBucket(for: facts, window: window),
            sourceConfidence: sourceConfidence(for: facts, signalCount: signalCount),
            signalCount: signalCount,
            continuityBucket: continuityBucket(for: facts, window: window),
            signalBuckets: signalBuckets,
            userEnteredSamplesExcluded: true,
            authorizationWindow: signalCount == 0 ? .deniedOrEmpty : .fullOrUnknown,
            sourceSummary: sourceSummary(for: facts, observedModalities: observedModalities),
            deviceSummary: deviceSummary(for: facts),
            limitations: limitations(signalCount: signalCount)
        )
    }

    private func activityBucket(
        total: Double,
        window: PulseCollectionWindow,
        lowPerDay: Double,
        highPerDay: Double
    ) -> PulseActivityBucket {
        guard total > 0 else {
            return .none
        }

        let days = max(window.duration / 86_400, 1)
        let averagePerDay = total / days

        if averagePerDay < lowPerDay {
            return .low
        }

        if averagePerDay < highPerDay {
            return .moderate
        }

        return .high
    }

    private func workoutBucket(
        _ workouts: [HKWorkout],
        window: PulseCollectionWindow
    ) -> PulseWorkoutBucket {
        guard let latestWorkout = workouts.map(\.endDate).max() else {
            return .none
        }

        let age = window.endedAt.timeIntervalSince(latestWorkout)
        return age <= 24 * 60 * 60 ? .recent : .seenInWindow
    }

    private func presenceBucket(_ samples: [HKQuantitySample]) -> PulseSamplePresenceBucket {
        switch samples.count {
        case 0:
            return .none
        case 1..<3:
            return .sparse
        case 3..<12:
            return .present
        default:
            return .sustained
        }
    }

    private func heartRateSpreadBucket(_ samples: [HKQuantitySample]) -> PulseHeartRateSpreadBucket {
        guard samples.count > 1 else {
            return samples.isEmpty ? .unavailable : .singleSample
        }

        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let values = samples.map { $0.quantity.doubleValue(for: bpmUnit) }
        guard let minValue = values.min(), let maxValue = values.max() else {
            return .unavailable
        }

        let spread = maxValue - minValue
        if spread < 10 {
            return .low
        }

        if spread < 30 {
            return .moderate
        }

        return .broad
    }

    private func recencyBucket(
        for facts: [SampleFact],
        window: PulseCollectionWindow
    ) -> PulseRecencyBucket {
        guard let latest = facts.map(\.endDate).max() else {
            return .none
        }

        let age = window.endedAt.timeIntervalSince(latest)
        if age <= 6 * 60 * 60 {
            return .under6Hours
        }

        if age <= 24 * 60 * 60 {
            return .under24Hours
        }

        if age <= 72 * 60 * 60 {
            return .under72Hours
        }

        return .stale
    }

    private func continuityBucket(
        for facts: [SampleFact],
        window: PulseCollectionWindow
    ) -> PulseContinuityBucket {
        guard !facts.isEmpty else {
            return .none
        }

        let activeDays = Set(facts.map { calendar.startOfDay(for: $0.endDate) }).count
        let possibleDays = max(Int(ceil(window.duration / 86_400)), 1)
        let ratio = Double(activeDays) / Double(possibleDays)

        if ratio < 0.25 {
            return .weak
        }

        if ratio < 0.75 {
            return .moderate
        }

        return .strong
    }

    private func sourceConfidence(
        for facts: [SampleFact],
        signalCount: Int
    ) -> PulseSourceConfidence {
        guard signalCount > 0 else {
            return .unknown
        }

        let watchCount = facts.filter { $0.sourceClass == .appleWatchLikely || $0.deviceClass == .appleWatchLikely }.count
        let appleCount = facts.filter {
            $0.sourceClass == .appleDeviceLikely ||
                $0.deviceClass == .appleDeviceLikely ||
                $0.deviceClass == .iPhoneLikely
        }.count
        let thirdPartyCount = facts.filter {
            $0.sourceClass == .thirdPartyOrUnknown && $0.deviceClass == .thirdPartyOrUnknown
        }.count

        if watchCount > 0 {
            return .watchLikely
        }

        if appleCount > 0 && thirdPartyCount == 0 {
            return .appleDeviceLikely
        }

        if thirdPartyCount > 0 && appleCount == 0 {
            return .thirdPartyOnly
        }

        return .healthKitMixed
    }

    private func sourceSummary(
        for facts: [SampleFact],
        observedModalities: Set<PulseSignalModality>
    ) -> PulseSourceSummary {
        PulseSourceSummary(
            appleWatchLikelySamples: countBucket(facts.filter { $0.sourceClass == .appleWatchLikely }.count),
            appleDeviceLikelySamples: countBucket(facts.filter { $0.sourceClass == .appleDeviceLikely }.count),
            thirdPartyOrUnknownSamples: countBucket(facts.filter { $0.sourceClass == .thirdPartyOrUnknown }.count),
            observedModalities: PulseSignalModality.allCases.filter { observedModalities.contains($0) }
        )
    }

    private func deviceSummary(for facts: [SampleFact]) -> PulseDeviceSummary {
        PulseDeviceSummary(
            appleWatchLikelySamples: countBucket(facts.filter { $0.deviceClass == .appleWatchLikely }.count),
            iPhoneLikelySamples: countBucket(facts.filter { $0.deviceClass == .iPhoneLikely }.count),
            appleDeviceLikelySamples: countBucket(facts.filter { $0.deviceClass == .appleDeviceLikely }.count),
            thirdPartyOrUnknownSamples: countBucket(facts.filter { $0.deviceClass == .thirdPartyOrUnknown }.count)
        )
    }

    private func countBucket(_ count: Int) -> PulseCountBucket {
        switch count {
        case 0:
            return .none
        case 1:
            return .one
        case 2..<5:
            return .few
        default:
            return .many
        }
    }

    private func limitations(signalCount: Int) -> [String] {
        var values = [
            "HealthKit source and device metadata are confidence signals, not sensor attestations.",
            "HealthKit read authorization is opaque; sparse results may mean denied access, limited history, or no samples.",
            "Bucket thresholds are POC defaults and need validation with real Apple Watch and iPhone data."
        ]

        if signalCount == 0 {
            values.append("No accepted samples were found in the requested window.")
        }

        return values
    }
}

private struct SampleFact {
    var modality: PulseSignalModality
    var endDate: Date
    var sourceClass: PulseSourceClass
    var deviceClass: PulseDeviceClass

    init(sample: HKSample, modality: PulseSignalModality) {
        self.modality = modality
        self.endDate = sample.endDate
        self.sourceClass = SampleFact.classifySource(sample)
        self.deviceClass = SampleFact.classifyDevice(sample)
    }

    private static func classifySource(_ sample: HKSample) -> PulseSourceClass {
        let bundleIdentifier = sample.sourceRevision.source.bundleIdentifier.lowercased()
        let sourceName = sample.sourceRevision.source.name.lowercased()
        let productType = sample.sourceRevision.productType?.lowercased() ?? ""

        if productType.contains("watch") || sourceName.contains("watch") || bundleIdentifier.contains("watch") {
            return .appleWatchLikely
        }

        if bundleIdentifier.hasPrefix("com.apple.") || sourceName.contains("apple") {
            return .appleDeviceLikely
        }

        return .thirdPartyOrUnknown
    }

    private static func classifyDevice(_ sample: HKSample) -> PulseDeviceClass {
        let productType = sample.sourceRevision.productType?.lowercased() ?? ""
        let manufacturer = sample.device?.manufacturer?.lowercased() ?? ""
        let model = sample.device?.model?.lowercased() ?? ""
        let name = sample.device?.name?.lowercased() ?? ""

        if productType.contains("watch") || model.contains("watch") || name.contains("watch") {
            return .appleWatchLikely
        }

        if model.contains("iphone") || name.contains("iphone") {
            return .iPhoneLikely
        }

        if manufacturer.contains("apple") || productType.contains("iphone") || productType.contains("ipad") {
            return .appleDeviceLikely
        }

        return .thirdPartyOrUnknown
    }
}

private extension HKObject {
    var pulseWasUserEntered: Bool {
        guard let value = metadata?[HKMetadataKeyWasUserEntered] else {
            return false
        }

        if let boolValue = value as? Bool {
            return boolValue
        }

        if let numberValue = value as? NSNumber {
            return numberValue.boolValue
        }

        return false
    }
}

#else

public final class HealthKitPulseCollector {
    public static let requestedReadTypeIdentifiers = [
        "HKQuantityTypeIdentifierStepCount",
        "HKQuantityTypeIdentifierActiveEnergyBurned",
        "HKWorkoutTypeIdentifier",
        "HKQuantityTypeIdentifierHeartRate",
        "HKQuantityTypeIdentifierRestingHeartRate"
    ]

    public init() {}

    public static func isHealthDataAvailable() -> Bool {
        false
    }

    public func requestReadAuthorization() async throws -> HealthKitAuthorizationResult {
        throw PulseKitError.healthKitUnavailable
    }

    public func collectPulseFeatures(
        window: PulseCollectionWindow = .recent(days: 3)
    ) async throws -> PulseFeatures {
        _ = window
        throw PulseKitError.healthKitUnavailable
    }
}

#endif

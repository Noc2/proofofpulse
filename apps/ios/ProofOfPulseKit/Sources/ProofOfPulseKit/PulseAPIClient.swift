import Foundation

public struct PulseAPIClient: Sendable {
    public var baseURL: URL
    public var session: URLSession

    public init(
        baseURL: URL = URL(string: "http://127.0.0.1:8787")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    public func registerDevelopmentAppAttestKey(keyId: String) async throws {
        let body = DevelopmentKeyRegistrationRequest(keyId: keyId)
        _ = try await send(
            path: "/v1/app-attest/register",
            method: "POST",
            body: body,
            responseType: DevelopmentKeyRegistrationResponse.self
        )
    }

    public func issueChallenge() async throws -> PulseChallenge {
        let response = try await send(
            path: "/v1/challenges",
            method: "POST",
            body: EmptyBody(),
            responseType: ChallengeResponse.self
        )
        return response.challenge
    }

    public func submitProof(envelope: PulseProofEnvelope) async throws -> PulseProofSubmissionResponse {
        try await send(
            path: "/v1/pulse-proofs",
            method: "POST",
            body: ProofSubmissionRequest(envelope: envelope),
            responseType: PulseProofSubmissionResponse.self
        )
    }

    private func send<Body: Encodable, Output: Decodable>(
        path: String,
        method: String,
        body: Body,
        responseType: Output.Type
    ) async throws -> Output {
        let url = baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try PulseJSON.encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PulseAPIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw PulseAPIError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }

        return try PulseJSON.decoder.decode(Output.self, from: data)
    }
}

public struct PulseProofSubmissionResponse: Codable, Equatable, Sendable {
    public var proof: PulsePublicProofStatus
    public var envelopeHash: String
}

public enum PulseAPIError: Error, LocalizedError {
    case invalidResponse
    case requestFailed(statusCode: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The API returned a response that could not be read."
        case let .requestFailed(statusCode, message):
            return "The API request failed with status \(statusCode): \(message)"
        }
    }
}

public enum PulseJSON {
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    public static let decoder = JSONDecoder()
}

private struct DevelopmentKeyRegistrationRequest: Codable {
    var keyId: String
}

private struct DevelopmentKeyRegistrationResponse: Codable {
    var key: DevelopmentKeyRecord
    var warning: String?
}

private struct DevelopmentKeyRecord: Codable {
    var keyId: String
    var provider: String
    var registeredAt: String
    var assertionCount: Int
}

private struct ChallengeResponse: Codable {
    var challenge: PulseChallenge
}

private struct ProofSubmissionRequest: Codable {
    var envelope: PulseProofEnvelope
}

private struct EmptyBody: Codable {}

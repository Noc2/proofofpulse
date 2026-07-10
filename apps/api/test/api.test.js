import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { createProofEnvelope } from "../../../packages/core/src/envelope.js";
import { createApi } from "../src/app.js";

describe("Proof of Pulse API", () => {
  it("issues a challenge, registers a development key, accepts one proof, and rejects replay", async () => {
    const api = createApi({
      now: () => new Date("2026-07-08T18:00:00.000Z")
    });

    const challengeResponse = await api(request("/v1/challenges", { method: "POST" }));
    assert.equal(challengeResponse.status, 201);
    const { challenge } = await challengeResponse.json();

    const keyResponse = await api(request("/v1/app-attest/register", {
      method: "POST",
      body: { keyId: "dev-key" }
    }));
    assert.equal(keyResponse.status, 201);

    const envelope = createProofEnvelope({
      challenge,
      features: passingFeatures(),
      appIntegrity: {
        provider: "development-app-attest",
        keyId: "dev-key",
        assertionId: "assertion-1"
      },
      now: new Date("2026-07-08T18:00:00.000Z")
    });

    const proofResponse = await api(request("/v1/pulse-proofs", {
      method: "POST",
      body: { envelope }
    }));
    assert.equal(proofResponse.status, 201);
    const { proof } = await proofResponse.json();
    assert.equal(proof.status, "valid");
    assert.equal(proof.scorePassed, true);

    const replayResponse = await api(request("/v1/pulse-proofs", {
      method: "POST",
      body: { envelope }
    }));
    assert.equal(replayResponse.status, 409);
  });

  it("rejects proofs without registered app integrity evidence", async () => {
    const api = createApi({
      now: () => new Date("2026-07-08T18:00:00.000Z")
    });
    const { challenge } = await (await api(request("/v1/challenges", { method: "POST" }))).json();
    const envelope = createProofEnvelope({
      challenge,
      features: passingFeatures(),
      appIntegrity: {
        provider: "development-app-attest",
        keyId: "missing-key",
        assertionId: "assertion-1"
      },
      now: new Date("2026-07-08T18:00:00.000Z")
    });

    const response = await api(request("/v1/pulse-proofs", {
      method: "POST",
      body: { envelope }
    }));

    assert.equal(response.status, 401);
  });

  it("rejects malformed JSON bodies", async () => {
    const api = createApi();

    const keyResponse = await api(request("/v1/app-attest/register", {
      method: "POST",
      rawBody: "{"
    }));
    assert.equal(keyResponse.status, 400);
    assert.equal((await keyResponse.json()).error, "malformed json");

    const proofResponse = await api(request("/v1/pulse-proofs", {
      method: "POST",
      rawBody: "{"
    }));
    assert.equal(proofResponse.status, 400);
    assert.equal((await proofResponse.json()).error, "malformed json");
  });

  it("rejects oversized JSON bodies", async () => {
    const api = createApi({ maxJsonBodyBytes: 12 });

    const response = await api(request("/v1/pulse-proofs", {
      method: "POST",
      rawBody: JSON.stringify({ envelope: { challengeId: "too-large" } })
    }));

    assert.equal(response.status, 413);
    assert.equal((await response.json()).error, "request body too large");
  });

  it("rejects development app attest registration in production", async () => {
    const api = createApi({ environment: "production" });

    const response = await api(request("/v1/app-attest/register", {
      method: "POST",
      body: { keyId: "dev-key" }
    }));

    assert.equal(response.status, 403);
    assert.equal(
      (await response.json()).error,
      "development app attest registration is disabled in production"
    );
  });

  it("rejects development app integrity evidence in production", async () => {
    const api = createApi({
      environment: "production",
      now: () => new Date("2026-07-08T18:00:00.000Z")
    });
    const { challenge } = await (await api(request("/v1/challenges", { method: "POST" }))).json();
    const envelope = createProofEnvelope({
      challenge,
      features: passingFeatures(),
      appIntegrity: {
        provider: "development-app-attest",
        keyId: "dev-key",
        assertionId: "assertion-1"
      },
      now: new Date("2026-07-08T18:00:00.000Z")
    });

    const response = await api(request("/v1/pulse-proofs", {
      method: "POST",
      body: { envelope }
    }));

    assert.equal(response.status, 403);
    assert.equal(
      (await response.json()).error,
      "development app integrity evidence is disabled in production"
    );
  });

  it("rejects mock and missing zk evidence in production", async () => {
    const api = createApi({
      environment: "production",
      now: () => new Date("2026-07-08T18:00:00.000Z")
    });

    const noneChallenge = await issueChallenge(api);
    const noZkEnvelope = createProofEnvelope({
      challenge: noneChallenge,
      features: passingFeatures(),
      appIntegrity: {
        provider: "app-attest",
        keyId: "real-key",
        assertionId: "assertion-1"
      },
      now: new Date("2026-07-08T18:00:00.000Z")
    });
    const noZkResponse = await api(request("/v1/pulse-proofs", {
      method: "POST",
      body: { envelope: noZkEnvelope }
    }));
    assert.equal(noZkResponse.status, 403);
    assert.equal((await noZkResponse.json()).error, "mock zk evidence is disabled in production");

    const mockChallenge = await issueChallenge(api);
    const mockEnvelope = createProofEnvelope({
      challenge: mockChallenge,
      features: passingFeatures(),
      appIntegrity: {
        provider: "app-attest",
        keyId: "real-key",
        assertionId: "assertion-2"
      },
      zk: {
        scheme: "mock-score-threshold-v0",
        proofId: "mock_zk_test",
        publicInputs: {}
      },
      now: new Date("2026-07-08T18:00:00.000Z")
    });
    const mockResponse = await api(request("/v1/pulse-proofs", {
      method: "POST",
      body: { envelope: mockEnvelope }
    }));
    assert.equal(mockResponse.status, 403);
    assert.equal((await mockResponse.json()).error, "mock zk evidence is disabled in production");
  });
});

async function issueChallenge(api) {
  const response = await api(request("/v1/challenges", { method: "POST" }));
  const { challenge } = await response.json();
  return challenge;
}

function request(path, { method = "GET", body, rawBody } = {}) {
  const requestBody = rawBody ?? (body ? JSON.stringify(body) : undefined);

  return new Request(`http://localhost${path}`, {
    method,
    body: requestBody,
    headers: requestBody ? { "content-type": "application/json" } : undefined
  });
}

function passingFeatures() {
  return {
    windowStartedAt: "2026-07-08T06:00:00.000Z",
    windowEndedAt: "2026-07-08T18:00:00.000Z",
    recencyBucket: "under_6h",
    sourceConfidence: "watch_likely",
    signalCount: 4,
    continuityBucket: "moderate",
    userEnteredSamplesExcluded: true,
    authorizationWindow: "full_or_unknown"
  };
}

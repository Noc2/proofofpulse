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
});

function request(path, { method = "GET", body } = {}) {
  return new Request(`http://localhost${path}`, {
    method,
    body: body ? JSON.stringify(body) : undefined,
    headers: body ? { "content-type": "application/json" } : undefined
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

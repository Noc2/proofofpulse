import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { createProofEnvelope, validateProofEnvelope } from "../src/envelope.js";

const challenge = {
  id: "ch_test",
  nonce: "nonce_test",
  expiresAt: "2026-07-08T18:02:00.000Z"
};

const features = {
  windowStartedAt: "2026-07-08T06:00:00.000Z",
  windowEndedAt: "2026-07-08T18:00:00.000Z",
  recencyBucket: "under_6h",
  sourceConfidence: "watch_likely",
  signalCount: 4,
  continuityBucket: "moderate",
  userEnteredSamplesExcluded: true,
  authorizationWindow: "full_or_unknown"
};

describe("proof envelopes", () => {
  it("creates and validates a challenge-bound envelope", () => {
    const envelope = createProofEnvelope({
      challenge,
      features,
      appIntegrity: {
        provider: "development-app-attest",
        keyId: "dev-key",
        assertionId: "dev-assertion"
      },
      now: new Date("2026-07-08T18:00:00.000Z")
    });

    const validation = validateProofEnvelope(envelope, challenge, {
      now: new Date("2026-07-08T18:01:00.000Z")
    });

    assert.equal(envelope.challengeId, "ch_test");
    assert.equal(envelope.score.passed, true);
    assert.equal(validation.ok, true);
  });

  it("rejects a mismatched challenge hash", () => {
    const envelope = createProofEnvelope({
      challenge,
      features,
      appIntegrity: { provider: "development-app-attest" },
      now: new Date("2026-07-08T18:00:00.000Z")
    });

    const validation = validateProofEnvelope(envelope, {
      ...challenge,
      nonce: "different"
    });

    assert.equal(validation.ok, false);
    assert.match(validation.errors.join("\n"), /challenge hash mismatch/u);
  });

  it("requires app integrity evidence by default", () => {
    const envelope = createProofEnvelope({
      challenge,
      features,
      now: new Date("2026-07-08T18:00:00.000Z")
    });

    const validation = validateProofEnvelope(envelope, challenge, {
      now: new Date("2026-07-08T18:01:00.000Z")
    });

    assert.equal(validation.ok, false);
    assert.match(validation.errors.join("\n"), /app integrity evidence required/u);
  });
});

import { DEFAULT_CHALLENGE_TTL_MS } from "../../../packages/core/src/constants.js";
import { randomId } from "../../../packages/core/src/crypto.js";

export function createMemoryStore({ challengeTtlMs = DEFAULT_CHALLENGE_TTL_MS } = {}) {
  const challenges = new Map();
  const appAttestKeys = new Map();
  const proofs = new Map();
  const nullifiers = new Map();

  return {
    issueChallenge({ now = new Date() } = {}) {
      const challenge = {
        id: randomId("ch"),
        nonce: randomId("nonce", 24),
        issuedAt: now.toISOString(),
        expiresAt: new Date(now.getTime() + challengeTtlMs).toISOString(),
        usedAt: null
      };
      challenges.set(challenge.id, challenge);
      return challenge;
    },

    getChallenge(id) {
      return challenges.get(id) ?? null;
    },

    markChallengeUsed(id, now = new Date()) {
      const challenge = challenges.get(id);
      if (challenge) {
        challenge.usedAt = now.toISOString();
      }
      return challenge ?? null;
    },

    registerDevelopmentAppAttestKey({ keyId, now = new Date() }) {
      const record = {
        keyId,
        provider: "development-app-attest",
        registeredAt: now.toISOString(),
        assertionCount: 0
      };
      appAttestKeys.set(keyId, record);
      return record;
    },

    verifyDevelopmentAppIntegrity(appIntegrity) {
      if (appIntegrity?.provider !== "development-app-attest") {
        return { ok: false, error: "unsupported app integrity provider" };
      }

      if (!appIntegrity?.keyId || !appAttestKeys.has(appIntegrity.keyId)) {
        return { ok: false, error: "unknown app attest key" };
      }

      if (!appIntegrity?.assertionId) {
        return { ok: false, error: "missing app attest assertion reference" };
      }

      const record = appAttestKeys.get(appIntegrity.keyId);
      record.assertionCount += 1;
      return { ok: true, record };
    },

    hasNullifier(nullifierHash) {
      return nullifiers.has(nullifierHash);
    },

    storeProof({ id, envelope, envelopeHash, publicStatus, zkVerified, now = new Date() }) {
      const record = {
        id,
        envelope,
        envelopeHash,
        publicStatus,
        zkVerified,
        createdAt: now.toISOString()
      };
      proofs.set(id, record);
      nullifiers.set(envelope.replayProtection.nullifierHash, id);
      return record;
    },

    getProof(id) {
      return proofs.get(id) ?? null;
    }
  };
}

import {
  ALGORITHM_VERSION,
  CLAIM_RECENT_LIVENESS,
  DEFAULT_PROOF_TTL_MS,
  PROOF_VERSION
} from "./constants.js";
import { hashChallenge, sha256Base64Url } from "./crypto.js";
import { scorePulseFeatures } from "./scoring.js";

export function createProofEnvelope({
  challenge,
  features,
  appIntegrity,
  zk = { scheme: "none", proofId: null, publicInputs: {} },
  scope = "local-dev/default",
  now = new Date(),
  proofTtlMs = DEFAULT_PROOF_TTL_MS
}) {
  assertChallengeShape(challenge);

  const issuedAt = new Date(now);
  const expiresAt = new Date(issuedAt.getTime() + proofTtlMs);
  const scored = scorePulseFeatures(features);
  const challengeHash = hashChallenge(challenge);
  const nullifierHash = sha256Base64Url(`${scope}:${challenge.id}:${challengeHash}`);

  return {
    version: PROOF_VERSION,
    challengeId: challenge.id,
    challengeHash,
    issuedAt: issuedAt.toISOString(),
    expiresAt: expiresAt.toISOString(),
    claim: CLAIM_RECENT_LIVENESS,
    algorithmVersion: ALGORITHM_VERSION,
    score: {
      tier: scored.tier,
      thresholdTier: scored.thresholdTier,
      passed: scored.passed
    },
    window: {
      startedAt: features?.windowStartedAt ?? null,
      endedAt: features?.windowEndedAt ?? null,
      granularity: "coarse"
    },
    features: scored.features,
    appIntegrity: normalizeAppIntegrity(appIntegrity),
    zk: {
      scheme: zk.scheme ?? "none",
      proofId: zk.proofId ?? null,
      publicInputs: {
        algorithmVersion: ALGORITHM_VERSION,
        challengeHash,
        scoreTier: scored.tier,
        ...(zk.publicInputs ?? {})
      }
    },
    replayProtection: {
      epoch: epochForDate(issuedAt),
      nullifierHash
    }
  };
}

export function validateProofEnvelope(envelope, challenge, {
  now = new Date(),
  requireAppIntegrity = true,
  acceptedZkSchemes = ["none", "mock-score-threshold-v0"]
} = {}) {
  const errors = [];
  const currentTime = new Date(now).getTime();

  if (envelope?.version !== PROOF_VERSION) {
    errors.push("invalid proof version");
  }

  if (envelope?.algorithmVersion !== ALGORITHM_VERSION) {
    errors.push("invalid scoring algorithm version");
  }

  if (envelope?.claim !== CLAIM_RECENT_LIVENESS) {
    errors.push("invalid claim");
  }

  if (!challenge || envelope?.challengeId !== challenge.id) {
    errors.push("challenge id mismatch");
  } else if (envelope?.challengeHash !== hashChallenge(challenge)) {
    errors.push("challenge hash mismatch");
  }

  if (!envelope?.score?.passed) {
    errors.push("score threshold not met");
  }

  if (Date.parse(envelope?.expiresAt ?? "") <= currentTime) {
    errors.push("proof expired");
  }

  if (requireAppIntegrity && envelope?.appIntegrity?.provider === "none") {
    errors.push("app integrity evidence required");
  }

  if (!acceptedZkSchemes.includes(envelope?.zk?.scheme)) {
    errors.push("unsupported zk scheme");
  }

  if (envelope?.zk?.publicInputs?.challengeHash !== envelope?.challengeHash) {
    errors.push("zk public challenge hash mismatch");
  }

  return {
    ok: errors.length === 0,
    errors
  };
}

export function toPublicProofStatus(id, envelope, { zkVerified = false, now = new Date() } = {}) {
  const nowMs = new Date(now).getTime();

  return {
    id,
    status: Date.parse(envelope.expiresAt) > nowMs ? "valid" : "expired",
    claim: envelope.claim,
    issuedAt: envelope.issuedAt,
    expiresAt: envelope.expiresAt,
    scorePassed: envelope.score.passed,
    scoreTier: envelope.score.tier,
    sourceConfidence: envelope.features.sourceConfidence,
    zkVerified,
    nullifierScope: envelope.replayProtection.epoch
  };
}

function normalizeAppIntegrity(appIntegrity) {
  return {
    provider: appIntegrity?.provider ?? "none",
    keyId: appIntegrity?.keyId ?? null,
    assertionId: appIntegrity?.assertionId ?? null
  };
}

function epochForDate(date) {
  return date.toISOString().slice(0, 13) + ":00Z";
}

function assertChallengeShape(challenge) {
  if (!challenge?.id || !challenge?.nonce || !challenge?.expiresAt) {
    throw new TypeError("challenge must include id, nonce, and expiresAt");
  }
}

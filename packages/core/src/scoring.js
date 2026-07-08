import { ALGORITHM_VERSION, SCORE_THRESHOLDS, SCORE_TIERS } from "./constants.js";

const RECENCY_POINTS = Object.freeze({
  under_6h: 35,
  under_24h: 28,
  under_72h: 14,
  stale: 0,
  none: -20
});

const SOURCE_POINTS = Object.freeze({
  watch_likely: 35,
  apple_device_likely: 25,
  healthkit_mixed: 12,
  third_party_only: -10,
  unknown: 0
});

const CONTINUITY_POINTS = Object.freeze({
  strong: 20,
  moderate: 12,
  weak: 5,
  none: 0
});

const AUTHORIZATION_POINTS = Object.freeze({
  full_or_unknown: 0,
  limited_recent: -5,
  denied_or_empty: -15
});

export function scorePulseFeatures(features) {
  const normalized = normalizeFeatures(features);
  const breakdown = {
    recency: RECENCY_POINTS[normalized.recencyBucket],
    sourceConfidence: SOURCE_POINTS[normalized.sourceConfidence],
    continuity: CONTINUITY_POINTS[normalized.continuityBucket],
    multimodal: Math.min(normalized.signalCount, 4) * 5,
    userEntered: normalized.userEnteredSamplesExcluded ? 0 : -25,
    authorizationWindow: AUTHORIZATION_POINTS[normalized.authorizationWindow],
    sparseOrImplausible: normalized.signalCount === 0 ? -20 : 0
  };

  const score = clamp(
    Object.values(breakdown).reduce((sum, points) => sum + points, 0),
    0,
    100
  );

  return {
    algorithmVersion: ALGORITHM_VERSION,
    score,
    tier: tierForScore(score),
    thresholdTier: score >= SCORE_THRESHOLDS.pass ? "pass" : "fail",
    passed: score >= SCORE_THRESHOLDS.pass,
    breakdown,
    features: normalized
  };
}

export function normalizeFeatures(features) {
  return {
    recencyBucket: enumOrDefault(features?.recencyBucket, RECENCY_POINTS, "none"),
    sourceConfidence: enumOrDefault(features?.sourceConfidence, SOURCE_POINTS, "unknown"),
    signalCount: clamp(Number.parseInt(features?.signalCount ?? 0, 10) || 0, 0, 10),
    continuityBucket: enumOrDefault(features?.continuityBucket, CONTINUITY_POINTS, "none"),
    userEnteredSamplesExcluded: features?.userEnteredSamplesExcluded === true,
    authorizationWindow: enumOrDefault(
      features?.authorizationWindow,
      AUTHORIZATION_POINTS,
      "full_or_unknown"
    ),
    digitalSignatureObserved: features?.digitalSignatureObserved === true
  };
}

export function tierForScore(score) {
  if (score >= SCORE_THRESHOLDS.passHigh) {
    return SCORE_TIERS.passHigh;
  }

  if (score >= SCORE_THRESHOLDS.pass) {
    return SCORE_TIERS.pass;
  }

  if (score >= 40) {
    return SCORE_TIERS.review;
  }

  return SCORE_TIERS.fail;
}

function enumOrDefault(value, dictionary, fallback) {
  return Object.hasOwn(dictionary, value) ? value : fallback;
}

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

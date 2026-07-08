export const PROOF_VERSION = "pop-proof-v0";
export const ALGORITHM_VERSION = "pulse-score-v0";
export const DEFAULT_PROOF_TTL_MS = 5 * 60 * 1000;
export const DEFAULT_CHALLENGE_TTL_MS = 2 * 60 * 1000;

export const SCORE_THRESHOLDS = Object.freeze({
  pass: 60,
  passHigh: 80
});

export const SCORE_TIERS = Object.freeze({
  passHigh: "pass_high",
  pass: "pass",
  review: "review",
  fail: "fail"
});

export const CLAIM_RECENT_LIVENESS = "recent-wearable-backed-liveness-signal";

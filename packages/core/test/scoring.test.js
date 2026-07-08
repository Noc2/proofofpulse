import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { scorePulseFeatures } from "../src/scoring.js";

describe("scorePulseFeatures", () => {
  it("passes high-confidence recent wearable-like features", () => {
    const result = scorePulseFeatures({
      recencyBucket: "under_6h",
      sourceConfidence: "watch_likely",
      signalCount: 4,
      continuityBucket: "moderate",
      userEnteredSamplesExcluded: true,
      authorizationWindow: "full_or_unknown"
    });

    assert.equal(result.passed, true);
    assert.equal(result.tier, "pass_high");
    assert.equal(result.score, 100);
  });

  it("fails stale sparse data", () => {
    const result = scorePulseFeatures({
      recencyBucket: "stale",
      sourceConfidence: "unknown",
      signalCount: 0,
      continuityBucket: "none",
      userEnteredSamplesExcluded: true,
      authorizationWindow: "denied_or_empty"
    });

    assert.equal(result.passed, false);
    assert.equal(result.tier, "fail");
  });

  it("penalizes samples when user-entered filtering was not applied", () => {
    const withFiltering = scorePulseFeatures({
      recencyBucket: "under_24h",
      sourceConfidence: "apple_device_likely",
      signalCount: 3,
      continuityBucket: "moderate",
      userEnteredSamplesExcluded: true
    });
    const withoutFiltering = scorePulseFeatures({
      recencyBucket: "under_24h",
      sourceConfidence: "apple_device_likely",
      signalCount: 3,
      continuityBucket: "moderate",
      userEnteredSamplesExcluded: false
    });

    assert.equal(withFiltering.passed, true);
    assert.equal(withoutFiltering.passed, false);
  });
});

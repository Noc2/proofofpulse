import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { createApi } from "../../api/src/app.js";
import { runPulseSimulation } from "../src/flow.js";

describe("pulse simulator", () => {
  it("runs the complete local proof flow", async () => {
    const result = await runPulseSimulation({
      api: createApi({
        now: () => new Date("2026-07-08T18:00:00.000Z")
      }),
      now: new Date("2026-07-08T18:00:00.000Z")
    });

    assert.equal(result.envelope.version, "pop-proof-v0");
    assert.equal(result.submission.proof.scorePassed, true);
    assert.equal(result.publicStatus.id, result.submission.proof.id);
    assert.equal(result.publicStatus.zkVerified, true);
  });
});

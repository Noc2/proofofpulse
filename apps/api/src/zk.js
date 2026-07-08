export function verifyZkEvidence(envelope) {
  const scheme = envelope?.zk?.scheme ?? "none";

  if (scheme === "none") {
    return { ok: true, verified: false };
  }

  if (scheme !== "mock-score-threshold-v0") {
    return { ok: false, verified: false, error: "unsupported zk scheme" };
  }

  const publicInputs = envelope.zk.publicInputs ?? {};
  const proofId = envelope.zk.proofId ?? "";

  if (!proofId.startsWith("mock_zk_")) {
    return { ok: false, verified: false, error: "mock zk proof id missing" };
  }

  if (publicInputs.challengeHash !== envelope.challengeHash) {
    return { ok: false, verified: false, error: "mock zk challenge hash mismatch" };
  }

  if (publicInputs.scoreTier !== envelope.score.tier) {
    return { ok: false, verified: false, error: "mock zk score tier mismatch" };
  }

  return { ok: true, verified: true };
}

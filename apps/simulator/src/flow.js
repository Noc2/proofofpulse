import { readFile } from "node:fs/promises";

import { createApi } from "../../api/src/app.js";
import { createProofEnvelope } from "../../../packages/core/src/envelope.js";
import { randomId } from "../../../packages/core/src/crypto.js";

const DEFAULT_FEATURE_FILE = new URL(
  "../../../packages/core/fixtures/synthetic-pulse-features.json",
  import.meta.url
);

export async function runPulseSimulation({
  api = createApi(),
  apiBaseUrl = null,
  featureFile = DEFAULT_FEATURE_FILE,
  keyId = "dev-simulator-key",
  assertionId = randomId("dev_assertion"),
  scope = "local-dev/simulator",
  zkScheme = "mock-score-threshold-v0",
  now = new Date()
} = {}) {
  const target = apiBaseUrl ?? api;
  const features = await loadFeatures(featureFile);

  const registration = await requestJson(target, "/v1/app-attest/register", {
    method: "POST",
    body: { keyId }
  });
  assertOk(registration, "register development app attest key");

  const challengeResponse = await requestJson(target, "/v1/challenges", {
    method: "POST"
  });
  assertOk(challengeResponse, "issue challenge");

  const challenge = challengeResponse.body.challenge;
  const envelope = createProofEnvelope({
    challenge,
    features,
    appIntegrity: {
      provider: "development-app-attest",
      keyId,
      assertionId
    },
    zk: zkForScheme(zkScheme),
    scope,
    now
  });

  const proofResponse = await requestJson(target, "/v1/pulse-proofs", {
    method: "POST",
    body: { envelope }
  });
  assertOk(proofResponse, "submit pulse proof");

  const proofId = proofResponse.body.proof.id;
  const publicStatus = await requestJson(target, `/v1/pulse-proofs/${proofId}`);
  assertOk(publicStatus, "fetch public proof status");

  return {
    challenge,
    envelope,
    submission: proofResponse.body,
    publicStatus: publicStatus.body.proof
  };
}

async function requestJson(target, path, { method = "GET", body } = {}) {
  const request = {
    method,
    headers: body ? { "content-type": "application/json" } : undefined,
    body: body ? JSON.stringify(body) : undefined
  };

  const response = typeof target === "string"
    ? await fetch(new URL(path, target), request)
    : await target(new Request(`http://localhost${path}`, request));

  return {
    status: response.status,
    ok: response.ok,
    body: await response.json()
  };
}

async function loadFeatures(featureFile) {
  const url = featureFile instanceof URL ? featureFile : new URL(featureFile, `file://${process.cwd()}/`);
  return JSON.parse(await readFile(url, "utf8"));
}

function zkForScheme(scheme) {
  if (scheme === "none") {
    return { scheme: "none", proofId: null, publicInputs: {} };
  }

  if (scheme === "mock-score-threshold-v0") {
    return {
      scheme,
      proofId: randomId("mock_zk"),
      publicInputs: {
        proofSystem: "development-mock"
      }
    };
  }

  throw new Error(`Unsupported simulator ZK scheme: ${scheme}`);
}

function assertOk(response, action) {
  if (!response.ok) {
    throw new Error(`Failed to ${action}: ${response.status} ${JSON.stringify(response.body)}`);
  }
}

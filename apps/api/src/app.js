import { envelopeHash, randomId } from "../../../packages/core/src/crypto.js";
import {
  toPublicProofStatus,
  validateProofEnvelope
} from "../../../packages/core/src/envelope.js";
import { createMemoryStore } from "./store.js";
import { verifyZkEvidence } from "./zk.js";

const DEFAULT_MAX_JSON_BODY_BYTES = 64 * 1024;

export function createApi({
  store = createMemoryStore(),
  now = () => new Date(),
  environment = process.env.NODE_ENV ?? "development",
  maxJsonBodyBytes = DEFAULT_MAX_JSON_BODY_BYTES
} = {}) {
  const productionMode = environment === "production";

  return async function handleRequest(request) {
    const url = new URL(request.url);

    if (request.method === "GET" && url.pathname === "/healthz") {
      return json({ ok: true, service: "proof-of-pulse-api" });
    }

    if (request.method === "POST" && url.pathname === "/v1/challenges") {
      const challenge = store.issueChallenge({ now: now() });
      return json({ challenge }, { status: 201 });
    }

    if (request.method === "POST" && url.pathname === "/v1/app-attest/register") {
      if (productionMode) {
        return json({
          error: "development app attest registration is disabled in production"
        }, { status: 403 });
      }

      const body = await readJson(request, { maxJsonBodyBytes });
      if (body instanceof Response) {
        return body;
      }

      if (!body.keyId) {
        return json({ error: "keyId is required" }, { status: 400 });
      }

      const key = store.registerDevelopmentAppAttestKey({ keyId: body.keyId, now: now() });
      return json({
        key,
        warning: "development-app-attest is a local POC stub, not Apple App Attest validation"
      }, { status: 201 });
    }

    if (request.method === "POST" && url.pathname === "/v1/pulse-proofs") {
      const body = await readJson(request, { maxJsonBodyBytes });
      if (body instanceof Response) {
        return body;
      }

      return submitProof({ body, store, now: now(), productionMode });
    }

    const proofMatch = url.pathname.match(/^\/v1\/pulse-proofs\/([^/]+)$/u);
    if (request.method === "GET" && proofMatch) {
      const proof = store.getProof(proofMatch[1]);
      if (!proof) {
        return json({ error: "proof not found" }, { status: 404 });
      }

      return json({ proof: proof.publicStatus });
    }

    return json({ error: "not found" }, { status: 404 });
  };
}

async function submitProof({ body, store, now, productionMode }) {
  const envelope = body.envelope;
  if (!envelope) {
    return json({ error: "envelope is required" }, { status: 400 });
  }

  if (productionMode) {
    const policy = validateProductionProofPolicy(envelope);
    if (!policy.ok) {
      return json({ error: policy.error }, { status: 403 });
    }
  }

  const challenge = store.getChallenge(envelope.challengeId);
  if (!challenge) {
    return json({ error: "unknown challenge" }, { status: 404 });
  }

  if (challenge.usedAt) {
    return json({ error: "challenge already used" }, { status: 409 });
  }

  if (Date.parse(challenge.expiresAt) <= now.getTime()) {
    return json({ error: "challenge expired" }, { status: 410 });
  }

  const appIntegrity = store.verifyDevelopmentAppIntegrity(envelope.appIntegrity);
  if (!appIntegrity.ok) {
    return json({ error: appIntegrity.error }, { status: 401 });
  }

  const validation = validateProofEnvelope(envelope, challenge, { now });
  if (!validation.ok) {
    return json({ error: "invalid proof envelope", details: validation.errors }, { status: 422 });
  }

  if (store.hasNullifier(envelope.replayProtection.nullifierHash)) {
    return json({ error: "nullifier already used" }, { status: 409 });
  }

  const zk = verifyZkEvidence(envelope);
  if (!zk.ok) {
    return json({ error: zk.error }, { status: 422 });
  }

  store.markChallengeUsed(challenge.id, now);

  const id = randomId("pp");
  const publicStatus = toPublicProofStatus(id, envelope, { zkVerified: zk.verified, now });
  const proof = store.storeProof({
    id,
    envelope,
    envelopeHash: envelopeHash(envelope),
    publicStatus,
    zkVerified: zk.verified,
    now
  });

  return json({
    proof: proof.publicStatus,
    envelopeHash: proof.envelopeHash
  }, { status: 201 });
}

async function readJson(request, { maxJsonBodyBytes }) {
  const contentLength = Number(request.headers.get("content-length") ?? 0);
  if (Number.isFinite(contentLength) && contentLength > maxJsonBodyBytes) {
    return json({ error: "request body too large" }, { status: 413 });
  }

  let totalBytes = 0;
  const decoder = new TextDecoder();
  let text = "";

  if (request.body) {
    const reader = request.body.getReader();
    while (true) {
      const { done, value } = await reader.read();
      if (done) {
        break;
      }

      totalBytes += value.byteLength;
      if (totalBytes > maxJsonBodyBytes) {
        return json({ error: "request body too large" }, { status: 413 });
      }

      text += decoder.decode(value, { stream: true });
    }

    text += decoder.decode();
  } else {
    text = await request.text();
  }

  if (!text) {
    return {};
  }

  try {
    return JSON.parse(text);
  } catch {
    return json({ error: "malformed json" }, { status: 400 });
  }
}

function validateProductionProofPolicy(envelope) {
  if (envelope?.appIntegrity?.provider === "development-app-attest") {
    return {
      ok: false,
      error: "development app integrity evidence is disabled in production"
    };
  }

  if (envelope?.zk?.scheme === "none" || envelope?.zk?.scheme === "mock-score-threshold-v0") {
    return {
      ok: false,
      error: "mock zk evidence is disabled in production"
    };
  }

  return { ok: true };
}

function json(value, { status = 200, headers = {} } = {}) {
  return new Response(JSON.stringify(value, null, 2), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      ...headers
    }
  });
}

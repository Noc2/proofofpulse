import { createHash, randomBytes } from "node:crypto";

export function base64url(input) {
  const buffer = Buffer.isBuffer(input) ? input : Buffer.from(input);
  return buffer
    .toString("base64")
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/u, "");
}

export function sha256Base64Url(input) {
  return base64url(createHash("sha256").update(input).digest());
}

export function randomId(prefix, byteLength = 16) {
  return `${prefix}_${base64url(randomBytes(byteLength))}`;
}

export function stableJson(value) {
  return JSON.stringify(sortForJson(value));
}

function sortForJson(value) {
  if (Array.isArray(value)) {
    return value.map(sortForJson);
  }

  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value)
        .sort(([left], [right]) => left.localeCompare(right))
        .map(([key, nested]) => [key, sortForJson(nested)])
    );
  }

  return value;
}

export function hashChallenge(challenge) {
  return sha256Base64Url(stableJson({
    id: challenge.id,
    nonce: challenge.nonce,
    expiresAt: challenge.expiresAt
  }));
}

export function envelopeHash(envelope) {
  return sha256Base64Url(stableJson(envelope));
}

#!/usr/bin/env node

import { runPulseSimulation } from "./flow.js";

const args = parseArgs(process.argv.slice(2));

try {
  const result = await runPulseSimulation({
    apiBaseUrl: args.api,
    featureFile: args.features,
    keyId: args.keyId ?? "dev-simulator-key",
    scope: args.scope ?? "local-dev/simulator",
    zkScheme: args.zk ?? "mock-score-threshold-v0"
  });

  console.log(JSON.stringify({
    proof: result.submission.proof,
    envelopeHash: result.submission.envelopeHash,
    publicStatus: result.publicStatus,
    caveat: "development-app-attest and mock-score-threshold-v0 are POC stubs"
  }, null, 2));
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}

function parseArgs(argv) {
  const parsed = {};

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (!arg.startsWith("--")) {
      throw new Error(`Unexpected argument: ${arg}`);
    }

    const key = arg.slice(2);
    const value = argv[index + 1];
    if (!value || value.startsWith("--")) {
      throw new Error(`Missing value for ${arg}`);
    }

    parsed[key] = value;
    index += 1;
  }

  return parsed;
}

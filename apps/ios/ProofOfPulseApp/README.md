# ProofOfPulseApp

Native SwiftUI iPhone host app for the Proof of Pulse POC.

## Local Simulator Flow

1. Start the local API from the repo root:

   ```sh
   npm run api
   ```

2. Open `ProofOfPulseApp.xcodeproj` in Xcode, or build from the command line.
3. Run the `ProofOfPulseApp` scheme on an iPhone simulator.
4. Keep `Use demo signal` enabled in the Keys tab.
5. Tap `Create Pulse Proof`.

The simulator flow uses synthetic coarse feature buckets and submits a development proof envelope to `http://127.0.0.1:8787`.

Debug builds keep the editable local API field, demo signal toggle, and local-network permission. Release builds read `ProofOfPulseAPIBaseURL` from the app Info plist, disable demo signal, and hide the editable local API control.

## Real Device Notes

- Disable `Use demo signal` in the Keys tab.
- Change the API URL to your Mac's LAN address, for example `http://192.168.1.20:8787`.
- Start the API bound to a reachable host, for example:

  ```sh
  HOST=0.0.0.0 npm run api
  ```

- Grant read-only HealthKit access when prompted.

The source-confidence label is heuristic and does not prove Apple Watch sensor attestation. `development-app-attest` and `mock-score-threshold-v0` remain POC stubs.

## Release Configuration

Before TestFlight, replace the Release `PROOF_OF_PULSE_API_BASE_URL` build setting in `ProofOfPulseApp.xcodeproj` with the HTTPS production API.

Release builds also set `com.apple.developer.devicecheck.appattest-environment` to `production`. The value is only useful after the App ID has the App Attest capability enabled in the Apple Developer account and the server implements real App Attest validation.

// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ProofOfPulseKit",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "ProofOfPulseKit",
            targets: ["ProofOfPulseKit"]
        )
    ],
    targets: [
        .target(name: "ProofOfPulseKit")
    ]
)

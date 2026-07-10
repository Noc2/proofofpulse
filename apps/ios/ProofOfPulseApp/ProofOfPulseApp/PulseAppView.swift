import SwiftUI

struct PulseAppView: View {
    @EnvironmentObject private var viewModel: PulseViewModel

    var body: some View {
        ZStack {
            PulseTheme.background
                .ignoresSafeArea()

            radialGlow

            VStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                PulseTabBar(
                    selected: $viewModel.activeTab,
                    proofAvailable: viewModel.lastProof != nil
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.activeTab {
        case .pulse:
            PulseHomeView()
        case .proofs:
            PulseProofsView()
        case .keys:
            PulseSettingsView()
        }
    }

    private var radialGlow: some View {
        ZStack {
            Circle()
                .fill(PulseTheme.green.opacity(0.16))
                .frame(width: 300, height: 300)
                .blur(radius: 120)
                .offset(y: -160)

            Circle()
                .fill(PulseTheme.blue.opacity(0.1))
                .frame(width: 240, height: 240)
                .blur(radius: 110)
                .offset(x: 120, y: 120)
        }
        .allowsHitTesting(false)
    }
}

private struct PulseHomeView: View {
    @EnvironmentObject private var viewModel: PulseViewModel

    var body: some View {
        VStack(spacing: 22) {
            PulseHeader()

            Spacer(minLength: 18)

            VStack(spacing: 28) {
                PulsingDotsView()
                    .frame(height: 152)

                VStack(spacing: 10) {
                    Text(viewModel.lastProof == nil ? "Your pulse proof is ready" : "Pulse proof accepted")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .foregroundStyle(PulseTheme.ink)
                        .frame(maxWidth: 310)

                    Text("Recent local signal buckets can become a short-lived private liveness summary.")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PulseTheme.muted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: 288)
                }
            }

            Spacer(minLength: 18)

            ProofPanel()
        }
        .padding(.bottom, 14)
    }
}

private struct PulseHeader: View {
    @EnvironmentObject private var viewModel: PulseViewModel

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("PROOF OF")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(4)
                    .foregroundStyle(PulseTheme.muted)

                Text("Pulse")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(PulseTheme.ink)
            }

            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.runState == .failed ? PulseTheme.warning : PulseTheme.green)
                    .frame(width: 8, height: 8)
                    .shadow(color: PulseTheme.green.opacity(0.75), radius: 10)

                Text(viewModel.runState == .failed ? "Check" : "Live")
                    .font(.system(size: 13, weight: .heavy))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(PulseTheme.green.opacity(0.11), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(PulseTheme.green.opacity(0.38), lineWidth: 1)
            )
        }
    }
}

private struct PulsingDotsView: View {
    @State private var animate = false

    private let hues: [Double] = [160, 170, 180, 190, 200, 210]

    var body: some View {
        ZStack {
            VStack(spacing: 30) {
                PulseLine()
                PulseLine()
                    .opacity(0.35)
            }

            HStack(spacing: 30) {
                ForEach(Array(hues.enumerated()), id: \.offset) { index, hue in
                    Circle()
                        .fill(Color(hue: hue / 360, saturation: 1, brightness: 1))
                        .frame(width: 17, height: 17)
                        .shadow(
                            color: Color(hue: hue / 360, saturation: 1, brightness: 1).opacity(animate ? 0 : 0.9),
                            radius: animate ? 36 : 8,
                            x: 0,
                            y: 0
                        )
                        .scaleEffect(animate ? 0.96 : 1.04)
                        .offset(y: animate ? 0 : -3)
                        .animation(
                            .easeOut(duration: 2)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.25),
                            value: animate
                        )
                }
            }
        }
        .onAppear {
            animate = true
        }
    }
}

private struct PulseLine: View {
    var body: some View {
        LinearGradient(
            colors: [
                .clear,
                PulseTheme.green.opacity(0.3),
                PulseTheme.blue.opacity(0.26),
                .clear
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
        .padding(.horizontal, 18)
    }
}

private struct ProofPanel: View {
    @EnvironmentObject private var viewModel: PulseViewModel

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("SIGNAL CONFIDENCE")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(PulseTheme.muted)

                    Text(viewModel.sourceLabel)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(PulseTheme.ink)
                }

                Spacer()

                ScoreRing(score: viewModel.score.score)
            }

            HStack(spacing: 10) {
                MetricCard(title: "Fresh", value: viewModel.freshnessLabel)
                MetricCard(title: "\(viewModel.features.signalCount) modes", value: "detected")
                MetricCard(title: "ZK", value: viewModel.zkStatusLabel)
            }

            Button {
                Task {
                    await viewModel.createPulseProof()
                }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isRunning {
                        ProgressView()
                            .tint(.black)
                    }
                    Text(viewModel.proofButtonTitle)
                }
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.02, green: 0.13, blue: 0.1))
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    LinearGradient(
                        colors: [PulseTheme.green, PulseTheme.cyan, PulseTheme.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .shadow(color: PulseTheme.green.opacity(0.24), radius: 24, y: 12)
            }
            .disabled(viewModel.isRunning)

            VStack(spacing: 4) {
                Text(viewModel.activityMessage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PulseTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PulseTheme.warning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(PulseTheme.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

private struct ScoreRing: View {
    var score: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 10)

            Circle()
                .trim(from: 0, to: CGFloat(min(max(score, 0), 100)) / 100)
                .stroke(
                    PulseTheme.green,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: PulseTheme.green.opacity(0.42), radius: 14)

            Text("\(score)")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(PulseTheme.ink)
        }
        .frame(width: 66, height: 66)
    }
}

private struct MetricCard: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(PulseTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PulseTheme.muted2)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct PulseProofsView: View {
    @EnvironmentObject private var viewModel: PulseViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PulseHeader()

            Text("Proofs")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(PulseTheme.ink)

            if let proof = viewModel.lastProof {
                VStack(alignment: .leading, spacing: 14) {
                    ProofRow(label: "Status", value: proof.status.capitalized)
                    ProofRow(label: "Proof ID", value: proof.id)
                    ProofRow(label: "Score tier", value: proof.scoreTier)
                    ProofRow(label: "Source", value: proof.sourceConfidence)
                    ProofRow(label: "Expires", value: proof.expiresAt)
                    if let envelopeHash = viewModel.envelopeHash {
                        ProofRow(label: "Envelope hash", value: envelopeHash)
                    }
                }
                .padding(16)
                .background(PulseTheme.panel, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            } else {
                Text("Create a Pulse Proof to see the public verifier status here.")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PulseTheme.muted)
                    .lineSpacing(4)
            }

            Spacer()
        }
        .padding(.bottom, 24)
    }
}

private struct ProofRow: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(PulseTheme.muted2)

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(PulseTheme.ink)
                .textSelection(.enabled)
                .lineLimit(3)
                .minimumScaleFactor(0.72)
        }
    }
}

private struct PulseSettingsView: View {
    @EnvironmentObject private var viewModel: PulseViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PulseHeader()

            Text("Keys")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(PulseTheme.ink)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.allowsDevelopmentSettings ? "LOCAL API" : "API")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(PulseTheme.muted)

                    if viewModel.allowsDevelopmentSettings {
                        TextField("http://127.0.0.1:8787", text: $viewModel.apiBaseURLString)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .padding(12)
                            .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    } else {
                        Text(viewModel.apiBaseURLString)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(PulseTheme.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                }

                if viewModel.allowsDevelopmentSettings {
                    Toggle("Use demo signal", isOn: $viewModel.useDemoSignal)
                        .font(.system(size: 15, weight: .bold))
                        .tint(PulseTheme.green)
                }

                Text(viewModel.allowsDevelopmentSettings ? "For simulator testing, keep demo signal enabled. For real device testing, disable it and grant HealthKit read access." : "\(viewModel.runtimeModeLabel) build. Demo signal and local API editing are disabled.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PulseTheme.muted)
                    .lineSpacing(4)
            }
            .padding(16)
            .background(PulseTheme.panel, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )

            Spacer()
        }
        .padding(.bottom, 24)
    }
}

private struct PulseTabBar: View {
    @Binding var selected: PulseViewModel.Tab
    var proofAvailable: Bool

    var body: some View {
        HStack {
            ForEach(PulseViewModel.Tab.allCases, id: \.self) { tab in
                Button {
                    selected = tab
                } label: {
                    VStack(spacing: 6) {
                        TabGlyph(tab: tab, active: selected == tab, proofAvailable: proofAvailable)
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: .black))
                    }
                    .foregroundStyle(selected == tab ? PulseTheme.ink : PulseTheme.muted2)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
        }
    }
}

private struct TabGlyph: View {
    var tab: PulseViewModel.Tab
    var active: Bool
    var proofAvailable: Bool

    var body: some View {
        ZStack {
            switch tab {
            case .pulse:
                Circle()
                    .stroke(active ? PulseTheme.green : PulseTheme.muted2, lineWidth: 2)
            case .proofs:
                RoundedRectangle(cornerRadius: 6)
                    .stroke(active ? PulseTheme.green : PulseTheme.muted2, lineWidth: 2)
            case .keys:
                Circle()
                    .stroke(active ? PulseTheme.green : PulseTheme.muted2, lineWidth: 2)
                Circle()
                    .fill(active ? PulseTheme.green : PulseTheme.muted2)
                    .frame(width: 6, height: 6)
            }

            if tab == .proofs && proofAvailable {
                Circle()
                    .fill(PulseTheme.green)
                    .frame(width: 6, height: 6)
                    .offset(x: 10, y: -10)
            }
        }
        .frame(width: 22, height: 22)
        .shadow(color: active ? PulseTheme.green.opacity(0.35) : .clear, radius: 12)
    }
}

enum PulseTheme {
    static let background = Color(red: 0.2, green: 0.2, blue: 0.2)
    static let ink = Color(red: 0.96, green: 1, blue: 0.98)
    static let muted = Color(red: 0.61, green: 0.7, blue: 0.67)
    static let muted2 = Color(red: 0.43, green: 0.51, blue: 0.49)
    static let panel = Color.white.opacity(0.075)
    static let green = Color(hue: 160.0 / 360.0, saturation: 1, brightness: 1)
    static let cyan = Color(hue: 180.0 / 360.0, saturation: 1, brightness: 1)
    static let blue = Color(hue: 205.0 / 360.0, saturation: 1, brightness: 1)
    static let warning = Color(red: 1, green: 0.38, blue: 0.32)
}

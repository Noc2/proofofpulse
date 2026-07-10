import SwiftUI

@main
struct ProofOfPulseApp: App {
    @StateObject private var viewModel = PulseViewModel()

    var body: some Scene {
        WindowGroup {
            PulseAppView()
                .environmentObject(viewModel)
        }
    }
}

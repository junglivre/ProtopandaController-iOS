import SwiftUI

@main
struct ProtopandaControllerApp: App {
    @StateObject private var viewModel = ControllerViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: viewModel,
                bleController: viewModel.bleController,
                motionController: viewModel.motionController
            )
            .preferredColorScheme(.dark)
            .onChange(of: scenePhase) { newPhase in
                switch newPhase {
                case .active:
                    viewModel.handleSceneActive()
                case .inactive, .background:
                    viewModel.handleSceneInactive()
                @unknown default:
                    break
                }
            }
        }
    }
}

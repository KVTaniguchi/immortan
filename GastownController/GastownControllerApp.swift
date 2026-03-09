import SwiftUI

@main
struct GastownControllerApp: App {
    @AppStorage("setupComplete") private var setupComplete = false
    @State private var showSetup = false
    
    var body: some Scene {
        WindowGroup {
            if showSetup || !setupComplete {
                SetupView {
                    showSetup = false
                    setupComplete = true
                }
            } else {
                ContentView()
                    .onAppear {
                        // Re-run a quick health check in background on each launch
                        // to catch regressions in CLI/runtime prerequisites.
                        Task {
                            let svc = SetupCheckService()
                            await svc.runAllChecks()
                            if !svc.allPassed {
                                showSetup = true
                            }
                        }
                    }
            }
        }
    }
}

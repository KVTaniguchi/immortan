import Foundation
import Combine

// MARK: - Check Status

enum CheckStatus: Equatable {
    case pending
    case checking
    case ok
    case failed(String)
    
    var isOk: Bool { self == .ok }
    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
    var failureMessage: String? {
        if case .failed(let msg) = self { return msg }
        return nil
    }
}

// MARK: - Individual Check

struct SetupCheck: Identifiable {
    let id: String
    let title: String
    let description: String
    var status: CheckStatus = .pending
}

// MARK: - SetupCheckService

@MainActor
class SetupCheckService: ObservableObject {
    @Published var checks: [SetupCheck] = []
    
    @Published var isRunningChecks = false
    
    private let runner: CommandRunner
    
    var allPassed: Bool { checks.allSatisfy { $0.status.isOk } }
    
    init(
        runner: CommandRunner = NativeCommandRunner()
    ) {
        self.runner = runner
        self.checks = Self.buildChecks()
    }
    
    // MARK: - Run All Checks
    
    func runAllChecks() async {
        isRunningChecks = true
        
        // Mark all as checking
        for i in checks.indices { checks[i].status = .checking }
        
        await checkGooseInstalled()
        await checkGtInstalled()
        
        isRunningChecks = false
    }
    
    // MARK: - Individual Checks
    
    private func checkGooseInstalled() async {
        let found = FileManager.default.fileExists(atPath: "/opt/homebrew/bin/goose")
        updateCheck(id: "goose_installed", status: found ? .ok : .failed("Goose not found at /opt/homebrew/bin/goose. Install via Homebrew."))
    }
    
    private func checkGtInstalled() async {
        let found = FileManager.default.fileExists(atPath: "/opt/homebrew/bin/gt")
        updateCheck(id: "gt_installed", status: found ? .ok : .failed("'gt' not found at /opt/homebrew/bin/gt."))
    }
    
    // MARK: - Fix Actions
    
    func installGoose() async {
        updateCheck(id: "goose_installed", status: .checking)
        do {
            let result = try await runner.runCommand(
                executable: URL(fileURLWithPath: "/opt/homebrew/bin/brew"),
                arguments: ["install", "block-goose-cli"],
                currentDirectory: URL(fileURLWithPath: NSHomeDirectory())
            )
            if result.status == 0 {
                updateCheck(id: "goose_installed", status: .ok)
            } else {
                let err = String(data: result.errorOutput, encoding: .utf8) ?? "Unknown error"
                updateCheck(id: "goose_installed", status: .failed(err))
            }
        } catch {
            updateCheck(id: "goose_installed", status: .failed(error.localizedDescription))
        }
    }
    
    // MARK: - Helpers
    
    private func updateCheck(id: String, status: CheckStatus) {
        if let idx = checks.firstIndex(where: { $0.id == id }) {
            checks[idx].status = status
        }
    }

    private static func buildChecks() -> [SetupCheck] {
        [
            SetupCheck(
                id: "goose_installed",
                title: "Goose Installed",
                description: "Agent runtime CLI is installed (brew install block-goose-cli)"
            ),
            SetupCheck(
                id: "gt_installed",
                title: "Gastown (gt) Installed",
                description: "The gt CLI must be available"
            )
        ]
    }
}

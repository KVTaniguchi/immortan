import Foundation
import AppKit
import Combine

private struct TownSettings: Decodable {
    let agents: [String: AgentConfig]
}

private struct AgentConfig: Decodable {
    let args: [String]?
}

private struct ModelRequirement {
    let checkId: String
    let title: String
    let description: String
    let modelName: String
}

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
    @Published var pullProgress: [String: Double] = [:]  // model name -> 0.0-1.0
    @Published var isPullingModel: String? = nil
    
    private let runner: CommandRunner
    private let hqLocation: String
    private var requiredModels: [ModelRequirement] = []
    
    var allPassed: Bool { checks.allSatisfy { $0.status.isOk } }
    
    init(
        hqLocation: String = "/Users/ktaniguchi/Development/immortan",
        runner: CommandRunner = NativeCommandRunner()
    ) {
        self.hqLocation = hqLocation
        self.runner = runner
        self.requiredModels = Self.loadRequiredModels(hqLocation: hqLocation)
        self.checks = Self.buildChecks(modelRequirements: requiredModels)
    }
    
    // MARK: - Run All Checks
    
    func runAllChecks() async {
        isRunningChecks = true
        
        // Mark all as checking
        for i in checks.indices { checks[i].status = .checking }
        
        await checkOllamaRunning()
        await checkGooseInstalled()
        await checkGtInstalled()
        for requirement in requiredModels {
            await checkModelAvailable(checkId: requirement.checkId, modelName: requirement.modelName)
        }
        
        isRunningChecks = false
    }
    
    // MARK: - Individual Checks
    
    private func checkOllamaRunning() async {
        let result = await withCheckedContinuation { continuation in
            let session = URLSession.shared
            guard let url = URL(string: "http://localhost:11434") else {
                continuation.resume(returning: false)
                return
            }
            let task = session.dataTask(with: url) { _, response, _ in
                let ok = (response as? HTTPURLResponse)?.statusCode != nil
                continuation.resume(returning: ok)
            }
            task.resume()
        }
        updateCheck(id: "ollama_running", status: result ? .ok : .failed("Ollama is not running. Open the Ollama app or run 'ollama serve'."))
    }
    
    private func checkGooseInstalled() async {
        let found = FileManager.default.fileExists(atPath: "/opt/homebrew/bin/goose")
        updateCheck(id: "goose_installed", status: found ? .ok : .failed("Goose not found at /opt/homebrew/bin/goose. Install via Homebrew."))
    }
    
    private func checkGtInstalled() async {
        let found = FileManager.default.fileExists(atPath: "/opt/homebrew/bin/gt")
        updateCheck(id: "gt_installed", status: found ? .ok : .failed("'gt' not found at /opt/homebrew/bin/gt."))
    }
    
    private func checkModelAvailable(checkId: String, modelName: String) async {
        do {
            let result = try await runner.runCommand(
                executable: URL(fileURLWithPath: "/opt/homebrew/bin/ollama"),
                arguments: ["list"],
                currentDirectory: URL(fileURLWithPath: NSHomeDirectory())
            )
            let output = String(data: result.output, encoding: .utf8) ?? ""
            let available = output.contains(modelName)
            updateCheck(id: checkId, status: available ? .ok : .failed("Model '\(modelName)' not downloaded yet."))
        } catch {
            updateCheck(id: checkId, status: .failed("Could not check Ollama models: \(error.localizedDescription)"))
        }
    }
    
    // MARK: - Fix Actions
    
    func launchOllama() {
        let script = "tell application \"Ollama\" to activate"
        if let appleScript = NSAppleScript(source: script) {
            var err: NSDictionary?
            appleScript.executeAndReturnError(&err)
        }
        // Fallback: open the app directly
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Ollama.app"))
    }
    
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
    
    func pullModel(modelName: String, checkId: String) async {
        isPullingModel = modelName
        updateCheck(id: checkId, status: .checking)
        do {
            let result = try await runner.runCommand(
                executable: URL(fileURLWithPath: "/opt/homebrew/bin/ollama"),
                arguments: ["pull", modelName],
                currentDirectory: URL(fileURLWithPath: NSHomeDirectory())
            )
            if result.status == 0 {
                updateCheck(id: checkId, status: .ok)
            } else {
                let err = String(data: result.errorOutput, encoding: .utf8) ?? "Pull failed"
                updateCheck(id: checkId, status: .failed(err))
            }
        } catch {
            updateCheck(id: checkId, status: .failed(error.localizedDescription))
        }
        isPullingModel = nil
    }

    func modelName(forCheckID checkId: String) -> String? {
        requiredModels.first(where: { $0.checkId == checkId })?.modelName
    }

    func isModelCheck(_ checkId: String) -> Bool {
        requiredModels.contains(where: { $0.checkId == checkId })
    }
    
    // MARK: - Helpers
    
    private func shellWhich(_ binary: String) async -> Bool {
        do {
            let result = try await runner.runCommand(
                executable: URL(fileURLWithPath: "/usr/bin/which"),
                arguments: [binary],
                currentDirectory: URL(fileURLWithPath: NSHomeDirectory())
            )
            return result.status == 0
        } catch {
            return false
        }
    }
    
    private func updateCheck(id: String, status: CheckStatus) {
        if let idx = checks.firstIndex(where: { $0.id == id }) {
            checks[idx].status = status
        }
    }

    private static func buildChecks(modelRequirements: [ModelRequirement]) -> [SetupCheck] {
        var checks: [SetupCheck] = [
            SetupCheck(id: "ollama_running",   title: "Ollama Running",         description: "Local inference server must be running"),
            SetupCheck(id: "goose_installed",  title: "Goose Installed",        description: "Persistent agent shell (brew install block-goose-cli)"),
            SetupCheck(id: "gt_installed",     title: "Gastown (gt) Installed", description: "The gt CLI must be available")
        ]

        checks.append(contentsOf: modelRequirements.map {
            SetupCheck(id: $0.checkId, title: $0.title, description: $0.description)
        })
        return checks
    }

    private static func loadRequiredModels(hqLocation: String) -> [ModelRequirement] {
        let configURL = URL(fileURLWithPath: hqLocation)
            .appendingPathComponent("settings")
            .appendingPathComponent("config.json")

        guard
            let data = try? Data(contentsOf: configURL),
            let settings = try? JSONDecoder().decode(TownSettings.self, from: data)
        else {
            return fallbackModelRequirements()
        }

        var requirements: [ModelRequirement] = []
        let roleTuples: [(role: String, title: String)] = [
            ("mayor", "Mayor Model Ready"),
            ("polecat", "Polecat Model Ready")
        ]

        for item in roleTuples {
            guard
                let config = settings.agents[item.role],
                let args = config.args,
                let model = extractModelName(from: args)
            else {
                continue
            }

            requirements.append(
                ModelRequirement(
                    checkId: "model_\(item.role)",
                    title: item.title,
                    description: model,
                    modelName: model
                )
            )
        }

        return requirements.isEmpty ? fallbackModelRequirements() : requirements
    }

    private static func fallbackModelRequirements() -> [ModelRequirement] {
        [
            ModelRequirement(
                checkId: "model_mayor",
                title: "Mayor Model Ready",
                description: "qwen2.5-coder:32b",
                modelName: "qwen2.5-coder:32b"
            ),
            ModelRequirement(
                checkId: "model_polecat",
                title: "Polecat Model Ready",
                description: "glm4:9b",
                modelName: "glm4:9b"
            )
        ]
    }

    private static func extractModelName(from args: [String]) -> String? {
        guard let idx = args.firstIndex(of: "--model"), args.indices.contains(idx + 1) else {
            return nil
        }
        return args[idx + 1]
    }
}

import Foundation
import Combine
import AppKit

@MainActor
class GastownService: ObservableObject {
    @Published var townStatus: TownStatus?
    @Published var error: String?
    @Published var isPolling = false
    
    private var timer: Timer?
    private let gtPath = "/opt/homebrew/bin/gt"
    private let pollInterval: TimeInterval = 2.0
    
    private let hqLocation: String
    let runner: CommandRunner

    
    init(hqLocation: String = "/Users/ktaniguchi/Development/immortan", runner: CommandRunner = NativeCommandRunner()) {
        self.hqLocation = hqLocation
        self.runner = runner
    }

    func startPolling() {
        guard !isPolling else { return }
        isPolling = true
        Task { @MainActor [weak self] in
            await self?.fetchStatus()
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchStatus()
            }
        }
    }
    
    func stopPolling() {
        isPolling = false
        timer?.invalidate()
        timer = nil
    }
    
    func fetchStatus() async {
        do {
            let result = try await self.runner.runCommand(
                executable: URL(fileURLWithPath: self.gtPath),
                arguments: ["status", "--json"],
                currentDirectory: URL(fileURLWithPath: self.hqLocation)
            )
            
            if result.status == 0 {
                let decoder = JSONDecoder()
                do {
                    let town = try decoder.decode(TownStatus.self, from: result.output)
                    if self.townStatus != town {
                        self.townStatus = town
                        self.error = nil
                    }
                } catch {
                    self.error = "Failed to parse Gastown JSON: \(error.localizedDescription)"
                    print(String(data: result.output, encoding: .utf8) ?? "Empty data")
                }
            } else {
                let errStr = String(data: result.errorOutput, encoding: .utf8) ?? "Unknown GT Error"
                self.error = "Gastown Error: \(errStr)"
            }
        } catch {
            print("GastownService fetchStatus error: \(error)")
            if let nsErr = error as NSError? {
                print("  domain: \(nsErr.domain), code: \(nsErr.code), userInfo: \(nsErr.userInfo)")
            }
            self.error = "Failed to run command: \(error.localizedDescription)"
        }
    }
    
    // MARK: - App Actions
    
    /// Adds a conventional git repository as a rig
    func addRig(name: String, url: String) async throws {
        let result = try await runner.runCommand(
            executable: URL(fileURLWithPath: gtPath),
            arguments: ["rig", "add", name, url],
            currentDirectory: URL(fileURLWithPath: hqLocation)
        )
        
        if result.status != 0 {
            let errorString = String(data: result.errorOutput, encoding: .utf8) ?? "Unknown Error adding rig"
            throw NSError(domain: "GastownService", code: result.status, userInfo: [NSLocalizedDescriptionKey: errorString])
        }
        
        // Immediately fetch status after adding a rig
        Task { @MainActor in
            await self.fetchStatus()
        }
    }
    
    /// Creates a new directory, runs `git init`, and then adopts it as a Gastown rig.
    /// - Parameter parentDirectory: Where to create the new project directory. Defaults to hqLocation.
    func createEmptyProject(name: String, parentDirectory: URL? = nil) async throws {
        let rootDirectory = parentDirectory ?? URL(fileURLWithPath: hqLocation)

        // 1. Mkdir
        let projectURL = rootDirectory.appendingPathComponent(name, isDirectory: true)
        try runner.createDirectory(at: projectURL, withIntermediateDirectories: true, attributes: nil)
        
        // 2. Git init
        let gitResult = try await runner.runCommand(
            executable: URL(fileURLWithPath: "/usr/bin/git"),
            arguments: ["init"],
            currentDirectory: projectURL
        )
        
        if gitResult.status != 0 {
            throw NSError(domain: "GastownService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize git repository"])
        }

        // 3. Adopt rig from the project directory while pinning the town root.
        // This allows projects to live outside the Immortan repo.
        try await adoptExistingProject(name: name, projectDirectory: projectURL)
    }

    /// Registers an existing local project directory as a rig in this town.
    func adoptExistingProject(name: String, projectDirectory: URL) async throws {
        let isDirectory = (try? projectDirectory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        guard isDirectory else {
            throw NSError(
                domain: "GastownService",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Selected path is not a directory: \(projectDirectory.path)"]
            )
        }

        let adoptResult = try await runner.runCommand(
            executable: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: ["GT_ROOT=\(hqLocation)", gtPath, "rig", "add", name, "--adopt", "--force"],
            currentDirectory: projectDirectory
        )

        if adoptResult.status != 0 {
            let errorString = String(data: adoptResult.errorOutput, encoding: .utf8) ?? "Unknown Error in rig adoption"
            throw NSError(domain: "GastownService", code: adoptResult.status, userInfo: [NSLocalizedDescriptionKey: errorString])
        }

        Task { @MainActor in
            await self.fetchStatus()
        }
    }
    
    /// Sends a message directly into the Mayor's running Goose session via gt nudge (tmux send-keys).
    /// NOTE: gt mail send only queues messages; Goose doesn't poll mail, so we must use gt nudge.
    func sendNativeMail(to address: String, message: String) async throws {
        let target = normalizeNudgeTarget(address)

        // Use --stdin to avoid shell quoting issues with special characters.
        let result = try await runner.runCommand(
            executable: URL(fileURLWithPath: gtPath),
            arguments: ["nudge", target, "--mode=immediate", "--stdin"],
            currentDirectory: URL(fileURLWithPath: hqLocation),
            stdinData: (message + "\n").data(using: .utf8)
        )
        
        if result.status != 0 {
            let errorString = String(data: result.errorOutput, encoding: .utf8) ?? "Failed to nudge mayor"
            throw NSError(domain: "GastownService", code: result.status, userInfo: [NSLocalizedDescriptionKey: errorString])
        }

        // In immediate mode, nudge injects text into tmux but can leave it unsubmitted.
        // Force Enter so the active prompt actually runs.
        try await submitPromptIfSessionFound(for: target)
    }
    
    /// Uses AppleScript to spawn a native macOS Terminal attached to the Mayor.
    func openMayorChat() {
        let scriptSource = """
        tell application "Terminal"
            activate
            do script "cd \(hqLocation) && \(gtPath) mayor attach"
        end tell
        """
        
        if let appleScript = NSAppleScript(source: scriptSource) {
            var errorInfo: NSDictionary?
            appleScript.executeAndReturnError(&errorInfo)
            
            if let error = errorInfo {
                print("AppleScript Error: \(error)")
                self.error = "Failed to open Terminal: \(error["NSAppleScriptErrorMessage"] ?? "Unknown")"
            }
        } else {
            self.error = "Failed to compile AppleScript for the Mayor chat."
        }
    }
    
    func startTown() async throws {
        _ = try await runner.runCommand(
            executable: URL(fileURLWithPath: gtPath),
            arguments: ["up"],
            currentDirectory: URL(fileURLWithPath: hqLocation)
        )
        
        Task { @MainActor in
            await self.fetchStatus()
        }
    }
    
    func startMayor(inRig rigName: String) async throws {
        let rigDirectory = workingDirectoryForRig(named: rigName)
        let result = try await runner.runCommand(
            executable: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: ["GT_ROOT=\(hqLocation)", gtPath, "mayor", "start"],
            currentDirectory: rigDirectory
        )

        if result.status != 0 {
            let errorString = String(data: result.errorOutput, encoding: .utf8) ?? "Failed to start mayor"
            throw NSError(domain: "GastownService", code: result.status, userInfo: [NSLocalizedDescriptionKey: errorString])
        }
        
        Task { @MainActor in
            await self.fetchStatus()
        }
    }

    /// One-click launch flow for a rig:
    /// 1) Ensure town services are running
    /// 2) Start mayor using provider/account configured in Gastown settings.
    func launchRig(name rigName: String) async throws {
        try await startTown()
        try await startMayor(inRig: rigName)
        await fetchStatus()
    }

    // MARK: - Message Helpers

    private func normalizeNudgeTarget(_ address: String) -> String {
        address.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func submitPromptIfSessionFound(for target: String) async throws {
        guard let tmuxPath = resolveTmuxPath() else { return }
        let candidates = candidateSessions(for: target)

        for session in candidates {
            let hasSession = try await runner.runCommand(
                executable: URL(fileURLWithPath: tmuxPath),
                arguments: ["has-session", "-t", session],
                currentDirectory: URL(fileURLWithPath: hqLocation)
            )

            guard hasSession.status == 0 else { continue }

            _ = try await runner.runCommand(
                executable: URL(fileURLWithPath: tmuxPath),
                arguments: ["send-keys", "-t", session, "Enter"],
                currentDirectory: URL(fileURLWithPath: hqLocation)
            )
            return
        }
    }

    private func candidateSessions(for target: String) -> [String] {
        if let status = townStatus {
            if let match = status.agents.first(where: {
                $0.name == target || $0.address.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == target
            }), let session = match.session, !session.isEmpty {
                return [session]
            }
        }

        if target == "mayor" {
            return ["hq-mayor", "gt-mayor"]
        }
        if target == "deacon" {
            return ["hq-deacon", "gt-deacon"]
        }
        return [target]
    }

    private func resolveTmuxPath() -> String? {
        let possiblePaths = ["/opt/homebrew/bin/tmux", "/usr/local/bin/tmux", "/usr/bin/tmux"]
        return possiblePaths.first { FileManager.default.fileExists(atPath: $0) }
    }

    private func workingDirectoryForRig(named rigName: String) -> URL {
        let rigPath = URL(fileURLWithPath: hqLocation).appendingPathComponent(rigName, isDirectory: true)
        let isDirectory = (try? rigPath.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        return isDirectory ? rigPath : URL(fileURLWithPath: hqLocation)
    }

    // MARK: - Config Helpers

    func configuredModel(forAgentAlias alias: String) -> String? {
        let configURL = URL(fileURLWithPath: hqLocation)
            .appendingPathComponent("settings")
            .appendingPathComponent("config.json")

        guard
            let data = try? Data(contentsOf: configURL),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let agents = root["agents"] as? [String: Any],
            let agent = agents[alias] as? [String: Any],
            let args = agent["args"] as? [String]
        else {
            return nil
        }

        guard let modelIdx = args.firstIndex(of: "--model"), args.indices.contains(modelIdx + 1) else {
            return nil
        }
        return args[modelIdx + 1]
    }
}

import Foundation
import Combine

@MainActor
class GastownService: ObservableObject {
    @Published var townStatus: TownStatus?
    @Published var error: String?
    @Published var isPolling = false
    
    private var timer: Timer?
    private let gtPath = "/opt/homebrew/bin/gt"
    private let pollInterval: TimeInterval = 2.0
    
    private let hqLocation: String
    private let runner: CommandRunner
    
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
    func createEmptyProject(name: String) async throws {
        // 1. Mkdir
        let projectURL = URL(fileURLWithPath: hqLocation).appendingPathComponent(name)
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
        
        // 3. Adopt rig
        let adoptResult = try await runner.runCommand(
            executable: URL(fileURLWithPath: gtPath),
            arguments: ["rig", "add", name, "--adopt", "--force"],
            currentDirectory: URL(fileURLWithPath: hqLocation)
        )
        
        if adoptResult.status != 0 {
            let errorString = String(data: adoptResult.errorOutput, encoding: .utf8) ?? "Unknown Error in rig adoption"
            throw NSError(domain: "GastownService", code: adoptResult.status, userInfo: [NSLocalizedDescriptionKey: errorString])
        }
        
        Task { @MainActor in
            await self.fetchStatus()
        }
    }
    
    /// Sends a native message to a Gastown address (like `mayor/`) without opening the terminal.
    func sendNativeMail(to address: String, message: String) async throws {
        let result = try await runner.runCommand(
            executable: URL(fileURLWithPath: gtPath),
            arguments: ["mail", "send", address, "-s", "Immortan Direct Message", "-m", message],
            currentDirectory: URL(fileURLWithPath: hqLocation)
        )
        
        if result.status != 0 {
            let errorString = String(data: result.errorOutput, encoding: .utf8) ?? "Failed to dispatch mail"
            throw NSError(domain: "GastownService", code: result.status, userInfo: [NSLocalizedDescriptionKey: errorString])
        }
        
        // Trigger status update to show unread mail
        Task { @MainActor in
            await self.fetchStatus()
        }
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
    
    // MARK: - Power Commands
    
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
        let rigURL = URL(fileURLWithPath: hqLocation).appendingPathComponent(rigName)
        
        _ = try await runner.runCommand(
            executable: URL(fileURLWithPath: gtPath),
            arguments: ["mayor", "start"],
            currentDirectory: rigURL
        )
        
        Task { @MainActor in
            await self.fetchStatus()
        }
    }
}

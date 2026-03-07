import Foundation

/// The standard production implementation of CommandRunner which uses Swift's Foundation.Process
/// and FileManager.default to execute real commands on the host macOS system.
class NativeCommandRunner: CommandRunner {

    private static let gtPath = "/opt/homebrew/bin/gt"

    func runCommand(executable: URL, arguments: [String], currentDirectory: URL?, stdinData: Data? = nil) async throws -> (status: Int, output: Data, errorOutput: Data) {
        let path = executable.path
        if path == Self.gtPath, !FileManager.default.isExecutableFile(atPath: path) {
            let msg = "Binary at \(Self.gtPath) is not executable by the app. Check permissions or App Sandbox."
            print("NativeCommandRunner: \(msg)")
            throw NSError(domain: "NativeCommandRunner", code: Int(POSIXErrorCode.EACCES.rawValue), userInfo: [NSLocalizedDescriptionKey: msg])
        }

        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory

        var env = ProcessInfo.processInfo.environment
        let pathEnv = env["PATH"] ?? ""
        if !pathEnv.contains("/opt/homebrew/bin") {
            env["PATH"] = "/opt/homebrew/bin:\(pathEnv)"
        }
        process.environment = env

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        var stdinPipe: Pipe?
        if let data = stdinData {
            let pipe = Pipe()
            stdinPipe = pipe
            process.standardInput = pipe
        }

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: (Int(proc.terminationStatus), outputData, errorData))
            }

            do {
                try process.run()
                if let data = stdinData, let pipe = stdinPipe {
                    pipe.fileHandleForWriting.write(data)
                    pipe.fileHandleForWriting.closeFile()
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func createDirectory(at url: URL, withIntermediateDirectories: Bool, attributes: [FileAttributeKey: Any]?) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: withIntermediateDirectories, attributes: attributes)
    }
}

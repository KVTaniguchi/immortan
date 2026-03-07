import Foundation

/// A protocol that abstracts executing shell commands and file system operations
/// so that GastownService can be unit tested without causing side effects.
protocol CommandRunner {
    /// Runs an executable with arguments and returns its output.
    func runCommand(executable: URL, arguments: [String], currentDirectory: URL?, stdinData: Data?) async throws -> (status: Int, output: Data, errorOutput: Data)
    
    /// Creates a directory at the specified URL.
    func createDirectory(at url: URL, withIntermediateDirectories: Bool, attributes: [FileAttributeKey: Any]?) throws
}

// Default stdinData = nil so existing call sites don't need to be updated.
extension CommandRunner {
    func runCommand(executable: URL, arguments: [String], currentDirectory: URL?) async throws -> (status: Int, output: Data, errorOutput: Data) {
        try await runCommand(executable: executable, arguments: arguments, currentDirectory: currentDirectory, stdinData: nil)
    }
}


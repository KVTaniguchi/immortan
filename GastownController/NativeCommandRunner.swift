import Foundation

/// The standard production implementation of CommandRunner which uses Swift's Foundation.Process
/// and FileManager.default to execute real commands on the host macOS system.
class NativeCommandRunner: CommandRunner {
    
    func runCommand(executable: URL, arguments: [String], currentDirectory: URL?) async throws -> (status: Int, output: Data, errorOutput: Data) {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        
        if let dir = currentDirectory {
            process.currentDirectoryURL = dir
        }
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        return (status: Int(process.terminationStatus), output: outputData, errorOutput: errorData)
    }
    
    func createDirectory(at url: URL, withIntermediateDirectories: Bool, attributes: [FileAttributeKey : Any]?) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: withIntermediateDirectories, attributes: attributes)
    }
}

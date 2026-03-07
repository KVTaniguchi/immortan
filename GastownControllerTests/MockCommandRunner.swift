import Foundation
@testable import GastownController

/// A mock implementation of CommandRunner for unit testing the GastownService
/// without making actual CLI calls or touching the local filesystem.
class MockCommandRunner: CommandRunner {
    
    // Tracking exact arguments used to assert they were called correctly
    var executedCommands: [[String]] = []
    var createdDirectories: [URL] = []
    
    // Injectable stubs for returning data or throwing errors
    var stubbedStatusOutput: Data = Data()
    var stubbedErrorOutput: Data = Data()
    var stubbedStatusCode: Int = 0
    var shouldThrowError: Bool = false
    
    func runCommand(executable: URL, arguments: [String], currentDirectory: URL?, stdinData: Data?) async throws -> (status: Int, output: Data, errorOutput: Data) {
        if shouldThrowError {
            throw NSError(domain: "MockRunnerError", code: 99, userInfo: nil)
        }
        
        // Log the command invocation for XCTest assertions
        var fullCommand = [executable.lastPathComponent]
        fullCommand.append(contentsOf: arguments)
        executedCommands.append(fullCommand)
        
        return (status: stubbedStatusCode, output: stubbedStatusOutput, errorOutput: stubbedErrorOutput)
    }
    
    func createDirectory(at url: URL, withIntermediateDirectories: Bool, attributes: [FileAttributeKey : Any]?) throws {
        if shouldThrowError {
            throw NSError(domain: "MockRunnerDirError", code: 88, userInfo: nil)
        }
        createdDirectories.append(url)
    }
}

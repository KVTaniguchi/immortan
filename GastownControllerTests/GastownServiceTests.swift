import XCTest
@testable import GastownController

@MainActor
final class GastownServiceTests: XCTestCase {
    
    var service: GastownService!
    var mockRunner: MockCommandRunner!
    
    override func setUp() {
        super.setUp()
        mockRunner = MockCommandRunner()
        // Inject the mock runner so tests are perfectly sandboxed
        service = GastownService(hqLocation: "/tmp/mockHQ", runner: mockRunner)
    }
    
    override func tearDown() {
        service = nil
        mockRunner = nil
        super.tearDown()
    }
    
    func testFetchStatusSuccessfullyDecodesJSON() async throws {
        // 1. Setup mock JSON matching TownStatus structure
        let mockJSON = """
        {
            "name": "TestTown",
            "location": "/tmp/mockHQ",
            "overseer": {
                "name": "Test User", 
                "email": "test@test.com", 
                "username": "tester",
                "source": "local",
                "unread_mail": 0
            },
            "daemon": {"running": true, "binary": "gt", "version": "1.0", "pid": 123},
            "dolt": {"running": true},
            "tmux": {"running": false, "socket": "test-socket", "socket_path": "/tmp/socket", "session_count": 0},
            "agents": [
                {
                    "name": "mayor",
                    "address": "mayor/",
                    "role": "coordinator",
                    "running": true,
                    "state": "idle",
                    "unread_mail": 0,
                    "has_work": false
                }
            ],
            "rigs": [
                {
                  "name": "todosampler",
                  "polecat_count": 0,
                  "crew_count": 0,
                  "has_witness": false,
                  "has_refinery": false
                }
            ],
            "summary": {
                "rig_count": 0,
                "polecat_count": 0,
                "crew_count": 0,
                "witness_count": 0,
                "refinery_count": 0,
                "active_hooks": 0
            }
        }
        """.data(using: .utf8)!
        
        mockRunner.stubbedStatusOutput = mockJSON
        mockRunner.stubbedStatusCode = 0
        
        // 2. Perform Fetch
        await service.fetchStatus()
        
        // 3. Assertions
        XCTAssertNotNil(service.townStatus)
        XCTAssertEqual(service.townStatus?.name, "TestTown")
        XCTAssertEqual(service.townStatus?.agents.first?.narrativeState, .planning)
        // Verify Command Runner intercepted exactly gt status --json
        XCTAssertTrue(mockRunner.executedCommands.contains(where: { $0 == ["gt", "status", "--json"] }))
    }
    
    func testCreateEmptyProjectExecutesCorrectPipelines() async throws {
        mockRunner.stubbedStatusCode = 0
        
        // Act
        try await service.createEmptyProject(name: "UnitTestRig")
        
        // Assert
        // 1. Verify Directory Created
        XCTAssertEqual(mockRunner.createdDirectories.last?.lastPathComponent, "UnitTestRig")
        
        // 2. Verify git init was triggered
        XCTAssertTrue(mockRunner.executedCommands.contains(where: { $0 == ["git", "init"] }))
        
        // 3. Verify gt rig adopt was triggered
        XCTAssertTrue(mockRunner.executedCommands.contains(where: { $0 == ["gt", "rig", "add", "UnitTestRig", "--adopt", "--force"] }))
    }
    
    func testStartMayorFiresCorrectCommandInRigDirectory() async throws {
        // 1. Trigger Mayor Boot
        try await service.startMayor(inRig: "todosampler")
        
        // 2. Verify GT_ROOT-pinned mayor start was triggered via env
        XCTAssertTrue(
            mockRunner.executedCommands.contains(where: {
                $0.count >= 5 &&
                $0[0] == "env" &&
                $0[2].hasSuffix("/gt") &&
                $0[3] == "mayor" &&
                $0[4] == "start"
            })
        )
    }
    
    func testSendNativeMailFormatsCorrectly() async throws {
        mockRunner.stubbedStatusCode = 0
        
        // Act
        try await service.sendNativeMail(to: "mayor/", message: "Test Nudge")
        
        // Assert format: gt nudge mayor --mode=immediate --stdin
        let expectedCommand = ["gt", "nudge", "mayor", "--mode=immediate", "--stdin"]
        XCTAssertTrue(mockRunner.executedCommands.contains(expectedCommand))
    }
}

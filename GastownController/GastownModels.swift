import Foundation

// MARK: - Narrative Layer

enum NarrativeState: String {
    case planning = "Planning next move"
    case forging = "Forging code"
    case jammed = "Jammed/Stalled"
    case asleep = "Asleep"
    case unknown = "Unknown status"
}

struct NarrativeEvent: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    let rawText: String
    
    // Derived human-readable strings based on simple parsing
    var narrativeText: String {
        if rawText.contains("slung to") {
            return "Task Assigned 🎯"
        } else if rawText.contains("patrol") {
            return "Witness on Patrol 🦉"
        } else if rawText.contains("failed") {
            return "Step Failed ✗"
        } else if rawText.contains("completed") {
            return "Milestone Hit ✓"
        }
        return rawText
    }
    
    enum CodingKeys: String, CodingKey {
        case rawText = "text"
    }
}

// MARK: - API Models

/// Root status payload from `gt status --json`
struct TownStatus: Codable, Equatable {
    let name: String
    let location: String
    let overseer: Overseer
    let daemon: DaemonStatus
    let dolt: DoltStatus
    let tmux: TmuxStatus
    let agents: [AgentStatus]
    let rigs: [Rig]? // Optional to handle legacy or empty states safely
    let summary: TownSummary
    var events: [NarrativeEvent]? // Optional since it might not exist yet in API
}

struct Overseer: Codable, Equatable {
    let name: String
    let email: String
    let username: String
    let source: String
    let unreadMail: Int
    
    enum CodingKeys: String, CodingKey {
        case name, email, username, source
        case unreadMail = "unread_mail"
    }
}

struct DaemonStatus: Codable, Equatable {
    let running: Bool
}

struct DoltStatus: Codable, Equatable {
    let running: Bool
    let pid: Int?
    let port: Int?
    let dataDir: String?
    
    enum CodingKeys: String, CodingKey {
        case running, pid, port
        case dataDir = "data_dir"
    }
}

struct TmuxStatus: Codable, Equatable {
    let socket: String
    let socketPath: String
    let running: Bool
    let sessionCount: Int
    
    enum CodingKeys: String, CodingKey {
        case socket, running
        case socketPath = "socket_path"
        case sessionCount = "session_count"
    }
}

struct AgentStatus: Codable, Equatable, Identifiable {
    var id: String { name }
    let name: String
    let address: String
    let session: String?
    let role: String?
    let running: Bool
    let hasWork: Bool
    let state: String?
    let unreadMail: Int
    let agentAlias: String?
    let agentInfo: String?
    
    enum CodingKeys: String, CodingKey {
        case name, address, session, role, running, state
        case hasWork = "has_work"
        case unreadMail = "unread_mail"
        case agentAlias = "agent_alias"
        case agentInfo = "agent_info"
    }
    
    var narrativeState: NarrativeState {
        guard running else { return .asleep }
        
        if let st = state?.lowercased() {
            if st == "idle" { return .planning }
            if st == "busy" { return .forging }
            if st.contains("stall") || st.contains("stuck") { return .jammed }
        }
        
        return .unknown
    }
}

struct Rig: Codable, Equatable, Identifiable {
    var id: String { name }
    let name: String
    let polecatCount: Int
    let crewCount: Int
    let hasWitness: Bool
    let hasRefinery: Bool
    
    enum CodingKeys: String, CodingKey {
        case name
        case polecatCount = "polecat_count"
        case crewCount = "crew_count"
        case hasWitness = "has_witness"
        case hasRefinery = "has_refinery"
    }
}

struct TownSummary: Codable, Equatable {
    let rigCount: Int
    let polecatCount: Int
    let crewCount: Int
    let witnessCount: Int
    let refineryCount: Int
    let activeHooks: Int
    
    enum CodingKeys: String, CodingKey {
        case rigCount = "rig_count"
        case polecatCount = "polecat_count"
        case crewCount = "crew_count"
        case witnessCount = "witness_count"
        case refineryCount = "refinery_count"
        case activeHooks = "active_hooks"
    }
}

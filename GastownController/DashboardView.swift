import SwiftUI

struct DashboardView: View {
    @ObservedObject var service: GastownService
    @State private var chatTarget: AgentStatus?
    
    // Industrial theme colors
    let warRigBackground = Color(red: 0.1, green: 0.1, blue: 0.12)
    let neonGreen = Color(red: 0.2, green: 0.9, blue: 0.4)
    let neonOrange = Color(red: 1.0, green: 0.6, blue: 0.0)
    let steelGray = Color(red: 0.25, green: 0.25, blue: 0.28)
    
    var body: some View {
        ZStack {
            warRigBackground.ignoresSafeArea()
            
            if let town = service.townStatus {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Error State
                        if let error = service.error {
                            ErrorBanner(message: error)
                        }
                        
                        // TOP: Citadel Header
                        HStack {
                            VStack(alignment: .leading) {
                                Text(town.name.uppercased())
                                    .font(.system(size: 32, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.white)
                                Text("SYSTEM: \(town.location)")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("OVERSEER: \(town.overseer.name.uppercased())")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(neonOrange)
                                
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(town.daemon.running ? neonGreen : .red)
                                        .frame(width: 8, height: 8)
                                    Text("DAEMON")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                        .monospaced()
                                    
                                    Circle()
                                        .fill(town.dolt.running ? neonGreen : .red)
                                        .frame(width: 8, height: 8)
                                    Text("DOLT")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                        .monospaced()
                                }
                            }
                        }
                        .padding(.bottom, 8)
                        
                        Divider().background(steelGray)
                        
                        // NEW: Projects / Rigs
                        Text("REGISTERED RIGS")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        
                        if let rigs = town.rigs, !rigs.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(rigs) { rig in
                                        RigStation(rig: rig, accent: .cyan, service: service)
                                    }
                                }
                            }
                        } else {
                            Text("NO PROJECTS DETECTED. CLICK '+' TO INITIALIZE NEW RIG.")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(neonOrange)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .border(steelGray, width: 1)
                        }
                        
                        Divider().background(steelGray)
                        
                        // MIDDLE: The Pipeline / Assembly Line
                        Text("PRODUCTION PIPELINE")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        
                        // Progress Bar (Total Active Hooks vs completed generic ratio just as visual flair)
                        VStack(spacing: 4) {
                            HStack {
                                Text("MILITARY TARGET")
                                    .font(.caption2)
                                    .foregroundColor(neonGreen)
                                Spacer()
                                Text("\(town.summary.activeHooks) ACTIVE BATTLES")
                                    .font(.caption2)
                            }
                            ProgressView(value: 0.6) // Fake milestone percent for now natively
                                .progressViewStyle(LinearProgressViewStyle(tint: neonOrange))
                        }
                        .padding(.vertical, 8)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                // 1. Mayor (Coordinator)
                                if let mayor = town.agents.first(where: { $0.role == "coordinator" }) {
                                    AssemblyStation(agent: mayor, title: "HQ / MAYOR", accent: neonOrange) {
                                        chatTarget = mayor
                                    }
                                }
                                
                                Image(systemName: "chevron.right.2")
                                    .foregroundColor(steelGray)
                                
                                // 2. Polecats (Workers)
                                VStack(spacing: 8) {
                                    Text("POLECATS (WORKERS)")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    HStack(spacing: 8) {
                                        ForEach(town.agents.filter { $0.role == nil || $0.role == "worker" }) { worker in
                                            AssemblyStation(agent: worker, title: worker.name.uppercased(), accent: .blue) {
                                                chatTarget = worker
                                            }
                                        }
                                    }
                                }
                                
                                Image(systemName: "chevron.right.2")
                                    .foregroundColor(steelGray)
                                
                                // 3. Witness & Deacon (Health Checkers)
                                VStack(spacing: 8) {
                                    Text("QA & RELIABILITY")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    HStack(spacing: 8) {
                                        ForEach(town.agents.filter { $0.role == "health-check" || $0.role == "witness" }) { checker in
                                            AssemblyStation(agent: checker, title: checker.name.uppercased(), accent: .purple) {
                                                chatTarget = checker
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        Divider().background(steelGray).padding(.vertical, 8)
                        
                        // BOTTOM: The Narrative Feed
                        Text("NARRATIVE FEED & ALERTS")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            if let events = town.events, !events.isEmpty {
                                ForEach(events) { event in
                                    HStack {
                                        Text(">")
                                            .foregroundColor(neonOrange)
                                            .font(.system(.body, design: .monospaced))
                                        Text(event.narrativeText)
                                            .foregroundColor(.white)
                                            .font(.system(.body, design: .monospaced))
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(steelGray.opacity(0.3))
                                    .border(steelGray, width: 1)
                                }
                            } else {
                                // Fallback simulated narrative
                                HStack {
                                    Text(">")
                                        .foregroundColor(neonGreen)
                                        .font(.system(.body, design: .monospaced))
                                    Text("The Town is quiet. Awaiting Overseer directives.")
                                        .foregroundColor(.gray)
                                        .font(.system(.body, design: .monospaced))
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(steelGray.opacity(0.3))
                                .border(steelGray, width: 1)
                            }
                        }
                        
                    }
                    .padding(32)
                }
            } else {
                VStack(spacing: 20) {
                    ProgressView()
                        .colorScheme(.dark)
                    Text("ESTABLISHING COMM LINK TO GASTOWN...")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(neonOrange)
                }
            }
        }
        .sheet(item: $chatTarget) { agent in
            QuickChatSheet(service: service, targetAgent: agent)
        }
    }
}

struct AssemblyStation: View {
    let agent: AgentStatus
    let title: String
    let accent: Color
    let onChat: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(agent.running ? accent : .gray)
                    .frame(width: 10, height: 10)
                    .shadow(color: agent.running ? accent : .clear, radius: 4)
                
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onChat) {
                    Image(systemName: "terminal")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(accent)
            }
            
            Text(agent.narrativeState.rawValue.uppercased())
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(agent.narrativeState == .forging ? accent : .gray)
            
            HStack {
                if agent.hasWork {
                    Label("ENGAGED", systemImage: "bolt.fill")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(accent)
                }
                if agent.unreadMail > 0 {
                    Label("\(agent.unreadMail) MAIL", systemImage: "envelope.fill")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(16)
        .frame(width: 220, height: 110)
        .background(Color(red: 0.15, green: 0.15, blue: 0.17))
        .border(agent.running ? accent.opacity(0.5) : Color.gray.opacity(0.3), width: 2)
    }
}

struct RigStation: View {
    let rig: Rig
    let accent: Color
    @ObservedObject var service: GastownService
    
    @State private var isWaking = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(accent)
                Text(rig.name.uppercased())
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
            }
            
            Divider().background(Color.gray.opacity(0.3))
            
            HStack(spacing: 12) {
                Label("\(rig.polecatCount) WKRS", systemImage: "person.2.fill")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray)
                
                if rig.hasWitness {
                    Label("WITNESS", systemImage: "checkmark.shield.fill")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.purple)
                }
                
                Spacer()
                
                Button(action: {
                    Task {
                        isWaking = true
                        try? await service.startMayor(inRig: rig.name)
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        isWaking = false
                    }
                }) {
                    if isWaking {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Text("WAKE UP")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .tint(accent)
            }
        }
        .padding(16)
        .frame(width: 260, height: 90)
        .background(Color(red: 0.15, green: 0.15, blue: 0.17))
        .border(Color.gray.opacity(0.3), width: 1)
    }
}

struct ErrorBanner: View {
    let message: String
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.black)
            Text("SYSTEM FAULT: \(message)")
                .font(.system(.footnote, design: .monospaced))
                .bold()
                .foregroundColor(.black)
            Spacer()
        }
        .padding()
        .background(Color.yellow)
        .border(.orange, width: 2)
    }
}

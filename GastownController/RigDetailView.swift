import SwiftUI

struct RigDetailView: View {
    let rig: Rig
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
                        
                        // Header
                        HStack {
                            VStack(alignment: .leading) {
                                Text(rig.name.uppercased())
                                    .font(.system(size: 32, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.white)
                                Text("RIG STATUS: \(rig.polecatCount) WORKERS")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            RigStation(rig: rig, accent: .cyan, service: service)
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
        .navigationTitle(rig.name.uppercased())
    }
}

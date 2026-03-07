import SwiftUI

struct RigDetailView: View {
    let rig: Rig
    @ObservedObject var service: GastownService
    
    @State private var chatTarget: AgentStatus?
    
    private var currentMilestone: NarrativeState {
        guard let town = service.townStatus else { return .unknown }
        let states = town.agents.map { $0.narrativeState }
        if states.contains(.jammed) { return .jammed }
        if states.contains(.forging) { return .forging }
        if states.contains(.planning) { return .planning }
        if states.contains(.asleep) { return .asleep }
        return .unknown
    }
    
    // Industrial theme colors
    let warRigBackground = Color(red: 0.1, green: 0.1, blue: 0.12)
    let neonGreen = Color(red: 0.2, green: 0.9, blue: 0.4)
    let neonOrange = Color(red: 1.0, green: 0.6, blue: 0.0)
    let steelGray = Color(red: 0.25, green: 0.25, blue: 0.28)
    
    var body: some View {
        ZStack {
            warRigBackground.ignoresSafeArea()
            
            if let town = service.townStatus {
                VStack(spacing: 0) {
                    // FIXED TOP: Admin Panel
                    VStack(alignment: .leading, spacing: 20) {
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
                        
                        // Pipeline
                        Text("PRODUCTION PIPELINE")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        
                        // Progress Bar
                        VStack(spacing: 4) {
                            HStack {
                                Text("CURRENT MILESTONE")
                                    .font(.caption2)
                                    .foregroundColor(neonGreen)
                                Spacer()
                                Text(currentMilestone.rawValue.uppercased())
                                    .font(.caption2)
                                    .foregroundColor(currentMilestone == .jammed ? .red : (currentMilestone == .forging ? neonOrange : neonGreen))
                            }
                            ProgressView(value: currentMilestone == .forging ? 0.6 : (currentMilestone == .jammed ? 0.3 : (currentMilestone == .planning ? 0.1 : 1.0)))
                                .progressViewStyle(LinearProgressViewStyle(tint: currentMilestone == .jammed ? .red : neonOrange))
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                if let mayor = town.agents.first(where: { $0.role == "coordinator" }) {
                                    AssemblyStation(agent: mayor, title: "HQ / MAYOR", accent: neonOrange) {
                                        chatTarget = mayor
                                    }
                                }
                                
                                Image(systemName: "chevron.right.2")
                                    .foregroundColor(steelGray)
                                
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
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(warRigBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(steelGray.opacity(0.85), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    
                    Divider().background(steelGray)
                    
                    // SCROLLABLE CONTENT: Narrative & Chat
                    MayorChatView(service: service, rigName: rig.name)
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
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 14)
        }
        .navigationTitle(rig.name.uppercased())
    }
}

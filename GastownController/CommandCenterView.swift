import SwiftUI

struct CommandCenterView: View {
    @ObservedObject var service: GastownService
    @Binding var selection: ContentView.SidebarItem?
    
    @State private var isPoweringOn = false
    
    // Industrial theme colors
    let warRigBackground = Color(red: 0.1, green: 0.1, blue: 0.12)
    let neonGreen = Color(red: 0.2, green: 0.9, blue: 0.4)
    let neonOrange = Color(red: 1.0, green: 0.6, blue: 0.0)
    let steelGray = Color(red: 0.25, green: 0.25, blue: 0.28)
    
    let columns = [GridItem(.adaptive(minimum: 260))]
    
    var body: some View {
        ZStack {
            warRigBackground.ignoresSafeArea()
            
            if let town = service.townStatus {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        if let error = service.error {
                            ErrorBanner(message: error)
                        }
                        
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
                                    if !town.daemon.running {
                                        Button(action: {
                                            isPoweringOn = true
                                            Task {
                                                try? await service.startTown()
                                                isPoweringOn = false
                                            }
                                        }) {
                                            if isPoweringOn {
                                                ProgressView()
                                                    .controlSize(.mini)
                                                    .padding(.horizontal, 8)
                                            } else {
                                                Text("POWER ON")
                                                    .font(.caption2.bold())
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(neonOrange)
                                                    .foregroundColor(.black)
                                                    .cornerRadius(4)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(isPoweringOn)
                                    }
                                    
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
                        
                        Text("REGISTERED RIGS")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        
                        if let rigs = town.rigs, !rigs.isEmpty {
                            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                                ForEach(rigs) { rig in
                                    Button(action: {
                                        selection = .rig(rig.name)
                                    }) {
                                        RigStation(rig: rig, accent: .cyan, service: service)
                                    }
                                    .buttonStyle(.plain)
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
    }
}

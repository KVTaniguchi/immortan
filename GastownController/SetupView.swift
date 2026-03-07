import SwiftUI

struct SetupView: View {
    @StateObject private var setup = SetupCheckService()
    @StateObject private var town = GastownService()
    @State private var isStartingTown = false
    let onComplete: () -> Void
    
    let bgColor  = Color(red: 0.1,  green: 0.1,  blue: 0.12)
    let neonGreen  = Color(red: 0.2,  green: 0.9,  blue: 0.4)
    let neonOrange = Color(red: 1.0,  green: 0.6,  blue: 0.0)
    let steelGray  = Color(red: 0.25, green: 0.25, blue: 0.28)
    
    private var gtInstalled: Bool {
        setup.checks.first(where: { $0.id == "gt_installed" })?.status.isOk ?? false
    }
    
    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("IMMORTAN")
                        .font(.system(size: 36, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                    Text("SYSTEM INITIALIZATION")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(neonOrange)
                }
                .padding(.horizontal, 40)
                .padding(.top, 40)
                .padding(.bottom, 32)
                
                Divider().background(steelGray).padding(.horizontal, 40)
                
                // Check rows
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach($setup.checks) { $check in
                            SetupCheckRow(
                                check: check,
                                isPulling: setup.isPullingModel == setup.modelName(forCheckID: check.id),
                                onFix: { fix(check: check) }
                            )
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 24)
                }
                
                Divider().background(steelGray).padding(.horizontal, 40)
                
                // Footer actions
                HStack(spacing: 16) {
                    Button(action: {
                        Task { await setup.runAllChecks() }
                    }) {
                        Label(setup.isRunningChecks ? "CHECKING..." : "RE-CHECK ALL",
                              systemImage: "arrow.clockwise")
                            .font(.system(.body, design: .monospaced).bold())
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.gray)
                    .disabled(setup.isRunningChecks)
                    
                    Spacer()
                    
                    if gtInstalled {
                        Button(action: {
                            isStartingTown = true
                            Task {
                                await town.ensureOllamaServerRunning()
                                try? await town.startTown()
                                isStartingTown = false
                            }
                        }) {
                            Label(isStartingTown ? "STARTING..." : "START TOWN",
                                  systemImage: "play.fill")
                                .font(.system(.body, design: .monospaced).bold())
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(steelGray)
                                .foregroundColor(neonOrange)
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .disabled(isStartingTown)
                    }
                    
                    Button(action: {
                        UserDefaults.standard.set(true, forKey: "setupComplete")
                        onComplete()
                    }) {
                        Label(setup.allPassed ? "LAUNCH GASTOWN" : "OPEN DASHBOARD",
                              systemImage: setup.allPassed ? "bolt.fill" : "rectangle.grid.2x2")
                            .font(.system(.body, design: .monospaced).bold())
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(neonGreen)
                            .foregroundColor(.black)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
                .animation(.easeInOut(duration: 0.3), value: setup.allPassed)
            }
        }
        .frame(minWidth: 600, minHeight: 480)
        .task {
            await setup.runAllChecks()
        }
    }
    
    // MARK: - Fix routing
    
    private func fix(check: SetupCheck) {
        Task {
            switch check.id {
            case "ollama_running":
                setup.launchOllama()
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3s for app to start
                await setup.runAllChecks()
            case "goose_installed":
                await setup.installGoose()
            case "gt_installed":
                NSWorkspace.shared.open(URL(string: "https://gastown.dev")!)
            case let id where setup.isModelCheck(id):
                if let model = setup.modelName(forCheckID: id) {
                    await setup.pullModel(modelName: model, checkId: id)
                }
            default:
                break
            }
        }
    }
}

// MARK: - Check Row

struct SetupCheckRow: View {
    let check: SetupCheck
    let isPulling: Bool
    let onFix: () -> Void
    
    let neonGreen  = Color(red: 0.2,  green: 0.9,  blue: 0.4)
    let neonOrange = Color(red: 1.0,  green: 0.6,  blue: 0.0)
    let steelGray  = Color(red: 0.25, green: 0.25, blue: 0.28)
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Status icon
            Group {
                switch check.status {
                case .pending:
                    Circle()
                        .fill(steelGray)
                        .frame(width: 14, height: 14)
                case .checking:
                    ProgressView()
                        .controlSize(.mini)
                        .frame(width: 14, height: 14)
                case .ok:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(neonGreen)
                        .font(.system(size: 16))
                case .failed:
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 16))
                }
            }
            .frame(width: 20, height: 20)
            .padding(.top, 2)
            
            // Labels
            VStack(alignment: .leading, spacing: 4) {
                Text(check.title.uppercased())
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(statusColor)
                
                Text(check.description)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
                
                if let msg = check.status.failureMessage {
                    Text(msg)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.red.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                if isPulling {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.mini)
                        Text("DOWNLOADING...")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(neonOrange)
                    }
                    .padding(.top, 4)
                }
            }
            
            Spacer()
            
            // Fix button
            if check.status.isFailed && !isPulling {
                Button(action: onFix) {
                    Text(fixLabel)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(neonOrange.opacity(0.15))
                        .foregroundColor(neonOrange)
                        .cornerRadius(3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(neonOrange.opacity(0.4), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(rowBackground)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(rowBorder, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: check.status)
    }
    
    private var statusColor: Color {
        switch check.status {
        case .ok:      return Color(red: 0.2, green: 0.9, blue: 0.4)
        case .failed:  return .red
        case .checking: return Color(red: 1.0, green: 0.6, blue: 0.0)
        default:       return .gray
        }
    }
    
    private var rowBackground: Color {
        switch check.status {
        case .ok:     return Color(red: 0.2, green: 0.9, blue: 0.4).opacity(0.05)
        case .failed: return Color.red.opacity(0.05)
        default:      return Color(white: 0.12)
        }
    }
    
    private var rowBorder: Color {
        switch check.status {
        case .ok:     return Color(red: 0.2, green: 0.9, blue: 0.4).opacity(0.2)
        case .failed: return Color.red.opacity(0.25)
        default:      return Color(white: 0.2)
        }
    }
    
    private var fixLabel: String {
        switch check.id {
        case "ollama_running":  return "LAUNCH OLLAMA"
        case "goose_installed": return "INSTALL GOOSE"
        case "gt_installed":    return "VIEW INSTALL GUIDE"
        case let id where id.hasPrefix("model_"): return "DOWNLOAD MODEL"
        default:                return "FIX"
        }
    }
}

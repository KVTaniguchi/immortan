import SwiftUI

struct QuickChatSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var service: GastownService
    let targetAgent: AgentStatus
    
    @State private var messagePrompt = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    
    // Industrial Theme colors matching dashboard
    let neonOrange = Color(red: 1.0, green: 0.6, blue: 0.0)
    let steelGray = Color(red: 0.25, green: 0.25, blue: 0.28)
    let neonGreen = Color(red: 0.2, green: 0.9, blue: 0.4)
    let bgDark = Color(red: 0.1, green: 0.1, blue: 0.12)
    
    var body: some View {
        NavigationStack {
            ZStack {
                bgDark.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("SECURE DIRECTIVE TO: **\(targetAgent.name.uppercased())**")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(neonOrange)
                        .padding(.top)
                        .padding(.horizontal)
                    
                    if let error = errorMessage {
                        Text("FAULT: \(error)")
                            .foregroundColor(.red)
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal)
                    }
                    
                    // Quick Action Nudges
                    Text("QUICK DIRECTIVES")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    HStack(spacing: 12) {
                        PMCommandButton(title: "STATUS UPDATE", icon: "waveform", accent: .blue) {
                            sendNudge(message: "Requesting a high-level status update. What milestone are you currently tackling?")
                        }
                        PMCommandButton(title: "NUDGE TO FINISH", icon: "bolt.fill", accent: neonOrange) {
                            sendNudge(message: "Wrap up the current bead. Please commit your work and proceed to the next phase.")
                        }
                        PMCommandButton(title: "ABORT BEAD", icon: "xmark.octagon.fill", accent: .red) {
                            sendNudge(message: "ABORT CURRENT BEAD. Stop execution and await new overseer instructions.")
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider().background(steelGray)
                        .padding(.vertical, 8)
                    
                    Text("CUSTOM DIRECTIVE")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    TextEditor(text: $messagePrompt)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .background(Color(white: 0.15))
                        .cornerRadius(4)
                        .foregroundColor(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(steelGray, lineWidth: 1)
                        )
                        .frame(minHeight: 120)
                        .padding(.horizontal)
                    
                    HStack {
                        Spacer()
                        Button(action: sendChatMessage) {
                            if isSending {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.horizontal, 16)
                            } else {
                                Label("DISPATCH", systemImage: "paperplane.fill")
                                    .font(.system(.body, design: .monospaced).bold())
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(neonGreen.opacity(0.8))
                        .foregroundColor(.black)
                        .cornerRadius(4)
                        .disabled(messagePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("Command Console")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Text("CANCEL")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 450)
    }
    
    private func sendNudge(message: String) {
        $messagePrompt.wrappedValue = message
        sendChatMessage()
    }
    
    private func sendChatMessage() {
        let prompt = messagePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        
        isSending = true
        errorMessage = nil
        
        Task {
            do {
                let address = targetAgent.name == "mayor" ? "mayor/" : targetAgent.name
                try await service.sendNativeMail(to: address, message: prompt)
                dismiss()
            } catch {
                self.errorMessage = error.localizedDescription
                self.isSending = false
            }
        }
    }
}

// Custom PM Button Style
struct PMCommandButton: View {
    let title: String
    let icon: String
    let accent: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.headline)
                    .padding(.bottom, 2)
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .foregroundColor(accent)
            .background(Color(white: 0.15))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(accent.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

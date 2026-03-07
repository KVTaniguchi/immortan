import SwiftUI

// MARK: - Chat Message Model

struct ChatMessage: Identifiable, Equatable {
    enum Role: Equatable { case user, mayor }
    enum EntryType: Equatable {
        case userMessage       // sent by the overseer
        case mayorThinking     // Mayor's prose/reasoning
        case toolCall(String)  // {"name": "shell", "arguments": ...}
        case toolResult        // ⏱ duration line
    }
    
    let id = UUID()
    let role: Role
    let type: EntryType
    let text: String
    let timestamp: Date
}

// MARK: - MayorChatView

struct MayorChatView: View {
    @ObservedObject var service: GastownService
    let rigName: String
    
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isSending = false
    @State private var sendError: String? = nil
    @State private var rawTmuxLines: [String] = []
    @State private var currentDirective: String? = nil
    
    // Session state
    @State private var isSessionAlive = true
    @State private var isWakingUp = false
    
    private let pollInterval: TimeInterval = 2.5
    private let mayorSession = "hq-mayor"
    
    let bgColor     = Color(red: 0.08, green: 0.08, blue: 0.10)
    let neonGreen   = Color(red: 0.2,  green: 0.9,  blue: 0.4)
    let neonOrange  = Color(red: 1.0,  green: 0.6,  blue: 0.0)
    let steelGray   = Color(red: 0.25, green: 0.25, blue: 0.28)
    let userBubble  = Color(red: 0.15, green: 0.15, blue: 0.20)
    
    var body: some View {
        VStack(spacing: 0) {
            // Header (Inline inside the chat view)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MAYOR SESSION")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                    Text("\(mayorSession) · qwen2.5-coder:32b")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                }
                Spacer()
                Circle()
                    .fill(isSessionAlive ? neonGreen : Color.gray)
                    .frame(width: 8, height: 8)
                Text(isSessionAlive ? "LIVE" : "OFFLINE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(isSessionAlive ? neonGreen : Color.gray)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(bgColor)
            
            Divider().background(steelGray)
            
            // Standing Order banner
            if let directive = currentDirective {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundColor(neonOrange)
                        Text("CURRENT DIRECTIVE")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundColor(neonOrange)
                        Spacer()
                    }
                    Text(directive)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(neonOrange.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(neonOrange.opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            
            ZStack {
                // Scrollable Area
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            
                            // 1. Narrative Feed (Integrated into the scroll view)
                            if let town = service.townStatus {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("NARRATIVE FEED & ALERTS")
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                        .foregroundColor(.gray)
                                    
                                    if let events = town.events, !events.isEmpty {
                                        ForEach(events) { event in
                                            NarrativeRow(text: event.narrativeText, color: neonOrange, steelGray: steelGray)
                                        }
                                    } else {
                                        NarrativeRow(text: "The Town is quiet. Awaiting Overseer directives.", color: neonGreen, steelGray: steelGray, isFallback: true)
                                    }
                                }
                                .padding(.top, 16)
                            }
                            
                            Divider().background(steelGray)
                            
                            // 2. Message stream
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(messages) { msg in
                                    MessageRow(msg: msg,
                                               neonGreen: neonGreen,
                                               neonOrange: neonOrange,
                                               steelGray: steelGray,
                                               userBubble: userBubble)
                                }
                                // Anchor to scroll to bottom
                                Color.clear.frame(height: 1).id("bottom")
                            }
                            .opacity(isSessionAlive ? 1.0 : 0.3)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .onChange(of: messages.count) { _ in
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }
                
                // Asleep Overlay
                if !isSessionAlive {
                    VStack(spacing: 16) {
                        Text("MAYOR IS ASLEEP")
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Text("The session for this rig is currently inactive.")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button(action: wakeUpMayor) {
                            if isWakingUp {
                                HStack {
                                    ProgressView().controlSize(.small)
                                    Text("WAKING UP...")
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(steelGray)
                                .foregroundColor(.white)
                            } else {
                                Text("WAKE UP MAYOR")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(neonOrange)
                                    .foregroundColor(.black)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isWakingUp)
                    }
                    .padding(32)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(neonOrange.opacity(0.5), lineWidth: 1))
                }
            }
            
            Divider().background(steelGray)
            
            // Error
            if let err = sendError {
                Text("⚠ \(err)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.red)
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
            }
            
            // Input area — Pinned to bottom
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Message the Mayor...", text: $inputText, axis: .vertical)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(4...10)
                    .padding(12)
                    .background(Color(white: 0.16))
                    .cornerRadius(6)
                    .foregroundColor(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(neonOrange.opacity(0.35), lineWidth: 1)
                    )
                    .disabled(!isSessionAlive)
                    .onKeyPress(.return) {
                        if !NSEvent.modifierFlags.contains(.shift) {
                            sendMessage()
                            return .handled
                        }
                        return .ignored
                    }
                
                Button(action: sendMessage) {
                    if isSending {
                        ProgressView().controlSize(.small).frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor((inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isSessionAlive) ? steelGray : neonGreen)
                    }
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending || !isSessionAlive)
                .padding(.bottom, 4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                bgColor
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(steelGray.opacity(0.9))
                            .frame(height: 1)
                    }
                    .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: -2)
            )

        }
        .background(bgColor)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 6)
        }
        .task {
            await loadMailHistory()
            await startPolling()
        }
    }
    
    // MARK: - Actions
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        let msg = ChatMessage(role: .user, type: .userMessage, text: text, timestamp: Date())
        messages.append(msg)
        currentDirective = text
        inputText = ""
        isSending = true
        sendError = nil
        
        Task {
            do {
                try await service.sendNativeMail(to: "mayor/", message: text)
                isSending = false
            } catch {
                sendError = error.localizedDescription
                isSending = false
            }
        }
    }
    
    private func wakeUpMayor() {
        isWakingUp = true
        Task {
            do {
                try await service.startMayor(inRig: rigName)
                try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                await fetchTmuxOutput()
                isWakingUp = false
            } catch {
                sendError = "Failed to wake Mayor: \(error.localizedDescription)"
                isWakingUp = false
            }
        }
    }
    
    // MARK: - Polling
    
    private func startPolling() async {
        while true {
            await fetchTmuxOutput()
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
    }
    
    private func fetchTmuxOutput() async {
        do {
            let tmuxPath: String
            if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/tmux") {
                tmuxPath = "/opt/homebrew/bin/tmux"
            } else if FileManager.default.fileExists(atPath: "/usr/local/bin/tmux") {
                tmuxPath = "/usr/local/bin/tmux"
            } else {
                tmuxPath = "/usr/bin/tmux"
            }

            let statusResult = try await service.runner.runCommand(
                executable: URL(fileURLWithPath: tmuxPath),
                arguments: ["has-session", "-t", mayorSession],
                currentDirectory: URL(fileURLWithPath: NSHomeDirectory())
            )
            
            let alive = statusResult.status == 0
            if alive != isSessionAlive {
                await MainActor.run { self.isSessionAlive = alive }
            }
            
            if !alive { return }

            let result = try await service.runner.runCommand(
                executable: URL(fileURLWithPath: tmuxPath),
                arguments: ["capture-pane", "-pt", mayorSession, "-S", "-200"],
                currentDirectory: URL(fileURLWithPath: NSHomeDirectory())
            )
            let raw = String(data: result.output, encoding: .utf8) ?? ""
            let newLines = raw.components(separatedBy: "\n")
            
            if newLines != rawTmuxLines {
                rawTmuxLines = newLines
                let parsed = parseTmuxLines(newLines)
                let userMessages = messages.filter { $0.role == .user }
                let allMessages = (userMessages + parsed).sorted { $0.timestamp < $1.timestamp }
                await MainActor.run { self.messages = allMessages }
            }
        } catch {
            if isSessionAlive {
                await MainActor.run { self.isSessionAlive = false }
            }
        }
    }
    
    private func loadMailHistory() async {
        do {
            let result = try await service.runner.runCommand(
                executable: URL(fileURLWithPath: "/opt/homebrew/bin/gt"),
                arguments: ["mail", "inbox", "mayor/", "--json"],
                currentDirectory: URL(fileURLWithPath: NSHomeDirectory())
            )
            if let data = Optional(result.output),
               let mails = try? JSONDecoder().decode([MailMessage].self, from: data) {
                let userMsgs = mails.reversed().map { mail in
                    ChatMessage(role: .user,
                                type: .userMessage,
                                text: mail.body,
                                timestamp: ISO8601DateFormatter().date(from: mail.timestamp) ?? Date())
                }
                await MainActor.run {
                    self.messages = userMsgs
                    // Restore the latest directive from mail history
                    if let lastMsg = userMsgs.last {
                        self.currentDirective = lastMsg.text
                    }
                }
            }
        } catch {}
        await fetchTmuxOutput()
    }
    
    private func parseTmuxLines(_ lines: [String]) -> [ChatMessage] {
        var results: [ChatMessage] = []
        var currentText = ""
        var currentType: ChatMessage.EntryType = .mayorThinking
        var lineIndex = 0
        let baseDate = Date().addingTimeInterval(-Double(lines.count) * 0.1)
        
        func flush() {
            let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                results.append(ChatMessage(
                    role: .mayor,
                    type: currentType,
                    text: trimmed,
                    timestamp: baseDate.addingTimeInterval(Double(lineIndex) * 0.1)
                ))
            }
            currentText = ""
            currentType = .mayorThinking
        }
        
        for line in lines {
            let stripped = stripAnsi(line)
            if stripped.hasPrefix("{\"name\"") || stripped.hasPrefix("{ \"name\"") {
                flush()
                let name = stripped
                    .components(separatedBy: "\"name\": \"").dropFirst().first?
                    .components(separatedBy: "\"").first ?? "tool"
                currentType = .toolCall(name)
                currentText = stripped
                flush()
                continue
            }
            if stripped.contains("⏱") {
                flush()
                currentType = .toolResult
                currentText = stripped
                flush()
                continue
            }
            if stripped.hasPrefix("🪿") || stripped.hasPrefix("━") ||
               stripped.hasPrefix("╌") || stripped.hasPrefix("◓") ||
               stripped.contains("keep me updated") || stripped.isEmpty {
                continue
            }
            if stripped.contains("new session") || stripped.contains("goose is ready") ||
               stripped.contains("Enter to send") || stripped.contains("Ctrl+J") {
                continue
            }
            currentText += (currentText.isEmpty ? "" : "\n") + stripped
            lineIndex += 1
        }
        flush()
        return results
    }
    
    private func stripAnsi(_ str: String) -> String {
        var result = str
        let pattern = "\u{1B}\\[[0-9;]*[a-zA-Z]"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        return result
    }
}

// MARK: - Narrative Helpers

struct NarrativeRow: View {
    let text: String
    let color: Color
    let steelGray: Color
    var isFallback: Bool = false
    
    var body: some View {
        HStack {
            Text(">")
                .foregroundColor(color)
                .font(.system(.body, design: .monospaced))
            Text(text)
                .foregroundColor(isFallback ? .gray : .white)
                .font(.system(.body, design: .monospaced))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(steelGray.opacity(0.3))
        .border(steelGray, width: 1)
    }
}

// MARK: - Mail Decodable

private struct MailMessage: Decodable {
    let id: String
    let from: String
    let body: String
    let timestamp: String
}

// MARK: - MessageRow

struct MessageRow: View {
    let msg: ChatMessage
    let neonGreen: Color
    let neonOrange: Color
    let steelGray: Color
    let userBubble: Color
    
    var body: some View {
        Group {
            switch msg.type {
            case .userMessage:
                userMessageView
            case .toolCall(let name):
                toolCallView(name: name)
            case .toolResult:
                toolResultView
            case .mayorThinking:
                mayorTextView
            }
        }
    }
    
    private var userMessageView: some View {
        HStack {
            Spacer(minLength: 60)
            Text(msg.text)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(red: 0.2, green: 0.35, blue: 0.55))
                .cornerRadius(12)
                .cornerRadius(3, corners: .topRight)
        }
    }
    
    private var mayorTextView: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("M")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundColor(.black)
                .frame(width: 20, height: 20)
                .background(neonOrange)
                .clipShape(Circle())
                .padding(.top, 2)
            
            Text(msg.text)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(Color(white: 0.88))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 20)
        }
    }
    
    private func toolCallView(name: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 11))
                .foregroundColor(.gray)
                .padding(.top, 3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("▶ \(name.uppercased())")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(neonGreen.opacity(0.7))
                Text(msg.text)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(white: 0.5))
                    .lineLimit(3)
            }
        }
        .padding(10)
        .background(Color(white: 0.09))
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(neonGreen.opacity(0.15), lineWidth: 1))
    }
    
    private var toolResultView: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(steelGray.opacity(0.5))
                .frame(width: 20, height: 1)
            Text(msg.text)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.gray)
            Spacer()
        }
        .padding(.leading, 30)
    }
}

// MARK: - Corner Radius helper

extension View {
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

enum RectCorner { case topRight, topLeft, bottomRight, bottomLeft }

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: RectCorner
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(radius, rect.width/2, rect.height/2)
        switch corners {
        case .topRight:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
            path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r),
                        radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        default:
            path.addRect(rect)
        }
        path.closeSubpath()
        return path
    }
}

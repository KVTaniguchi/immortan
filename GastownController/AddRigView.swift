import SwiftUI
import AppKit

struct AddRigView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var service: GastownService
    
    enum SourceType: String, CaseIterable, Identifiable {
        case newProject = "New Project"
        case importExisting = "Import Folder"
        case gitClone = "Clone Git Repo"
        var id: String { self.rawValue }
    }
    
    @State private var rigName = ""
    @State private var gitUrl = ""
    @State private var sourceType: SourceType = .newProject
    @State private var projectRootURL: URL = FileManager.default.homeDirectoryForCurrentUser
    @State private var existingProjectURL: URL = FileManager.default.homeDirectoryForCurrentUser
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Project Genesis")) {
                    Picker("Source", selection: $sourceType) {
                        ForEach(SourceType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 8)
                    
                    TextField("Project/Rig Name", text: $rigName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    if sourceType == .newProject {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Project Location")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(projectRootURL.path)
                                    .font(.caption.monospaced())
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Button("Choose...") {
                                chooseProjectLocation()
                            }
                        }
                    }

                    if sourceType == .importExisting {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Existing Project Folder")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(existingProjectURL.path)
                                    .font(.caption.monospaced())
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Button("Choose...") {
                                chooseExistingProjectFolder()
                            }
                        }
                    }
                    
                    if sourceType == .gitClone {
                        TextField("Git Repository URL", text: $gitUrl)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disableAutocorrection(true)
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                Section {
                    Button(action: submitRig) {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Add Rig")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(rigName.isEmpty || (sourceType == .gitClone && gitUrl.isEmpty) || isSubmitting)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("Initialize New Rig")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 250)
    }
    
    private func submitRig() {
        let safeName = rigName.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: ".", with: "_")
            
        guard !safeName.isEmpty else { return }
        
        if sourceType == .gitClone && gitUrl.isEmpty {
            self.errorMessage = "Git URL required for remote cloning."
            return
        }
        
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                if sourceType == .newProject {
                    try await service.createEmptyProject(name: safeName, parentDirectory: projectRootURL)
                } else if sourceType == .importExisting {
                    try await service.adoptExistingProject(name: safeName, projectDirectory: existingProjectURL)
                } else {
                    try await service.addRig(name: safeName, url: gitUrl)
                }
                dismiss() // Close on success
            } catch {
                self.errorMessage = error.localizedDescription
                self.isSubmitting = false
            }
        }
    }

    private func chooseProjectLocation() {
        let panel = NSOpenPanel()
        panel.title = "Select New Project Location"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = projectRootURL

        if panel.runModal() == .OK, let url = panel.url {
            projectRootURL = url
        }
    }

    private func chooseExistingProjectFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Existing Project Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = existingProjectURL

        if panel.runModal() == .OK, let url = panel.url {
            existingProjectURL = url
            if rigName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                rigName = url.lastPathComponent
            }
        }
    }
}

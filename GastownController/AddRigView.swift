import SwiftUI

struct AddRigView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var service: GastownService
    
    @State private var rigName = ""
    @State private var gitUrl = ""
    @State private var isLocalOnly = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Project Genesis")) {
                    TextField("Project/Rig Name", text: $rigName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Toggle("Create new empty project locally", isOn: $isLocalOnly)
                    
                    if !isLocalOnly {
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
                    .disabled(rigName.isEmpty || (!isLocalOnly && gitUrl.isEmpty) || isSubmitting)
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
        
        if !isLocalOnly && gitUrl.isEmpty {
            self.errorMessage = "Git URL required for remote cloning."
            return
        }
        
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                if isLocalOnly {
                    try await service.createEmptyProject(name: safeName)
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
}


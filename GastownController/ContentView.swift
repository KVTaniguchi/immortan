import SwiftUI

struct ContentView: View {
    @StateObject private var service = GastownService()
    @State private var selectedItem: SidebarItem? = .overview
    @State private var showingAddRig = false
    
    enum SidebarItem: Hashable {
        case overview
        case rig(String)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                Section("Dashboard") {
                    NavigationLink(value: SidebarItem.overview) {
                        Label("Command Center", systemImage: "building.2.crop.circle")
                    }
                }
                
                if let rigs = service.townStatus?.rigs, !rigs.isEmpty {
                    Section("Projects") {
                        ForEach(rigs) { rig in
                            NavigationLink(value: SidebarItem.rig(rig.name)) {
                                Label(rig.name, systemImage: "folder.fill")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Gastown")
            .listStyle(.sidebar)
            
        } detail: {
            switch selectedItem {
            case .overview, .none:
                CommandCenterView(service: service, selection: $selectedItem)
            case .rig(let rigName):
                if let rig = service.townStatus?.rigs?.first(where: { $0.name == rigName }) {
                    RigDetailView(rig: rig, service: service)
                } else {
                    Text("Rig not found.")
                }
            }
        }
        .onAppear {
            service.startPolling()
            Task { await service.ensureOllamaServerRunning() }
        }
        .onDisappear {
            service.stopPolling()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddRig = true }) {
                    Label("Add Rig", systemImage: "plus")
                }
                .help("Add a New Gastown Rig")
            }
        }
        .sheet(isPresented: $showingAddRig) {
            AddRigView(service: service)
        }
    }
}

#Preview {
    ContentView()
}

import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        NavigationSplitView {
            List(selection: $state.section) {
                ForEach(SidebarSection.allCases) { section in
                    Label(section.title, systemImage: section.symbol)
                        .tag(section)
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210)
        } detail: {
            switch state.section ?? .dashboard {
            case .dashboard: DashboardView()
            case .junk: JunkView()
            case .largeFiles: LargeFilesView()
            case .uninstaller: UninstallerView()
            case .startup: StartupView()
            case .security: SecurityView()
            }
        }
    }
}

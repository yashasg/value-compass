import SwiftUI

/// Adaptive root for post-onboarding usage. `NavigationSplitView` provides
/// the iPad-native sidebar layout automatically and collapses to a stack on
/// iPhone — satisfying the "iPhone and iPad layouts" spec requirement
/// without needing two separate view trees.
struct MainView: View {
    enum Section: String, Hashable, CaseIterable, Identifiable {
        case dashboard = "Dashboard"
        case settings = "Settings"
        var id: String { rawValue }
    }

    @State private var selection: Section? = .dashboard

    var body: some View {
        NavigationSplitView {
            List(Section.allCases, selection: $selection) { section in
                NavigationLink(value: section) {
                    Label(section.rawValue, systemImage: icon(for: section))
                }
            }
            .navigationTitle("Value Compass")
        } detail: {
            switch selection ?? .dashboard {
            case .dashboard:
                DashboardView()
            case .settings:
                SettingsView()
            }
        }
    }

    private func icon(for section: Section) -> String {
        switch section {
        case .dashboard: return "chart.line.uptrend.xyaxis"
        case .settings:  return "gear"
        }
    }
}

/// Placeholder dashboard. Real content lands once the OpenAPI-generated
/// client is wired up to the backend's quote/portfolio endpoints.
struct DashboardView: View {
    var body: some View {
        ContentUnavailableView(
            "No Data Yet",
            systemImage: "chart.line.uptrend.xyaxis",
            description: Text("Pull-to-refresh once the backend is reachable.")
        )
        .navigationTitle("Dashboard")
    }
}

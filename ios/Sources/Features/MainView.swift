import SwiftUI

/// Adaptive root for post-onboarding usage. Compact widths use a
/// `NavigationStack`; regular widths use an iPad-native `NavigationSplitView`.
struct MainView: View {
    enum NavigationShellKind {
        case stack
        case splitView
    }

    enum Section: String, Hashable, CaseIterable, Identifiable {
        case dashboard = "Dashboard"
        case settings = "Settings"
        var id: String { rawValue }
    }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selection: Section? = .dashboard

    var body: some View {
        switch Self.navigationShellKind(for: horizontalSizeClass) {
        case .stack:
            NavigationStack {
                List(Section.allCases) { section in
                    NavigationLink(value: section) {
                        Label(section.rawValue, systemImage: icon(for: section))
                    }
                }
                .navigationTitle("Value Compass")
                .navigationDestination(for: Section.self) { section in
                    destination(for: section)
                }
            }
        case .splitView:
            splitView
        }
    }

    static func navigationShellKind(for horizontalSizeClass: UserInterfaceSizeClass?) -> NavigationShellKind {
        horizontalSizeClass == .compact ? .stack : .splitView
    }

    private var splitView: some View {
        NavigationSplitView {
            List(Section.allCases, selection: $selection) { section in
                NavigationLink(value: section) {
                    Label(section.rawValue, systemImage: icon(for: section))
                }
            }
            .navigationTitle("Value Compass")
        } detail: {
            destination(for: selection ?? .dashboard)
        }
    }

    @ViewBuilder
    private func destination(for section: Section) -> some View {
        switch section {
        case .dashboard:
            DashboardView()
        case .settings:
            SettingsView()
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

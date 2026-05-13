import SwiftData
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
        PortfolioListView()
    }
}

enum PortfolioEditorValidationError: LocalizedError, Equatable {
    case emptyName
    case invalidBudget
    case invalidMAWindow(Int)

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Portfolio name is required."
        case .invalidBudget:
            return "Monthly budget must be greater than 0."
        case .invalidMAWindow:
            return "Moving average window must be 50 or 200 days."
        }
    }
}

struct PortfolioEditorValues: Equatable {
    let name: String
    let monthlyBudget: Decimal
    let maWindow: Int
}

struct PortfolioFormDraft: Equatable {
    var name: String = ""
    var monthlyBudgetText: String = ""
    var maWindow: Int = Portfolio.allowedMAWindows[0]

    init(name: String = "", monthlyBudgetText: String = "", maWindow: Int = Portfolio.allowedMAWindows[0]) {
        self.name = name
        self.monthlyBudgetText = monthlyBudgetText
        self.maWindow = maWindow
    }

    init(portfolio: Portfolio) {
        self.name = portfolio.name
        self.monthlyBudgetText = Self.displayText(for: portfolio.monthlyBudget)
        self.maWindow = portfolio.maWindow
    }

    func validatedValues() throws -> PortfolioEditorValues {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw PortfolioEditorValidationError.emptyName
        }

        guard
            let budget = Decimal(string: monthlyBudgetText.trimmingCharacters(in: .whitespacesAndNewlines)),
            budget > 0
        else {
            throw PortfolioEditorValidationError.invalidBudget
        }

        guard Portfolio.allowedMAWindows.contains(maWindow) else {
            throw PortfolioEditorValidationError.invalidMAWindow(maWindow)
        }

        return PortfolioEditorValues(name: trimmedName, monthlyBudget: budget, maWindow: maWindow)
    }

    func makePortfolio() throws -> Portfolio {
        let values = try validatedValues()
        return Portfolio(name: values.name, monthlyBudget: values.monthlyBudget, maWindow: values.maWindow)
    }

    func apply(to portfolio: Portfolio) throws {
        let values = try validatedValues()
        portfolio.name = values.name
        portfolio.monthlyBudget = values.monthlyBudget
        portfolio.maWindow = values.maWindow
    }

    static func displayText(for amount: Decimal) -> String {
        NSDecimalNumber(decimal: amount).stringValue
    }
}

struct PortfolioListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Portfolio.createdAt, order: .reverse) private var portfolios: [Portfolio]
    @State private var editorMode: PortfolioEditorMode?
    @State private var saveError: SaveError?

    var body: some View {
        Group {
            if portfolios.isEmpty {
                ContentUnavailableView {
                    Label("No Portfolios Yet", systemImage: "folder.badge.plus")
                } description: {
                    Text("Create a local portfolio to start planning offline.")
                } actions: {
                    Button("Create Portfolio") {
                        editorMode = .create
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("portfolio.empty.create")
                }
            } else {
                List {
                    ForEach(portfolios) { portfolio in
                        NavigationLink {
                            PortfolioDetailView(portfolio: portfolio)
                        } label: {
                            PortfolioRowView(portfolio: portfolio)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) {
                                delete(portfolio)
                            }

                            Button("Edit") {
                                editorMode = .edit(portfolio)
                            }
                            .tint(.blue)
                        }
                    }
                    .onDelete(perform: delete)
                }
                .accessibilityIdentifier("portfolio.list")
            }
        }
        .navigationTitle("Portfolios")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editorMode = .create
                } label: {
                    Label("Create Portfolio", systemImage: "plus")
                }
                .accessibilityIdentifier("portfolio.create")
            }
        }
        .sheet(item: $editorMode) { mode in
            PortfolioEditorView(mode: mode) { draft in
                try save(mode: mode, draft: draft)
            }
        }
        .alert(item: $saveError) { error in
            Alert(
                title: Text("Could Not Save Portfolio"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func save(mode: PortfolioEditorMode, draft: PortfolioFormDraft) throws {
        switch mode {
        case .create:
            modelContext.insert(try draft.makePortfolio())
        case .edit(let portfolio):
            try draft.apply(to: portfolio)
        }

        try modelContext.save()
    }

    private func delete(_ portfolio: Portfolio) {
        modelContext.delete(portfolio)
        do {
            try modelContext.save()
        } catch {
            saveError = SaveError(message: error.localizedDescription)
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            delete(portfolios[index])
        }
    }
}

struct PortfolioRowView: View {
    let portfolio: Portfolio

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(portfolio.name)
                .font(.headline)

            HStack {
                Label("$\(PortfolioFormDraft.displayText(for: portfolio.monthlyBudget))/mo", systemImage: "dollarsign.circle")
                Label("\(portfolio.maWindow)-day MA", systemImage: "chart.line.uptrend.xyaxis")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

enum PortfolioEditorMode: Identifiable {
    case create
    case edit(Portfolio)

    var id: String {
        switch self {
        case .create:
            return "create"
        case .edit(let portfolio):
            return portfolio.id.uuidString
        }
    }

    var title: String {
        switch self {
        case .create:
            return "Create Portfolio"
        case .edit:
            return "Edit Portfolio"
        }
    }

    var initialDraft: PortfolioFormDraft {
        switch self {
        case .create:
            return PortfolioFormDraft()
        case .edit(let portfolio):
            return PortfolioFormDraft(portfolio: portfolio)
        }
    }
}

struct PortfolioEditorView: View {
    let mode: PortfolioEditorMode
    let onSave: (PortfolioFormDraft) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: PortfolioFormDraft
    @State private var validationError: PortfolioEditorValidationError?
    @State private var saveError: SaveError?

    init(mode: PortfolioEditorMode, onSave: @escaping (PortfolioFormDraft) throws -> Void) {
        self.mode = mode
        self.onSave = onSave
        _draft = State(initialValue: mode.initialDraft)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Portfolio") {
                    TextField("Name", text: $draft.name)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("portfolio.editor.name")

                    TextField("Monthly budget", text: $draft.monthlyBudgetText)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("portfolio.editor.budget")
                }

                Section("Moving Average") {
                    Picker("Window", selection: $draft.maWindow) {
                        ForEach(Portfolio.allowedMAWindows, id: \.self) { window in
                            Text("\(window) days").tag(window)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("portfolio.editor.maWindow")
                }

                if let validationError {
                    Text(validationError.localizedDescription)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("portfolio.editor.validationError")
                }
            }
            .navigationTitle(mode.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .accessibilityIdentifier("portfolio.editor.save")
                }
            }
            .alert(item: $saveError) { error in
                Alert(
                    title: Text("Could Not Save Portfolio"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private func save() {
        do {
            _ = try draft.validatedValues()
            validationError = nil
            try onSave(draft)
            dismiss()
        } catch let error as PortfolioEditorValidationError {
            validationError = error
        } catch {
            saveError = SaveError(message: error.localizedDescription)
        }
    }
}

struct PortfolioDetailView: View {
    let portfolio: Portfolio

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summarySection
                placeholderSection(
                    title: "Holdings Editor",
                    systemImage: "list.bullet.rectangle",
                    message: "Category and ticker editing lands in the next MVP slice."
                )
                placeholderSection(
                    title: "Calculate",
                    systemImage: "function",
                    message: "The calculator seam will use this portfolio once market data input is available."
                )
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(portfolio.name)
        .accessibilityIdentifier("portfolio.detail")
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.title2.bold())

            LabeledContent("Monthly Budget", value: "$\(PortfolioFormDraft.displayText(for: portfolio.monthlyBudget))")
            LabeledContent("Moving Average", value: "\(portfolio.maWindow) days")
            LabeledContent("Categories", value: "\(portfolio.categories.count)")
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func placeholderSection(title: String, systemImage: String, message: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct SaveError: Identifiable {
    let id = UUID()
    let message: String
}

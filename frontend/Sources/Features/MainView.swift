import SwiftData
import SwiftUI

/// Adaptive root for post-onboarding usage. Compact widths use a
/// `NavigationStack`; regular widths use an iPad-native `NavigationSplitView`.
struct MainView: View {
  enum NavigationShellKind {
    case stack
    case splitView
  }

  enum SidebarSelection: String, Hashable, CaseIterable, Identifiable {
    case portfolios = "Portfolios"
    case settings = "Settings"
    var id: String { rawValue }
  }

  enum DetailSelection: Equatable {
    case portfolio(UUID)
    case settings
    case emptyPortfolioSelection
  }

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Query(sort: \Portfolio.createdAt, order: .reverse) private var portfolios: [Portfolio]
  @State private var sidebarSelection: SidebarSelection? = .portfolios
  @State private var selectedPortfolioID: UUID?

  var body: some View {
    switch Self.navigationShellKind(for: horizontalSizeClass) {
    case .stack:
      NavigationStack {
        PortfolioListView(showsSettingsLink: true)
      }
    case .splitView:
      splitView
    }
  }

  static func navigationShellKind(for horizontalSizeClass: UserInterfaceSizeClass?)
    -> NavigationShellKind
  {
    horizontalSizeClass == .compact ? .stack : .splitView
  }

  private var splitView: some View {
    NavigationSplitView {
      List(selection: $sidebarSelection) {
        AppBrandSidebarHeader()

        ForEach(SidebarSelection.allCases) { section in
          NavigationLink(value: section) {
            Label(section.rawValue, systemImage: icon(for: section))
          }
        }
      }
      .navigationTitle(AppBrand.displayName)
      .navigationSplitViewColumnWidth(
        min: AppLayoutMetrics.sidebarMinWidth,
        ideal: AppLayoutMetrics.sidebarIdealWidth,
        max: AppLayoutMetrics.sidebarMaxWidth)
    } content: {
      switch sidebarSelection ?? .portfolios {
      case .portfolios:
        PortfolioListView(selectedPortfolioID: $selectedPortfolioID, showsSettingsLink: false)
          .navigationSplitViewColumnWidth(
            min: AppLayoutMetrics.sidebarMinWidth,
            ideal: AppLayoutMetrics.sidebarIdealWidth,
            max: AppLayoutMetrics.sidebarMaxWidth)
      case .settings:
        SettingsView()
      }
    } detail: {
      detailView(
        for: Self.detailSelection(
          sidebarSelection: sidebarSelection,
          selectedPortfolioID: selectedPortfolioID,
          firstPortfolioID: portfolios.first?.id))
    }
  }

  @ViewBuilder
  private func detailView(for detailSelection: DetailSelection) -> some View {
    switch detailSelection {
    case .portfolio(let id):
      if let portfolio = portfolios.first(where: { $0.id == id }) {
        PortfolioDetailView(portfolio: portfolio)
      } else {
        emptyPortfolioSelectionView
      }
    case .settings:
      SettingsView()
    case .emptyPortfolioSelection:
      emptyPortfolioSelectionView
    }
  }

  private var emptyPortfolioSelectionView: some View {
    ContentUnavailableView {
      Label("Select a Portfolio", systemImage: "sidebar.leading")
    } description: {
      Text("Choose or create a portfolio from the list.")
    }
    .navigationTitle("Portfolio")
  }

  static func detailSelection(
    sidebarSelection: SidebarSelection?,
    selectedPortfolioID: UUID?,
    firstPortfolioID: UUID?
  ) -> DetailSelection {
    if sidebarSelection == .settings {
      return .settings
    }

    if let selectedPortfolioID {
      return .portfolio(selectedPortfolioID)
    }

    if let firstPortfolioID {
      return .portfolio(firstPortfolioID)
    }

    return .emptyPortfolioSelection
  }

  private func icon(for section: SidebarSelection) -> String {
    switch section {
    case .portfolios: return "chart.line.uptrend.xyaxis"
    case .settings: return "gear"
    }
  }
}

private struct AppBrandSidebarHeader: View {
  var body: some View {
    AppBrandHeader(logoSize: 44, subtitle: nil)
      .padding(.vertical, 8)
      .listRowSeparator(.hidden)
      .accessibilityIdentifier("app.brand.header")
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

  init(
    name: String = "", monthlyBudgetText: String = "", maWindow: Int = Portfolio.allowedMAWindows[0]
  ) {
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
      let budget = Decimal(
        string: monthlyBudgetText.trimmingCharacters(in: .whitespacesAndNewlines)),
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
    return Portfolio(
      name: values.name, monthlyBudget: values.monthlyBudget, maWindow: values.maWindow)
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
  private let selectedPortfolioID: Binding<UUID?>?
  private let showsSettingsLink: Bool

  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Portfolio.createdAt, order: .reverse) private var portfolios: [Portfolio]
  @State private var editorMode: PortfolioEditorMode?
  @State private var saveError: SaveError?

  init(selectedPortfolioID: Binding<UUID?>? = nil, showsSettingsLink: Bool = true) {
    self.selectedPortfolioID = selectedPortfolioID
    self.showsSettingsLink = showsSettingsLink
  }

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
            portfolioRow(for: portfolio)
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

      if showsSettingsLink {
        ToolbarItem(placement: .secondaryAction) {
          NavigationLink {
            SettingsView()
          } label: {
            Label("Settings", systemImage: "gear")
          }
          .accessibilityIdentifier("portfolio.settings")
        }
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

  @ViewBuilder
  private func portfolioRow(for portfolio: Portfolio) -> some View {
    if let selectedPortfolioID {
      Button {
        selectedPortfolioID.wrappedValue = portfolio.id
      } label: {
        HStack {
          PortfolioRowView(portfolio: portfolio)
          Spacer()
          if selectedPortfolioID.wrappedValue == portfolio.id {
            Image(systemName: "checkmark.circle.fill")
              .foregroundStyle(Color.appPrimary)
              .accessibilityHidden(true)
          }
        }
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("portfolio.list.selection")
      .accessibilityAddTraits(selectedPortfolioID.wrappedValue == portfolio.id ? .isSelected : [])
    } else {
      NavigationLink {
        PortfolioDetailView(portfolio: portfolio)
      } label: {
        PortfolioRowView(portfolio: portfolio)
      }
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
        .valueCompassTextStyle(.headlineMedium)

      HStack {
        Label(
          "$\(PortfolioFormDraft.displayText(for: portfolio.monthlyBudget))/mo",
          systemImage: "dollarsign.circle")
        Label("\(portfolio.maWindow)-day MA", systemImage: "chart.line.uptrend.xyaxis")
      }
      .valueCompassTextStyle(.labelCaps)
      .foregroundStyle(Color.appContentSecondary)
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
            .foregroundStyle(Color.appError)
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
  let calculator: any ContributionCalculating

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var calculationOutput: ContributionOutput?
  @State private var isShowingResult = false

  init(
    portfolio: Portfolio,
    calculator: any ContributionCalculating = MovingAverageContributionCalculator()
  ) {
    self.portfolio = portfolio
    self.calculator = calculator
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        summarySection
        holdingsSection
        calculateSection
      }
      .padding(AppLayoutMetrics.mainMargin)
      .frame(maxWidth: AppLayoutMetrics.readableContentMaxWidth, alignment: .leading)
      .frame(maxWidth: .infinity, alignment: .center)
    }
    .navigationTitle(portfolio.name)
    .navigationDestination(isPresented: $isShowingResult) {
      if let calculationOutput {
        ContributionResultView(portfolio: portfolio, initialOutput: calculationOutput) {
          ContributionCalculationService.calculate(portfolio: portfolio, calculator: calculator)
        }
      }
    }
    .accessibilityIdentifier("portfolio.detail")
  }

  private var summarySection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Summary")
        .valueCompassTextStyle(.headlineMedium)
        .foregroundStyle(Color.appContentPrimary)

      LabeledContent(
        "Monthly Budget", value: "$\(PortfolioFormDraft.displayText(for: portfolio.monthlyBudget))"
      )
      .valueCompassTextStyle(.data)
      LabeledContent("Moving Average", value: "\(portfolio.maWindow) days")
        .valueCompassTextStyle(.data)
      LabeledContent("Categories", value: "\(portfolio.categories.count)")
        .valueCompassTextStyle(.data)
      LabeledContent("Market Data", value: marketDataCompletionText)
        .valueCompassTextStyle(.data)
    }
    .padding()
    .background(Color.appSurfaceElevated, in: RoundedRectangle(cornerRadius: 16))
  }

  private var marketDataCompletionText: String {
    let tickers = portfolio.categories.flatMap(\.tickers)
    let completeCount = tickers.filter { $0.currentPrice != nil && $0.movingAverage != nil }.count
    let incompleteCount = tickers.count - completeCount
    return "\(completeCount) complete / \(incompleteCount) incomplete"
  }

  private var holdingsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Holdings")
          .valueCompassTextStyle(.headlineMedium)
          .foregroundStyle(Color.appContentPrimary)

        Spacer()

        NavigationLink {
          HoldingsEditorView(portfolio: portfolio)
        } label: {
          Label("Edit Holdings", systemImage: "list.bullet.rectangle")
        }
        .buttonStyle(.borderedProminent)
        .appMinimumTouchTarget()
        .accessibilityIdentifier("portfolio.detail.editHoldings")
      }

      let draft = HoldingsDraft(portfolio: portfolio)
      if draft.categories.isEmpty {
        Text("No categories yet. Add categories and tickers before calculating.")
          .foregroundStyle(Color.appContentSecondary)
      } else {
        ForEach(draft.categories, id: \.id) { (category: CategoryDraft) in
          VStack(alignment: .leading, spacing: 6) {
            HStack {
              Text(category.displayName)
                .valueCompassTextStyle(.bodyLarge)
                .foregroundStyle(Color.appContentPrimary)
              Spacer()
              Text("\(category.weightPercentText)%")
                .valueCompassTextStyle(.data)
                .foregroundStyle(Color.appContentSecondary)
            }

            if category.tickers.isEmpty {
              Label("Warning: no tickers", systemImage: "exclamationmark.circle")
                .valueCompassTextStyle(.labelCaps)
                .foregroundStyle(Color.appNegative)
                .accessibilityIdentifier("portfolio.detail.holdings.warning")
            } else {
              if horizontalSizeClass == .regular {
                tickerTableHeader
              }

              ForEach(category.tickers, id: \.id) { (ticker: TickerDraft) in
                tickerMarketDataRow(for: ticker)
              }
            }
          }
        }

        if !draft.canCalculate() {
          Label(
            "Warnings must be resolved before calculating.", systemImage: "exclamationmark.triangle"
          )
          .foregroundStyle(Color.appNegative)
          .accessibilityIdentifier("portfolio.detail.calculateBlocked")
        }
      }
    }
    .padding()
    .background(Color.appSurfaceElevated, in: RoundedRectangle(cornerRadius: 16))
  }

  private var tickerTableHeader: some View {
    HStack(spacing: AppLayoutMetrics.gridGutter) {
      Text("Ticker")
        .frame(width: 80, alignment: .leading)
      Text("Current Price")
        .frame(maxWidth: .infinity, alignment: .trailing)
      Text("\(portfolio.maWindow)-day MA")
        .frame(maxWidth: .infinity, alignment: .trailing)
      Text("Status")
        .frame(width: 88, alignment: .trailing)
    }
    .valueCompassTextStyle(.labelCaps)
    .foregroundStyle(Color.appContentSecondary)
  }

  @ViewBuilder
  private func tickerMarketDataRow(for ticker: TickerDraft) -> some View {
    if horizontalSizeClass == .regular {
      HStack(spacing: AppLayoutMetrics.gridGutter) {
        Text(ticker.normalizedSymbol)
          .valueCompassTextStyle(.labelCaps)
          .foregroundStyle(Color.appContentPrimary)
          .frame(width: 80, alignment: .leading)
        Text(TickerDraft.displayDecimalText(for: ticker.currentPrice))
          .valueCompassTextStyle(.data)
          .frame(maxWidth: .infinity, alignment: .trailing)
        Text(TickerDraft.displayDecimalText(for: ticker.movingAverage))
          .valueCompassTextStyle(.data)
          .frame(maxWidth: .infinity, alignment: .trailing)
        Text(ticker.hasCompleteMarketData ? "Ready" : "Missing")
          .valueCompassTextStyle(.labelCaps)
          .foregroundStyle(tickerMarketDataStatusColor(for: ticker))
          .frame(width: 88, alignment: .trailing)
      }
      .accessibilityIdentifier("portfolio.detail.tickerMarketData")
    } else {
      HStack {
        Text(ticker.normalizedSymbol)
          .valueCompassTextStyle(.labelCaps)
          .foregroundStyle(Color.appContentPrimary)
        Spacer()
        Text(marketDataSummary(for: ticker))
          .valueCompassTextStyle(.data)
          .foregroundStyle(
            ticker.hasCompleteMarketData ? Color.appContentSecondary : Color.appNegative)
      }
      .accessibilityIdentifier("portfolio.detail.tickerMarketData")
    }
  }

  private func marketDataSummary(for ticker: TickerDraft) -> String {
    guard ticker.hasCompleteMarketData else {
      return "Missing price/MA"
    }

    return
      "Price \(TickerDraft.displayDecimalText(for: ticker.currentPrice)) | MA \(TickerDraft.displayDecimalText(for: ticker.movingAverage))"
  }

  private func tickerMarketDataStatusColor(for ticker: TickerDraft) -> Color {
    ticker.hasCompleteMarketData ? Color.appContentSecondary : Color.appNegative
  }

  private var calculateSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("Calculate", systemImage: "function")
          .valueCompassTextStyle(.headlineMedium)
          .foregroundStyle(Color.appContentPrimary)

        Spacer()

        NavigationLink {
          ContributionHistoryListView(portfolio: portfolio)
        } label: {
          Label("History", systemImage: "clock.arrow.circlepath")
        }
        .buttonStyle(.bordered)
        .appMinimumTouchTarget()
        .accessibilityIdentifier("portfolio.detail.history")

        Button {
          showCalculationResult()
        } label: {
          Label("Calculate", systemImage: "play.fill")
        }
        .buttonStyle(.borderedProminent)
        .appMinimumTouchTarget()
        .accessibilityIdentifier("portfolio.detail.calculate")
      }

      if let calculationOutput {
        if let error = calculationOutput.error {
          Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
            .foregroundStyle(Color.appNegative)
            .accessibilityIdentifier("portfolio.detail.calculateError")
        } else {
          VStack(alignment: .leading, spacing: 6) {
            Text(
              "Monthly contribution: $\(PortfolioFormDraft.displayText(for: calculationOutput.totalAmount))"
            )
            .valueCompassTextStyle(.data)
            .foregroundStyle(Color.appContentPrimary)
            Text("\(calculationOutput.allocations.count) ticker allocations ready.")
              .foregroundStyle(Color.appContentSecondary)
            Button("View Result") {
              isShowingResult = true
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("portfolio.detail.viewResult")
          }
          .accessibilityIdentifier("portfolio.detail.calculateSuccess")
        }
      } else {
        Text(
          "Uses the local moving-average VCA calculator after validating budget, weights, tickers, and market data."
        )
        .foregroundStyle(Color.appContentSecondary)
      }
    }
    .padding()
    .background(Color.appSurfaceElevated, in: RoundedRectangle(cornerRadius: 16))
  }

  private func showCalculationResult() {
    calculationOutput = ContributionCalculationService.calculate(
      portfolio: portfolio,
      calculator: calculator
    )
    isShowingResult = true
  }
}

struct ContributionResultView: View {
  let portfolio: Portfolio
  let recalculate: () -> ContributionOutput

  @Environment(\.modelContext) private var modelContext
  @State private var output: ContributionOutput
  @State private var saveError: SaveError?
  @State private var saveConfirmation: SaveConfirmation?

  init(
    portfolio: Portfolio,
    initialOutput: ContributionOutput,
    recalculate: @escaping () -> ContributionOutput
  ) {
    self.portfolio = portfolio
    self.recalculate = recalculate
    _output = State(initialValue: initialOutput)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        if let error = output.error {
          calculationErrorView(error)
        } else {
          resultSummary
          categoryBreakdown
          actions
        }
      }
      .padding()
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .navigationTitle(output.error == nil ? "Contribution Result" : "Calculation Failed")
    .alert(item: $saveError) { error in
      Alert(
        title: Text("Could Not Save Result"),
        message: Text(error.message),
        dismissButton: .default(Text("OK"))
      )
    }
    .alert(item: $saveConfirmation) { confirmation in
      Alert(
        title: Text("Result Saved"),
        message: Text(confirmation.message),
        dismissButton: .default(Text("OK"))
      )
    }
    .accessibilityIdentifier("contribution.result")
  }

  private var resultSummary: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Total Monthly Contribution")
        .valueCompassTextStyle(.labelCaps)
        .foregroundStyle(Color.appContentSecondary)

      Text("$\(decimalText(output.totalAmount))")
        .valueCompassTextStyle(.displayLarge)
        .minimumScaleFactor(0.7)
        .foregroundStyle(Color.appContentPrimary)
        .accessibilityIdentifier("contribution.result.total")
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.appSurfaceElevated, in: RoundedRectangle(cornerRadius: 16))
  }

  private var categoryBreakdown: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Breakdown")
        .valueCompassTextStyle(.headlineMedium)
        .foregroundStyle(Color.appContentPrimary)

      ForEach(Array(output.categoryBreakdown.enumerated()), id: \.offset) { _, category in
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text(category.categoryName)
              .valueCompassTextStyle(.bodyLarge)
              .foregroundStyle(Color.appContentPrimary)
            Spacer()
            Text("$\(decimalText(category.amount))")
              .valueCompassTextStyle(.data)
              .foregroundStyle(Color.appContentPrimary)
          }

          ForEach(
            Array(
              output.allocations.filter { $0.categoryName == category.categoryName }.enumerated()),
            id: \.offset
          ) { _, allocation in
            HStack {
              Text(allocation.tickerSymbol)
                .valueCompassTextStyle(.labelCaps)
                .foregroundStyle(Color.appContentPrimary)
              Spacer()
              Text("$\(decimalText(allocation.amount))")
                .valueCompassTextStyle(.data)
                .foregroundStyle(Color.appContentPrimary)
              Text("\(percentText(allocation.allocatedWeight))%")
                .valueCompassTextStyle(.data)
                .foregroundStyle(Color.appContentSecondary)
            }
            .accessibilityIdentifier("contribution.result.ticker")
          }
        }
        .padding()
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("contribution.result.category")
      }
    }
  }

  private var actions: some View {
    HStack(spacing: 12) {
      Button {
        saveResult()
      } label: {
        Label("Save", systemImage: "tray.and.arrow.down")
      }
      .buttonStyle(.borderedProminent)
      .accessibilityIdentifier("contribution.result.save")

      NavigationLink {
        ContributionHistoryListView(portfolio: portfolio)
      } label: {
        Label("History", systemImage: "clock.arrow.circlepath")
      }
      .buttonStyle(.bordered)
      .accessibilityIdentifier("contribution.result.history")
    }
  }

  private func calculationErrorView(_ error: LocalizedError) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
        .valueCompassTextStyle(.bodyLarge)
        .foregroundStyle(Color.appNegative)
        .accessibilityIdentifier("contribution.result.error")

      Button {
        output = recalculate()
      } label: {
        Label("Retry", systemImage: "arrow.clockwise")
      }
      .buttonStyle(.borderedProminent)
      .accessibilityIdentifier("contribution.result.retry")
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.appSurfaceElevated, in: RoundedRectangle(cornerRadius: 16))
  }

  private func saveResult() {
    do {
      let record = try ContributionRecord(snapshotFor: portfolio, output: output)
      modelContext.insert(record)
      try modelContext.save()
      saveConfirmation = SaveConfirmation(
        message: "Saved $\(decimalText(record.totalAmount)) for \(portfolio.name).")
    } catch {
      saveError = SaveError(message: error.localizedDescription)
    }
  }

  private func decimalText(_ value: Decimal) -> String {
    NSDecimalNumber(decimal: value).stringValue
  }

  private func percentText(_ value: Decimal) -> String {
    decimalText(value * 100)
  }
}

struct ContributionHistoryListView: View {
  let portfolio: Portfolio

  @Environment(\.modelContext) private var modelContext
  @State private var recordPendingDeletion: ContributionRecord?
  @State private var deleteError: SaveError?

  var body: some View {
    List {
      if monthSections.isEmpty {
        ContentUnavailableView {
          Label("No Saved Results", systemImage: "clock")
        } description: {
          Text("Save a contribution result to build local history.")
        } actions: {
          NavigationLink {
            PortfolioDetailView(portfolio: portfolio)
          } label: {
            Label("Calculate", systemImage: "function")
          }
          .buttonStyle(.borderedProminent)
          .accessibilityIdentifier("contribution.history.calculate")
        }
      } else {
        ForEach(monthSections) { section in
          Section {
            ForEach(section.records) { record in
              NavigationLink {
                ContributionHistoryDetailView(record: record)
              } label: {
                ContributionHistoryRowView(record: record)
              }
              .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button("Delete", role: .destructive) {
                  recordPendingDeletion = record
                }
              }
              .accessibilityIdentifier("contribution.history.record")
            }
            .onDelete { offsets in
              if let firstOffset = offsets.first {
                recordPendingDeletion = section.records[firstOffset]
              }
            }
          } header: {
            HStack {
              Text(section.title)
              Spacer()
              Text("$\(decimalText(section.totalAmount))")
            }
          }
        }
      }
    }
    .navigationTitle("History")
    .alert(item: $recordPendingDeletion) { record in
      Alert(
        title: Text("Delete Saved Result?"),
        message: Text("This removes the saved result from \(dateText(record.date))."),
        primaryButton: .destructive(Text("Delete")) {
          delete(record)
        },
        secondaryButton: .cancel()
      )
    }
    .alert(item: $deleteError) { error in
      Alert(
        title: Text("Could Not Delete Result"),
        message: Text(error.message),
        dismissButton: .default(Text("OK"))
      )
    }
    .accessibilityIdentifier("contribution.history")
  }

  private var records: [ContributionRecord] {
    portfolio.contributionRecords
      .filter { $0.portfolioId == portfolio.id }
      .sorted { $0.date > $1.date }
  }

  private var monthSections: [ContributionHistoryMonthSection] {
    ContributionHistoryMonthSection.group(records: records)
  }

  private func delete(_ record: ContributionRecord) {
    modelContext.delete(record)
    do {
      try modelContext.save()
    } catch {
      deleteError = SaveError(message: error.localizedDescription)
    }
  }

  private func decimalText(_ value: Decimal) -> String {
    NSDecimalNumber(decimal: value).stringValue
  }

  private func dateText(_ date: Date) -> String {
    ContributionHistoryDateFormatters.day.string(from: date)
  }
}

struct ContributionHistoryRowView: View {
  let record: ContributionRecord

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(ContributionHistoryDateFormatters.day.string(from: record.date))
          .valueCompassTextStyle(.bodyLarge)
          .foregroundStyle(Color.appContentPrimary)
        Text("\(record.tickerAllocations.count) ticker allocations")
          .valueCompassTextStyle(.bodySmall)
          .foregroundStyle(Color.appContentSecondary)
      }

      Spacer()

      Text("$\(decimalText(record.totalAmount))")
        .valueCompassTextStyle(.data)
        .foregroundStyle(Color.appContentPrimary)
    }
    .accessibilityElement(children: .combine)
  }

  private func decimalText(_ value: Decimal) -> String {
    NSDecimalNumber(decimal: value).stringValue
  }
}

struct ContributionHistoryDetailView: View {
  let record: ContributionRecord

  var body: some View {
    List {
      Section("Summary") {
        LabeledContent(
          "Date", value: ContributionHistoryDateFormatters.day.string(from: record.date))
        LabeledContent("Total", value: "$\(decimalText(record.totalAmount))")
      }

      Section("Category Totals") {
        ForEach(categoryBreakdown, id: \.categoryName) { category in
          LabeledContent(category.categoryName, value: "$\(decimalText(category.amount))")
            .accessibilityIdentifier("contribution.history.detail.category")
        }
      }

      Section("Ticker Breakdown") {
        ForEach(tickerAllocations, id: \.id) { allocation in
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Text(allocation.tickerSymbol)
                .valueCompassTextStyle(.labelCaps)
                .foregroundStyle(Color.appContentPrimary)
              Spacer()
              Text("$\(decimalText(allocation.amount))")
                .valueCompassTextStyle(.data)
                .foregroundStyle(Color.appContentPrimary)
            }
            Text(allocation.categoryName)
              .valueCompassTextStyle(.bodySmall)
              .foregroundStyle(Color.appContentSecondary)
          }
          .accessibilityIdentifier("contribution.history.detail.ticker")
        }
      }
    }
    .navigationTitle("Saved Result")
    .accessibilityIdentifier("contribution.history.detail")
  }

  private var categoryBreakdown: [CategoryContribution] {
    record.categoryBreakdown.sorted { lhs, rhs in
      if lhs.categoryName == rhs.categoryName {
        return lhs.amount > rhs.amount
      }
      return lhs.categoryName < rhs.categoryName
    }
  }

  private var tickerAllocations: [TickerAllocation] {
    record.tickerAllocations.sorted { lhs, rhs in
      if lhs.categoryName == rhs.categoryName {
        return lhs.tickerSymbol < rhs.tickerSymbol
      }
      return lhs.categoryName < rhs.categoryName
    }
  }

  private func decimalText(_ value: Decimal) -> String {
    NSDecimalNumber(decimal: value).stringValue
  }
}

struct ContributionHistoryMonthSection: Identifiable {
  let monthStart: Date
  let title: String
  let records: [ContributionRecord]

  var id: Date { monthStart }

  var totalAmount: Decimal {
    records.reduce(Decimal(0)) { $0 + $1.totalAmount }
  }

  static func group(
    records: [ContributionRecord],
    calendar: Calendar = .current
  ) -> [ContributionHistoryMonthSection] {
    let sortedRecords = records.sorted { $0.date > $1.date }
    let groupedRecords = Dictionary(grouping: sortedRecords) { record in
      calendar.dateInterval(of: .month, for: record.date)?.start ?? record.date
    }

    return groupedRecords.keys.sorted(by: >).map { monthStart in
      ContributionHistoryMonthSection(
        monthStart: monthStart,
        title: ContributionHistoryDateFormatters.monthString(from: monthStart, calendar: calendar),
        records: groupedRecords[monthStart] ?? []
      )
    }
  }
}

enum ContributionHistoryDateFormatters {
  static let day: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
  }()

  static func monthString(from date: Date, calendar: Calendar) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM yyyy"
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    return formatter.string(from: date)
  }
}

struct SaveError: Identifiable {
  let id = UUID()
  let message: String
}

struct SaveConfirmation: Identifiable {
  let id = UUID()
  let message: String
}

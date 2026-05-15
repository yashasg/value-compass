import ComposableArchitecture
import SwiftData
import SwiftUI

enum HoldingsDraftIssue: Equatable, Sendable {
  case noCategories
  case emptyCategoryName
  case invalidCategoryWeight
  case categoryWeightsDoNotSumTo100
  case categoryHasNoTickers(String)
  case emptyTickerSymbol
  case missingTickerMarketData(String)
  case invalidTickerMarketData(String)
  case duplicateTickerSymbols([String])

  var message: String {
    switch self {
    case .noCategories:
      return "Add at least one category before calculating."
    case .emptyCategoryName:
      return "Category names are required."
    case .invalidCategoryWeight:
      return "Category weights must be between 0 and 100%."
    case .categoryWeightsDoNotSumTo100:
      return "Category weights must add up to 100% before calculating."
    case .categoryHasNoTickers(let categoryName):
      return "\(categoryName) has no tickers."
    case .emptyTickerSymbol:
      return "Ticker symbols are required."
    case .missingTickerMarketData(let symbol):
      return "\(symbol) is missing current price or moving average."
    case .invalidTickerMarketData(let symbol):
      return "\(symbol) market data must be greater than 0."
    case .duplicateTickerSymbols(let symbols):
      return "Ticker symbols must be unique: \(symbols.joined(separator: ", "))."
    }
  }

  var blocksSaving: Bool {
    switch self {
    case .emptyCategoryName, .invalidCategoryWeight, .emptyTickerSymbol, .invalidTickerMarketData,
      .duplicateTickerSymbols:
      return true
    case .noCategories, .categoryWeightsDoNotSumTo100, .categoryHasNoTickers,
      .missingTickerMarketData:
      return false
    }
  }
}

struct HoldingsDraft: Equatable, Sendable {
  var categories: [CategoryDraft]

  init(categories: [CategoryDraft] = []) {
    self.categories = categories
  }

  init(portfolio: Portfolio) {
    categories = portfolio.categories
      .sorted { $0.sortOrder < $1.sortOrder }
      .map(CategoryDraft.init(category:))
  }

  mutating func addCategory() {
    categories.append(
      CategoryDraft(
        name: "",
        weightPercentText: categories.isEmpty ? "100" : "0",
        tickers: []
      ))
    normalizeCategorySortOrders()
  }

  mutating func deleteCategory(id: UUID) {
    categories.removeAll { $0.id == id }
    normalizeCategorySortOrders()
  }

  mutating func moveCategory(id: UUID, direction: MoveDirection) {
    guard let index = categories.firstIndex(where: { $0.id == id }) else {
      return
    }
    let newIndex = direction == .up ? index - 1 : index + 1
    guard categories.indices.contains(newIndex) else {
      return
    }
    categories.swapAt(index, newIndex)
    normalizeCategorySortOrders()
  }

  func issues() -> [HoldingsDraftIssue] {
    var issues: [HoldingsDraftIssue] = []

    if categories.isEmpty {
      issues.append(.noCategories)
    }

    let weights = categories.map(\.weightPercent)
    if categories.contains(where: {
      $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }) {
      issues.append(.emptyCategoryName)
    }

    if weights.contains(where: { weight in
      guard let weight else {
        return true
      }
      return weight < 0 || weight > 100
    }) {
      issues.append(.invalidCategoryWeight)
    }

    if !weights.contains(nil), weights.reduce(Decimal(0), { $0 + ($1 ?? 0) }) != 100 {
      issues.append(.categoryWeightsDoNotSumTo100)
    }

    for category in categories where category.tickers.isEmpty {
      issues.append(.categoryHasNoTickers(category.displayName))
    }

    let tickers = categories.flatMap(\.tickers)
    if tickers.contains(where: { $0.normalizedSymbol.isEmpty }) {
      issues.append(.emptyTickerSymbol)
    }

    for ticker in tickers where !ticker.normalizedSymbol.isEmpty {
      if ticker.hasInvalidMarketData {
        issues.append(.invalidTickerMarketData(ticker.normalizedSymbol))
      } else if !ticker.hasCompleteMarketData {
        issues.append(.missingTickerMarketData(ticker.normalizedSymbol))
      }
    }

    let duplicates = duplicateTickerSymbols()
    if !duplicates.isEmpty {
      issues.append(.duplicateTickerSymbols(duplicates))
    }

    return issues
  }

  func saveBlockingIssues() -> [HoldingsDraftIssue] {
    issues().filter(\.blocksSaving)
  }

  func canCalculate() -> Bool {
    issues().isEmpty
  }

  func duplicateTickerSymbols() -> [String] {
    var seen = Set<String>()
    var duplicates = Set<String>()

    for symbol in categories.flatMap(\.tickers).map(\.normalizedSymbol) where !symbol.isEmpty {
      if !seen.insert(symbol).inserted {
        duplicates.insert(symbol)
      }
    }

    return duplicates.sorted()
  }

  func apply(to portfolio: Portfolio, in modelContext: ModelContext) throws {
    if let firstBlockingIssue = saveBlockingIssues().first {
      throw HoldingsEditorValidationError.issue(firstBlockingIssue)
    }

    let currentCategories = Dictionary(
      uniqueKeysWithValues: portfolio.categories.map { ($0.id, $0) })
    let requestedCategoryIDs = Set(categories.map(\.id))

    for category in portfolio.categories where !requestedCategoryIDs.contains(category.id) {
      modelContext.delete(category)
    }

    var updatedCategories: [Category] = []
    for (categoryIndex, categoryDraft) in categories.enumerated() {
      let category =
        currentCategories[categoryDraft.id]
        ?? Category(
          id: categoryDraft.id,
          name: categoryDraft.name,
          weight: 0,
          sortOrder: categoryIndex
        )
      if currentCategories[categoryDraft.id] == nil {
        modelContext.insert(category)
      }

      category.name = categoryDraft.name.trimmingCharacters(in: .whitespacesAndNewlines)
      category.weight = categoryDraft.storedWeight
      category.sortOrder = categoryIndex
      category.portfolio = portfolio
      applyTickers(categoryDraft.tickers, to: category, in: modelContext)
      updatedCategories.append(category)
    }

    portfolio.categories = updatedCategories
    try modelContext.save()
  }

  private func applyTickers(
    _ tickerDrafts: [TickerDraft], to category: Category, in modelContext: ModelContext
  ) {
    let currentTickers = Dictionary(uniqueKeysWithValues: category.tickers.map { ($0.id, $0) })
    let requestedTickerIDs = Set(tickerDrafts.map(\.id))

    for ticker in category.tickers where !requestedTickerIDs.contains(ticker.id) {
      modelContext.delete(ticker)
    }

    var updatedTickers: [Ticker] = []
    for (tickerIndex, tickerDraft) in tickerDrafts.enumerated() {
      let ticker =
        currentTickers[tickerDraft.id]
        ?? Ticker(
          id: tickerDraft.id,
          symbol: tickerDraft.normalizedSymbol,
          currentPrice: tickerDraft.currentPrice,
          movingAverage: tickerDraft.movingAverage,
          bandPosition: tickerDraft.bandPosition,
          sortOrder: tickerIndex
        )
      if currentTickers[tickerDraft.id] == nil {
        modelContext.insert(ticker)
      }

      ticker.symbol = tickerDraft.normalizedSymbol
      ticker.currentPrice = tickerDraft.currentPrice
      ticker.movingAverage = tickerDraft.movingAverage
      ticker.bandPosition = tickerDraft.bandPosition
      ticker.sortOrder = tickerIndex
      ticker.category = category
      updatedTickers.append(ticker)
    }

    category.tickers = updatedTickers
  }

  private mutating func normalizeCategorySortOrders() {
    for index in categories.indices {
      categories[index].sortOrder = index
    }
  }
}

enum HoldingsEditorValidationError: LocalizedError, Equatable, Sendable {
  case issue(HoldingsDraftIssue)

  var errorDescription: String? {
    switch self {
    case .issue(let issue):
      return issue.message
    }
  }
}

enum MoveDirection: Equatable, Sendable {
  case up
  case down
}

struct CategoryDraft: Identifiable, Equatable, Sendable {
  let id: UUID
  var name: String
  var weightPercentText: String
  var sortOrder: Int
  var tickers: [TickerDraft]

  init(
    id: UUID = UUID(),
    name: String,
    weightPercentText: String,
    sortOrder: Int = 0,
    tickers: [TickerDraft] = []
  ) {
    self.id = id
    self.name = name
    self.weightPercentText = weightPercentText
    self.sortOrder = sortOrder
    self.tickers = tickers
  }

  init(category: Category) {
    id = category.id
    name = category.name
    weightPercentText = Self.displayPercentText(for: category.weight)
    sortOrder = category.sortOrder
    tickers = category.tickers
      .sorted { $0.sortOrder < $1.sortOrder }
      .map(TickerDraft.init(ticker:))
  }

  var displayName: String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "New Category" : trimmed
  }

  var weightPercent: Decimal? {
    Decimal(string: weightPercentText.trimmingCharacters(in: .whitespacesAndNewlines))
  }

  var storedWeight: Decimal {
    (weightPercent ?? 0) / 100
  }

  mutating func addTicker() {
    tickers.append(TickerDraft(symbol: "", sortOrder: tickers.count))
  }

  mutating func deleteTicker(id: UUID) {
    tickers.removeAll { $0.id == id }
    normalizeTickerSortOrders()
  }

  mutating func moveTicker(id: UUID, direction: MoveDirection) {
    guard let index = tickers.firstIndex(where: { $0.id == id }) else {
      return
    }
    let newIndex = direction == .up ? index - 1 : index + 1
    guard tickers.indices.contains(newIndex) else {
      return
    }
    tickers.swapAt(index, newIndex)
    normalizeTickerSortOrders()
  }

  static func displayPercentText(for storedWeight: Decimal) -> String {
    NSDecimalNumber(decimal: storedWeight * 100).stringValue
  }

  private mutating func normalizeTickerSortOrders() {
    for index in tickers.indices {
      tickers[index].sortOrder = index
    }
  }
}

struct TickerDraft: Identifiable, Equatable, Sendable {
  let id: UUID
  var symbol: String
  var currentPriceText: String
  var movingAverageText: String
  var bandPositionText: String
  var sortOrder: Int

  init(
    id: UUID = UUID(),
    symbol: String,
    currentPrice: Decimal? = nil,
    movingAverage: Decimal? = nil,
    bandPosition: Decimal? = nil,
    sortOrder: Int
  ) {
    self.id = id
    self.symbol = symbol
    self.currentPriceText = Self.displayDecimalText(for: currentPrice)
    self.movingAverageText = Self.displayDecimalText(for: movingAverage)
    self.bandPositionText = Self.displayDecimalText(for: bandPosition)
    self.sortOrder = sortOrder
  }

  init(ticker: Ticker) {
    id = ticker.id
    symbol = ticker.symbol
    currentPriceText = Self.displayDecimalText(for: ticker.currentPrice)
    movingAverageText = Self.displayDecimalText(for: ticker.movingAverage)
    bandPositionText = Self.displayDecimalText(for: ticker.bandPosition)
    sortOrder = ticker.sortOrder
  }

  var normalizedSymbol: String {
    symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
  }

  /// Accessibility-facing label fallback used by per-row reorder/delete
  /// controls in ``HoldingsEditorView``. VoiceOver and Voice Control resolve
  /// commands by matching the control's spoken/AT label, so an empty draft
  /// symbol still needs a unique-ish per-row anchor instead of an empty
  /// interpolation gap (issue #268).
  var displaySymbol: String {
    let normalized = normalizedSymbol
    return normalized.isEmpty ? "New ticker" : normalized
  }

  var currentPrice: Decimal? {
    Self.validPositiveDecimal(from: currentPriceText)
  }

  var movingAverage: Decimal? {
    Self.validPositiveDecimal(from: movingAverageText)
  }

  var bandPosition: Decimal? {
    Self.validDecimal(from: bandPositionText)
  }

  var hasCompleteMarketData: Bool {
    currentPrice != nil && movingAverage != nil
  }

  var hasInvalidMarketData: Bool {
    Self.hasInvalidPositiveDecimal(currentPriceText)
      || Self.hasInvalidPositiveDecimal(movingAverageText)
  }

  var marketDataStatusMessage: String? {
    if hasInvalidMarketData {
      return "Price and moving average must be greater than 0."
    }
    if !hasCompleteMarketData {
      return "Current price and moving average are required before calculating."
    }
    return nil
  }

  static func displayDecimalText(for decimal: Decimal?) -> String {
    guard let decimal else {
      return ""
    }

    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.minimumFractionDigits = 2
    formatter.maximumFractionDigits = 2
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = false
    return formatter.string(from: NSDecimalNumber(decimal: decimal))
      ?? NSDecimalNumber(decimal: decimal).stringValue
  }

  private static func validPositiveDecimal(from text: String) -> Decimal? {
    guard let value = validDecimal(from: text), value > 0 else {
      return nil
    }
    return value
  }

  private static func validDecimal(from text: String) -> Decimal? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return nil
    }
    return Decimal(string: trimmed)
  }

  private static func hasInvalidPositiveDecimal(_ text: String) -> Bool {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return false
    }
    return validPositiveDecimal(from: trimmed) == nil
  }

  private static func hasInvalidDecimal(_ text: String) -> Bool {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return false
    }
    return validDecimal(from: trimmed) == nil
  }
}

/// Holdings editor view, driven by `HoldingsEditorFeature`. Pure TCA: scope
/// a `StoreOf<HoldingsEditorFeature>` from the parent and pass it in.
struct HoldingsEditorView: View {
  /// Identifies a `.decimalPad` `TextField` so a single shared keyboard
  /// toolbar can resign whichever numeric field is currently focused.
  /// `.decimalPad` has no Return key, so HIG Inputs → Virtual Keyboards
  /// requires an input-accessory affordance to dismiss it (issue #283).
  private enum FocusedField: Hashable {
    case categoryWeight(UUID)
    case tickerCurrentPrice(UUID)
    case tickerMovingAverage(UUID)
  }

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.dismiss) private var dismiss
  @State private var store: StoreOf<HoldingsEditorFeature>
  @State private var selectedCategoryID: UUID?
  @FocusState private var focusedField: FocusedField?

  init(store: StoreOf<HoldingsEditorFeature>) {
    _store = State(initialValue: store)
  }

  var body: some View {
    @Bindable var store = store
    Group {
      if horizontalSizeClass == .regular {
        splitEditor(store: store)
      } else {
        compactEditor(store: store)
      }
    }
    .navigationTitle("Edit Holdings")
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") {
          // Route through the reducer so dirty-state inspection + the
          // discard-confirmation dialog stay testable from `TestStore`.
          // When the draft matches `baseline` the reducer emits
          // `.delegate(.canceled)` (clean dismiss); when dirty it sets
          // `pendingCancellation = true` and the `.confirmationDialog`
          // below takes over — see #325.
          Task {
            await store.send(.cancelTapped).finish()
            if !store.pendingCancellation {
              dismiss()
            }
          }
        }
        .accessibilityIdentifier("holdings.editor.cancel")
      }

      if horizontalSizeClass != .regular {
        ToolbarItem(placement: .primaryAction) {
          addCategoryButton
        }
      }

      ToolbarItem(placement: .confirmationAction) {
        Button("Save") {
          Task {
            await store.send(.saveTapped).finish()
            if store.saveError == nil {
              dismiss()
            }
          }
        }
        .accessibilityIdentifier("holdings.editor.save")
      }

      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") { focusedField = nil }
          .accessibilityIdentifier("holdings.editor.keyboard.doneButton")
      }
    }
    .alert(
      "Could Not Save Holdings",
      isPresented: Binding(
        get: { store.saveError != nil },
        set: { isPresented in
          if !isPresented {
            store.send(.saveErrorDismissed)
          }
        }
      ),
      presenting: store.saveError
    ) { _ in
      Button("OK", role: .cancel) {
        store.send(.saveErrorDismissed)
      }
    } message: { message in
      Text(message)
    }
    .confirmationDialog(
      "Discard Changes?",
      isPresented: Binding(
        get: { store.pendingCancellation },
        set: { newValue in
          // The dialog drives `isPresented = false` on outside-tap or back
          // gesture. Route that through `.keepEditing` so the reducer stays
          // the single source of truth for `pendingCancellation` (#325).
          if !newValue { store.send(.keepEditing) }
        }
      ),
      titleVisibility: .visible
    ) {
      Button("Discard Changes", role: .destructive) {
        Task {
          await store.send(.confirmDiscard).finish()
          dismiss()
        }
      }
      .accessibilityIdentifier("holdings.editor.discardConfirm")
      Button("Keep Editing", role: .cancel) {
        store.send(.keepEditing)
      }
      .accessibilityIdentifier("holdings.editor.keepEditing")
    } message: {
      Text("Your unsaved edits will be lost.")
    }
    // HIG Sheets: block accidental swipe-down dismissal when there is
    // unsaved content. Currently HoldingsEditor is presented as a push so
    // this is a no-op today, but pre-wires the modality fix for #229 when
    // the screen flips to a sheet (#325 coordination note).
    .interactiveDismissDisabled(store.hasUnsavedChanges)
    .task { await store.send(.task).finish() }
    .onAppear(perform: selectInitialCategoryIfNeeded)
    .onChange(of: store.draft.categories.map(\.id)) { _, _ in
      selectInitialCategoryIfNeeded()
    }
  }

  private func compactEditor(store: StoreOf<HoldingsEditorFeature>) -> some View {
    @Bindable var store = store
    return Form {
      if store.draft.categories.isEmpty {
        ContentUnavailableView {
          Label("No Categories", systemImage: "folder.badge.plus")
        } description: {
          Text("Add a category to start organizing tickers.")
        } actions: {
          addCategoryButton
        }
      } else {
        validationSection

        ForEach($store.draft.categories) { $category in
          categorySection(category: $category)
        }
      }
    }
  }

  private func splitEditor(store: StoreOf<HoldingsEditorFeature>) -> some View {
    @Bindable var store = store
    return NavigationSplitView {
      List(selection: $selectedCategoryID) {
        if store.draft.categories.isEmpty {
          ContentUnavailableView {
            Label("No Categories", systemImage: "folder.badge.plus")
          } description: {
            Text("Add a category to start organizing tickers.")
          } actions: {
            addCategoryButton
          }
        } else {
          validationSummaryRow

          ForEach(store.draft.categories) { category in
            VStack(alignment: .leading, spacing: 6) {
              Text(category.displayName)
                .valueCompassTextStyle(.bodyLarge)
              HStack {
                Text("\(category.weightPercentText)% target")
                Spacer()
                Text("\(category.tickers.count) tickers")
              }
              .valueCompassTextStyle(.labelCaps)
              .foregroundStyle(Color.appContentSecondary)
            }
            .padding(.vertical, 6)
            .tag(category.id)
            .accessibilityIdentifier("holdings.category.sidebarRow")
          }
          .onDelete(perform: deleteCategories)
        }
      }
      .navigationTitle("Categories")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          addCategoryButton
        }
      }
      .navigationSplitViewColumnWidth(
        min: AppLayoutMetrics.sidebarMinWidth,
        ideal: AppLayoutMetrics.sidebarIdealWidth,
        max: AppLayoutMetrics.sidebarMaxWidth)
    } detail: {
      if store.draft.categories.isEmpty {
        ContentUnavailableView {
          Label("No Categories", systemImage: "folder.badge.plus")
        } description: {
          Text("Add a category to edit target weights and ticker market data.")
        } actions: {
          addCategoryButton
        }
      } else if let selectedIndex = selectedCategoryIndex {
        categoryDetail(category: $store.draft.categories[selectedIndex])
      } else {
        ContentUnavailableView {
          Label("Select a Category", systemImage: "sidebar.leading")
        } description: {
          Text("Choose a category from the sidebar.")
        }
      }
    }
  }

  private var addCategoryButton: some View {
    Button {
      addCategory()
    } label: {
      Label("Add Category", systemImage: "plus")
    }
    .appMinimumTouchTarget()
    .accessibilityIdentifier("holdings.category.add")
  }

  @ViewBuilder
  private var validationSummaryRow: some View {
    let issues = store.issues
    if !issues.isEmpty {
      Label("\(issues.count) warnings", systemImage: "exclamationmark.triangle")
        .foregroundStyle(validationSummaryColor(for: issues))
        .accessibilityIdentifier("holdings.validation.summary")
    }
  }

  @ViewBuilder
  private var validationSection: some View {
    let issues = store.issues
    if !issues.isEmpty {
      Section("Warnings") {
        ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
          Label(
            issue.message,
            systemImage: issue.blocksSaving
              ? "exclamationmark.triangle.fill" : "exclamationmark.circle"
          )
          .foregroundStyle(issue.blocksSaving ? Color.appError : Color.appWarning)
        }
      }
      .accessibilityIdentifier("holdings.validation")
    }
  }

  private func categorySection(category: Binding<CategoryDraft>) -> some View {
    Section {
      TextField("Category name", text: category.name)
        .textInputAutocapitalization(.words)
        .accessibilityIdentifier("holdings.category.name")

      TextField("Weight %", text: category.weightPercentText)
        .keyboardType(.decimalPad)
        .focused($focusedField, equals: .categoryWeight(category.wrappedValue.id))
        .accessibilityIdentifier("holdings.category.weight")

      if category.wrappedValue.tickers.isEmpty {
        Label("Warning: no tickers", systemImage: "exclamationmark.circle")
          .foregroundStyle(Color.appWarning)
          .accessibilityIdentifier("holdings.category.warning")
      }

      ForEach(category.tickers) { $ticker in
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            TextField("Ticker symbol", text: $ticker.symbol)
              .textInputAutocapitalization(.characters)
              .autocorrectionDisabled()
              .accessibilityIdentifier("holdings.ticker.symbol")

            tickerControls(
              categoryID: category.wrappedValue.id,
              tickerID: ticker.id,
              categoryName: category.wrappedValue.displayName,
              tickerSymbol: ticker.displaySymbol
            )
          }

          tickerMarketDataFields(ticker: $ticker)

          if let message = ticker.marketDataStatusMessage {
            Label(
              message,
              systemImage: ticker.hasInvalidMarketData
                ? "exclamationmark.triangle.fill" : "exclamationmark.circle"
            )
            .valueCompassTextStyle(.labelCaps)
            .foregroundStyle(ticker.hasInvalidMarketData ? Color.appError : Color.appWarning)
            .accessibilityIdentifier("holdings.ticker.marketDataWarning")
          }
        }
      }

      Button {
        store.send(.addTicker(categoryID: category.wrappedValue.id))
      } label: {
        Label("Add Ticker", systemImage: "plus")
      }
      .appMinimumTouchTarget()
      .accessibilityIdentifier("holdings.ticker.add")
    } header: {
      HStack {
        Text(category.wrappedValue.displayName)
        Spacer()
        categoryControls(
          categoryID: category.wrappedValue.id,
          categoryName: category.wrappedValue.displayName
        )
      }
    }
    .accessibilityIdentifier("holdings.category.section")
  }

  private func categoryControls(categoryID: UUID, categoryName: String) -> some View {
    HStack {
      Button {
        store.send(.moveCategory(id: categoryID, direction: .up))
      } label: {
        Image(systemName: "chevron.up")
      }
      .disabled(store.draft.categories.first?.id == categoryID)
      .appMinimumTouchTarget()
      .accessibilityLabel("Move category \(categoryName) up")

      Button {
        store.send(.moveCategory(id: categoryID, direction: .down))
      } label: {
        Image(systemName: "chevron.down")
      }
      .disabled(store.draft.categories.last?.id == categoryID)
      .appMinimumTouchTarget()
      .accessibilityLabel("Move category \(categoryName) down")

      Button(role: .destructive) {
        store.send(.deleteCategory(id: categoryID))
      } label: {
        Image(systemName: "trash")
      }
      .tint(Color.appError)
      .appMinimumTouchTarget()
      .accessibilityLabel("Delete category \(categoryName)")
    }
    .buttonStyle(.borderless)
  }

  private var selectedCategoryIndex: Int? {
    guard let selectedCategoryID,
      let index = store.draft.categories.firstIndex(where: { $0.id == selectedCategoryID })
    else {
      return nil
    }
    return index
  }

  private func categoryDetail(category: Binding<CategoryDraft>) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: AppLayoutMetrics.stackGap) {
        validationSection

        VStack(alignment: .leading, spacing: AppLayoutMetrics.stackGap) {
          Text("Category")
            .valueCompassTextStyle(.headlineMedium)

          HStack(spacing: AppLayoutMetrics.gridGutter) {
            TextField("Category name", text: category.name)
              .textInputAutocapitalization(.words)
              .accessibilityIdentifier("holdings.category.name")

            TextField("Weight %", text: category.weightPercentText)
              .keyboardType(.decimalPad)
              .focused($focusedField, equals: .categoryWeight(category.wrappedValue.id))
              .frame(width: 120)
              .accessibilityIdentifier("holdings.category.weight")

            categoryControls(
              categoryID: category.wrappedValue.id,
              categoryName: category.wrappedValue.displayName
            )
          }
        }
        .padding()
        .background(Color.appSurfaceElevated, in: RoundedRectangle(cornerRadius: 16))

        VStack(alignment: .leading, spacing: AppLayoutMetrics.stackGap) {
          HStack {
            Text("Tickers")
              .valueCompassTextStyle(.headlineMedium)
            Spacer()
            Button {
              store.send(.addTicker(categoryID: category.wrappedValue.id))
            } label: {
              Label("Add Ticker", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .appMinimumTouchTarget()
            .accessibilityIdentifier("holdings.ticker.add")
          }

          if category.wrappedValue.tickers.isEmpty {
            Label("Warning: no tickers", systemImage: "exclamationmark.circle")
              .foregroundStyle(Color.appWarning)
              .accessibilityIdentifier("holdings.category.warning")
          } else {
            ForEach(category.tickers) { $ticker in
              VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: AppLayoutMetrics.gridGutter) {
                  TextField("Ticker symbol", text: $ticker.symbol)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .frame(width: 120)
                    .accessibilityIdentifier("holdings.ticker.symbol")

                  tickerMarketDataFields(ticker: $ticker)

                  tickerControls(
                    categoryID: category.wrappedValue.id,
                    tickerID: ticker.id,
                    categoryName: category.wrappedValue.displayName,
                    tickerSymbol: ticker.displaySymbol
                  )
                }

                if let message = ticker.marketDataStatusMessage {
                  Label(
                    message,
                    systemImage: ticker.hasInvalidMarketData
                      ? "exclamationmark.triangle.fill" : "exclamationmark.circle"
                  )
                  .valueCompassTextStyle(.labelCaps)
                  .foregroundStyle(ticker.hasInvalidMarketData ? Color.appError : Color.appWarning)
                  .accessibilityIdentifier("holdings.ticker.marketDataWarning")
                }
              }
              .padding()
              .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 12))
              .accessibilityIdentifier("holdings.ticker.editorRow")
            }
          }
        }
        .padding()
        .background(Color.appSurfaceElevated, in: RoundedRectangle(cornerRadius: 16))
      }
      .padding(AppLayoutMetrics.mainMargin)
      .frame(maxWidth: AppLayoutMetrics.wideContentMaxWidth, alignment: .leading)
      .frame(maxWidth: .infinity, alignment: .center)
    }
    .navigationTitle(category.wrappedValue.displayName)
  }

  private func tickerMarketDataFields(ticker: Binding<TickerDraft>) -> some View {
    HStack(spacing: AppLayoutMetrics.gridGutter) {
      TextField("Current Price", text: ticker.currentPriceText)
        .keyboardType(.decimalPad)
        .focused($focusedField, equals: .tickerCurrentPrice(ticker.wrappedValue.id))
        .accessibilityIdentifier("holdings.ticker.currentPrice")

      TextField("Moving Average", text: ticker.movingAverageText)
        .keyboardType(.decimalPad)
        .focused($focusedField, equals: .tickerMovingAverage(ticker.wrappedValue.id))
        .accessibilityIdentifier("holdings.ticker.movingAverage")
    }
  }

  private func tickerControls(
    categoryID: UUID,
    tickerID: UUID,
    categoryName: String,
    tickerSymbol: String
  ) -> some View {
    HStack(spacing: 4) {
      Button {
        store.send(.moveTicker(categoryID: categoryID, tickerID: tickerID, direction: .up))
      } label: {
        Image(systemName: "chevron.up")
      }
      .disabled(firstTickerID(in: categoryID) == tickerID)
      .appMinimumTouchTarget()
      .accessibilityLabel("Move \(tickerSymbol) up in \(categoryName)")

      Button {
        store.send(.moveTicker(categoryID: categoryID, tickerID: tickerID, direction: .down))
      } label: {
        Image(systemName: "chevron.down")
      }
      .disabled(lastTickerID(in: categoryID) == tickerID)
      .appMinimumTouchTarget()
      .accessibilityLabel("Move \(tickerSymbol) down in \(categoryName)")

      Button(role: .destructive) {
        store.send(.deleteTicker(categoryID: categoryID, tickerID: tickerID))
      } label: {
        Image(systemName: "trash")
      }
      .tint(Color.appError)
      .appMinimumTouchTarget()
      .accessibilityLabel("Delete \(tickerSymbol) from \(categoryName)")
    }
    .buttonStyle(.borderless)
  }

  private func firstTickerID(in categoryID: UUID) -> UUID? {
    store.draft.categories.first(where: { $0.id == categoryID })?.tickers.first?.id
  }

  private func lastTickerID(in categoryID: UUID) -> UUID? {
    store.draft.categories.first(where: { $0.id == categoryID })?.tickers.last?.id
  }

  private func addCategory() {
    store.send(.addCategoryTapped)
    selectedCategoryID = store.draft.categories.last?.id
  }

  private func deleteCategories(at offsets: IndexSet) {
    let deletedIDs = offsets.map { store.draft.categories[$0].id }
    for id in deletedIDs {
      store.send(.deleteCategory(id: id))
    }
    if let selectedCategoryID, deletedIDs.contains(selectedCategoryID) {
      self.selectedCategoryID = store.draft.categories.first?.id
    }
  }

  private func selectInitialCategoryIfNeeded() {
    guard !store.draft.categories.isEmpty else {
      selectedCategoryID = nil
      return
    }

    if selectedCategoryID == nil
      || !store.draft.categories.contains(where: { $0.id == selectedCategoryID })
    {
      selectedCategoryID = store.draft.categories.first?.id
    }
  }

  private func validationSummaryColor(for issues: [HoldingsDraftIssue]) -> Color {
    issues.contains(where: \.blocksSaving) ? Color.appError : Color.appWarning
  }
}

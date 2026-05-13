import SwiftData
import SwiftUI

enum HoldingsDraftIssue: Equatable {
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
        case .emptyCategoryName, .invalidCategoryWeight, .emptyTickerSymbol, .invalidTickerMarketData, .duplicateTickerSymbols:
            return true
        case .noCategories, .categoryWeightsDoNotSumTo100, .categoryHasNoTickers, .missingTickerMarketData:
            return false
        }
    }
}

struct HoldingsDraft: Equatable {
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
        categories.append(CategoryDraft(
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
        if categories.contains(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
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

        let currentCategories = Dictionary(uniqueKeysWithValues: portfolio.categories.map { ($0.id, $0) })
        let requestedCategoryIDs = Set(categories.map(\.id))

        for category in portfolio.categories where !requestedCategoryIDs.contains(category.id) {
            modelContext.delete(category)
        }

        var updatedCategories: [Category] = []
        for (categoryIndex, categoryDraft) in categories.enumerated() {
            let category = currentCategories[categoryDraft.id] ?? Category(
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

    private func applyTickers(_ tickerDrafts: [TickerDraft], to category: Category, in modelContext: ModelContext) {
        let currentTickers = Dictionary(uniqueKeysWithValues: category.tickers.map { ($0.id, $0) })
        let requestedTickerIDs = Set(tickerDrafts.map(\.id))

        for ticker in category.tickers where !requestedTickerIDs.contains(ticker.id) {
            modelContext.delete(ticker)
        }

        var updatedTickers: [Ticker] = []
        for (tickerIndex, tickerDraft) in tickerDrafts.enumerated() {
            let ticker = currentTickers[tickerDraft.id] ?? Ticker(
                id: tickerDraft.id,
                symbol: tickerDraft.normalizedSymbol,
                currentPrice: tickerDraft.currentPrice,
                movingAverage: tickerDraft.movingAverage,
                sortOrder: tickerIndex
            )
            if currentTickers[tickerDraft.id] == nil {
                modelContext.insert(ticker)
            }

            ticker.symbol = tickerDraft.normalizedSymbol
            ticker.currentPrice = tickerDraft.currentPrice
            ticker.movingAverage = tickerDraft.movingAverage
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

enum HoldingsEditorValidationError: LocalizedError, Equatable {
    case issue(HoldingsDraftIssue)

    var errorDescription: String? {
        switch self {
        case .issue(let issue):
            return issue.message
        }
    }
}

enum MoveDirection {
    case up
    case down
}

struct CategoryDraft: Identifiable, Equatable {
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

struct TickerDraft: Identifiable, Equatable {
    let id: UUID
    var symbol: String
    var currentPriceText: String
    var movingAverageText: String
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        symbol: String,
        currentPrice: Decimal? = nil,
        movingAverage: Decimal? = nil,
        sortOrder: Int
    ) {
        self.id = id
        self.symbol = symbol
        self.currentPriceText = Self.displayDecimalText(for: currentPrice)
        self.movingAverageText = Self.displayDecimalText(for: movingAverage)
        self.sortOrder = sortOrder
    }

    init(ticker: Ticker) {
        id = ticker.id
        symbol = ticker.symbol
        currentPriceText = Self.displayDecimalText(for: ticker.currentPrice)
        movingAverageText = Self.displayDecimalText(for: ticker.movingAverage)
        sortOrder = ticker.sortOrder
    }

    var normalizedSymbol: String {
        symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    var currentPrice: Decimal? {
        Self.validPositiveDecimal(from: currentPriceText)
    }

    var movingAverage: Decimal? {
        Self.validPositiveDecimal(from: movingAverageText)
    }

    var hasCompleteMarketData: Bool {
        currentPrice != nil && movingAverage != nil
    }

    var hasInvalidMarketData: Bool {
        Self.hasInvalidPositiveDecimal(currentPriceText) || Self.hasInvalidPositiveDecimal(movingAverageText)
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
        return formatter.string(from: NSDecimalNumber(decimal: decimal)) ?? NSDecimalNumber(decimal: decimal).stringValue
    }

    private static func validPositiveDecimal(from text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Decimal(string: trimmed), value > 0 else {
            return nil
        }
        return value
    }

    private static func hasInvalidPositiveDecimal(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }
        return validPositiveDecimal(from: trimmed) == nil
    }
}

struct HoldingsEditorView: View {
    let portfolio: Portfolio

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var draft: HoldingsDraft
    @State private var saveError: SaveError?

    init(portfolio: Portfolio) {
        self.portfolio = portfolio
        _draft = State(initialValue: HoldingsDraft(portfolio: portfolio))
    }

    var body: some View {
        Form {
            if draft.categories.isEmpty {
                ContentUnavailableView {
                    Label("No Categories", systemImage: "folder.badge.plus")
                } description: {
                    Text("Add a category to start organizing tickers.")
                } actions: {
                    addCategoryButton
                }
            } else {
                validationSection

                ForEach($draft.categories) { $category in
                    categorySection(category: $category)
                }
            }
        }
        .navigationTitle("Edit Holdings")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .primaryAction) {
                addCategoryButton
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .accessibilityIdentifier("holdings.editor.save")
            }
        }
        .alert(item: $saveError) { error in
            Alert(
                title: Text("Could Not Save Holdings"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var addCategoryButton: some View {
        Button {
            draft.addCategory()
        } label: {
            Label("Add Category", systemImage: "plus")
        }
        .accessibilityIdentifier("holdings.category.add")
    }

    @ViewBuilder
    private var validationSection: some View {
        let issues = draft.issues()
        if !issues.isEmpty {
            Section("Warnings") {
                ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
                    Label(issue.message, systemImage: issue.blocksSaving ? "exclamationmark.triangle.fill" : "exclamationmark.circle")
                        .foregroundStyle(issue.blocksSaving ? .red : .orange)
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
                .accessibilityIdentifier("holdings.category.weight")

            if category.wrappedValue.tickers.isEmpty {
                Label("Warning: no tickers", systemImage: "exclamationmark.circle")
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("holdings.category.warning")
            }

            ForEach(category.tickers) { $ticker in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Ticker symbol", text: $ticker.symbol)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("holdings.ticker.symbol")

                        Button {
                            category.wrappedValue.moveTicker(id: ticker.id, direction: .up)
                        } label: {
                            Image(systemName: "chevron.up")
                        }
                        .disabled(category.wrappedValue.tickers.first?.id == ticker.id)

                        Button {
                            category.wrappedValue.moveTicker(id: ticker.id, direction: .down)
                        } label: {
                            Image(systemName: "chevron.down")
                        }
                        .disabled(category.wrappedValue.tickers.last?.id == ticker.id)

                        Button(role: .destructive) {
                            category.wrappedValue.deleteTicker(id: ticker.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }

                    HStack {
                        TextField("Current Price", text: $ticker.currentPriceText)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("holdings.ticker.currentPrice")

                        TextField("Moving Average", text: $ticker.movingAverageText)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("holdings.ticker.movingAverage")
                    }

                    if let message = ticker.marketDataStatusMessage {
                        Label(message, systemImage: ticker.hasInvalidMarketData ? "exclamationmark.triangle.fill" : "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(ticker.hasInvalidMarketData ? .red : .orange)
                            .accessibilityIdentifier("holdings.ticker.marketDataWarning")
                    }
                }
            }

            Button {
                category.wrappedValue.addTicker()
            } label: {
                Label("Add Ticker", systemImage: "plus")
            }
            .accessibilityIdentifier("holdings.ticker.add")
        } header: {
            HStack {
                Text(category.wrappedValue.displayName)
                Spacer()
                categoryControls(categoryID: category.wrappedValue.id)
            }
        }
        .accessibilityIdentifier("holdings.category.section")
    }

    private func categoryControls(categoryID: UUID) -> some View {
        HStack {
            Button {
                draft.moveCategory(id: categoryID, direction: .up)
            } label: {
                Image(systemName: "chevron.up")
            }
            .disabled(draft.categories.first?.id == categoryID)

            Button {
                draft.moveCategory(id: categoryID, direction: .down)
            } label: {
                Image(systemName: "chevron.down")
            }
            .disabled(draft.categories.last?.id == categoryID)

            Button(role: .destructive) {
                draft.deleteCategory(id: categoryID)
            } label: {
                Image(systemName: "trash")
            }
        }
        .buttonStyle(.borderless)
    }

    private func save() {
        do {
            try draft.apply(to: portfolio, in: modelContext)
            dismiss()
        } catch let error as HoldingsEditorValidationError {
            saveError = SaveError(message: error.localizedDescription)
        } catch {
            saveError = SaveError(message: error.localizedDescription)
        }
    }
}

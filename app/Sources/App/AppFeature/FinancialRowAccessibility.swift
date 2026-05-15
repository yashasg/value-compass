import Foundation

/// VoiceOver label / value composers for the multi-text "financial row"
/// surfaces called out in #227. SwiftUI's default behaviour exposes each
/// `Text` inside an `HStack` as an independent accessibility element, so a
/// row like `[VTI] [$250.00] [25%]` reaches a VoiceOver user as three
/// unrelated focus targets with no programmatic relationship to the ticker
/// they belong to (WCAG 2.2 SC 1.3.1 / SC 4.1.2). The fix at the view
/// layer is to collapse each row into a single element with an explicit
/// label (the ticker / category) and an explicit value (the financial
/// breakdown that the row encodes).
///
/// The string composition lives here — at file scope, not nested inside a
/// view — so unit tests can pin the exact spoken contract for each row
/// type without spinning up a SwiftUI host. Currency / percent strings are
/// produced through `Decimal.appCurrencyFormatted()` and
/// `Decimal.appPercentFormatted()` so VoiceOver pronounces "dollars" and
/// "percent" via the locale-tagged formatters (the #257 fix) rather than
/// the literal glyphs.
enum FinancialRowAccessibility {
  // MARK: - ContributionResultView allocation row

  /// VoiceOver label for `ContributionResultView`'s per-ticker allocation
  /// row (`Sources/Features/ContributionResultView.swift`). The label is
  /// the ticker symbol the row is "about"; the dollar / percent
  /// breakdown is the row's value.
  static func label(forResultAllocation allocation: TickerContributionAllocation) -> String {
    allocation.tickerSymbol
  }

  static func value(forResultAllocation allocation: TickerContributionAllocation) -> String {
    "\(allocation.amount.appCurrencyFormatted()), \(allocation.allocatedWeight.appPercentFormatted())"
  }

  // MARK: - ContributionResultView category header row

  /// VoiceOver label for the per-category header row that sits above
  /// each category's allocation list in `ContributionResultView`. The
  /// row encodes `<category name> [Spacer] <category amount>`; on its
  /// own that splits into two unlabeled focus targets, so we collapse
  /// it the same way as the allocation rows below it.
  static func label(forResultCategory category: CategoryContributionResult) -> String {
    category.categoryName
  }

  static func value(forResultCategory category: CategoryContributionResult) -> String {
    category.amount.appCurrencyFormatted()
  }

  // MARK: - PortfolioDetailView ticker market-data row

  /// VoiceOver label for the per-ticker market-data row in
  /// `PortfolioDetailView` (`Sources/Features/PortfolioDetailView.swift`).
  /// Both the regular-width (4 cells: symbol, current price, MA, status)
  /// and compact (symbol + summary) layouts collapse to the same
  /// spoken contract: label = symbol, value = readable price/MA/status
  /// sentence.
  static func label(forTicker ticker: TickerSnapshot) -> String {
    ticker.normalizedSymbol
  }

  static func value(forTicker ticker: TickerSnapshot, maWindow: Int) -> String {
    let status = ticker.hasCompleteMarketData ? "Ready" : "Missing market data"
    guard
      ticker.hasCompleteMarketData,
      let price = ticker.currentPrice,
      let movingAverage = ticker.movingAverage
    else {
      return status
    }
    return
      "Price \(price.appCurrencyFormatted()), \(maWindow)-day moving average \(movingAverage.appCurrencyFormatted()), status \(status)"
  }

  // MARK: - ContributionHistoryView detail breakdown row

  /// VoiceOver label for the per-ticker breakdown row inside the saved-
  /// result detail surface (`Sources/Features/ContributionHistoryView.swift`).
  /// The row shows `<symbol> [Spacer] <amount>` and a secondary
  /// `<category name>` line; all three are collapsed into one element so
  /// the symbol, amount, and category are spoken together.
  static func label(forHistoryAllocation allocation: TickerAllocationSnapshot) -> String {
    allocation.tickerSymbol
  }

  static func value(forHistoryAllocation allocation: TickerAllocationSnapshot) -> String {
    "\(allocation.amount.appCurrencyFormatted()), \(allocation.categoryName)"
  }
}

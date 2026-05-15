import Foundation
import SwiftData

// MVP-only SwiftData models that complement the legacy contribution-history
// schema in `DomainModels.swift`. These types are *additive*: they do not
// modify or replace any existing `@Model` type. Once feature reducers migrate
// to the MVP shape (#123), the legacy contribution-history models will be
// removed in a follow-up change.
//
// ## Cascade contract
// `Holding` and `InvestSnapshot` reference their owning `Portfolio` by
// `portfolioId` (UUID), not by SwiftData `@Relationship`. This intentionally
// keeps shared market data (`MarketDataBar`) safe from cascade deletes when
// a portfolio is removed, and keeps `DomainModels.swift` untouched so the
// legacy reducers remain bit-identical until they migrate.
//
// `PortfolioCascadeDeleter` (under `Backend/Persistence/`) owns the explicit
// "delete portfolio + dependent rows" sequence; deleting a `Portfolio`
// directly via `ModelContext.delete` will *not* cascade to MVP rows. The
// `MVPModelsPersistenceTests` suite asserts this contract end-to-end.

/// One symbol-only line item inside a `Portfolio`. The MVP holding drops the
/// derived indicator outputs (`currentPrice` / `movingAverage` /
/// `bandPosition`) that live on the legacy `Ticker` — those outputs belong
/// on the shared `MarketDataBar` rows once the Massive client (#128) lands.
@Model
final class Holding {
  @Attribute(.unique) var id: UUID
  var portfolioId: UUID
  var symbol: String
  var costBasis: Decimal
  var shares: Decimal
  var sortOrder: Int
  var createdAt: Date

  init(
    id: UUID = UUID(),
    portfolioId: UUID,
    symbol: String,
    costBasis: Decimal = 0,
    shares: Decimal = 0,
    sortOrder: Int = 0,
    createdAt: Date = Date()
  ) {
    self.id = id
    self.portfolioId = portfolioId
    self.symbol = symbol
    self.costBasis = costBasis
    self.shares = shares
    self.sortOrder = sortOrder
    self.createdAt = createdAt
  }

  var normalizedSymbol: String {
    Holding.normalize(symbol: symbol)
  }

  static func normalize(symbol: String) -> String {
    symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
  }
}

/// Bundled metadata for an exchange-listed equity or ETF. Used by the
/// typeahead picker (#126). Symbol is the unique key; the row is replaced
/// in place when bundled metadata is refreshed at app launch.
@Model
final class TickerMetadata {
  @Attribute(.unique) var symbol: String
  var name: String
  var exchange: String
  var assetClass: String
  var isActive: Bool

  init(
    symbol: String,
    name: String,
    exchange: String,
    assetClass: AssetClass,
    isActive: Bool = true
  ) {
    self.symbol = TickerMetadata.normalize(symbol: symbol)
    self.name = name
    self.exchange = exchange
    self.assetClass = assetClass.rawValue
    self.isActive = isActive
  }

  enum AssetClass: String {
    case equity = "EQUITY"
    case etf = "ETF"
  }

  var assetClassValue: AssetClass? {
    AssetClass(rawValue: assetClass)
  }

  static func normalize(symbol: String) -> String {
    symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
  }
}

/// One end-of-day OHLC bar for a symbol on a calendar date. Bars are shared
/// across portfolios — never cascade-deleted with a portfolio. Identity is
/// the string `"<SYMBOL>|<yyyy-MM-dd-UTC>"` to provide compound uniqueness
/// without relying on a SwiftData feature it doesn't support.
@Model
final class MarketDataBar {
  @Attribute(.unique) var id: String
  var symbol: String
  var date: Date
  var open: Decimal
  var high: Decimal
  var low: Decimal
  var close: Decimal
  var volume: Int
  var fetchedAt: Date

  init(
    symbol: String,
    date: Date,
    open: Decimal,
    high: Decimal,
    low: Decimal,
    close: Decimal,
    volume: Int = 0,
    fetchedAt: Date = Date()
  ) {
    let normalizedSymbol = MarketDataBar.normalize(symbol: symbol)
    let normalizedDate = MarketDataBar.startOfUTCDay(for: date)
    self.id = MarketDataBar.makeID(symbol: normalizedSymbol, date: normalizedDate)
    self.symbol = normalizedSymbol
    self.date = normalizedDate
    self.open = open
    self.high = high
    self.low = low
    self.close = close
    self.volume = volume
    self.fetchedAt = fetchedAt
  }

  /// Build the canonical row identifier for `(symbol, date)`. The symbol is
  /// uppercased, the date is normalized to the start of the UTC day, then
  /// rendered as `yyyy-MM-dd`. This keeps round-tripping through the
  /// Massive client deterministic regardless of the caller's time zone.
  static func makeID(symbol: String, date: Date) -> String {
    let normalizedSymbol = normalize(symbol: symbol)
    let normalizedDate = startOfUTCDay(for: date)
    return "\(normalizedSymbol)|\(idDateFormatter.string(from: normalizedDate))"
  }

  static func normalize(symbol: String) -> String {
    symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
  }

  static func startOfUTCDay(for date: Date) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
    return calendar.startOfDay(for: date)
  }

  private static let idDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = TimeZone(identifier: "UTC") ?? .current
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()
}

/// Decoded form of `InvestSnapshot.compositionJSON`. Captures the
/// portfolio composition (categories, weights, member symbols) at snapshot
/// time so a snapshot can be re-computed later without depending on the
/// then-current portfolio.
struct CategorySnapshotInput: Codable, Equatable {
  var name: String
  var weight: Decimal
  var symbols: [String]
}

/// A snapshot of an "Invest" calculation's *inputs* and metadata only. Per
/// #131, snapshots never persist displayed outputs or market-data blobs —
/// they record only what the user can re-compute later: portfolio
/// composition (encoded as `[CategorySnapshotInput]` JSON), VCA parameters,
/// the shared market-data window the snapshot referenced, and any warnings
/// emitted by the calculation.
@Model
final class InvestSnapshot {
  @Attribute(.unique) var id: UUID
  var portfolioId: UUID
  var capturedAt: Date
  var capitalAmount: Decimal
  var maWindow: Int
  var marketDataWindowStart: Date
  var marketDataWindowEnd: Date
  /// JSON-encoded `[CategorySnapshotInput]`.
  var compositionJSON: String
  /// JSON-encoded `[String]` of warnings emitted at calculation time.
  var warningsJSON: String

  init(
    id: UUID = UUID(),
    portfolioId: UUID,
    capturedAt: Date = Date(),
    capitalAmount: Decimal,
    maWindow: Int,
    marketDataWindowStart: Date,
    marketDataWindowEnd: Date,
    compositionJSON: String,
    warningsJSON: String = "[]"
  ) {
    self.id = id
    self.portfolioId = portfolioId
    self.capturedAt = capturedAt
    self.capitalAmount = capitalAmount
    self.maWindow = maWindow
    self.marketDataWindowStart = marketDataWindowStart
    self.marketDataWindowEnd = marketDataWindowEnd
    self.compositionJSON = compositionJSON
    self.warningsJSON = warningsJSON
  }

  /// Convenience: encode `composition` and `warnings` as JSON before storing.
  /// Throws the encoder's error so callers see real failures instead of a
  /// silent empty array.
  convenience init(
    portfolioId: UUID,
    capturedAt: Date = Date(),
    capitalAmount: Decimal,
    maWindow: Int,
    marketDataWindowStart: Date,
    marketDataWindowEnd: Date,
    composition: [CategorySnapshotInput],
    warnings: [String] = []
  ) throws {
    let compositionData = try InvestSnapshot.encoder.encode(composition)
    let warningsData = try InvestSnapshot.encoder.encode(warnings)
    self.init(
      portfolioId: portfolioId,
      capturedAt: capturedAt,
      capitalAmount: capitalAmount,
      maWindow: maWindow,
      marketDataWindowStart: marketDataWindowStart,
      marketDataWindowEnd: marketDataWindowEnd,
      compositionJSON: String(decoding: compositionData, as: UTF8.self),
      warningsJSON: String(decoding: warningsData, as: UTF8.self)
    )
  }

  func decodedComposition() throws -> [CategorySnapshotInput] {
    let data = Data(compositionJSON.utf8)
    return try InvestSnapshot.decoder.decode([CategorySnapshotInput].self, from: data)
  }

  func decodedWarnings() throws -> [String] {
    let data = Data(warningsJSON.utf8)
    return try InvestSnapshot.decoder.decode([String].self, from: data)
  }

  private static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }()

  private static let decoder = JSONDecoder()
}

/// Single-row settings record for the MVP. Keyed by a fixed `singletonID` so
/// the row can be upserted without ambiguity. Use `AppSettingsRepository.loadOrSeed`
/// to fetch or create the row.
@Model
final class AppSettings {
  static let singletonID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!

  @Attribute(.unique) var id: UUID
  var themePreference: String
  var backgroundRefreshEnabled: Bool
  /// Stored for v2 even though the MVP does not send notifications (#133).
  var notificationsOptIn: Bool
  var hasAcceptedDisclaimer: Bool

  init(
    id: UUID = AppSettings.singletonID,
    themePreference: ThemePreference = .system,
    backgroundRefreshEnabled: Bool = false,
    notificationsOptIn: Bool = false,
    hasAcceptedDisclaimer: Bool = false
  ) {
    self.id = id
    self.themePreference = themePreference.rawValue
    self.backgroundRefreshEnabled = backgroundRefreshEnabled
    self.notificationsOptIn = notificationsOptIn
    self.hasAcceptedDisclaimer = hasAcceptedDisclaimer
  }

  enum ThemePreference: String {
    case system
    case light
    case dark
  }

  var themePreferenceValue: ThemePreference? {
    ThemePreference(rawValue: themePreference)
  }
}

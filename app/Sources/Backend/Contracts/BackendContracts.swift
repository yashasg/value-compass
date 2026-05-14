import Foundation

/// Marker namespace for the Backend boundary.
///
/// `Sources/Backend/` is the only place active code may depend on
/// SwiftData models, Keychain APIs, the Massive client, technical-indicator
/// wrappers (TA-Lib), and the local VCA calculation engine. App and Feature
/// layers should depend on protocols re-exported here, never on those
/// underlying implementations directly.
///
/// Concrete protocols land alongside their implementations:
/// - `Backend/Services/ContributionCalculator.swift` exposes
///   `ContributionCalculating` (already used by `MainView`).
/// - `Backend/Networking/...` exposes the API client and version monitor.
///
/// Future MVP work will populate this directory with:
/// - `MassiveAPIKeyStoring` — Keychain-backed Massive key storage (#127).
/// - `MarketDataProviding` — local EOD market-data refresh (#128).
/// - `TechnicalIndicating` — TA-Lib facade (#129).
/// - `TickerMetadataProviding` — bundled NYSE/ETF metadata (#126).
enum BackendContracts {}

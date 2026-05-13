import SwiftUI
import XCTest
@testable import VCA

final class NavigationShellTests: XCTestCase {
    func testCompactWidthUsesNavigationStack() {
        XCTAssertEqual(MainView.navigationShellKind(for: .compact), .stack)
    }

    func testRegularWidthUsesNavigationSplitView() {
        XCTAssertEqual(MainView.navigationShellKind(for: .regular), .splitView)
    }

    func testPortfolioDraftTrimsAndValidatesPortfolioValues() throws {
        let draft = PortfolioFormDraft(name: "  Long Term  ", monthlyBudgetText: "250.75", maWindow: 200)

        let values = try draft.validatedValues()

        XCTAssertEqual(values.name, "Long Term")
        XCTAssertEqual(values.monthlyBudget, Decimal(string: "250.75"))
        XCTAssertEqual(values.maWindow, 200)
    }

    func testPortfolioDraftRejectsInvalidValuesBeforeSave() {
        XCTAssertThrowsError(try PortfolioFormDraft(name: " ", monthlyBudgetText: "100", maWindow: 50).validatedValues()) { error in
            XCTAssertEqual(error as? PortfolioEditorValidationError, .emptyName)
        }
        XCTAssertThrowsError(try PortfolioFormDraft(name: "Core", monthlyBudgetText: "0", maWindow: 50).validatedValues()) { error in
            XCTAssertEqual(error as? PortfolioEditorValidationError, .invalidBudget)
        }
        XCTAssertThrowsError(try PortfolioFormDraft(name: "Core", monthlyBudgetText: "100", maWindow: 100).validatedValues()) { error in
            XCTAssertEqual(error as? PortfolioEditorValidationError, .invalidMAWindow(100))
        }
    }

    func testPortfolioDraftCreatesAndUpdatesModelOnlyOnApply() throws {
        let created = try PortfolioFormDraft(name: "Core", monthlyBudgetText: "1000", maWindow: 50).makePortfolio()

        XCTAssertEqual(created.name, "Core")
        XCTAssertEqual(created.monthlyBudget, Decimal(1_000))
        XCTAssertEqual(created.maWindow, 50)

        let editDraft = PortfolioFormDraft(name: "Core Updated", monthlyBudgetText: "1500", maWindow: 200)
        XCTAssertEqual(created.name, "Core")

        try editDraft.apply(to: created)

        XCTAssertEqual(created.name, "Core Updated")
        XCTAssertEqual(created.monthlyBudget, Decimal(1_500))
        XCTAssertEqual(created.maWindow, 200)
    }
}

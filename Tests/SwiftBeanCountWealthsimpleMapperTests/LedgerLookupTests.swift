import SwiftBeanCountModel
@testable import SwiftBeanCountWealthsimpleMapper
import Wealthsimple
import XCTest

struct TestAccount: Wealthsimple.Account {
    var accountType = Wealthsimple.AccountType.nonRegistered
    var number = ""
    var id = ""
    var currency = ""
}

final class LedgerLookupTests: XCTestCase {

    private let accountName = try! AccountName("Assets:Test") // swiftlint:disable:this force_try
    private var ledger = Ledger()
    private var ledgerLookup: LedgerLookup!

    override func setUpWithError() throws {
        ledger = Ledger()
        ledgerLookup = LedgerLookup(ledger)
    }

    func testLedgerAccountCommoditySymbol() throws {
        let name2 = try AccountName("Assets:Test1")
        let symbol = "CAD"

        // account does not exist
        XCTAssertNil(ledgerLookup.ledgerAccountCommoditySymbol(of: accountName))

        // account does not have a commodity
        try ledger.add(Account(name: accountName))
        ledgerLookup = LedgerLookup(ledger)
        XCTAssertNil(ledgerLookup.ledgerAccountCommoditySymbol(of: accountName))

        // account has a commodity
        try ledger.add(Account(name: name2, commoditySymbol: symbol))
        ledgerLookup = LedgerLookup(ledger)
        XCTAssertNil(ledgerLookup.ledgerAccountCommoditySymbol(of: accountName))
        XCTAssertEqual(ledgerLookup.ledgerAccountCommoditySymbol(of: name2), symbol)

    }

    func testLedgerAccountNameOf() throws {
        let account = TestAccount(number: "abc")

        // not found
        assert(
            try ledgerLookup.ledgerAccountName(of: account),
            throws: WealthsimpleConversionError.missingWealthsimpleAccount("abc")
        )

        // base account
        try ledger.add(Commodity(symbol: "XGRO"))
        try ledger.add(Account(name: accountName, metaData: ["importer-type": "wealthsimple", "number": "abc"]))
        ledgerLookup = LedgerLookup(ledger)
        XCTAssertEqual(try ledgerLookup.ledgerAccountName(of: account), accountName)

        // commodity account
        XCTAssertEqual(try ledgerLookup.ledgerAccountName(of: account, symbol: "XGRO"), try AccountName("Assets:XGRO"))

        // invalid commodity symbol
        try ledger.add(Commodity(symbol: "XGRO:"))
        assert(
            try ledgerLookup.ledgerAccountName(of: account, symbol: "XGRO:"),
            throws: WealthsimpleConversionError.invalidCommoditySymbol("XGRO:")
        )
    }

    func testLedgerAccountNameFor() throws {
        var number = "abc123"

        // fallback for payment spend
        XCTAssertEqual(try ledgerLookup.ledgerAccountName(for: .transactionType(.paymentSpend), in: TestAccount(number: number), ofType: [.expense] ),
                       WealthsimpleLedgerMapper.fallbackExpenseAccountName)

        // not found
        assert(try ledgerLookup.ledgerAccountName(for: .rounding, in: TestAccount(number: number), ofType: [.income]),
               throws: WealthsimpleConversionError.missingAccount(MetaDataKeys.rounding, number, "Income"))
        assert(try ledgerLookup.ledgerAccountName(for: .transactionType(.dividend), in: TestAccount(number: number), ofType: [.income]),
               throws: WealthsimpleConversionError.missingAccount("\(MetaDataKeys.prefix)\(TransactionType.dividend)", number, "Income"))

        // rounding
        try ledger.add(Account(name: accountName, metaData: [MetaDataKeys.rounding: number]))
        ledgerLookup = LedgerLookup(ledger)
        XCTAssertEqual(try ledgerLookup.ledgerAccountName(for: .rounding, in: TestAccount(number: number), ofType: [.asset] ), accountName)

        // wrong type
        assert(try ledgerLookup.ledgerAccountName(for: .rounding, in: TestAccount(number: number), ofType: [.income, .expense, .equity] ),
               throws: WealthsimpleConversionError.missingAccount(MetaDataKeys.rounding, number, "Income, or Expenses, or Equity"))

        // multiple numbers
        var name = try AccountName("Assets:Test:Two")
        number = "def456"
        let number2 = "ghi789"
        try ledger.add(Account(name: name, metaData: [MetaDataKeys.rounding: "\(number) \(number2)"]))
        ledgerLookup = LedgerLookup(ledger)
        XCTAssertEqual(try ledgerLookup.ledgerAccountName(for: .rounding, in: TestAccount(number: number), ofType: [.asset] ), name)
        XCTAssertEqual(try ledgerLookup.ledgerAccountName(for: .rounding, in: TestAccount(number: number2), ofType: [.asset] ), name)

        // contribution room
        name = try AccountName("Assets:Test:Three")
        try ledger.add(Account(name: name, metaData: [MetaDataKeys.contributionRoom: number]))
        ledgerLookup = LedgerLookup(ledger)
        XCTAssertEqual(try ledgerLookup.ledgerAccountName(for: .contributionRoom, in: TestAccount(number: number), ofType: [.asset] ), name)

        // dividend + transaction type multi key
        name = try AccountName("Income:Test")
        let symbol = "XGRO"
        try ledger.add(Account(name: name, metaData: ["\(MetaDataKeys.dividendPrefix)\(symbol)": number, "\(MetaDataKeys.prefix)giveaway-bonus": number]))
        try ledger.add(Commodity(symbol: symbol))
        ledgerLookup = LedgerLookup(ledger)
        XCTAssertEqual(try ledgerLookup.ledgerAccountName(for: .dividend(symbol), in: TestAccount(number: number), ofType: [.income] ), name)
        XCTAssertEqual(try ledgerLookup.ledgerAccountName(for: .transactionType(.giveawayBonus), in: TestAccount(number: number), ofType: [.income] ), name)
    }

    func testDoesTransactionExistInLedger() {
        var metaData = TransactionMetaData(date: Date(), metaData: [MetaDataKeys.id: "abc"])
        var transaction = Transaction(metaData: metaData, postings: [])
        ledger.add(transaction)
        var ledgerLookup = LedgerLookup(ledger)

        // same transaction
        XCTAssert(ledgerLookup.doesTransactionExistInLedger(transaction))

        // different date
        metaData = TransactionMetaData(date: Date(timeIntervalSinceReferenceDate: 0), metaData: [MetaDataKeys.id: "abc"])
        transaction = Transaction(metaData: metaData, postings: [])
        XCTAssert(ledgerLookup.doesTransactionExistInLedger(transaction))

        // nrwt id
        metaData = TransactionMetaData(date: Date(), metaData: [MetaDataKeys.nrwtId: "abcd"])
        transaction = Transaction(metaData: metaData, postings: [])
        ledger.add(transaction)
        ledgerLookup = LedgerLookup(ledger)
        metaData = TransactionMetaData(date: Date(), metaData: [MetaDataKeys.id: "abcd"])
        transaction = Transaction(metaData: metaData, postings: [])
        XCTAssert(ledgerLookup.doesTransactionExistInLedger(transaction))

        // different id
        metaData = TransactionMetaData(date: Date(), metaData: [MetaDataKeys.id: "abc1"])
        transaction = Transaction(metaData: metaData, postings: [])
        XCTAssertFalse(ledgerLookup.doesTransactionExistInLedger(transaction))

        // no id
        metaData = TransactionMetaData(date: Date())
        transaction = Transaction(metaData: metaData, postings: [])
        XCTAssertFalse(ledgerLookup.doesTransactionExistInLedger(transaction))
    }

    func testDoesPriceExistInLedger() throws {
        let date = Date()
        var price = try Price(date: date, commoditySymbol: "CAD", amount: Amount(number: Decimal(1), commoditySymbol: "EUR"))
        try ledger.add(price)
        ledgerLookup = LedgerLookup(ledger)

        // same price
        XCTAssert(ledgerLookup.doesPriceExistInLedger(price))

        // different price object with same properties
        price = try Price(date: date, commoditySymbol: "CAD", amount: Amount(number: Decimal(1), commoditySymbol: "EUR"))
        XCTAssert(ledgerLookup.doesPriceExistInLedger(price))

        // different date
        price = try Price(date: Date(timeIntervalSinceReferenceDate: 0), commoditySymbol: "CAD", amount: Amount(number: Decimal(1), commoditySymbol: "EUR"))
        XCTAssertFalse(ledgerLookup.doesPriceExistInLedger(price))

        // different commodity
        price = try Price(date: date, commoditySymbol: "CAD", amount: Amount(number: Decimal(1), commoditySymbol: "USD"))
        XCTAssertFalse(ledgerLookup.doesPriceExistInLedger(price))
    }

    func testDoesBalanceExistInLedger() throws {
        let date = Date()
        var balance = Balance(date: date, accountName: accountName, amount: Amount(number: Decimal(1), commoditySymbol: "USD"))
        ledger.add(balance)
        ledgerLookup = LedgerLookup(ledger)

        // same balance
        XCTAssert(ledgerLookup.doesBalanceExistInLedger(balance))

        // different balance object with same properties
        balance = Balance(date: date, accountName: accountName, amount: Amount(number: Decimal(1), commoditySymbol: "USD"))
        XCTAssert(ledgerLookup.doesBalanceExistInLedger(balance))

        // different date
        balance = Balance(date: Date(timeIntervalSinceReferenceDate: 0), accountName: accountName, amount: Amount(number: Decimal(1), commoditySymbol: "USD"))
        XCTAssertFalse(ledgerLookup.doesBalanceExistInLedger(balance))

        // different commodity
        balance = Balance(date: date, accountName: accountName, amount: Amount(number: Decimal(1), commoditySymbol: "EUR"))
        XCTAssertFalse(ledgerLookup.doesBalanceExistInLedger(balance))

        // different account
        balance = Balance(date: date, accountName: try AccountName("Assets:TEST1"), amount: Amount(number: Decimal(1), commoditySymbol: "USD"))
        XCTAssertFalse(ledgerLookup.doesBalanceExistInLedger(balance))
    }

    func testCommoditySymbolForAssetSymbol() throws {
        var commodity = Commodity(symbol: "EUR")
        try ledger.add(commodity)
        ledgerLookup = LedgerLookup(ledger)

        // not existing
        assert(
            try ledgerLookup.commoditySymbol(for: "USD"),
            throws: WealthsimpleConversionError.missingCommodity("USD")
        )

        // fallback
        XCTAssertEqual(try ledgerLookup.commoditySymbol(for: "EUR"), "EUR")

        // mapping exists
        commodity = Commodity(symbol: "USDABC", metaData: [MetaDataKeys.commoditySymbol: "USD"])
        try ledger.add(commodity)
        ledgerLookup = LedgerLookup(ledger)
        XCTAssertEqual(try ledgerLookup.commoditySymbol(for: "USD"), "USDABC")

        // mapping + fallback exists
        commodity = Commodity(symbol: "USD")
        try ledger.add(commodity)
        ledgerLookup = LedgerLookup(ledger)
        XCTAssertEqual(try ledgerLookup.commoditySymbol(for: "USD"), "USDABC")
    }

}

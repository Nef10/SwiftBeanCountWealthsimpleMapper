//
//  WealthsimpleConversionError.swift
//  SwiftBeanCountWealthsimpleMapper
//
//  Created by Steffen Kötte on 2020-07-27.
//

import Foundation

/// Errors which can happen when transforming downloaded wealthsimple data into SwiftBeanCountModel types
public enum WealthsimpleConversionError: Error, Equatable {
    /// a commodity was not found in the ledger
    case missingCommodity(String)
    /// an account was not found in the ledger
    case missingAccount(String, String, String)
    /// a wealthsimple account was not found in the ledger
    case missingWealthsimpleAccount(String)
    /// mapping of this transaction type has not been implemented yet
    case unsupportedTransactionType(String)
    /// the descriptions of the wealthsimple transactions is not the correct format
    case unexpectedDescription(String)
    /// the account of the postion or transaction is not contained in the account property
    /// Did you forget to set it to the downloaded accounts before attempting mapping?
    case accountNotFound(String)
    /// A commodity symbol was used which cannot be used as account name string
    case invalidCommoditySymbol(String)
    /// A stock split was performed but two matching transactions do not exist
    case unexpectedStockSplit(String)
}

extension WealthsimpleConversionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .missingCommodity(symbol):
            return "The Commodity \(symbol) was not found in your ledger. Please make sure you add the metadata \"\(MetaDataKeys.commoditySymbol): \"\(symbol)\"\" to it."
        case let .missingAccount(key, number, category):
            return """
                The \(category) account for account number \(number) and key \(key) was not found in your ledger. \
                Please make sure you add the metadata \"\(key): \"\(number)\"" to it.
                """
        case let .missingWealthsimpleAccount(number):
            return """
                The account for the wealthsimple account with the number \(number) was not found in your ledger. \
                Please make sure you add the metadata \"\(MetaDataKeys.importerType): \"\(MetaData.importerType)\" \(MetaDataKeys.number): \"\(number)\"\" to it.
                """
        case let .unsupportedTransactionType(type):
            return "Transactions of Type \(type) are currently not yet supported"
        case let .unexpectedDescription(string):
            return "Wealthsimple returned an unexpected description for a transaction: \(string)"
        case let .accountNotFound(accountId):
            return "Wealthsimple returned an element from an account with id \(accountId) which was not found."
        case let .invalidCommoditySymbol(symbol):
            return "Could not generate account for commodity \(symbol). For the mapping to work commodity symbols must only contain charaters allowed in account names."
        case let .unexpectedStockSplit(description):
            return "A stock split happend, but not exactly two transaction could be found: \(description)"
        }
    }
}

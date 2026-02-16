

import AppKit



struct DatasCompte : Codable, Identifiable {

    var type: String
    var name: String
    var id: UUID

    var children: [DefAccount]
}

struct DefAccount : Codable, Hashable, Identifiable {

    var type: String
    var name: String
    var surName: String
    var numAccount: String
    var icon: String
    var solde: Double
    
    var id: UUID
}

struct Datas : Codable, Identifiable {

    var name: String
    var icon: String
    var id: UUID

    var children: [Children]
}

struct Children : Codable, Hashable, Identifiable {

    var nameView: String
    var name: String
    var icon: String
    var viewKind: String

    var id: UUID

    /// Returns the DetailViewKind matching this child's `viewKind` key.
    var detailViewKind: DetailViewKind? {
        DetailViewKind(rawValue: viewKind)
    }
}

// MARK: - DetailViewKind

/// Stable identifiers for detail views, independent of locale.
/// Each case maps to a specific view displayed in the content area.
enum DetailViewKind: String, Hashable, CaseIterable {
    // Suivi de trésorerie
    case transactionList
    case cashFlowCurve
    case filter
    case internetReconciliation
    case bankStatement
    case notes

    // Rapports
    case categoryBar1
    case categoryBar2
    case paymentMethod
    case incomeExpenseBar
    case incomeExpensePie
    case rubricBar
    case rubricPie

    // Référence compte
    case identity
    case scheduler
    case settings
}

protocol AnyDecoder {
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T
}

extension PropertyListDecoder: AnyDecoder {}

extension Bundle {
    /// Decode a plist file from the bundle
    /// - Parameters:
    ///   - type: The type to decode
    ///   - file: The file name (with extension)
    /// - Returns: The decoded object
    /// - Throws: ResourceError if file not found, failed to load, or failed to decode
    func decode<T: Decodable>(_ type: T.Type, from file: String) throws -> T {
        guard let url = self.url(forResource: file, withExtension: nil) else {
            throw ResourceError.fileNotFound(file)
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ResourceError.failedToLoad(file)
        }

        let decoder = PropertyListDecoder()
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw ResourceError.failedToDecode(file)
        }
    }

    /// Decode a plist file from the bundle with a default value fallback
    /// - Parameters:
    ///   - type: The type to decode
    ///   - file: The file name (with extension)
    ///   - defaultValue: The default value to return if decoding fails
    /// - Returns: The decoded object or the default value
    func decode<T: Decodable>(_ type: T.Type, from file: String, default defaultValue: T) -> T {
        do {
            return try decode(type, from: file)
        } catch {
            printTag("Warning: Failed to decode \(file): \(error.localizedDescription)")
            return defaultValue
        }
    }
}

//extension JSONDecoder: AnyDecoder {}
//
//extension Encodable {
//    func encoded() throws -> Data {
//        return try PropertyListEncoder().encode(self)
//    }
//}

//extension Data {
//    func decoded<T: Decodable>() throws -> T {
//        return try PropertyListDecoder().decode(T.self, from: self)
//    }
//}

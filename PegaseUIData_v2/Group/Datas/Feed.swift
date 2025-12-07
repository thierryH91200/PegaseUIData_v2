

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
    
    var id: UUID
}

protocol AnyDecoder {
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T
}

extension PropertyListDecoder: AnyDecoder {}

extension Bundle {
    func decode<T: Decodable>(_ type: T.Type, from file : String) -> T {
        guard let url = self.url(forResource: file, withExtension: nil) else {
            fatalError("faile to locate")
        }
        
        guard let data = try? Data(contentsOf: url) else {
            fatalError("faile to load")
        }
        
        let decoder = PropertyListDecoder()
        guard let loaded = try? decoder.decode(T.self, from : data) else {
            fatalError("faile to decode")
        }
        return loaded
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

import Foundation

/// Encodeur DER minimal : juste ce qu'il faut pour produire une signature
/// PKCS#7 (CMS SignedData) détachée, comme l'exige Apple Wallet.
nonisolated enum DER {
    static func tlv(_ tag: UInt8, _ content: [UInt8]) -> [UInt8] {
        [tag] + length(content.count) + content
    }

    static func length(_ count: Int) -> [UInt8] {
        if count < 0x80 { return [UInt8(count)] }
        var bytes: [UInt8] = []
        var value = count
        while value > 0 {
            bytes.insert(UInt8(value & 0xFF), at: 0)
            value >>= 8
        }
        return [0x80 | UInt8(bytes.count)] + bytes
    }

    static func sequence(_ items: [[UInt8]]) -> [UInt8] {
        tlv(0x30, items.flatMap { $0 })
    }

    /// SET OF : en DER, les éléments sont triés selon leur encodage.
    static func set(_ items: [[UInt8]]) -> [UInt8] {
        tlv(0x31, items.sorted { $0.lexicographicallyPrecedes($1) }.flatMap { $0 })
    }

    /// Balise contextuelle construite `[number]` (EXPLICIT, ou IMPLICIT d'un type construit).
    static func context(_ number: UInt8, _ content: [UInt8]) -> [UInt8] {
        tlv(0xA0 | number, content)
    }

    static func integer(_ value: Int) -> [UInt8] {
        precondition(value >= 0)
        var bytes: [UInt8] = []
        var remaining = value
        repeat {
            bytes.insert(UInt8(remaining & 0xFF), at: 0)
            remaining >>= 8
        } while remaining > 0
        if bytes[0] & 0x80 != 0 { bytes.insert(0, at: 0) }
        return tlv(0x02, bytes)
    }

    static func octetString(_ bytes: [UInt8]) -> [UInt8] {
        tlv(0x04, bytes)
    }

    static let null: [UInt8] = [0x05, 0x00]

    static func oid(_ dotted: String) -> [UInt8] {
        let arcs = dotted.split(separator: ".").map { UInt64($0)! }
        precondition(arcs.count >= 2)
        var body = base128(arcs[0] * 40 + arcs[1])
        for arc in arcs.dropFirst(2) {
            body += base128(arc)
        }
        return tlv(0x06, body)
    }

    static func utcTime(_ date: Date) -> [UInt8] {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyMMddHHmmss'Z'"
        return tlv(0x17, Array(formatter.string(from: date).utf8))
    }

    private static func base128(_ value: UInt64) -> [UInt8] {
        var remaining = value >> 7
        var bytes: [UInt8] = [UInt8(value & 0x7F)]
        while remaining > 0 {
            bytes.insert(UInt8(remaining & 0x7F) | 0x80, at: 0)
            remaining >>= 7
        }
        return bytes
    }
}

nonisolated enum OID {
    static let data = "1.2.840.113549.1.7.1"
    static let signedData = "1.2.840.113549.1.7.2"
    static let contentType = "1.2.840.113549.1.9.3"
    static let messageDigest = "1.2.840.113549.1.9.4"
    static let signingTime = "1.2.840.113549.1.9.5"
    static let sha256 = "2.16.840.1.101.3.4.2.1"
    static let rsaEncryption = "1.2.840.113549.1.1.1"
    static let userID = "0.9.2342.19200300.100.1.1"
    static let organizationalUnit = "2.5.4.11"
}

/// Élément DER décodé (tag, octets complets, contenu).
nonisolated struct DERElement {
    let tag: UInt8
    let bytes: [UInt8]
    let content: [UInt8]
}

nonisolated enum DERParser {
    nonisolated struct MalformedData: Error {}

    static func element(in bytes: [UInt8], at offset: Int = 0) throws -> (element: DERElement, next: Int) {
        guard offset + 2 <= bytes.count else { throw MalformedData() }
        let tag = bytes[offset]
        var index = offset + 1
        let first = bytes[index]
        index += 1
        var length = 0
        if first < 0x80 {
            length = Int(first)
        } else {
            let count = Int(first & 0x7F)
            guard count > 0, count <= 4, index + count <= bytes.count else { throw MalformedData() }
            for _ in 0..<count {
                length = (length << 8) | Int(bytes[index])
                index += 1
            }
        }
        guard index + length <= bytes.count else { throw MalformedData() }
        let element = DERElement(
            tag: tag,
            bytes: Array(bytes[offset..<(index + length)]),
            content: Array(bytes[index..<(index + length)])
        )
        return (element, index + length)
    }

    static func children(of bytes: [UInt8]) throws -> [DERElement] {
        var result: [DERElement] = []
        var offset = 0
        while offset < bytes.count {
            let parsed = try Self.element(in: bytes, at: offset)
            result.append(parsed.element)
            offset = parsed.next
        }
        return result
    }
}

/// Les quelques champs d'un certificat X.509 dont la signature a besoin.
nonisolated struct CertificateInfo {
    let serialNumber: [UInt8]
    let issuer: [UInt8]
    let subject: [UInt8]

    init(der: [UInt8]) throws {
        let certificate = try DERParser.element(in: der).element
        guard certificate.tag == 0x30,
              let tbs = try DERParser.children(of: certificate.content).first,
              tbs.tag == 0x30 else { throw DERParser.MalformedData() }
        var fields = try DERParser.children(of: tbs.content)
        if fields.first?.tag == 0xA0 { fields.removeFirst() } // version
        guard fields.count >= 5, fields[0].tag == 0x02, fields[2].tag == 0x30, fields[4].tag == 0x30 else {
            throw DERParser.MalformedData()
        }
        serialNumber = fields[0].bytes
        issuer = fields[2].bytes
        subject = fields[4].bytes
    }

    /// Valeur d'un attribut du sujet (ex. UID = identifiant de type de pass, OU = Team ID).
    func subjectValue(for oid: String) -> String? {
        let target = DER.oid(oid)
        guard let name = try? DERParser.element(in: subject).element,
              let relativeNames = try? DERParser.children(of: name.content) else { return nil }
        for relativeName in relativeNames {
            for attribute in (try? DERParser.children(of: relativeName.content)) ?? [] {
                guard let parts = try? DERParser.children(of: attribute.content), parts.count == 2 else { continue }
                if parts[0].bytes == target {
                    return String(decoding: parts[1].content, as: UTF8.self)
                }
            }
        }
        return nil
    }
}

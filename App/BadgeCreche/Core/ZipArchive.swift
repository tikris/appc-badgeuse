import Foundation

/// Écrit une archive ZIP sans compression (méthode « stored »).
/// Un fichier .pkpass n'est rien d'autre qu'un ZIP de ce type.
enum ZipArchive {
    struct Entry {
        let name: String
        let data: Data
    }

    static func make(_ entries: [Entry], modifiedAt date: Date = Date()) -> Data {
        let (dosTime, dosDate) = dosTimestamp(date)
        var archive = Data()
        var centralDirectory = Data()

        for entry in entries {
            let name = Array(entry.name.utf8)
            let crc = CRC32.checksum(entry.data)
            let size = UInt32(entry.data.count)
            let offset = UInt32(archive.count)

            archive.appendLittleEndian(UInt32(0x0403_4B50))
            archive.appendLittleEndian(UInt16(20)) // version nécessaire
            archive.appendLittleEndian(UInt16(0x0800)) // noms en UTF-8
            archive.appendLittleEndian(UInt16(0)) // pas de compression
            archive.appendLittleEndian(dosTime)
            archive.appendLittleEndian(dosDate)
            archive.appendLittleEndian(crc)
            archive.appendLittleEndian(size)
            archive.appendLittleEndian(size)
            archive.appendLittleEndian(UInt16(name.count))
            archive.appendLittleEndian(UInt16(0))
            archive.append(contentsOf: name)
            archive.append(entry.data)

            centralDirectory.appendLittleEndian(UInt32(0x0201_4B50))
            centralDirectory.appendLittleEndian(UInt16(20)) // version créatrice
            centralDirectory.appendLittleEndian(UInt16(20)) // version nécessaire
            centralDirectory.appendLittleEndian(UInt16(0x0800))
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(dosTime)
            centralDirectory.appendLittleEndian(dosDate)
            centralDirectory.appendLittleEndian(crc)
            centralDirectory.appendLittleEndian(size)
            centralDirectory.appendLittleEndian(size)
            centralDirectory.appendLittleEndian(UInt16(name.count))
            centralDirectory.appendLittleEndian(UInt16(0)) // champ extra
            centralDirectory.appendLittleEndian(UInt16(0)) // commentaire
            centralDirectory.appendLittleEndian(UInt16(0)) // disque
            centralDirectory.appendLittleEndian(UInt16(0)) // attributs internes
            centralDirectory.appendLittleEndian(UInt32(0)) // attributs externes
            centralDirectory.appendLittleEndian(offset)
            centralDirectory.append(contentsOf: name)
        }

        let centralDirectoryOffset = UInt32(archive.count)
        archive.append(centralDirectory)
        archive.appendLittleEndian(UInt32(0x0605_4B50))
        archive.appendLittleEndian(UInt16(0))
        archive.appendLittleEndian(UInt16(0))
        archive.appendLittleEndian(UInt16(entries.count))
        archive.appendLittleEndian(UInt16(entries.count))
        archive.appendLittleEndian(UInt32(centralDirectory.count))
        archive.appendLittleEndian(centralDirectoryOffset)
        archive.appendLittleEndian(UInt16(0))
        return archive
    }

    private static func dosTimestamp(_ date: Date) -> (time: UInt16, date: UInt16) {
        let calendar = Calendar(identifier: .gregorian)
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = max((parts.year ?? 1980) - 1980, 0)
        let time = ((parts.hour ?? 0) << 11) | ((parts.minute ?? 0) << 5) | ((parts.second ?? 0) / 2)
        let day = (year << 9) | ((parts.month ?? 1) << 5) | (parts.day ?? 1)
        return (UInt16(truncatingIfNeeded: time), UInt16(truncatingIfNeeded: day))
    }
}

enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { index -> UInt32 in
        var value = UInt32(index)
        for _ in 0..<8 {
            value = (value & 1) != 0 ? (0xEDB8_8320 ^ (value >> 1)) : (value >> 1)
        }
        return value
    }

    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }
}

private extension Data {
    mutating func appendLittleEndian(_ value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8(value >> 8))
    }

    mutating func appendLittleEndian(_ value: UInt32) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8(value >> 24))
    }
}

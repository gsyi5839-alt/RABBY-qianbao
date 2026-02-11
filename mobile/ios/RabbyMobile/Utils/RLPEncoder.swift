import Foundation

/// RLP (Recursive Length Prefix) encoding implementation
/// Used for encoding Ethereum transactions
class RLPEncoder {
    
    /// Encode any value to RLP format
    static func encode(_ value: Any) throws -> Data {
        if let data = value as? Data {
            return try encodeData(data)
        } else if let string = value as? String {
            guard let data = string.data(using: .utf8) else {
                throw RLPError.invalidInput
            }
            return try encodeData(data)
        } else if let number = value as? Int {
            return try encodeInt(number)
        } else if let array = value as? [Any] {
            return try encodeArray(array)
        } else {
            throw RLPError.unsupportedType
        }
    }
    
    /// Encode data
    private static func encodeData(_ data: Data) throws -> Data {
        if data.count == 1 && data[0] < 0x80 {
            return data
        } else if data.count <= 55 {
            var result = Data()
            result.append(UInt8(0x80 + data.count))
            result.append(data)
            return result
        } else {
            let lengthData = encodeLengthData(UInt64(data.count))
            var result = Data()
            result.append(UInt8(0xb7 + lengthData.count))
            result.append(lengthData)
            result.append(data)
            return result
        }
    }
    
    /// Encode integer
    private static func encodeInt(_ value: Int) throws -> Data {
        if value == 0 {
            return Data([0x80])
        }
        
        let bytes = toBytes(value)
        return try encodeData(bytes)
    }
    
    /// Encode array
    private static func encodeArray(_ array: [Any]) throws -> Data {
        var encodedItems = Data()
        
        for item in array {
            let encoded = try encode(item)
            encodedItems.append(encoded)
        }
        
        if encodedItems.count <= 55 {
            var result = Data()
            result.append(UInt8(0xc0 + encodedItems.count))
            result.append(encodedItems)
            return result
        } else {
            let lengthData = encodeLengthData(UInt64(encodedItems.count))
            var result = Data()
            result.append(UInt8(0xf7 + lengthData.count))
            result.append(lengthData)
            result.append(encodedItems)
            return result
        }
    }
    
    /// Convert integer to bytes
    private static func toBytes(_ value: Int) -> Data {
        if value == 0 {
            return Data()
        }
        
        var bytes = [UInt8]()
        var num = value
        
        while num > 0 {
            bytes.insert(UInt8(num & 0xFF), at: 0)
            num >>= 8
        }
        
        return Data(bytes)
    }
    
    /// Encode length as data
    private static func encodeLengthData(_ length: UInt64) -> Data {
        if length == 0 {
            return Data()
        }
        
        var bytes = [UInt8]()
        var len = length
        
        while len > 0 {
            bytes.insert(UInt8(len & 0xFF), at: 0)
            len >>= 8
        }
        
        return Data(bytes)
    }
}

/// RLP Decoder (for future use)
class RLPDecoder {
    
    static func decode(_ data: Data) throws -> Any {
        guard !data.isEmpty else {
            throw RLPError.emptyInput
        }
        
        let (decoded, _) = try decodeItem(data, offset: 0)
        return decoded
    }
    
    private static func decodeItem(_ data: Data, offset: Int) throws -> (Any, Int) {
        guard offset < data.count else {
            throw RLPError.invalidInput
        }
        
        let prefix = data[offset]
        
        if prefix < 0x80 {
            // Single byte
            return (Data([prefix]), offset + 1)
        } else if prefix <= 0xb7 {
            // String 0-55 bytes
            let length = Int(prefix - 0x80)
            let end = offset + 1 + length
            guard end <= data.count else {
                throw RLPError.invalidInput
            }
            return (data.subdata(in: (offset + 1)..<end), end)
        } else if prefix <= 0xbf {
            // String > 55 bytes
            let lengthSize = Int(prefix - 0xb7)
            let lengthEnd = offset + 1 + lengthSize
            guard lengthEnd <= data.count else {
                throw RLPError.invalidInput
            }
            
            let lengthData = data.subdata(in: (offset + 1)..<lengthEnd)
            let length = Int(lengthData.reduce(0) { $0 << 8 | UInt64($1) })
            
            let dataEnd = lengthEnd + length
            guard dataEnd <= data.count else {
                throw RLPError.invalidInput
            }
            
            return (data.subdata(in: lengthEnd..<dataEnd), dataEnd)
        } else if prefix <= 0xf7 {
            // List 0-55 bytes
            let length = Int(prefix - 0xc0)
            let end = offset + 1 + length
            guard end <= data.count else {
                throw RLPError.invalidInput
            }
            
            var items: [Any] = []
            var currentOffset = offset + 1
            
            while currentOffset < end {
                let (item, newOffset) = try decodeItem(data, offset: currentOffset)
                items.append(item)
                currentOffset = newOffset
            }
            
            return (items, end)
        } else {
            // List > 55 bytes
            let lengthSize = Int(prefix - 0xf7)
            let lengthEnd = offset + 1 + lengthSize
            guard lengthEnd <= data.count else {
                throw RLPError.invalidInput
            }
            
            let lengthData = data.subdata(in: (offset + 1)..<lengthEnd)
            let length = Int(lengthData.reduce(0) { $0 << 8 | UInt64($1) })
            
            let dataEnd = lengthEnd + length
            guard dataEnd <= data.count else {
                throw RLPError.invalidInput
            }
            
            var items: [Any] = []
            var currentOffset = lengthEnd
            
            while currentOffset < dataEnd {
                let (item, newOffset) = try decodeItem(data, offset: currentOffset)
                items.append(item)
                currentOffset = newOffset
            }
            
            return (items, dataEnd)
        }
    }
}

// MARK: - Helper Class for RLP encoding

class RLP {
    static func encode(_ items: [Any]) throws -> Data {
        return try RLPEncoder.encode(items)
    }
    
    static func decode(_ data: Data) throws -> Any {
        return try RLPDecoder.decode(data)
    }
}

// MARK: - Errors

enum RLPError: Error, LocalizedError {
    case invalidInput
    case emptyInput
    case unsupportedType
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "Invalid RLP input"
        case .emptyInput:
            return "Empty RLP input"
        case .unsupportedType:
            return "Unsupported type for RLP encoding"
        case .decodingFailed:
            return "Failed to decode RLP data"
        }
    }
}

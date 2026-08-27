//
//  MECAttributeType+DefaultText.swift
//  MIOEntityCore
//
//  Created by MIO Research Labs on 2026.
//
//  The model's default, which every model file stores as text, read back as a
//  value of the declared type.
//

import Foundation

extension MECAttributeType
{
    /// Reads ``MECAttribute/defaultValueString`` as a value of this type.
    ///
    /// A model file records defaults as text, and `"1"` is a valid default for
    /// both a ``boolean`` and an ``integer64``. Only the declared type says which.
    ///
    /// - Returns: The value, or `nil` when the text cannot be read as this type.
    ///   Not an error: the caller falls back to the absent-value rules.
    ///
    /// - Important: No `default:`, for the reason the JSON leg gives.
    public func value( fromDefaultText text: String ) -> Any? {

        switch self {

            case .string:
                return text

            case .boolean:
                // Core Data writes YES/NO, the editors write 1/0, and hand-edited
                // models carry true/false. All three mean the same thing.
                switch text.lowercased() {
                    case "yes", "true", "1":  return true
                    case "no", "false", "0":  return false
                    default:                  return nil
                }

            case .integer16, .integer32, .integer64:
                return Int( text )

            case .double:
                return Double( text )

            case .float:
                return Float( text )

            case .decimal:
                return Decimal( string: text )

            case .uuid:
                return UUID( uuidString: text )

            case .date:
                // A date default is a fixed instant in the model file, which is
                // rare and unrepresentable in the `.xcdatamodeld` grammar as
                // anything but a timestamp. Read seconds since the reference
                // date, the way Core Data records `defaultDateTimeInterval`.
                guard let interval = Double( text ) else { return nil }
                return Date( timeIntervalSinceReferenceDate: interval )

            case .binaryData:
                return Data( base64Encoded: text )

            case .uri:
                return URL( string: text )

            case .transformable, .objectID, .undefined:
                // None of the three has a text spelling this package can honour:
                // a transformable needs its value transformer, and the other two
                // are not values a model file gives a default for.
                return nil
        }
    }

    /// Writes a typed default back as text.
    ///
    /// The mirror of ``value(fromDefaultText:)``. An `NSAttributeDescription`
    /// hands over `defaultValue` typed, because Core Data parsed the model file
    /// long ago and kept the value rather than the text.
    ///
    /// - Returns: The text, or `nil` when there is no faithful spelling, which
    ///   means the attribute simply has no default. The alternative is
    ///   `String( describing: )`, whose output the reader cannot parse back.
    ///
    /// - Important: No `default:`, for the reason the JSON leg gives.
    public func defaultText( from value: Any? ) -> String? {

        guard let value, value is NSNull == false else { return nil }

        switch self {

            case .string:
                return value as? String

            case .boolean:
                // Written the way Core Data writes it, so a model file this
                // round-trips through reads identically in Xcode.
                guard let flag = value as? Bool else { return nil }
                return flag ? "YES" : "NO"

            case .integer16, .integer32, .integer64:
                guard let integer = MECAttributeType.integer( from: value ) else { return nil }
                return String( integer )

            case .double:
                guard let double = value as? Double else { return nil }
                return String( double )

            case .float:
                guard let float = value as? Float else { return nil }
                return String( float )

            case .decimal:
                guard let decimal = MECAttributeType.decimal( from: value ) else { return nil }
                return NSDecimalNumber( decimal: decimal ).stringValue

            case .uuid:
                return ( value as? UUID )?.uuidString

            case .date:
                guard let date = value as? Date else { return nil }
                return String( date.timeIntervalSinceReferenceDate )

            case .binaryData:
                return ( value as? Data )?.base64EncodedString()

            case .uri:
                if let url = value as? URL { return url.absoluteString }
                return value as? String

            case .transformable, .objectID, .undefined:
                return nil
        }
    }

    /// Reads an integer out of the several widths a driver or a model might use.
    package static func integer( from value: Any? ) -> Int64? {
        if let integer = value as? Int64 { return integer }
        if let integer = value as? Int   { return Int64( integer ) }
        if let integer = value as? Int32 { return Int64( integer ) }
        if let integer = value as? Int16 { return Int64( integer ) }
        if let integer = value as? Int8  { return Int64( integer ) }
        return nil
    }
}

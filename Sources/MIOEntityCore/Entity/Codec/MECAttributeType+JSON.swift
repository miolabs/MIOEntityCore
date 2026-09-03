//
//  MECAttributeType+JSON.swift
//  MIOEntityCore
//
//  Created by MIO Research Labs on 2026.
//
//  One attribute type, one model value, out to JSON.
//

import Foundation

extension MECAttributeType
{
    /// Renders one value of this type as something `JSONSerialization` accepts.
    ///
    /// The value is assumed present: absence, the default and the required check
    /// belong to ``MECAttribute/jsonValue(from:policy:in:)``, which is what
    /// callers use.
    ///
    /// - Important: No `default:` in the switch below, ever. A new
    ///   ``MECAttributeType`` case has to break the build here.
    public func jsonValue( from value: Any?,
                           policy: MECPolicy = .default,
                           entity: String = "?",
                           property: String = "?" ) throws -> Any? {

        switch self {

            case .uuid:
                if let uuid = value as? UUID { return _render( uuid, policy ) }
                // Some drivers hand identity back as text. Normalise rather than
                // pass through, so one row does not serialize two ways depending
                // on which backend produced it.
                if let text = value as? String, let uuid = UUID( uuidString: text ) {
                    return _render( uuid, policy )
                }
                throw MECError.mismatch( entity: entity, property: property, value: value )

            case .date:
                if let date = value as? Date { return policy.dateFormatter( date ) }
                // Already formatted by a driver that returned text; trust it
                // rather than reformat something we cannot parse unambiguously.
                if let text = value as? String { return text }
                throw MECError.mismatch( entity: entity, property: property, value: value )

            case .decimal:
                guard let decimal = MECAttributeType.decimal( from: value ) else {
                    throw MECError.mismatch( entity: entity, property: property, value: value )
                }
                switch policy.decimalFormat {
                    case .number: return NSDecimalNumber( decimal: decimal )
                    case .string: return NSDecimalNumber( decimal: decimal ).stringValue
                }

            case .binaryData:
                guard let data = value as? Data else {
                    throw MECError.mismatch( entity: entity, property: property, value: value )
                }
                return data.base64EncodedString()

            case .uri:
                if let url = value as? URL { return url.absoluteString }
                if let text = value as? String { return text }
                throw MECError.mismatch( entity: entity, property: property, value: value )

            case .transformable:
                throw MECError.unsupportedAttribute(
                    entity: entity, property: property,
                    reason: "a transformable attribute needs its own value transformer" )

            case .integer16, .integer32, .integer64,
                 .double, .float,
                 .boolean, .string:
                return value

            case .objectID, .undefined:
                return NSNull()
        }
    }

    private func _render( _ uuid: UUID, _ policy: MECPolicy ) -> String {
        return policy.uppercaseUUIDs ? uuid.uuidString.uppercased()
                                     : uuid.uuidString.lowercased()
    }

    /// Reads a decimal out of whatever a driver handed back. `Double` is in the
    /// list and is already lossy by then; it is accepted because a backend that
    /// returns money as a double leaves no better option.
    package static func decimal( from value: Any? ) -> Decimal? {
        if let decimal = value as? Decimal { return decimal }
        if let number  = value as? NSDecimalNumber { return number.decimalValue }
        if let double  = value as? Double { return Decimal( double ) }
        if let integer = value as? Int { return Decimal( integer ) }
        if let text    = value as? String { return Decimal( string: text ) }
        return nil
    }
}

extension MECAttribute
{
    /// Renders this attribute's value as JSON, applying the model's rules about
    /// absence first: an absent value falls back to the default, and only an
    /// absent value with no default on a required attribute is an error.
    ///
    /// - Returns: A JSON value, or `NSNull` for an absent optional. Whether that
    ///   null reaches the payload is ``MECPolicy/includeNulls``.
    public func jsonValue( from value: Any?,
                           policy: MECPolicy = .default,
                           in entity: String = "?" ) throws -> Any? {

        if value == nil || value is NSNull {
            if let text = defaultValueString,
               let fallback = type.value( fromDefaultText: text ) {
                return try type.jsonValue( from: fallback, policy: policy,
                                           entity: entity, property: name )
            }
            if isOptional { return NSNull() }
            throw MECError.missingRequiredValue( entity: entity, property: name )
        }

        return try type.jsonValue( from: value, policy: policy,
                                   entity: entity, property: name )
    }
}

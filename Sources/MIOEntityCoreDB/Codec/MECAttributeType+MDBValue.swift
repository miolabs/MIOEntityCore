//
//  MECAttributeType+MDBValue.swift
//  MIOEntityCoreDB
//
//  Created by MIO Research Labs on 2026.
//
//  One attribute type, one model value, out to SQL.
//

import Foundation
import MIODB
import MIOEntityCore

extension MECAttributeType
{
    /// Renders one value of this type as an ``MDBValue``.
    ///
    /// Unlike `MDBValue.init( _: Any? )`, which picks a storage case by looking
    /// at the Swift value, the model's declared type chooses here and the value
    /// is read to fit it.
    ///
    /// - Important: No `default:`, ever. A new ``MECAttributeType`` case has to
    ///   break this switch too.
    public func dbValue( from value: Any?,
                         entity: String = "?",
                         property: String = "?" ) throws -> MDBValue {

        if value == nil || value is NSNull { return MDBValue( storage: .null ) }

        switch self {

            case .string:
                guard let text = value as? String else { throw _mismatch( value, entity, property ) }
                return MDBValue( storage: .string( text ) )

            case .integer16, .integer32, .integer64:
                guard let integer = MECAttributeType.integer( from: value ) else {
                    throw _mismatch( value, entity, property )
                }
                return MDBValue( storage: .int( integer ) )

            case .double:
                guard let double = value as? Double else { throw _mismatch( value, entity, property ) }
                return MDBValue( storage: .double( double ) )

            case .float:
                guard let float = value as? Float else { throw _mismatch( value, entity, property ) }
                return MDBValue( storage: .float( float ) )

            case .decimal:
                // The declared type winning over the value's own is exactly what
                // this method exists for: a Double here stays a decimal.
                guard let decimal = MECAttributeType.decimal( from: value ) else {
                    throw _mismatch( value, entity, property )
                }
                return MDBValue( storage: .decimal( decimal ) )

            case .boolean:
                guard let flag = value as? Bool else { throw _mismatch( value, entity, property ) }
                return MDBValue( storage: .bool( flag ) )

            case .date:
                guard let date = value as? Date else { throw _mismatch( value, entity, property ) }
                return MDBValue( storage: .date( date ) )

            case .uuid:
                if let uuid = value as? UUID { return MDBValue( storage: .uuid( uuid ) ) }
                // Same normalisation as the JSON leg: a driver that hands
                // identity back as text must not produce a second spelling.
                if let text = value as? String, let uuid = UUID( uuidString: text ) {
                    return MDBValue( storage: .uuid( uuid ) )
                }
                throw _mismatch( value, entity, property )

            case .uri:
                // A URL is its absolute string, in SQL as in JSON.
                if let url = value as? URL { return MDBValue( storage: .string( url.absoluteString ) ) }
                if let text = value as? String { return MDBValue( storage: .string( text ) ) }
                throw _mismatch( value, entity, property )

            case .binaryData:
                // Refused rather than encoded. `MDBValueStorage` has no bytes case, and
                // every choice here is wrong differently: base64 lands in a bytea column
                // as characters, a hex literal is dialect-specific. The fix is a storage
                // case in MIODB, not a guess at this layer.
                throw MECError.unsupportedAttribute(
                    entity: entity, property: property,
                    reason: "binary data has no SQL storage in MIODB yet" )

            case .transformable:
                throw MECError.unsupportedAttribute(
                    entity: entity, property: property,
                    reason: "a transformable attribute needs its own value transformer" )

            case .objectID, .undefined:
                // Neither is a value a backend stores. Null, matching the JSON
                // leg, which renders them as null too.
                return MDBValue( storage: .null )
        }
    }

    private func _mismatch( _ value: Any?, _ entity: String, _ property: String ) -> MECError {
        return MECError.mismatch( entity: entity, property: property, value: value )
    }
}

extension MECAttribute
{
    /// Renders this attribute's value as an ``MDBValue``, applying the model's
    /// rules about absence first, in the same order as the JSON leg. An absent
    /// optional is SQL `NULL`.
    public func dbValue( from value: Any?, in entity: String = "?" ) throws -> MDBValue {

        if value == nil || value is NSNull {
            if let text = defaultValueString,
               let fallback = type.value( fromDefaultText: text ) {
                return try type.dbValue( from: fallback, entity: entity, property: name )
            }
            if isOptional { return MDBValue( storage: .null ) }
            throw MECError.missingRequiredValue( entity: entity, property: name )
        }

        return try type.dbValue( from: value, entity: entity, property: name )
    }
}

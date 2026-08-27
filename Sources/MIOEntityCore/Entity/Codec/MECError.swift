//
//  MECError.swift
//  MIOEntityCore
//
//  Created by MIO Research Labs on 2026.
//

/// What a codec refuses to do, and why.
///
/// Every case names the entity and the property, because a translation failure
/// three layers down a save is useless without them.
public enum MECError : Error, Equatable, Sendable
{
    /// The model says this property is required and no value arrived, with no
    /// default to fall back on. A modelling error rather than a rendering one.
    case missingRequiredValue( entity: String, property: String )

    /// A value that does not match its declared type: a `String` where the model
    /// says ``MECAttributeType/uuid``, and nothing that could be read as one.
    ///
    /// The offending value is carried as a **description**, not as `Any`. An
    /// `Any` payload costs the whole error type its `Sendable` conformance, and
    /// this error crosses a server's isolation boundaries on its way to a log.
    case valueTypeMismatch( entity: String, property: String, value: String )

    /// A type this codec cannot render in this context, which is not the same as
    /// a bad value. ``MECAttributeType/transformable`` in JSON is the standing
    /// example: it is whatever its value transformer says, and no codec here has
    /// been handed that transformer.
    case unsupportedAttribute( entity: String, property: String, reason: String )
}

extension MECError : CustomStringConvertible
{
    public var description: String {
        switch self {
            case .missingRequiredValue( let entity, let property ):
                return "\(entity).\(property) is required and has no value"

            case .valueTypeMismatch( let entity, let property, let value ):
                return "\(entity).\(property) cannot read \(value) as its declared type"

            case .unsupportedAttribute( let entity, let property, let reason ):
                return "\(entity).\(property) cannot be rendered: \(reason)"
        }
    }
}

extension MECError
{
    /// Builds a ``valueTypeMismatch`` from the offending value.
    ///
    /// One place that decides how a rejected value is described, so the same
    /// value reads the same way whichever leg refused it.
    package static func mismatch( entity: String, property: String, value: Any? ) -> MECError {
        guard let value else {
            return .valueTypeMismatch( entity: entity, property: property, value: "nil" )
        }
        return .valueTypeMismatch( entity: entity, property: property,
                                   value: "\(type( of: value )) \(value)" )
    }
}

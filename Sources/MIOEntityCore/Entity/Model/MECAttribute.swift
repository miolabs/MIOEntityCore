//
//  MECAttribute.swift
//  MIOEntityCore
//
//  Created by MIO Research Labs on 2026.
//

/// One attribute of a ``MECEntity``: a name, a type, and whether a value is
/// required.
///
/// A value type, so an entity's attribute list cannot be mutated behind the
/// model's back once it is built.
///
/// ```swift
/// let title = MECAttribute( name: "title", type: .string )
/// let price = MECAttribute( name: "price", type: .decimal, isOptional: true )
/// ```
public struct MECAttribute : Sendable, Equatable
{
    /// The attribute's name as the model spells it, which is also how JSON
    /// spells it.
    public let name: String

    public let type: MECAttributeType

    /// Whether the model allows this attribute to hold no value. A required
    /// attribute with no value is a modelling error, and the codec says so
    /// rather than writing a null.
    public let isOptional: Bool

    /// The model's default, as text, the way a model file records it.
    ///
    /// Text rather than a typed value: `"1"` is a valid default for both a
    /// ``MECAttributeType/boolean`` and an ``MECAttributeType/integer64``, and
    /// only the codec, which knows the target context, can say which.
    public let defaultValueString: String?

    /// Whether the attribute is computed rather than stored. A transient
    /// attribute has no column and is not written.
    public let isTransient: Bool

    public init( name: String,
                 type: MECAttributeType,
                 isOptional: Bool = false,
                 defaultValueString: String? = nil,
                 isTransient: Bool = false ) {
        self.name               = name
        self.type               = type
        self.isOptional         = isOptional
        self.defaultValueString = defaultValueString
        self.isTransient        = isTransient
    }
}

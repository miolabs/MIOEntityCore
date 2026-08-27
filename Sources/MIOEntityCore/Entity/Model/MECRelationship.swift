//
//  MECRelationship.swift
//  MIOEntityCore
//
//  Created by MIO Research Labs on 2026.
//

/// One relationship of a ``MECEntity``, pointing at another entity **by name**.
///
/// ```swift
/// let todos = MECRelationship( name: "todos",
///                              destinationEntityName: "Todo",
///                              inverseName: "folder",
///                              isToMany: true )
/// ```
///
/// - Important: The destination is a name, not a reference. Inverses are
///   cyclic by definition, so references would mean a retain cycle or an
///   `unowned` and the crash after it. Resolve one through
///   ``MECModel/entity(named:)``.
public struct MECRelationship : Sendable, Equatable
{
    /// The relationship's name as the model spells it.
    public let name: String

    /// The name of the entity at the other end. Resolve it through the model;
    /// nothing here guarantees it exists, and a name that resolves to nothing is
    /// the "dangling destination" a model validator reports.
    public let destinationEntityName: String

    /// The name of the relationship coming back the other way, if the model
    /// declares one.
    ///
    /// Under foreign-key storage a to-many is read *through* its inverse: the
    /// child's to-one is the column holding the key. A to-many without one has
    /// nowhere to read from.
    public let inverseName: String?

    /// Whether this side holds many.
    public let isToMany: Bool

    /// Whether the model allows this relationship to be empty.
    public let isOptional: Bool

    public init( name: String,
                 destinationEntityName: String,
                 inverseName: String? = nil,
                 isToMany: Bool = false,
                 isOptional: Bool = true ) {
        self.name                  = name
        self.destinationEntityName = destinationEntityName
        self.inverseName           = inverseName
        self.isToMany              = isToMany
        self.isOptional            = isOptional
    }
}

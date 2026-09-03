//
//  MECEntity.swift
//  MIOEntityCore
//
//  Created by Javier Segura Perez on 17/6/25.
//  Split out of MECModel.swift and grown into a schema on 2026-08-26.
//

/// One entity: a name, its attributes and relationships, and where it sits in an
/// inheritance chain.
///
/// You create entities from the roots down, passing each one its parent, and
/// pass the entities themselves to ``MECCache`` rather than passing names around.
///
/// ```swift
/// let folder = MECEntity( name: "Folder",
///                         attributes: [ MECAttribute( name: "identifier", type: .uuid ),
///                                       MECAttribute( name: "title", type: .string ) ],
///                         relationships: [ MECRelationship( name: "todos",
///                                                           destinationEntityName: "Todo",
///                                                           inverseName: "folder",
///                                                           isToMany: true ) ] )
/// ```
///
/// Attributes and relationships are optional at every call site, so an entity
/// built the way the cache has always built one still compiles unchanged:
///
/// ```swift
/// let product   = MECEntity( name: "Product" )
/// let menu_item = MECEntity( name: "MenuItem", superEntity: product )
/// ```
///
/// - Note: ``MECCache`` reads only the name and the inheritance chain. The
///   attributes and relationships are here for the codecs.
///
/// - Important: An entity is immutable once built, which is what makes it
///   `Sendable`. A parent is passed at `init`, so build a hierarchy from the
///   roots down, and ask ``MECModel/subEntities(of:)`` for the way back down.
public final class MECEntity : Sendable
{
    /// The entity name as the model spells it. Uppercase, in every MIO model:
    /// `MenuItem`, not `menu_item`. SQL asks a ``MECSchema`` for the table name.
    public let name: String

    /// Marks the entity abstract. Nothing enforces it, and inserting an object
    /// as an abstract entity works normally. The flag matters only when this
    /// entity is someone else's parent, because the cache's inheritance walk
    /// stops when it reaches it.
    public let isAbstract: Bool

    /// The entity this one inherits from.
    public let superEntity: MECEntity?

    /// The entity's own attributes, in model order.
    ///
    /// Inherited attributes are not merged in. Walk ``superEntity`` for the
    /// flattened set: JSON and SQL disagree on whether a parent's attributes
    /// belong to the child.
    public let attributes: [MECAttribute]

    /// The entity's own relationships, in model order.
    public let relationships: [MECRelationship]

    /// ``attributes``, keyed by name.
    public let attributesByName: [String: MECAttribute]

    /// ``relationships``, keyed by name.
    public let relationshipsByName: [String: MECRelationship]

    /// Creates an entity.
    ///
    /// - Parameters:
    ///   - name: The entity name. ``MECCache`` builds its index keys from it, so
    ///     it should be unique within a model.
    ///   - isAbstract: Marks the entity abstract. See ``isAbstract``.
    ///   - superEntity: The entity this one inherits from, which must therefore
    ///     already exist. Build a hierarchy from the roots down.
    ///   - attributes: The entity's own attributes. A repeated name overwrites
    ///     the earlier entry in ``attributesByName``, and both stay in the list.
    ///   - relationships: The entity's own relationships, same rule.
    ///
    /// - Warning: An abstract entity is **not usable as a lookup key** in
    ///   ``MECCache``. The cache's inheritance walk stops when it reaches an
    ///   abstract parent and stops *without* indexing it, so
    ///   `cache.fetch( entity: abstractParent, id: someID )` always returns `nil`
    ///   even though the object is in the cache. Use `isAbstract: false` for any
    ///   entity you intend to fetch by.
    public init( name: String,
                 isAbstract: Bool = false,
                 superEntity: MECEntity? = nil,
                 attributes: [MECAttribute] = [],
                 relationships: [MECRelationship] = [] ) {
        self.name          = name
        self.isAbstract    = isAbstract
        self.superEntity   = superEntity
        self.attributes    = attributes
        self.relationships = relationships

        self.attributesByName    = Dictionary( attributes.map { ( $0.name, $0 ) },
                                               uniquingKeysWith: { _, later in later } )
        self.relationshipsByName = Dictionary( relationships.map { ( $0.name, $0 ) },
                                               uniquingKeysWith: { _, later in later } )
    }
}

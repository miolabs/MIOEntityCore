//
//  MECModel.swift
//  MIOEntityCore
//
//  Created by Javier Segura Perez on 17/6/25.
//

/// A minimal description of your entities and how they inherit from each other.
///
/// ``MECCache`` is driven by a model. You build one ``MECEntity`` per type, wire the inheritance with
/// ``MECEntity/setParent(_:)``, and then hand the entities to the cache.
///
/// This is not a schema. It carries no attributes, no relationships and no validation, only the names
/// and the inheritance graph, which is all the cache needs in order to index an object under its own
/// entity and its superentities.
///
/// ```swift
/// let product   = MECEntity( name: "Product" )
/// let menu_item = MECEntity( name: "MenuItem" )
/// menu_item.setParent( product )
///
/// let model = MECModel( entities: [ product, menu_item ] )
/// ```
public class MECModel
{
    var entities: [MECEntity]

    /// The backing store for ``entitiesByName``, kept in step by ``init(entities:)`` and
    /// ``addEntity(_:)``.
    ///
    /// - Note: Declared `open`, so it can be replaced wholesale from outside the module. Prefer
    ///   ``entitiesByName`` for reading and ``addEntity(_:)`` for writing.
    open var _entities_by_name: [String: MECEntity]

    /// The model's entities, keyed by ``MECEntity`` name.
    ///
    /// Use this to look up the entity value you need to pass to ``MECCache`` when all you have is a
    /// name.
    public var entitiesByName: [String: MECEntity] { return _entities_by_name }

    /// Creates a model from a set of entities.
    ///
    /// The entities are indexed by name as they are added. Their inheritance links are read from the
    /// entities themselves, so call ``MECEntity/setParent(_:)`` before or after this, whichever suits,
    /// as long as it happens before you insert anything into a cache.
    ///
    /// - Parameter entities: The entities making up the model. Names are expected to be unique; a
    ///   repeated name overwrites the earlier entry in ``entitiesByName``.
    public init( entities: [MECEntity] ) {
        self.entities = entities
        self._entities_by_name = [:]
        for e in entities {
            _entities_by_name[e.name] = e
        }
    }

    /// Adds one more entity to the model, indexing it by name.
    ///
    /// - Parameter entity: The entity to add. If an entity with the same name is already present, this
    ///   one replaces it in ``entitiesByName``, and both remain in the underlying list.
    public func addEntity(_ entity: MECEntity) {
        entities.append( entity )
        _entities_by_name[entity.name] = entity
    }
}

/// One entity in a ``MECModel``: a name, an optional superentity, and whether it is abstract.
///
/// You create entities up front, wire the inheritance with ``setParent(_:)``, then pass the entities
/// themselves to ``MECCache`` rather than passing names around.
///
/// ```swift
/// let product   = MECEntity( name: "Product" )
/// let menu_item = MECEntity( name: "MenuItem" )
/// menu_item.setParent( product )
/// ```
///
/// - Note: `name`, `isAbstract`, `superEntity` and `subEntities` are all internal, so from outside the
///   module an entity is opaque. You set it up through ``init(name:isAbstract:)`` and
///   ``setParent(_:)``, but you cannot read any of it back.
public final class MECEntity
{
    var name: String
    var isAbstract: Bool

    var superEntity: MECEntity? = nil
    var subEntities: [MECEntity] = []

    /// Creates an entity.
    ///
    /// - Parameters:
    ///   - name: The entity name. ``MECCache`` builds its index keys from it, so it should be unique
    ///     within a model.
    ///   - isAbstract: Marks the entity abstract. Nothing enforces it, and inserting an object as
    ///     an abstract entity works normally. The flag only matters when this entity is someone
    ///     else's parent, because the inheritance walk stops when it reaches it.
    ///
    /// - Warning: An abstract entity is **not usable as a lookup key** in ``MECCache``. The cache's
    ///   inheritance walk stops when it reaches an abstract parent and stops *without* indexing it, so
    ///   `cache.fetch( entity: abstractParent, id: someID )` always returns `nil` even though the
    ///   object is in the cache. Use `isAbstract: false` for any entity you intend to fetch by.
    public init(name: String, isAbstract: Bool = false) {
        self.name = name
        self.isAbstract = isAbstract
    }

    /// Makes `parent` the superentity of this entity, and adds this entity to the parent's subentities.
    ///
    /// Wire up the whole hierarchy before inserting anything into a ``MECCache``. The cache reads the
    /// chain at insert time to index the object under its superentities, and it does not go back and
    /// re-index when the hierarchy changes afterwards.
    ///
    /// - Parameter parent: The superentity, or `nil` to detach. Passing `nil` clears this entity's own
    ///   parent link, but does not remove it from the previous parent's subentities.
    public func setParent(_ parent: MECEntity?) {
        superEntity = parent
        parent?.subEntities.append( self )
    }
}

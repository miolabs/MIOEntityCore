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
/// Entities carry their attributes and relationships, so a model is a schema:
/// enough to render an object to JSON or to SQL without holding an
/// `NSEntityDescription` as well. It carries no validation, and the cache still
/// reads only the names and the inheritance graph.
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
    /// Private. It used to be `open`, which did nothing on a class that is not
    /// itself `open`, and offered callers a way to replace the index without
    /// touching ``entities``. Read through ``entitiesByName`` and write through
    /// ``addEntity(_:)``.
    private var _entities_by_name: [String: MECEntity]

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

    /// The entity with this name, or `nil`.
    ///
    /// The lookup a ``MECRelationship`` needs: relationships hold the
    /// destination's *name*, so resolving one is a question for the model.
    ///
    /// - Parameter name: The entity name, as the model spells it.
    public func entity( named name: String ) -> MECEntity? { return _entities_by_name[ name ] }

    /// The entities that name `entity` as their parent.
    ///
    /// Derived rather than stored, which is what lets ``MECEntity`` be immutable
    /// and therefore `Sendable`: a stored downward list has to be appended to
    /// *after* the child exists, and that is a mutation of the parent. "Who
    /// inherits from this" is a question about a model anyway, not about an
    /// entity, and only a model can answer it completely.
    ///
    /// - Parameter entity: The parent.
    /// - Complexity: O(n) in the model's entity count. Index it yourself if you
    ///   are walking a whole hierarchy.
    public func subEntities( of entity: MECEntity ) -> [MECEntity] {
        return entities.filter { $0.superEntity === entity }
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

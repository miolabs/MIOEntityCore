//
//  MECCache.swift
//  MIOEntityCore
//
//  Created by Javier Segura Perez on 16/6/25.
//

import Foundation
import MIOCoreLogger


/// The closure ``MECCache/update(entity:_:version:updateBlock:)`` calls to rewrite a cached body.
///
/// You are handed the current body and return the new one. Returning the value you were given leaves
/// the body untouched while the object's version is still set to the one you passed.
///
/// The body is typed `Any` rather than the cache's `T` because ``MECCacheObject`` stores it untyped;
/// cast it to your body type inside the closure.
public typealias MECCacheObjectUpdateBlock = ( _ body:Any ) -> Any

/// A single object held by a ``MECCache``: its entity, id, version and body.
///
/// ``MECCache/insert(entity:id:body:version:)`` and ``MECCache/fetch(entity:id:)`` hand these back.
///
/// - Important: Every member of this class is internal, so from outside `MIOEntityCore` the object is
///   an opaque handle with nothing readable on it. To get at the contents, use
///   ``MECCache/value(entity:id:version:)``, which returns the typed body directly.
public class MECCacheObject
{
    let hash:String = UUID().uuidString
    let id:UUID
    var entity:MECEntity
    var version:Int64
    var body:Any
    
    var reference: String {
        return entity.name + "://" + id.uuidString
    }

    init( entity: MECEntity, id: UUID, version: Int64, body: Any ) {
        self.entity = entity
        self.id = id
        self.version = version
        self.body = body
    }
    
    func updateValues( version:Int64, updateBlock: @escaping MECCacheObjectUpdateBlock ) {
        self.version = version
        body = updateBlock( body )
    }
}

/// An index that answers "is this one in this set", inheritance included.
///
/// Keyed by ``MECEntity`` and UUID, with a version per object. Reach for this when one pass needs to
/// hold several sets of the same objects and ask which set a given id is in: what you already had,
/// what a batch is asking to change, the two combined. There is no separate set type here, so when
/// you have nothing to keep alongside the ids, use a `MECCache<Bool>` and store `true`.
///
/// ``MECEntityCache`` answers the other question, "which entities and ids are in this batch", and is
/// the better fit when you want to group a batch and act on it a group at a time. The two share no
/// code and neither sees the other's contents.
///
/// ## What it gives you over a dictionary
///
/// - **Identity.** Objects are keyed by `(entity, id)`, and ``insert(entity:id:body:version:)`` is
///   idempotent, so re-inserting an id you already hold returns what you already have instead of
///   duplicating it. That is what you want when overlapping batches keep arriving.
/// - **Versions.** Every object carries an `Int64` version that you set and read. Nothing in the
///   cache interprets it.
/// - **Missing ids.** ``diffIDs(entity:ids:)`` answers "which of these ids am I missing", so you can
///   go and get only the ones you lack. It compares ids alone, never versions.
/// - **Inheritance.** An object inserted as a subentity is also findable by its concrete
///   superentities, which a plain `[String: [UUID: T]]` cannot do.
///
/// ```swift
/// let product   = MECEntity( name: "Product" )
/// let menu_item = MECEntity( name: "MenuItem" )
/// menu_item.setParent( product )
///
/// let cache = MECCache<[String:Any]>( )
/// let obj   = cache.insert( entity: menu_item, id: item_id, body: [ "name": "Latte" ], version: 3 )
///
/// // found through the superentity, because Product is concrete
/// let body    = cache.value( entity: product, id: item_id )
/// let missing = cache.diffIDs( entity: menu_item, ids: wanted_ids )
/// ```
///
/// - Warning: This type is **not thread safe**. It is a class holding plain mutable dictionaries with
///   no locking, so confine an instance to a single thread or serialise access yourself.
///
/// - Note: Insertions and removals emit `Log.debug` lines of the form `Inserting REFID: Name://uuid`,
///   which is why the package depends on `MIOCoreLogger`.
public class MECCache<T>
{
    var _entity_graph:[String:String]
    var _entities_by_hash:[String:MECCacheObject]
    var _entities_by_name:[String:[UUID]]
    var _objects:[MECCacheObject]

    func _hash_key( _ entity: MECEntity, _ id: UUID) -> String {
        return entity.name + "#" + id.uuidString
    }

    func _uuid_from_string(_ str:String ) -> UUID {
        return UUID(uuidString: str )!
    }
            
    /// Creates an empty cache.
    ///
    /// The cache holds no reference to a ``MECModel``. You pass the entities in on every call, so it
    /// is up to you to keep handing it entities from the same model.
    public init() {
        _entity_graph = [:]
        _entities_by_hash = [:]
        _entities_by_name = [:]
        _objects = []
    }
    
    func insertEntity( _ name:String, id:UUID ) {
        var array = _entities_by_name[ name ] ?? []
        array.append( id )
        _entities_by_name[ name ] = array
    }
    
    func removeEntity( _ name:String, id:UUID ) {
        var array = _entities_by_name[ name ] ?? []
        array.removeAll { $0 == id }
        
        if array.isEmpty {
            _entities_by_name.removeValue( forKey: name )
        } else {
            _entities_by_name[ name ] = array
        }
    }
    
    /// The names of the entities objects have been inserted as, in no particular order.
    ///
    /// This reports each object's own concrete entity, not the superentities it was additionally
    /// indexed under. For the ids held for a given name, including inherited registrations, use
    /// ``ids(fromEntityName:)``.
    ///
    /// - Note: A name appears here once anything has been inserted under it, and keeps appearing
    ///   after ``remove(entity:id:)`` takes its last object away. Use ``ids(fromEntityName:)`` when
    ///   you need the ids actually held, and ``contains(entity:id:)`` to test a single object; both
    ///   reflect removals immediately.
    public var entitiesByName: [String] {
        let entities_names = Set( _objects.map { $0.entity.name } )
        return Array( entities_names )
    }

    /// The ids currently held for an entity name.
    ///
    /// Includes ids registered under this name through inheritance, so asking for a concrete
    /// superentity returns the ids of its subentities' objects too.
    ///
    /// - Parameter entityName: The entity name to look up.
    /// - Returns: The ids held, or an empty array if nothing is cached for that name.
    public func ids( fromEntityName entityName: String) -> [UUID] {
        return _entities_by_name[ entityName ] ?? []
    }

    /// Caches an object, indexing it under its entity and its concrete superentities.
    ///
    /// Idempotent: if the `(entity, id)` pair is already cached, the existing object is returned
    /// untouched and `body` and `version` are ignored. To overwrite a cached body, use
    /// ``update(entity:_:version:updateBlock:)``.
    ///
    /// - Parameters:
    ///   - entity: The object's concrete entity.
    ///   - id: The object id, as either a `UUID` or a UUID `String`.
    ///   - body: The value to cache.
    ///   - version: A version number of your own choosing, stored alongside the object. Defaults
    ///     to `0`. Nothing in the cache interprets it.
    /// - Returns: The newly cached object, or the one already held for this `(entity, id)`.
    ///
    /// - Warning: `id` is force-converted. A `String` that is not a valid UUID, or any type other than
    ///   `UUID` and `String`, is a **crash**, not an error.
    ///
    /// - Warning: The result is not marked `@discardableResult`, so callers are forced to bind a value
    ///   whose members are all internal. Assign to `_` when you only want the side effect.
    ///
    /// - Note: The object is indexed under every **concrete** superentity, so it can later be fetched
    ///   by a parent entity. Abstract superentities are skipped, see ``MECEntity/init(name:isAbstract:)``.
    public func insert( entity: MECEntity, id: Any, body: T, version:Int64 = 0 ) -> MECCacheObject
    {
        let uuid = id is String ? _uuid_from_string( id as! String ) : id as! UUID

        var obj = fetch( entity:entity, id: uuid )
        if (obj != nil) { return obj! }

        obj = MECCacheObject( entity: entity, id: uuid, version: version, body: body )
        _entities_by_hash[ obj!.hash ] = obj!
        _objects.append( obj! )

        // Abstract superentities are never indexed: the walk advances to the parent and then breaks
        // *before* registering it when that parent is abstract. The same pattern repeats in
        // remove/fetch/update below, so a lookup by an abstract entity always misses.
        //
        // All four walks in this type agree on this, so an abstract entity is never a valid
        // lookup key.
        var parent:MECEntity? = entity
        while parent != nil {
            let hash = _hash_key( parent!, obj!.id )
            _entity_graph[ hash ] = obj!.hash
            insertEntity( parent!.name, id: obj!.id )
            Log.debug( "Inserting REFID: \(parent!.name)://\(uuid)" )
            parent = parent!.superEntity
            if parent?.isAbstract == true { break }
        }

        return obj!
    }

    /// Drops a cached object, unindexing it from its entity and its concrete superentities.
    ///
    /// Does nothing if the `(entity, id)` pair is not cached.
    ///
    /// - Parameters:
    ///   - entity: The entity the object was indexed under.
    ///   - id: The object id, as either a `UUID` or a UUID `String`.
    ///
    /// - Warning: `id` is force-converted, see ``insert(entity:id:body:version:)``.
    ///
    /// - Note: Registrations under subentities are left alone, so removing an object by one of its
    ///   parent types leaves the entry under its own type behind. ``fetch(entity:id:)`` clears that up
    ///   by itself the next time it runs into it.
    public func remove( entity: MECEntity, id: Any )
    {
        let uuid = id is String ? _uuid_from_string( id as! String ) : id as! UUID
        
        let entity_key = _hash_key( entity, uuid )
        let hash = _entity_graph[ entity_key ]
        if hash == nil { return }

        _entities_by_hash.removeValue( forKey: hash! )
        _entity_graph.removeValue(forKey: entity_key )
        removeEntity( entity.name, id: uuid )
        _objects.removeAll { $0.hash == entity_key }

        Log.debug( "Removing REFID: \(entity.name)://\(uuid)" )

        // remove parent entities
        var parent:MECEntity? = entity.superEntity
        while parent != nil {
            let key = _hash_key( parent!, uuid )
            _entity_graph.removeValue(forKey: key )
            removeEntity( parent!.name, id:uuid )
            Log.debug( "Removing REFID: \(parent!.name)://\(uuid)" )
            parent = parent!.superEntity
            if parent?.isAbstract == true { break }
        }

        // TODO: Check if we relaly need to remove subentities
        // remove super entities
        // for (let child of entity.subentities) {
        //     let key = child.name + "#" + id.UUIDString;
        //     delete this._entity_graph[key];
        // }
        
    }

    /// Looks up a cached object by entity and id, walking up the inheritance chain.
    ///
    /// The lookup tries the entity you pass, then each concrete superentity in turn, so an object
    /// inserted as a subentity is found when you ask for a parent.
    ///
    /// - Parameters:
    ///   - entity: The entity to look under. May be the object's own entity or a concrete superentity.
    ///   - id: The object id, as either a `UUID` or a UUID `String`.
    /// - Returns: The cached object, or `nil` if nothing is held for this pair.
    ///
    /// - Important: The returned ``MECCacheObject`` has no public members, so outside this module it
    ///   is an opaque handle. Use ``value(entity:id:version:)`` when you want the body.
    ///
    /// - Warning: Returns `nil` for an **abstract** entity even when the object is cached, because
    ///   abstract entities are never indexed. See ``MECEntity/init(name:isAbstract:)``.
    ///
    /// - Note: Self-healing. If the index still points at an object that is no longer held, the stale
    ///   entry is removed and `nil` is returned.
    public func fetch( entity: MECEntity, id: Any) -> MECCacheObject?
    {
        let uuid = id is String ? _uuid_from_string( id as! String ) : id as! UUID
        
        var parent:MECEntity? = entity
        var hash:String? = nil
        while parent != nil {
            let key = _hash_key( parent!, uuid )
            hash = _entity_graph[key]
            if hash != nil { break }
            parent = parent!.superEntity
            if parent?.isAbstract == true { break }
        }

        if hash == nil { return nil }
        let obj = _entities_by_hash[ hash! ]
        if obj != nil { return obj }

        // Could not exits a hash value but not the object value
        // so we have an unlink hash object in the graph
        // we remove the object from the graph
        remove( entity: entity, id: id )

        return nil
    }
    
    /// The typed body of a cached object, looked up the same way as ``fetch(entity:id:)``.
    ///
    /// - Parameters:
    ///   - entity: The entity to look under. May be the object's own entity or a concrete superentity.
    ///   - id: The object id, as either a `UUID` or a UUID `String`.
    ///   - version: Not consulted. See the note below.
    /// - Returns: The body cast to `T`, or `nil` if nothing is cached for this pair or the stored body
    ///   is not a `T`.
    ///
    /// - Note: The cached object is returned whatever its version, so this does not filter out
    ///   objects older than the version you pass. ``MECCache/update(entity:_:version:updateBlock:)``
    ///   is what sets an object's version.
    public func value( entity: MECEntity, id: Any, version: Int64 = 0 ) -> T? {
        let obj = fetch( entity: entity, id: id )
        return obj?.body as? T
    }

    /// Rewrites a cached object's body and sets its version.
    ///
    /// If the object is not indexed under `entity` directly, its superentities are searched. When it
    /// is found that way, the object is re-pointed at `entity` and the index is extended to cover the
    /// new chain, which is how an object promoted from a parent entity to a more specific subentity
    /// gets re-linked.
    ///
    /// ```swift
    /// cache.update( entity: menu_item, item_id, version: 4 ) { body in
    ///     var updated = body as! [String:Any]
    ///     updated[ "price" ] = 2.40
    ///     return updated
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - entity: The entity the object should be indexed under after the update.
    ///   - id: The object id, as either a `UUID` or a UUID `String`.
    ///   - version: The new version. Unlike ``value(entity:id:version:)``, this one is stored.
    ///   - updateBlock: Receives the current body, returns the replacement.
    ///
    /// - Note: Does nothing but log when the object is not cached. There is no return value and no
    ///   error, so the call is silent either way.
    public func update( entity: MECEntity, _ id: Any, version:Int64, updateBlock:@escaping MECCacheObjectUpdateBlock )
    {
        let uuid = id is String ? _uuid_from_string( id as! String ) : id as! UUID
        
        let entity_key = _hash_key( entity, uuid )
        var hash = _entity_graph[ entity_key ]
        var update_graph = false
        if hash == nil {
            // Find the super entity
            update_graph = true
            var parent = entity.superEntity
            while parent != nil {
                let key = _hash_key( parent!, uuid )
                hash = _entity_graph[key]
                if hash != nil { break }
                parent = parent!.superEntity
                if parent?.isAbstract == true { break }
            }
        }

        if hash == nil {
            Log.debug("MWSEntityCache: updateEntity: Entity not found")
            return
        }

        let obj = _entities_by_hash[ hash! ]!
        obj.updateValues( version:version, updateBlock: updateBlock )

        // Update new graph
        if update_graph {
            obj.entity = entity
            var parent:MECEntity? = entity
            while parent != nil {
                let key = _hash_key( parent!, uuid )
                hash = _entity_graph[key]
                if hash != nil { break }
                _entity_graph[ key ] = obj.hash
                insertEntity( parent!.name, id: uuid )
                parent = parent!.superEntity
                if parent?.isAbstract == true { break }
            }
        }
    }
    
    /// Whether an object is cached for this entity and id.
    ///
    /// Uses the same inheritance-aware lookup as ``fetch(entity:id:)``, and shares its behaviour for
    /// abstract entities: `false` even when the object is present.
    ///
    /// - Parameters:
    ///   - entity: The entity to look under. May be the object's own entity or a concrete superentity.
    ///   - id: The object id, as either a `UUID` or a UUID `String`.
    /// - Returns: `true` if an object is held for this pair.
    public func contains ( entity: MECEntity, id: Any ) -> Bool {
        return fetch( entity: entity, id: id ) != nil ? true : false
    }

    /// The ids from `ids` that are **not** already cached for this entity.
    ///
    /// Hand it the ids you are interested in and get back only the ones you still need to go and get.
    ///
    /// ```swift
    /// let missing = cache.diffIDs( entity: menu_item, ids: wanted_ids )
    /// // ... then fetch only `missing`
    /// ```
    ///
    /// - Parameters:
    ///   - entity: The entity whose cached ids to subtract. Matched by name, and the name's id set
    ///     includes objects registered through inheritance.
    ///   - ids: The ids you are interested in.
    /// - Returns: `ids` minus everything already cached for `entity`. Returns `ids` unchanged when
    ///   nothing is cached for that entity.
    ///
    /// - Note: Compares ids only, never versions. An id you hold at an older version counts as present
    ///   and will not be reported as missing, so this finds *new* objects, not *changed* ones.
    public func diffIDs ( entity: MECEntity, ids: Set<UUID> ) -> Set<UUID> {
        guard let array = _entities_by_name[ entity.name ] else { return ids }
        
        let cache_ids:Set<UUID> = Set( array )
        return ids.subtracting( cache_ids )
    }

}

//
//  File.swift
//  
//
//  Created by David Trallero on 3/11/21.
//

import Foundation


extension UUID {
    func cacheIndex ( ) -> Int {
        return Int( uuid.0 & 3 )
    }
}


/// An index that groups a batch by entity name, so you can act on it a group at a time.
///
/// Keyed by entity **name**, with ids sharded four ways and an optional subclass map for inheritance
/// lookups.
///
/// The shape it is built for: insert a heterogeneous batch, then walk ``entities_name()`` and
/// ``entity_ids(_:)`` to issue one operation per entity type rather than one per object.
///
/// ```swift
/// let batch = MECEntityCache<Row>( )
/// for row in incoming { batch.insert( row.entityName, row.id, row ) }
///
/// for name in batch.entities_name( ) {
///     let ids = batch.entity_ids( name )
///     // act on all of this type's ids at once, instead of one at a time
/// }
/// ```
///
/// Used that way you read back under the exact name you inserted under, so the subclass map never
/// comes into it. That is why the no-argument initializer is the common case for this shape.
///
/// - Important: ``MECCache`` answers the other question, "is this one present in this set", and
///   indexes inheritance in the opposite direction. The two are independent and share no code or base
///   type. Note that re-inserting a known id **overwrites** here and is **ignored** there, so moving
///   code between them changes refresh behaviour.
///
/// How it differs from ``MECCache``:
///
/// - Entities are plain `String` names, so there is no ``MECModel``/``MECEntity`` to set up.
/// - Inheritance comes from a `superClasses` map you pass to ``init(_:)``, not from an entity graph.
/// - **There is no version tracking at all.** Objects are just bodies in a dictionary, so the
///   version tracking that ``MECCache`` provides has no equivalent here.
/// - Ids are bucketed into four `Set`s by the first byte of the UUID.
///
/// ```swift
/// let cache = MECEntityCache<[String:Any]>( [ "MenuItem": [ "Product" ] ] )
/// cache.insert( "MenuItem", item_id, [ "name": "Latte" ] )
///
/// cache.contains( "Product", item_id )            // true, checks child classes
/// let fresh = cache.diff_ids( "MenuItem", wanted_ids )
/// ```
///
/// - Warning: Not thread safe. Plain mutable dictionaries with no locking.
///
/// - Note: `clone`, `batch_insert` and a `filter` helper exist in the source but are commented out.
public class MECEntityCache<T>
{
    var body        : [ String: [ UUID: T ]   ] = [:]
    var entities    : [ String: [ Set<UUID> ] ] = [:]
    // var parent_class: [ String: [String]      ] = [:] // for a given entity A, returns all the super entities of A
    var child_class : [ String: Set<String>   ] = [:]
    
    /// Creates a cache, optionally teaching it your entity inheritance.
    ///
    /// The map is inverted on the way in, from child to parents into parent to children, which is the
    /// direction `contains` and ``value(_:_:)`` need in order to widen a lookup on a parent name to
    /// its children.
    ///
    /// - Parameter superClasses: Entity name to the names of **all** its ancestors.
    ///
    /// - Warning: The map must be **fully flattened**. Lookups descend exactly one level, so for
    ///   `Refund` inheriting `Ticket` inheriting `Document` you must pass
    ///   `[ "Refund": [ "Ticket", "Document" ] ]`. Passing direct parents only,
    ///   `[ "Refund": [ "Ticket" ], "Ticket": [ "Document" ] ]`, makes `contains( "Document", refundID )`
    ///   return `false`.
    public init ( _ superClasses: [ String: [String] ] = [:] ) {
        // parent_class = superClasses
        
        for (childCls, cls) in superClasses {
            for parentClass in cls {
                if child_class[ parentClass ] == nil {
                    child_class[ parentClass ] = Set( )
                }
                
                child_class[ parentClass ]!.insert( childCls )
            }
        }
    }
    
//    public func clone ( ) -> MECEntityCache<T> {
//        let copy = MECEntityCache( ) ;
//
//        for (entity_name,entry) in entities {
//            copy.batch_insert( entity_name, entry[ 0 ] )
//            copy.batch_insert( entity_name, entry[ 1 ] )
//            copy.batch_insert( entity_name, entry[ 2 ] )
//            copy.batch_insert( entity_name, entry[ 3 ] )
//        }
//
//        return copy
//    }
    
    /// Whether an object is cached under this entity name or any of its known child classes.
    ///
    /// - Parameters:
    ///   - entityName: The entity name to check, which may be a parent name.
    ///   - entityID: The object id as a UUID `String`.
    /// - Returns: `true` if the object is held under this name or one of its children.
    ///
    /// - Warning: Force-unwraps the id. A string that is not a valid UUID is a **crash**.
    public func contains ( _ entityName: String, _ entityID: String ) -> Bool {
        return contains( entityName, UUID( uuidString: entityID )! )
    }

    /// Whether an object is cached under this entity name or any of its known child classes.
    ///
    /// Checks the exact name first, then each child class from the `superClasses` map given to
    /// ``init(_:)``, which is why that map has to be fully flattened.
    ///
    /// - Parameters:
    ///   - entityName: The entity name to check, which may be a parent name.
    ///   - entityID: The object id.
    /// - Returns: `true` if the object is held under this name or one of its children.
    public func contains ( _ entityName: String, _ entityID: UUID ) -> Bool {
        if contains_entity( entityName, entityID ) {
           return true
        }
        
        if child_class[ entityName ] != nil {
            for cls in child_class[ entityName ]! {
                if contains_entity( cls, entityID ) {
                    return true
                }
            }
        }
        
        return false
    }

    func contains_entity ( _ entityName: String, _ entityID: UUID ) -> Bool {
        if    entities[ entityName ] != nil
           && entities[ entityName ]![ entityID.cacheIndex( ) ].contains( entityID ) {
           return true
        }

        return false
    }
    
    
    /// The cached body for an id, looked up under this entity name or any of its child classes.
    ///
    /// - Parameters:
    ///   - entityName: The entity name to look under, which may be a parent name.
    ///   - entityID: The object id.
    /// - Returns: The cached body, or `nil` if it is held under neither this name nor a child class.
    ///
    /// - Note: Child classes are tried in `Set` order, so if the same id somehow sits under two
    ///   sibling classes, which of them wins is not defined. Use ``value_entity(_:_:)`` when you need
    ///   the exact class.
    public func value ( _ entityName: String, _ entityID: UUID ) -> T? {
        if let v = value_entity( entityName, entityID ) {
            return v
        }
        
        if child_class[ entityName ] != nil {
            for cls in child_class[ entityName ]! {
                if let v = value_entity( cls, entityID ) {
                    return v
                }
            }
        }
        
        return nil
    }

    /// The cached body for an id under **exactly** this entity name, ignoring child classes.
    ///
    /// - Parameters:
    ///   - entityName: The exact entity name the object was inserted under.
    ///   - entityID: The object id.
    /// - Returns: The cached body, or `nil`.
    public func value_entity ( _ entityName: String, _ entityID: UUID ) -> T? {
        return body[ entityName ]?[ entityID ]
    }


    /// Every cached body inserted under **exactly** this entity name, in no particular order.
    ///
    /// - Parameter entityName: The exact entity name. Child classes are not included.
    /// - Returns: The bodies held, or an empty array.
    public func values ( _ entityName: String ) -> [T] {
        if let dict = body[ entityName ] {
            return Array( dict.values )
        }
    
        return []
    }

    
    /// The ids from `ids` that are **not** already cached under this entity name.
    ///
    /// Hand it the ids you are interested in, get back only the ones you do not already hold.
    ///
    /// - Parameters:
    ///   - entityName: The exact entity name. Child classes are **not** consulted, unlike
    ///     ``value(_:_:)``, so ids held under a subclass are reported as missing.
    ///   - ids: The candidate ids.
    /// - Returns: `ids` minus everything cached under that name, or `ids` unchanged if the name is
    ///   unknown.
    public func diff_ids ( _ entityName: String, _ ids: Set<UUID> ) -> Set<UUID> {
        if entities[ entityName ] == nil { return ids }
        
        return ids.subtracting( entities[ entityName ]![ 0 ] )
                  .subtracting( entities[ entityName ]![ 1 ] )
                  .subtracting( entities[ entityName ]![ 2 ] )
                  .subtracting( entities[ entityName ]![ 3 ] )
    }

    
//    public func batch_insert ( _ entityName: String, _ ids: Set<UUID> ) {
//        assert_insert( entityName )
//
//        for entityID in ids {
//            insert_entity( entityName, entityID )
//        }
//    }

    /// Caches a body under an entity name and id, creating the name's buckets on first use.
    ///
    /// - Parameters:
    ///   - entityName: The exact entity name to file the object under. Superclass names are not
    ///     written to; inheritance is resolved at read time instead.
    ///   - uuid: The object id.
    ///   - entityBody: The value to cache.
    ///
    /// - Note: Not idempotent, unlike ``MECCache/insert(entity:id:body:version:)``. Inserting an id
    ///   you already hold overwrites the stored body.
    public func insert ( _ entityName: String, _ uuid: UUID, _ entityBody: T ) {
        assert_insert( entityName )
        insert_entity( entityName, uuid, entityBody )
    }

    func assert_insert ( _ entityName: String ) {
        if entities[ entityName ] == nil {
            entities[ entityName ] = [ Set( ), Set( ), Set( ), Set( ) ]
            body[ entityName ] = [:]
        }
    }
    
    func insert_entity (  _ entityName: String, _ uuid: UUID, _ entityBody: T ) {
        entities[ entityName ]![ uuid.cacheIndex( ) ].insert( uuid )
        body[ entityName ]![ uuid ] = entityBody
    }

    
    /// Drops a cached object from **exactly** this entity name.
    ///
    /// Does nothing if the name is unknown. Child classes are not touched, so an object filed under a
    /// subclass survives a removal aimed at its parent name.
    ///
    /// - Parameters:
    ///   - entityName: The exact entity name the object was inserted under.
    ///   - uuid: The object id.
    public func remove ( _ entityName: String, _ uuid: UUID ) {
        if entities[ entityName ] == nil {
            return
        }
        
        entities[ entityName ]![ uuid.cacheIndex( ) ].remove( uuid )
        
        if body[ entityName ] == nil {
            return
        }
        
        body[ entityName ]!.removeValue( forKey: uuid )
    }

    
//    func filter ( _ entityName: String, _ fetched: [t_db_row] ) -> [t_db_row] {
//        if let cache = entities[ entityName ] {
//            return fetched.filter{
//                let entity_id = UUID( uuidString: $0[ "identifier" ] as! String )!
//
//                return !cache[ 0 ].contains( entity_id )
//                    && !cache[ 1 ].contains( entity_id )
//                    && !cache[ 2 ].contains( entity_id )
//                    && !cache[ 3 ].contains( entity_id )
//            }
//        }
//
//        return fetched
//    }
    
    
    /// The entity names this cache has buckets for, in no particular order.
    ///
    /// A name appears once anything has been inserted under it, and keeps appearing after its objects
    /// are removed, because ``remove(_:_:)`` empties the buckets rather than deleting them.
    ///
    /// - Returns: The known entity names.
    public func entities_name ( ) -> [String] {
        return Array( entities.keys )
    }


    /// Every id cached under **exactly** this entity name, recombined from the four shards.
    ///
    /// - Parameter entity_name: The exact entity name. Child classes are not included.
    /// - Returns: The ids held, or an empty array if the name is unknown.
    public func entity_ids ( _ entity_name: String ) -> [UUID] {
        if let cache = entities[ entity_name ] {
            return Array( cache[ 0 ].union( cache[ 1 ].union( cache[ 2 ].union( cache[ 3 ] ) ) ) )
        }
    
        return []
    }
}

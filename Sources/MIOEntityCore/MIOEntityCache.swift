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


public class MECEntityCache<T>
{
    var body       : [ String: [ UUID: T ]   ] = [:]
    var entities   : [ String: [ Set<UUID> ] ] = [:]
    var child_class: [ String: Set<String>   ] = [:]
    
    public init ( _ superClasses: [ String: [String] ] = [:] ) {
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
    
    public func contains ( _ entityName: String, _ entityID: String ) -> Bool {
        return contains( entityName, UUID( uuidString: entityID )! )
    }
    
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

    public func value_entity ( _ entityName: String, _ entityID: UUID ) -> T? {
        return body[ entityName ]?[ entityID ]
    }

    
    public func values ( _ entityName: String ) -> [T] {
        if let dict = body[ entityName ] {
            return Array( dict.values )
        }
    
        return []
    }

    
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

    
    public func remove ( _ entityName: String, _ uuid: UUID ) {
        if entities[ entityName ] == nil {
            return
        }
        
        entities[ entityName ]![ uuid.cacheIndex( ) ].remove( uuid )
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
    
    
    public func entities_name ( ) -> [String] {
        return Array( entities.keys )
    }
    
    
    public func entity_ids ( _ entity_name: String ) -> [UUID] {
        if let cache = entities[ entity_name ] {
            return Array( cache[ 0 ].union( cache[ 1 ].union( cache[ 2 ].union( cache[ 3 ] ) ) ) )
        }
    
        return []
    }
}

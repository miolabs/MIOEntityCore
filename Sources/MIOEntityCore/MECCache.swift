//
//  MECCache.swift
//  MIOEntityCore
//
//  Created by Javier Segura Perez on 16/6/25.
//

import Foundation
import MIOCoreLogger


public typealias MECCacheObjectUpdateBlock = ( _ body:Any ) -> Any

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
    
    public var entitiesByName: [String] {
        let entities_names = Set( _objects.map { $0.entity.name } )
        return Array( entities_names )
    }
    
    public func ids( fromEntityName entityName: String) -> [UUID] {
        return _entities_by_name[ entityName ] ?? []
    }
    
    public func insert( entity: MECEntity, id: Any, body: T, version:Int64 = 0 ) -> MECCacheObject
    {
        let uuid = id is String ? _uuid_from_string( id as! String ) : id as! UUID

        var obj = fetch( entity:entity, id: uuid )
        if (obj != nil) { return obj! }

        obj = MECCacheObject( entity: entity, id: uuid, version: version, body: body )
        _entities_by_hash[ obj!.hash ] = obj!
        _objects.append( obj! )

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
    
    public func value( entity: MECEntity, id: Any, version: Int64 = 0 ) -> T? {
        let obj = fetch( entity: entity, id: id )
        return obj?.body as? T
    }

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
    
    public func contains ( entity: MECEntity, id: Any ) -> Bool {
        return fetch( entity: entity, id: id ) != nil ? true : false
    }
    
    public func diffIDs ( entity: MECEntity, ids: Set<UUID> ) -> Set<UUID> {
        guard let array = _entities_by_name[ entity.name ] else { return ids }
        
        let cache_ids:Set<UUID> = Set( array )
        return ids.subtracting( cache_ids )
    }

}

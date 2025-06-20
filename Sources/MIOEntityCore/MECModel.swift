//
//  MECModel.swift
//  MIOEntityCore
//
//  Created by Javier Segura Perez on 17/6/25.
//

public class MECModel
{
    var entities: [MECEntity]
    
    open var _entities_by_name: [String: MECEntity]
    public var entitiesByName: [String: MECEntity] { return _entities_by_name }
    
    public init( entities: [MECEntity] ) {
        self.entities = entities
        self._entities_by_name = [:]
        for e in entities {
            _entities_by_name[e.name] = e
        }
    }
    
    public func addEntity(_ entity: MECEntity) {
        entities.append( entity )
        _entities_by_name[entity.name] = entity
    }
}

public final class MECEntity
{
    var name: String
    var isAbstract: Bool
    
    var superEntity: MECEntity? = nil
    var subEntities: [MECEntity] = []
    
    public init(name: String, isAbstract: Bool = false) {
        self.name = name
        self.isAbstract = isAbstract
    }
    
    public func setParent(_ parent: MECEntity?) {
        superEntity = parent
        parent?.subEntities.append( self )
    }
}

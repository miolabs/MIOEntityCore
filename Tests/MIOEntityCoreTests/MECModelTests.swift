//
//  MECModelTests.swift
//
//  Created by MIO Research Labs on 2026.
//

import XCTest
@testable import MIOEntityCore

final class MECModelTests: XCTestCase {
    // MARK: - MECModel

    func testInitIndexesEntitiesByName ( ) throws {
        let product  = MECEntity( name: "Product" )
        let menuItem = MECEntity( name: "MenuItem" )
        let model    = MECModel( entities: [ product, menuItem ] )

        XCTAssertEqual( Set( model.entitiesByName.keys ), [ "Product", "MenuItem" ] )
        XCTAssertTrue( model.entitiesByName[ "Product" ] === product )
    }

    func testAddEntityIndexesTheNewEntity ( ) throws {
        let model    = MECModel( entities: [ ] )
        let product  = MECEntity( name: "Product" )

        XCTAssertTrue( model.entitiesByName.isEmpty )
        model.addEntity( product )

        XCTAssertTrue( model.entitiesByName[ "Product" ] === product )
        XCTAssertEqual( model.entities.count, 1 )
    }

    func testRepeatedNameReplacesInTheIndexButBothStayInTheList ( ) throws {
        let first  = MECEntity( name: "Product" )
        let second = MECEntity( name: "Product" )
        let model  = MECModel( entities: [ first ] )

        model.addEntity( second )

        XCTAssertTrue( model.entitiesByName[ "Product" ] === second )
        XCTAssertEqual( model.entities.count, 2 )
    }

    func testEntitiesByNameIndexIsReplaceable ( ) throws {
        let model = MECModel( entities: [ MECEntity( name: "Product" ) ] )

        model._entities_by_name = [ : ]

        XCTAssertTrue( model.entitiesByName.isEmpty )
    }

    // MARK: - MECEntity

    func testEntityIsConcreteByDefault ( ) throws {
        XCTAssertFalse( MECEntity( name: "Product" ).isAbstract )
        XCTAssertTrue( MECEntity( name: "Document", isAbstract: true ).isAbstract )
    }

    func testSetParentWiresBothDirections ( ) throws {
        let product  = MECEntity( name: "Product" )
        let menuItem = MECEntity( name: "MenuItem" )

        menuItem.setParent( product )

        XCTAssertTrue( menuItem.superEntity === product )
        XCTAssertEqual( product.subEntities.count, 1 )
        XCTAssertTrue( product.subEntities.first === menuItem )
    }

    func testSetParentNilLeavesTheOldParentsSubEntities ( ) throws {
        let product  = MECEntity( name: "Product" )
        let menuItem = MECEntity( name: "MenuItem" )

        menuItem.setParent( product )
        menuItem.setParent( nil )

        XCTAssertNil( menuItem.superEntity )
        XCTAssertEqual( product.subEntities.count, 1 )
    }

    func testSetParentTwiceAppendsToBothParents ( ) throws {
        let document = MECEntity( name: "Document" )
        let product  = MECEntity( name: "Product" )
        let menuItem = MECEntity( name: "MenuItem" )

        menuItem.setParent( document )
        menuItem.setParent( product )

        XCTAssertTrue( menuItem.superEntity === product )
        XCTAssertEqual( document.subEntities.count, 1 )
        XCTAssertEqual( product.subEntities.count, 1 )
    }

    func testHierarchyDrivesCacheInheritance ( ) throws {
        let product  = MECEntity( name: "Product" )
        let menuItem = MECEntity( name: "MenuItem" )
        let model    = MECModel( entities: [ product, menuItem ] )
        let id       = UUID( )

        menuItem.setParent( product )

        let cache = MECCache<[String:Any]>( )
        _ = cache.insert( entity: model.entitiesByName[ "MenuItem" ]!, id: id, body: [ : ] )

        XCTAssertTrue( cache.contains( entity: model.entitiesByName[ "Product" ]!, id: id ) )
    }
}

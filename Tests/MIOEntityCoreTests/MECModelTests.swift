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

    /// The index used to be replaceable wholesale through an `open` backing
    /// property, which let it drift out of step with ``MECModel/entities``. It is
    /// private now, and the only ways in are the initialiser and `addEntity`.
    func testTheIndexCannotDriftFromTheList ( ) throws {
        let model = MECModel( entities: [ MECEntity( name: "Product" ) ] )
        model.addEntity( MECEntity( name: "MenuItem" ) )

        XCTAssertEqual( model.entities.count, model.entitiesByName.count )
    }

    /// The lookup a relationship needs: they hold the destination's name, so
    /// resolving one is the model's job.
    func testEntityNamed ( ) throws {
        let product = MECEntity( name: "Product" )
        let model   = MECModel( entities: [ product ] )

        XCTAssertTrue( model.entity( named: "Product" ) === product )
        XCTAssertNil( model.entity( named: "Nowhere" ) )
    }

    // MARK: - MECEntity

    func testEntityIsConcreteByDefault ( ) throws {
        XCTAssertFalse( MECEntity( name: "Product" ).isAbstract )
        XCTAssertTrue( MECEntity( name: "Document", isAbstract: true ).isAbstract )
    }

    func testTheParentIsPassedAtInit ( ) throws {
        let product  = MECEntity( name: "Product" )
        let menuItem = MECEntity( name: "MenuItem", superEntity: product )

        XCTAssertTrue( menuItem.superEntity === product )
        XCTAssertNil( product.superEntity )
    }

    /// The downward list is derived, so it cannot drift from the upward links
    /// the way an appended-to array could.
    func testSubEntitiesComeFromTheModel ( ) throws {
        let product  = MECEntity( name: "Product" )
        let menuItem = MECEntity( name: "MenuItem", superEntity: product )
        let model    = MECModel( entities: [ product, menuItem ] )

        XCTAssertEqual( model.subEntities( of: product ).map( \.name ), [ "MenuItem" ] )
        XCTAssertTrue( model.subEntities( of: menuItem ).isEmpty )
    }

    /// An entity added later is answered for immediately, because nothing was
    /// cached at wiring time. The three tests this replaced covered the opposite
    /// situation: `setParent( nil )` left the child in the old parent's list, and
    /// calling it twice put the child in two parents at once. Neither state is
    /// reachable now.
    func testSubEntitiesSeeAnEntityAddedLater ( ) throws {
        let product = MECEntity( name: "Product" )
        let model   = MECModel( entities: [ product ] )

        XCTAssertTrue( model.subEntities( of: product ).isEmpty )

        model.addEntity( MECEntity( name: "MenuItem", superEntity: product ) )

        XCTAssertEqual( model.subEntities( of: product ).map( \.name ), [ "MenuItem" ] )
    }

    /// A model only answers for the entities it holds. An entity built outside
    /// one has no subentities, whoever points at it.
    func testSubEntitiesOnlyCountsTheModelsOwn ( ) throws {
        let product = MECEntity( name: "Product" )
        let stray   = MECEntity( name: "Stray", superEntity: product )
        let model   = MECModel( entities: [ product ] )

        XCTAssertTrue( model.subEntities( of: product ).isEmpty, "\(stray.name) is not in this model" )
    }

    func testHierarchyDrivesCacheInheritance ( ) throws {
        let product  = MECEntity( name: "Product" )
        let menuItem = MECEntity( name: "MenuItem", superEntity: product )
        let model    = MECModel( entities: [ product, menuItem ] )
        let id       = UUID( )

        let cache = MECCache<[String:Any]>( )
        _ = cache.insert( entity: model.entitiesByName[ "MenuItem" ]!, id: id, body: [ : ] )

        XCTAssertTrue( cache.contains( entity: model.entitiesByName[ "Product" ]!, id: id ) )
    }
}

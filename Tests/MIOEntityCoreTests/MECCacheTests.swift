//
//  MECCacheTests.swift
//
//  Created by MIO Research Labs on 2026.
//

import XCTest
@testable import MIOEntityCore

final class MECCacheTests: XCTestCase {
    // Document (abstract) <- Product (concrete) <- MenuItem (concrete)
    private struct Model {
        let document: MECEntity
        let product: MECEntity
        let menuItem: MECEntity

        // Roots first: a parent has to exist before the child that names it.
        init ( ) {
            document = MECEntity( name: "Document", isAbstract: true )
            product  = MECEntity( name: "Product", superEntity: document )
            menuItem = MECEntity( name: "MenuItem", superEntity: product )
        }
    }

    // MARK: - insert and fetch

    func testInsertThenFetchByOwnEntity ( ) throws {
        let m     = Model( )
        let id    = UUID( )
        let cache = MECCache<[String:Any]>( )

        _ = cache.insert( entity: m.menuItem, id: id, body: [ "name": "Latte" ] )

        let body = cache.value( entity: m.menuItem, id: id )

        XCTAssertNotNil( cache.fetch( entity: m.menuItem, id: id ) )
        XCTAssertEqual( body?[ "name" ] as? String, "Latte" )
    }

    func testInsertAcceptsStringID ( ) throws {
        let m     = Model( )
        let id    = UUID( )
        let cache = MECCache<[String:Any]>( )

        _ = cache.insert( entity: m.menuItem, id: id.uuidString, body: [ "name": "Latte" ] )

        XCTAssertTrue( cache.contains( entity: m.menuItem, id: id ) )
        XCTAssertTrue( cache.contains( entity: m.menuItem, id: id.uuidString ) )
    }

    func testInsertIsIdempotent ( ) throws {
        let m     = Model( )
        let id    = UUID( )
        let cache = MECCache<[String:Any]>( )

        _ = cache.insert( entity: m.menuItem, id: id, body: [ "name": "first" ], version: 1 )
        _ = cache.insert( entity: m.menuItem, id: id, body: [ "name": "second" ], version: 9 )

        let body = cache.value( entity: m.menuItem, id: id )

        XCTAssertEqual( body?[ "name" ] as? String, "first" )
        XCTAssertEqual( cache.ids( fromEntityName: "MenuItem" ).count, 1 )
    }

    func testFetchMissingReturnsNil ( ) throws {
        let m     = Model( )
        let cache = MECCache<[String:Any]>( )

        XCTAssertNil( cache.fetch( entity: m.menuItem, id: UUID( ) ) )
        XCTAssertFalse( cache.contains( entity: m.menuItem, id: UUID( ) ) )
    }

    // MARK: - inheritance

    func testFetchByConcreteSuperentity ( ) throws {
        let m     = Model( )
        let id    = UUID( )
        let cache = MECCache<[String:Any]>( )

        _ = cache.insert( entity: m.menuItem, id: id, body: [ "name": "Latte" ] )

        let body = cache.value( entity: m.product, id: id )

        XCTAssertTrue( cache.contains( entity: m.product, id: id ) )
        XCTAssertEqual( body?[ "name" ] as? String, "Latte" )
    }

    func testIDsFromEntityNameIncludesInheritedRegistration ( ) throws {
        let m     = Model( )
        let id    = UUID( )
        let cache = MECCache<[String:Any]>( )

        _ = cache.insert( entity: m.menuItem, id: id, body: [ : ] )

        XCTAssertEqual( cache.ids( fromEntityName: "MenuItem" ), [ id ] )
        XCTAssertEqual( cache.ids( fromEntityName: "Product" ), [ id ] )
    }

    func testFetchByAbstractSuperentityMisses ( ) throws {
        let m     = Model( )
        let id    = UUID( )
        let cache = MECCache<[String:Any]>( )

        _ = cache.insert( entity: m.menuItem, id: id, body: [ "name": "Latte" ] )

        XCTAssertFalse( cache.contains( entity: m.document, id: id ) )
        XCTAssertNil( cache.value( entity: m.document, id: id ) )
        XCTAssertEqual( cache.ids( fromEntityName: "Document" ), [ ] )
    }

    func testInsertingAsAnAbstractEntityDoesIndexIt ( ) throws {
        let m     = Model( )
        let id    = UUID( )
        let cache = MECCache<[String:Any]>( )

        _ = cache.insert( entity: m.document, id: id, body: [ "name": "raw" ] )

        XCTAssertTrue( cache.contains( entity: m.document, id: id ) )
    }

    // MARK: - value

    func testValueDoesNotFilterByVersion ( ) throws {
        let m     = Model( )
        let id    = UUID( )
        let cache = MECCache<[String:Any]>( )

        _ = cache.insert( entity: m.menuItem, id: id, body: [ "name": "Latte" ], version: 3 )

        XCTAssertNotNil( cache.value( entity: m.menuItem, id: id, version: 999 ) )
    }

    func testValueReturnsNilWhenBodyIsNotT ( ) throws {
        let m     = Model( )
        let id    = UUID( )
        let cache = MECCache<String>( )

        _ = cache.insert( entity: m.menuItem, id: id, body: "a string" )

        XCTAssertEqual( cache.value( entity: m.menuItem, id: id ), "a string" )
        XCTAssertNotNil( cache.fetch( entity: m.menuItem, id: id ) )
    }

    // MARK: - update

    func testUpdateRewritesBodyAndVersion ( ) throws {
        let m     = Model( )
        let id    = UUID( )
        let cache = MECCache<[String:Any]>( )

        _ = cache.insert( entity: m.menuItem, id: id, body: [ "price": 2.10 ], version: 1 )

        cache.update( entity: m.menuItem, id, version: 4 ) { body in
            guard var updated = body as? [String:Any] else { return body }
            updated[ "price" ] = 2.40
            return updated
        }

        let body   = cache.value( entity: m.menuItem, id: id )
        let object = cache.fetch( entity: m.menuItem, id: id )

        XCTAssertEqual( body?[ "price" ] as? Double, 2.40 )
        XCTAssertEqual( object?.version, 4 )
    }

    func testContainsWalksUpSoASubentityLookupFindsAParentsObject ( ) throws {
        let m     = Model( )
        let id    = UUID( )
        let cache = MECCache<[String:Any]>( )

        _ = cache.insert( entity: m.product, id: id, body: [ "name": "Latte" ] )

        XCTAssertTrue( cache.contains( entity: m.menuItem, id: id ) )
        XCTAssertEqual( cache.ids( fromEntityName: "MenuItem" ), [ ] )
        XCTAssertEqual( cache.ids( fromEntityName: "Product" ), [ id ] )
    }

    func testUpdatePromotesFromSuperentityToSubentity ( ) throws {
        let m     = Model( )
        let id    = UUID( )
        let cache = MECCache<[String:Any]>( )

        _ = cache.insert( entity: m.product, id: id, body: [ "name": "Latte" ], version: 1 )

        let beforeUpdate = cache.fetch( entity: m.menuItem, id: id )

        XCTAssertEqual( beforeUpdate?.entity.name, "Product" )
        XCTAssertEqual( cache.ids( fromEntityName: "MenuItem" ), [ ] )

        cache.update( entity: m.menuItem, id, version: 2 ) { $0 }

        let afterUpdate = cache.fetch( entity: m.menuItem, id: id )

        XCTAssertEqual( afterUpdate?.entity.name, "MenuItem" )
        XCTAssertEqual( afterUpdate?.version, 2 )
        XCTAssertEqual( cache.ids( fromEntityName: "MenuItem" ), [ id ] )
        XCTAssertTrue( cache.contains( entity: m.product, id: id ) )
    }

    func testUpdateOnMissingObjectIsASilentNoOp ( ) throws {
        let m     = Model( )
        let cache = MECCache<[String:Any]>( )

        var blockRan = false

        cache.update( entity: m.menuItem, UUID( ), version: 1 ) { body in
            blockRan = true
            return body
        }

        XCTAssertFalse( blockRan )
    }

    // MARK: - remove

    func testRemoveUnindexesFromOwnEntityAndSuperentities ( ) throws {
        let m     = Model( )
        let id    = UUID( )
        let cache = MECCache<[String:Any]>( )

        _ = cache.insert( entity: m.menuItem, id: id, body: [ : ] )
        cache.remove( entity: m.menuItem, id: id )

        XCTAssertFalse( cache.contains( entity: m.menuItem, id: id ) )
        XCTAssertFalse( cache.contains( entity: m.product, id: id ) )
        XCTAssertEqual( cache.ids( fromEntityName: "MenuItem" ), [ ] )
        XCTAssertEqual( cache.ids( fromEntityName: "Product" ), [ ] )
    }

    func testRemoveOfAnAbsentObjectIsANoOp ( ) throws {
        let m     = Model( )
        let id    = UUID( )
        let cache = MECCache<[String:Any]>( )

        _ = cache.insert( entity: m.menuItem, id: id, body: [ : ] )
        cache.remove( entity: m.menuItem, id: UUID( ) )

        XCTAssertTrue( cache.contains( entity: m.menuItem, id: id ) )
    }

    func testEntitiesByNameKeepsANameAfterItsLastObjectIsRemoved ( ) throws {
        let m     = Model( )
        let id    = UUID( )
        let cache = MECCache<[String:Any]>( )

        _ = cache.insert( entity: m.menuItem, id: id, body: [ : ] )
        XCTAssertEqual( cache.entitiesByName, [ "MenuItem" ] )

        cache.remove( entity: m.menuItem, id: id )

        XCTAssertEqual( cache.entitiesByName, [ "MenuItem" ] )
        XCTAssertEqual( cache.ids( fromEntityName: "MenuItem" ), [ ] )
        XCTAssertFalse( cache.contains( entity: m.menuItem, id: id ) )
    }

    // MARK: - diffIDs

    func testDiffIDsReturnsOnlyTheMissingIDs ( ) throws {
        let m       = Model( )
        let held    = UUID( )
        let missing = UUID( )
        let cache   = MECCache<[String:Any]>( )

        _ = cache.insert( entity: m.menuItem, id: held, body: [ : ] )

        XCTAssertEqual( cache.diffIDs( entity: m.menuItem, ids: [ held, missing ] ), [ missing ] )
    }

    func testDiffIDsReturnsEverythingForAnUnknownEntity ( ) throws {
        let m     = Model( )
        let ids   = Set( [ UUID( ), UUID( ) ] )
        let cache = MECCache<[String:Any]>( )

        XCTAssertEqual( cache.diffIDs( entity: m.menuItem, ids: ids ), ids )
    }

    func testDiffIDsComparesIDsNotVersions ( ) throws {
        let m     = Model( )
        let id    = UUID( )
        let cache = MECCache<[String:Any]>( )

        _ = cache.insert( entity: m.menuItem, id: id, body: [ : ], version: 1 )

        XCTAssertEqual( cache.diffIDs( entity: m.menuItem, ids: [ id ] ), [ ] )
    }

    func testDiffIDsOnASuperentitySeesSubentityRegistrations ( ) throws {
        let m     = Model( )
        let id    = UUID( )
        let cache = MECCache<[String:Any]>( )

        _ = cache.insert( entity: m.menuItem, id: id, body: [ : ] )

        XCTAssertEqual( cache.diffIDs( entity: m.product, ids: [ id ] ), [ ] )
    }
}

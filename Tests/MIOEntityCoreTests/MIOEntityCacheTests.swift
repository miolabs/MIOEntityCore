//
//  MIOEntityCacheTests.swift
//
//  Created by MIO Research Labs on 2026.
//

import XCTest
@testable import MIOEntityCore

final class MIOEntityCacheTests: XCTestCase {
    func testContains() throws {
        let entity1_id = UUID( )
        let cache = MECEntityCache<[String:Any]>( )
        
        cache.insert( "A", entity1_id, ["hello": "world"] )
        
        XCTAssertTrue( cache.contains( "A", entity1_id ) )
        XCTAssertFalse( cache.contains( "B", entity1_id ) )
        XCTAssertEqual( cache.value( "A", entity1_id )?[ "hello" ] as! String, "world" )
    }

    
    func testContainsInherit() throws {
        let entity1_id = UUID( )
        // C inherits from B that inherits from A
        let cache = MECEntityCache<[String:Any]>(  [ "C": [ "B", "A" ] ]  )
        
        cache.insert( "C", entity1_id, ["hello": "world"] )
        
        XCTAssertTrue( cache.contains( "A", entity1_id ) )
        XCTAssertTrue( cache.contains( "B", entity1_id ) )
        XCTAssertTrue( cache.contains( "C", entity1_id ) )
        XCTAssertEqual( cache.value( "A", entity1_id )?[ "hello" ] as? String, "world" )
        XCTAssertEqual( cache.value( "B", entity1_id )?[ "hello" ] as? String, "world" )
        XCTAssertEqual( cache.value( "C", entity1_id )?[ "hello" ] as? String, "world" )
    }

    func testNoArgumentInitMeansNoInheritanceWidening ( ) throws {
        let entity1_id = UUID( )
        let cache = MECEntityCache<[String:Any]>( )

        cache.insert( "C", entity1_id, [ "hello": "world" ] )

        XCTAssertTrue( cache.contains( "C", entity1_id ) )
        XCTAssertFalse( cache.contains( "B", entity1_id ) )
        XCTAssertFalse( cache.contains( "A", entity1_id ) )
        XCTAssertNil( cache.value( "A", entity1_id ) )
    }

    func testDirectParentsOnlyMapMissesTheGrandparent ( ) throws {
        let entity1_id = UUID( )
        let cache = MECEntityCache<[String:Any]>( [ "C": [ "B" ], "B": [ "A" ] ] )

        cache.insert( "C", entity1_id, [ "hello": "world" ] )

        XCTAssertTrue( cache.contains( "B", entity1_id ) )
        XCTAssertFalse( cache.contains( "A", entity1_id ) )
    }

    // MARK: - exact-name reads

    func testValueEntityIgnoresChildClasses ( ) throws {
        let entity1_id = UUID( )
        let cache = MECEntityCache<[String:Any]>( [ "C": [ "B", "A" ] ] )

        cache.insert( "C", entity1_id, [ "hello": "world" ] )

        XCTAssertNotNil( cache.value( "A", entity1_id ) )
        XCTAssertNil( cache.value_entity( "A", entity1_id ) )
        XCTAssertNotNil( cache.value_entity( "C", entity1_id ) )
    }

    func testDiffIDsIsNotInheritanceAware ( ) throws {
        let entity1_id = UUID( )
        let cache = MECEntityCache<[String:Any]>( [ "C": [ "B", "A" ] ] )

        cache.insert( "C", entity1_id, [ "hello": "world" ] )

        XCTAssertTrue( cache.contains( "A", entity1_id ) )
        XCTAssertEqual( cache.diff_ids( "A", [ entity1_id ] ), [ entity1_id ] )
        XCTAssertEqual( cache.diff_ids( "C", [ entity1_id ] ), [ ] )
    }

    // MARK: - insert, remove, enumeration

    func testInsertIsNotIdempotentAndOverwrites ( ) throws {
        let entity1_id = UUID( )
        let cache = MECEntityCache<[String:Any]>( )

        cache.insert( "A", entity1_id, [ "hello": "first" ] )
        cache.insert( "A", entity1_id, [ "hello": "second" ] )

        let body = cache.value( "A", entity1_id )

        XCTAssertEqual( body?[ "hello" ] as? String, "second" )
        XCTAssertEqual( cache.entity_ids( "A" ).count, 1 )
    }

    func testRemoveOnlyTouchesTheExactName ( ) throws {
        let entity1_id = UUID( )
        let cache = MECEntityCache<[String:Any]>( [ "C": [ "B", "A" ] ] )

        cache.insert( "C", entity1_id, [ "hello": "world" ] )
        cache.remove( "A", entity1_id )

        XCTAssertTrue( cache.contains( "C", entity1_id ) )

        cache.remove( "C", entity1_id )
        XCTAssertFalse( cache.contains( "C", entity1_id ) )
    }

    func testEntitiesNameKeepsANameAfterItsObjectsAreGone ( ) throws {
        let entity1_id = UUID( )
        let cache = MECEntityCache<[String:Any]>( )

        cache.insert( "A", entity1_id, [ "hello": "world" ] )
        cache.remove( "A", entity1_id )

        XCTAssertEqual( cache.entities_name( ), [ "A" ] )
        XCTAssertEqual( cache.entity_ids( "A" ), [ ] )
    }

    func testValuesReturnsEveryBodyUnderTheExactName ( ) throws {
        let cache = MECEntityCache<[String:Any]>( )
        let ids = [ UUID( ), UUID( ), UUID( ) ]

        for (i, id) in ids.enumerated( ) {
            cache.insert( "A", id, [ "n": i ] )
        }

        XCTAssertEqual( cache.values( "A" ).count, 3 )
        XCTAssertEqual( Set( cache.entity_ids( "A" ) ), Set( ids ) )
        XCTAssertEqual( cache.values( "B" ).count, 0 )
    }

    func testIDsAreShardedAcrossFourBucketsButReadBackWhole ( ) throws {
        let cache = MECEntityCache<[String:Any]>( )
        let ids = ( 0 ..< 64 ).map { _ in UUID( ) }

        for id in ids { cache.insert( "A", id, [ : ] ) }

        XCTAssertEqual( Set( cache.entity_ids( "A" ) ), Set( ids ) )
        XCTAssertEqual( cache.diff_ids( "A", Set( ids ) ), [ ] )
    }
}

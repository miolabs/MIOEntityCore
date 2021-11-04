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
        let cache = MECEntityCache<[String:Any]>(  [ "C": [ "B", "A" ] ]  )
        
        cache.insert( "C", entity1_id, ["hello": "world"] )
        
        XCTAssertTrue( cache.contains( "A", entity1_id ) )
        XCTAssertTrue( cache.contains( "B", entity1_id ) )
        XCTAssertTrue( cache.contains( "C", entity1_id ) )
        XCTAssertEqual( cache.value( "A", entity1_id )?[ "hello" ] as? String, "world" )
        XCTAssertEqual( cache.value( "B", entity1_id )?[ "hello" ] as? String, "world" )
        XCTAssertEqual( cache.value( "C", entity1_id )?[ "hello" ] as? String, "world" )
    }
}

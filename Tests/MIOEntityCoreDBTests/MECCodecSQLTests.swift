//
//  MECCodecSQLTests.swift
//  MIOEntityCoreTests
//
//  Created by MIO Research Labs on 2026.
//
//  Phase 4 of MIOENTITYCORE-ENTITY-OWNERSHIP-PLAN.md: the SQL leg.
//
//  The rows mirror MIODB/Tests/MIODBTests/TestGoldenRendering.swift, which
//  pinned what `MDBValue`'s own type-sniffing initialiser produces. Same
//  instant, same UUID, same order. Where a row here disagrees with the row
//  there, the disagreement is the point of this file and is called out.
//

import Foundation
import XCTest
import MIODB
import MIOEntityCore
@testable import MIOEntityCoreDB

final class MECCodecSQLTests : XCTestCase
{
    /// The same instant both golden tables use. 2023-11-14 22:13:20 UTC.
    static let instant = Date( timeIntervalSince1970: 1_700_000_000 )

    static let uuid = UUID( uuidString: "6BA7B810-9DAD-11D1-80B4-00C04FD430C8" )!

    // MARK: - The table

    func testGoldenSQLRendering ( ) throws {
        // (type, the model value it holds, the SQL it renders as)
        let rows: [( type: MECAttributeType, value: Any?, sql: String )] = [
            ( .string,    "L'Oréal",                  "'L''Oréal'"                    ),
            ( .integer16, Int16( 42 ),                "42"                            ),
            ( .integer32, Int32( 42 ),                "42"                            ),
            ( .integer64, Int64( 42 ),                "42"                            ),
            ( .integer64, Int( 42 ),                  "42"                            ),
            ( .double,    Double( 1.5 ),              "1.5"                           ),
            ( .float,     Float( 1.5 ),               "1.5"                           ),
            ( .boolean,   true,                       "TRUE"                          ),
            ( .boolean,   false,                      "FALSE"                         ),
            ( .decimal,   Decimal( string: "1.50" )!, "1.5"                           ),
            ( .date,      Self.instant,               "'2023-11-14 22:13:20.000000'"  ),
            ( .uuid,      Self.uuid,                  "'6BA7B810-9DAD-11D1-80B4-00C04FD430C8'" ),
            ( .string,    nil,                        "NULL"                          ),
        ]

        for row in rows {
            let rendered = try row.type.dbValue( from: row.value ).value
            XCTAssertEqual( rendered, row.sql, "SQL rendering of \(row.type)" )
        }
    }

    // MARK: - What this leg does that MDBValue's own initialiser cannot

    /// The reason this method exists. `MDBValue( _: Any? )` sniffs the Swift
    /// type, so a decimal a driver handed back as a `Double` is stored as
    /// `.double` and rendered through `String( Double )`. Here the model's
    /// declared type wins and the value is read to fit it.
    func testTheDeclaredTypeWins ( ) throws {
        let sniffed = try MDBValue( Double( 1.5 ) )
        if case .double = sniffed.storage {} else { XCTFail( "the old path sniffs to .double" ) }

        let declared = try MECAttributeType.decimal.dbValue( from: Double( 1.5 ) )
        if case .decimal = declared.storage {} else {
            XCTFail( "the declared type says decimal, so the storage is decimal" )
        }
    }

    /// An integer arrives at whatever width the driver felt like. The declared
    /// type says integer, so all of them land as `.int`.
    func testEveryIntegerWidthLands ( ) throws {
        for value in [ Int8( 42 ) as Any, Int16( 42 ), Int32( 42 ), Int64( 42 ), Int( 42 ) ] {
            let rendered = try MECAttributeType.integer64.dbValue( from: value ).value
            XCTAssertEqual( rendered, "42", "\(type( of: value ))" )
        }
    }

    /// Same normalisation as the JSON leg, so identity has one spelling
    /// whichever side read it.
    func testUUIDFromTextIsNormalised ( ) throws {
        let rendered = try MECAttributeType.uuid.dbValue( from: "6ba7b810-9dad-11d1-80b4-00c04fd430c8" ).value
        XCTAssertEqual( rendered, "'6BA7B810-9DAD-11D1-80B4-00C04FD430C8'" )
    }

    // MARK: - Where the two legs deliberately differ

    /// **A behaviour change, on purpose.** `MDBValue( URL )` throws, because a
    /// `URL` is not in its `is`-chain, which was an accident of type-sniffing
    /// rather than a decision. A URI is its absolute string in SQL exactly as it
    /// is in JSON, so this leg renders it.
    func testURIRendersHereAndNotThroughTheOldPath ( ) throws {
        let url = URL( string: "https://miolabs.com/a" )!

        XCTAssertThrowsError( try MDBValue( url ).value, "the old sniffing path has no URL case" )
        XCTAssertEqual( try MECAttributeType.uri.dbValue( from: url ).value,
                        "'https://miolabs.com/a'" )
    }

    /// **Still refused, and deliberately.** `MDBValueStorage` has no bytes case,
    /// and every encoding available here is wrong in a different way: base64
    /// text lands in a `bytea` column as characters, and a hex literal is
    /// dialect-specific. The fix is a storage case in MIODB, not a guess at this
    /// layer, so the refusal is explicit and names why.
    func testBinaryDataIsRefusedWithAReason ( ) {
        XCTAssertThrowsError( try MECAttributeType.binaryData.dbValue( from: Data( "MIO".utf8 ),
                                                                       entity: "Item",
                                                                       property: "blob" ) ) { error in
            XCTAssertEqual( error as? MECError,
                            .unsupportedAttribute( entity: "Item", property: "blob",
                                                   reason: "binary data has no SQL storage in MIODB yet" ) )
        }
    }

    func testTransformableIsRefused ( ) {
        XCTAssertThrowsError( try MECAttributeType.transformable.dbValue( from: "anything" ) )
    }

    /// Core Data's own identity is not a value a backend stores. Null here, and
    /// null in JSON too.
    func testObjectIDAndUndefinedAreNull ( ) throws {
        XCTAssertEqual( try MECAttributeType.objectID.dbValue( from: "anything" ).value, "NULL" )
        XCTAssertEqual( try MECAttributeType.undefined.dbValue( from: "anything" ).value, "NULL" )
    }

    // MARK: - Absence, defaults, and the required check

    func testAbsentOptionalIsNull ( ) throws {
        let note = MECAttribute( name: "note", type: .string, isOptional: true )
        XCTAssertEqual( try note.dbValue( from: nil, in: "Item" ).value, "NULL" )
    }

    func testAbsentRequiredIsAnError ( ) {
        let title = MECAttribute( name: "title", type: .string )
        XCTAssertThrowsError( try title.dbValue( from: nil, in: "Item" ) ) { error in
            XCTAssertEqual( error as? MECError,
                            .missingRequiredValue( entity: "Item", property: "title" ) )
        }
    }

    /// The same order as the JSON leg: default first, required check second.
    func testTheDefaultIsUsedBeforeTheRequiredCheck ( ) throws {
        let count = MECAttribute( name: "count", type: .integer64, defaultValueString: "3" )
        XCTAssertEqual( try count.dbValue( from: nil, in: "Item" ).value, "3" )
    }

    /// The declared type reads the text, so a boolean default of `"1"` is
    /// `TRUE` in SQL and an integer default of `"1"` is `1`.
    func testTheSameDefaultTextRendersTwoWays ( ) throws {
        let done  = MECAttribute( name: "done", type: .boolean, defaultValueString: "1" )
        let count = MECAttribute( name: "count", type: .integer64, defaultValueString: "1" )

        XCTAssertEqual( try done.dbValue( from: nil, in: "Item" ).value, "TRUE" )
        XCTAssertEqual( try count.dbValue( from: nil, in: "Item" ).value, "1" )
    }
}

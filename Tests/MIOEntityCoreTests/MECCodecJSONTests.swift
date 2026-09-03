//
//  MECCodecJSONTests.swift
//  MIOEntityCoreTests
//
//  Created by MIO Research Labs on 2026.
//
//  Phase 2 of MIOENTITYCORE-ENTITY-OWNERSHIP-PLAN.md: the JSON leg.
//
//  The table below is the same one pinned in
//  MIOCoreData/Tests/MIOCoreDataSerializationTests/TestGoldenRendering.swift,
//  against the code this leg replaces. Same instant, same UUID, same row order,
//  same expected strings. That is the acceptance test for the port: if a row
//  here disagrees with the row there, the move changed behaviour.
//

import Foundation
import XCTest
@testable import MIOEntityCore

final class MECCodecJSONTests : XCTestCase
{
    /// The same instant both golden tables use. 2023-11-14 22:13:20 UTC.
    static let instant = Date( timeIntervalSince1970: 1_700_000_000 )

    static let uuid = UUID( uuidString: "6BA7B810-9DAD-11D1-80B4-00C04FD430C8" )!

    /// Renders whatever the codec returned as a stable string, so the table can
    /// hold literals rather than typed comparisons.
    private func describe( _ value: Any? ) -> String {
        switch value {
            case nil:                return "nil"
            case is NSNull:          return "null"
            case let text as String: return text
            case let flag as Bool:   return flag ? "true" : "false"
            case let other?:         return String( describing: other )
        }
    }

    // MARK: - The table

    func testGoldenJSONRendering ( ) throws {
        // (type, the model value it holds, the JSON it renders as)
        let rows: [( type: MECAttributeType, value: Any?, json: String )] = [
            ( .string,     "L'Oréal",                  "L'Oréal"                              ),
            ( .integer16,  Int( 42 ),                  "42"                                   ),
            ( .integer32,  Int( 42 ),                  "42"                                   ),
            ( .integer64,  Int( 42 ),                  "42"                                   ),
            ( .double,     Double( 1.5 ),              "1.5"                                  ),
            ( .float,      Float( 1.5 ),               "1.5"                                  ),
            ( .boolean,    true,                       "true"                                 ),
            ( .decimal,    Decimal( string: "1.50" )!, "1.5"                                  ),
            ( .date,       Self.instant,               "2023-11-14T22:13:20.000Z"             ),
            ( .uuid,       Self.uuid,                  "6BA7B810-9DAD-11D1-80B4-00C04FD430C8" ),
            ( .binaryData, Data( "MIO".utf8 ),         "TUlP"                                 ),
            ( .uri,        URL( string: "https://miolabs.com/a" )!, "https://miolabs.com/a"   ),
        ]

        for row in rows {
            let rendered = try row.type.jsonValue( from: row.value )
            XCTAssertEqual( describe( rendered ), row.json, "JSON rendering of \(row.type)" )
        }
    }

    // MARK: - Policy

    func testDefaultPolicy ( ) {
        let policy = MECPolicy.default
        XCTAssertTrue( policy.uppercaseUUIDs )
        XCTAssertFalse( policy.includeNulls )
        XCTAssertEqual( policy.dateFormatter( Self.instant ), "2023-11-14T22:13:20.000Z" )
        XCTAssertEqual( policy.decimalFormat, .string )
    }

    func testDecimalAsNumberIsTheOtherPolicy ( ) throws {
        let rendered = try MECAttributeType.decimal.jsonValue( from: Decimal( string: "1.50" )!,
                                                               policy: MECPolicy( decimalFormat: .number ) )
        XCTAssertTrue( rendered is NSDecimalNumber, "a number, not a string" )
    }

    func testLowercaseUUIDsAreAPolicy ( ) throws {
        let rendered = try MECAttributeType.uuid.jsonValue( from: Self.uuid,
                                                            policy: MECPolicy( uppercaseUUIDs: false ) )
        XCTAssertEqual( describe( rendered ), "6ba7b810-9dad-11d1-80b4-00c04fd430c8" )
    }

    /// Text from a driver is normalised, not passed through, so one row cannot
    /// serialize two ways depending on which backend read it.
    func testTextFromADriverIsNormalised ( ) throws {
        let rendered = try MECAttributeType.uuid.jsonValue( from: "6ba7b810-9dad-11d1-80b4-00c04fd430c8" )
        XCTAssertEqual( describe( rendered ), "6BA7B810-9DAD-11D1-80B4-00C04FD430C8" )
    }

    // MARK: - Refusals

    func testTransformableIsRefused ( ) {
        XCTAssertThrowsError( try MECAttributeType.transformable.jsonValue( from: "anything",
                                                                            entity: "Item",
                                                                            property: "payload" ) ) { error in
            XCTAssertEqual( error as? MECError,
                            .unsupportedAttribute( entity: "Item", property: "payload",
                                                   reason: "a transformable attribute needs its own value transformer" ) )
        }
    }

    func testAMismatchNamesTheProperty ( ) {
        XCTAssertThrowsError( try MECAttributeType.uuid.jsonValue( from: 42,
                                                                   entity: "Item",
                                                                   property: "identifier" ) ) { error in
            guard case .valueTypeMismatch( let entity, let property, _ )? = error as? MECError else {
                return XCTFail( "expected a mismatch, got \(error)" )
            }
            XCTAssertEqual( entity, "Item" )
            XCTAssertEqual( property, "identifier" )
        }
    }

    /// The error carries a description rather than the value, so the whole type
    /// stays `Sendable` on its way to a log across an isolation boundary.
    func testTheErrorIsSendable ( ) {
        let error = MECError.mismatch( entity: "Item", property: "identifier", value: 42 )
        XCTAssertEqual( error.description, "Item.identifier cannot read Int 42 as its declared type" )
    }

    /// Two types the SQL leg refuses and this one renders. Pinned in both places
    /// so the asymmetry is a decision somebody took, not a surprise.
    func testBinaryAndURIRenderHere ( ) throws {
        XCTAssertEqual( describe( try MECAttributeType.binaryData.jsonValue( from: Data( "MIO".utf8 ) ) ),
                        "TUlP" )
        XCTAssertEqual( describe( try MECAttributeType.uri.jsonValue( from: URL( string: "https://miolabs.com/a" )! ) ),
                        "https://miolabs.com/a" )
    }

    // MARK: - Absence, defaults, and the required check

    func testAbsentOptionalIsNull ( ) throws {
        let note: MECAttribute = MECAttribute( name: "note", type: .string, isOptional: true )
        XCTAssertEqual( describe( try note.jsonValue( from: nil, in: "Item" ) ), "null" )
    }

    func testAbsentRequiredIsAnError ( ) {
        let title = MECAttribute( name: "title", type: .string )
        XCTAssertThrowsError( try title.jsonValue( from: nil, in: "Item" ) ) { error in
            XCTAssertEqual( error as? MECError,
                            .missingRequiredValue( entity: "Item", property: "title" ) )
        }
    }

    /// An absent value falls back to the model's default before the required
    /// check runs, which is the order the servers already rely on.
    func testTheDefaultIsUsedBeforeTheRequiredCheck ( ) throws {
        let count = MECAttribute( name: "count", type: .integer64, defaultValueString: "3" )
        XCTAssertEqual( describe( try count.jsonValue( from: nil, in: "Item" ) ), "3" )
    }

    /// The default is text, so the declared type is what decides how to read it.
    /// `"1"` is a true and a 1, and only the type says which.
    func testTheSameTextReadsAsTwoThings ( ) {
        XCTAssertEqual( MECAttributeType.boolean.value( fromDefaultText: "1" ) as? Bool, true )
        XCTAssertEqual( MECAttributeType.integer64.value( fromDefaultText: "1" ) as? Int, 1 )
    }

    func testBooleanDefaultSpellings ( ) {
        for text in [ "YES", "yes", "true", "TRUE", "1" ] {
            XCTAssertEqual( MECAttributeType.boolean.value( fromDefaultText: text ) as? Bool, true, text )
        }
        for text in [ "NO", "no", "false", "FALSE", "0" ] {
            XCTAssertEqual( MECAttributeType.boolean.value( fromDefaultText: text ) as? Bool, false, text )
        }
        XCTAssertNil( MECAttributeType.boolean.value( fromDefaultText: "perhaps" ) )
    }

    /// A default that does not parse is not an error, it is a default the model
    /// should not have had. The attribute falls back to the absent-value rules.
    func testAnUnparseableDefaultFallsThrough ( ) throws {
        let count = MECAttribute( name: "count", type: .integer64,
                                  isOptional: true, defaultValueString: "three" )
        XCTAssertEqual( describe( try count.jsonValue( from: nil, in: "Item" ) ), "null" )
    }
}

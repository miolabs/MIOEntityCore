//
//  MECSchemaTests.swift
//  MIOEntityCoreTests
//
//  Created by MIO Research Labs on 2026.
//
//  Phase 1 of MIOENTITYCORE-ENTITY-OWNERSHIP-PLAN.md: the schema types.
//

import XCTest
@testable import MIOEntityCore

final class MECSchemaTests : XCTestCase
{
    // MARK: - MECAttributeType

    /// The raw values are Core Data's, so the MIOCoreData bridge is one
    /// expression each way. If this table ever disagrees with
    /// `CoreDataSwift.NSAttributeType`, the bridge silently mistypes columns.
    func testRawValuesAreCoreDatas ( ) {
        let expected: [( MECAttributeType, Int )] = [
            ( .undefined,     0    ),
            ( .integer16,     100  ),
            ( .integer32,     200  ),
            ( .integer64,     300  ),
            ( .decimal,       400  ),
            ( .double,        500  ),
            ( .float,         600  ),
            ( .string,        700  ),
            ( .boolean,       800  ),
            ( .date,          900  ),
            ( .binaryData,    1000 ),
            ( .uuid,          1100 ),
            ( .uri,           1200 ),
            ( .transformable, 1800 ),
            ( .objectID,      2000 ),
        ]

        for ( type, raw ) in expected {
            XCTAssertEqual( type.coreDataRawValue, raw, "\(type)" )
            XCTAssertEqual( MECAttributeType( coreDataRawValue: raw ), type )
        }

        XCTAssertEqual( expected.count, MECAttributeType.allCases.count,
                        "a new case needs a row here, and a decision in every codec" )
    }

    /// A raw value we do not know is `nil`, not `.undefined`. A type we cannot
    /// name and a model that recorded no type are different problems, and
    /// collapsing them hides the day Core Data adds a case.
    func testUnknownRawValueIsNil ( ) {
        XCTAssertNil( MECAttributeType( coreDataRawValue: 2100 ) )
    }

    // MARK: - MECAttribute

    func testAttributeDefaults ( ) {
        let title = MECAttribute( name: "title", type: .string )

        XCTAssertEqual( title.name, "title" )
        XCTAssertEqual( title.type, .string )
        XCTAssertFalse( title.isOptional, "required unless the model says otherwise" )
        XCTAssertNil( title.defaultValueString )
        XCTAssertFalse( title.isTransient )
    }

    /// The default is text because that is what the `.xcdatamodeld` holds, and
    /// because `"1"` is a valid default for both a boolean and an integer. Only
    /// the codec, which knows the target context, can say which one it is.
    func testDefaultIsCarriedAsText ( ) {
        let done = MECAttribute( name: "done", type: .boolean, defaultValueString: "1" )
        XCTAssertEqual( done.defaultValueString, "1" )
    }

    // MARK: - MECRelationship

    func testRelationshipHoldsANameNotAReference ( ) {
        let todos = MECRelationship( name: "todos",
                                     destinationEntityName: "Todo",
                                     inverseName: "folder",
                                     isToMany: true )

        XCTAssertEqual( todos.destinationEntityName, "Todo" )
        XCTAssertEqual( todos.inverseName, "folder" )
        XCTAssertTrue( todos.isToMany )
        XCTAssertTrue( todos.isOptional, "a relationship is optional unless the model says otherwise" )
    }

    /// The reason the destination is a name: a pair of inverses is a cycle, and
    /// two entities holding each other would be a retain cycle or an `unowned`.
    /// Resolution goes through the model, and only when someone asks.
    func testAnInversePairResolvesThroughTheModel ( ) throws {
        let folder = MECEntity( name: "Folder",
                                relationships: [ MECRelationship( name: "todos",
                                                                  destinationEntityName: "Todo",
                                                                  inverseName: "folder",
                                                                  isToMany: true ) ] )
        let todo   = MECEntity( name: "Todo",
                                relationships: [ MECRelationship( name: "folder",
                                                                  destinationEntityName: "Folder",
                                                                  inverseName: "todos" ) ] )
        let model  = MECModel( entities: [ folder, todo ] )

        let outbound    = try XCTUnwrap( folder.relationshipsByName[ "todos" ] )
        let destination = try XCTUnwrap( model.entity( named: outbound.destinationEntityName ) )
        XCTAssertTrue( destination === todo )

        let inverse = try XCTUnwrap( todo.relationshipsByName[ try XCTUnwrap( outbound.inverseName ) ] )
        XCTAssertEqual( inverse.destinationEntityName, "Folder" )
    }

    /// A destination that resolves to nothing is not an error here. It is the
    /// dangling relationship a model validator reports, and the schema stays
    /// able to describe a model that is wrong.
    func testADanglingDestinationIsRepresentable ( ) {
        let model = MECModel( entities: [ MECEntity( name: "Todo",
                                                     relationships: [ MECRelationship( name: "ghost",
                                                                                       destinationEntityName: "Nowhere" ) ] ) ] )
        XCTAssertNil( model.entity( named: "Nowhere" ) )
    }

    // MARK: - MECEntity carrying them

    func testEntityIndexesItsProperties ( ) throws {
        let folder = MECEntity( name: "Folder",
                                attributes: [ MECAttribute( name: "identifier", type: .uuid ),
                                              MECAttribute( name: "title", type: .string ) ],
                                relationships: [ MECRelationship( name: "todos",
                                                                  destinationEntityName: "Todo",
                                                                  isToMany: true ) ] )

        XCTAssertEqual( folder.attributes.count, 2 )
        XCTAssertEqual( folder.attributesByName[ "title" ]?.type, .string )
        XCTAssertEqual( folder.relationshipsByName[ "todos" ]?.destinationEntityName, "Todo" )
    }

    /// The cache has always built entities with a name alone, and still can.
    /// Phase 1 is additive: nothing that compiled before stops compiling.
    func testAnEntityWithNoPropertiesStillWorks ( ) {
        let product = MECEntity( name: "Product" )

        XCTAssertTrue( product.attributes.isEmpty )
        XCTAssertTrue( product.relationships.isEmpty )
        XCTAssertTrue( product.attributesByName.isEmpty )
    }

    /// Inherited attributes are not merged in. Flattening is the caller's walk,
    /// because JSON and SQL disagree about whether a parent's attributes belong
    /// to the child.
    func testInheritedAttributesAreNotMerged ( ) {
        let document = MECEntity( name: "Document",
                                  isAbstract: true,
                                  attributes: [ MECAttribute( name: "identifier", type: .uuid ) ] )
        let invoice  = MECEntity( name: "Invoice",
                                  superEntity: document,
                                  attributes: [ MECAttribute( name: "total", type: .decimal ) ] )

        XCTAssertEqual( invoice.attributes.map( \.name ), [ "total" ] )
        XCTAssertEqual( invoice.superEntity?.attributes.map( \.name ), [ "identifier" ] )
    }

    /// The name and the inheritance chain used to be internal, which made an
    /// entity opaque from outside the module and the schema useless.
    func testTheSchemaIsReadableFromOutside ( ) {
        let product   = MECEntity( name: "Product" )
        let menu_item = MECEntity( name: "MenuItem", superEntity: product )
        let model     = MECModel( entities: [ product, menu_item ] )

        XCTAssertEqual( menu_item.name, "MenuItem" )
        XCTAssertFalse( menu_item.isAbstract )
        XCTAssertEqual( menu_item.superEntity?.name, "Product" )
        XCTAssertEqual( model.subEntities( of: product ).map( \.name ), [ "MenuItem" ] )
    }
}

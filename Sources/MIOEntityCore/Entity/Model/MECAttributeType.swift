//
//  MECAttributeType.swift
//  MIOEntityCore
//
//  Created by MIO Research Labs on 2026.
//

/// What an attribute holds, independent of how any one context spells it.
///
/// The cases mirror Core Data's `NSAttributeType` and carry its raw values, so
/// translating either way is one expression. Nothing here imports Core Data, and
/// a backend that has never heard of it reads these cases fine.
///
/// - Important: Every switch over this enum is written without a `default:`, so
///   adding a case breaks the build everywhere a decision is needed. Do not add
///   one to quieten the compiler.
public enum MECAttributeType : Int, Sendable, CaseIterable
{
    /// No type recorded. Core Data models can hold one; it renders as null.
    case undefined      = 0

    case integer16      = 100
    case integer32      = 200
    case integer64      = 300

    /// Fixed-point. Kept apart from ``double`` because rounding it is a money bug.
    case decimal        = 400

    case double         = 500
    case float          = 600
    case string         = 700
    case boolean        = 800
    case date           = 900

    /// Raw bytes. Renders as base64 in JSON, and has no SQL spelling today.
    case binaryData     = 1000

    case uuid           = 1100

    /// A URL, carried as its absolute string.
    case uri            = 1200

    /// Whatever its value transformer says it is, which is why no codec here can
    /// render one without being handed that transformer.
    case transformable  = 1800

    /// Core Data's own object identity. Not a value a backend stores.
    case objectID       = 2000

    /// The `NSAttributeType` raw value this case corresponds to.
    ///
    /// Spelled out rather than left as ``RawRepresentable/rawValue``, so the
    /// bridge in MIOCoreData reads as a translation and not as a coincidence.
    public var coreDataRawValue: Int { rawValue }

    /// Builds a type from Core Data's raw value.
    ///
    /// - Parameter coreDataRawValue: The `NSAttributeType` raw value.
    /// - Returns: The matching case, or `nil` for a raw value this package does
    ///   not know. `nil` rather than ``undefined``: a type we cannot name is not
    ///   the same as a model that recorded no type, and collapsing the two hides
    ///   the day Core Data adds one.
    public init?( coreDataRawValue: Int ) {
        self.init( rawValue: coreDataRawValue )
    }
}

//
//  MECPolicy.swift
//  MIOEntityCore
//
//  Created by MIO Research Labs on 2026.
//

import Foundation

/// The choices a codec cannot make for you.
///
/// All of it travels with the call rather than living on the entity: the same
/// model serializes differently for two APIs, and that is a property of the
/// API, not of the schema.
public struct MECPolicy : Sendable
{
    /// Which attribute carries an entity's identity.
    ///
    /// A relationship reaches the wire as the identity of what it points at, so
    /// something has to name that attribute. Defaults to `identifier`.
    public var identifierKey: @Sendable ( MECEntity ) -> String

    /// Whether a ``MECAttributeType/uuid`` renders uppercase. Matches the SQL
    /// leg, so identity has one spelling whichever side produced it.
    public var uppercaseUUIDs: Bool

    /// How a ``MECAttributeType/decimal`` reaches JSON.
    public enum DecimalFormat : Sendable, Equatable
    {
        /// As a JSON number.
        case number

        /// As a JSON string, the default: a reader that turns money into a
        /// `Double` loses precision silently, and a string prevents that.
        case string
    }

    public var decimalFormat: DecimalFormat

    /// How a ``MECAttributeType/date`` is written. Defaults to ``iso8601``
    /// with fractional seconds; dropping them reorders records written in the
    /// same second.
    public var dateFormatter: @Sendable ( Date ) -> String

    /// Whether an absent optional appears as null or is left out. Left out by
    /// default, because an absent key and an explicit null mean different
    /// things to a PATCH-style API.
    public var includeNulls: Bool

    public init( identifierKey: @escaping @Sendable ( MECEntity ) -> String = { _ in "identifier" },
                 uppercaseUUIDs: Bool = true,
                 decimalFormat: DecimalFormat = .string,
                 includeNulls: Bool = false,
                 dateFormatter: @escaping @Sendable ( Date ) -> String = MECPolicy.iso8601 ) {
        self.identifierKey  = identifierKey
        self.uppercaseUUIDs = uppercaseUUIDs
        self.decimalFormat  = decimalFormat
        self.includeNulls   = includeNulls
        self.dateFormatter  = dateFormatter
    }

    public static let `default` = MECPolicy()

    /// ISO 8601 with fractional seconds, in UTC.
    @Sendable
    public static func iso8601( _ date: Date ) -> String {
        return _iso8601_formatter.string( from: date )
    }

    nonisolated(unsafe) private static let _iso8601_formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [ .withInternetDateTime, .withFractionalSeconds ]
        return formatter
    }()
}

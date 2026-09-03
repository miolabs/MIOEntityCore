// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

#if os(WASI)
let dependencies: [Package.Dependency] = [] ////[.package(url: "https://github.com/swiftwasm/carton", from: "1.0.0")]
#else
let dependencies: [Package.Dependency] = [
    .package( url: "https://github.com/miolabs/MIOCore.git", branch: "master" ),
    // The SQL leg of the codec renders through MDBValue, so it lives in this
    // one target rather than behind a package boundary. See the third-pass
    // section of MIOENTITYCORE-ENTITY-OWNERSHIP-PLAN.md, which also records
    // what has to be true before this is worth splitting again. `branch`
    // rather than a version, matching how every consumer pins MIODB and how
    // this manifest already pins MIOCore.
    .package( url: "https://github.com/miolabs/MIODB.git", branch: "master" ),
]
#endif

let package = Package(
    name: "MIOEntityCore",
    // macOS 12, matching MIOCore, MIODB and MIOCoreData. It was .v13, which was
    // the odd floor in the stack and blocked MIOCoreData from depending on this
    // at all. Nothing here needs it: value types, dictionaries, and an
    // ISO8601DateFormatter that has existed since 10.13.
    platforms: [.macOS(.v12), .iOS(.v12)],
    products: [
        // The entity, its schema and the JSON codec. MIOCore only, so an app can
        // depend on it without acquiring a query builder.
        .library(
            name: "MIOEntityCore",
            targets: ["MIOEntityCore"]),
        // The SQL leg, the only part that needs MIODB. Server-side consumers
        // take this one. MIOCoreData deliberately does not, because it ships
        // inside every client.
        .library(
            name: "MIOEntityCoreDB",
            targets: ["MIOEntityCoreDB"]),
    ],
    dependencies: dependencies,
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "MIOEntityCore",
            dependencies: [
                .product( name: "MIOCoreLogger", package: "MIOCore" ),
            ]
//            swiftSettings: [
//              .enableExperimentalFeature("Extern") ]
        ),
        .target(
            name: "MIOEntityCoreDB",
            dependencies: [
                "MIOEntityCore",
                .product( name: "MIODB", package: "MIODB" ),
            ]
        ),
        .testTarget(
            name: "MIOEntityCoreTests",
            dependencies: ["MIOEntityCore"]),
        .testTarget(
            name: "MIOEntityCoreDBTests",
            dependencies: ["MIOEntityCoreDB"]),
    ]
)

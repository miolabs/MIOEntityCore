// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

#if os(WASI)
let dependencies: [Package.Dependency] = [] ////[.package(url: "https://github.com/swiftwasm/carton", from: "1.0.0")]
#else
let dependencies: [Package.Dependency] = [.package(url: "https://github.com/miolabs/MIOCore.git", branch: "master" ),]
#endif

let package = Package(
    name: "MIOEntityCore",
    platforms: [.macOS(.v13), .iOS(.v12)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "MIOEntityCore",
            targets: ["MIOEntityCore"]),
    ],
    dependencies: dependencies,
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "MIOEntityCore",
            dependencies: [.product(name: "MIOCoreLogger", package: "MIOCore"),]
//            swiftSettings: [
//              .enableExperimentalFeature("Extern") ]
        ),
        .testTarget(
            name: "MIOEntityCoreTests",
            dependencies: ["MIOEntityCore"]),
    ]
)

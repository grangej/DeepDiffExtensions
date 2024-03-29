// swift-tools-version:5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DeepDiffExtensions",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "DeepDiffExtensions",
            targets: ["DeepDiffExtensions"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/onmyway133/DeepDiff.git", from: "2.3.0"),
        .package(url: "https://github.com/grangej/Logger.git", from: "6.0.0"),
        .package(url: "https://github.com/ReactiveX/RxSwift.git", from: "6.0.0"),

    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "DeepDiffExtensions",
            dependencies: ["DeepDiff", 
                           "Logger",
                           .product(name: "RxSwift", package: "RxSwift"),
                           .product(name: "RxCocoa", package: "RxSwift")
                          ]),
    ]
)

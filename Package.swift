// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "SwiftBeanCountWealthsimpleMapper",
    products: [
        .library(
            name: "SwiftBeanCountWealthsimpleMapper",
            targets: ["SwiftBeanCountWealthsimpleMapper"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/Nef10/SwiftBeanCountModel.git",
            .exact("0.1.6")
        ),
        .package(
            url: "https://github.com/Nef10/SwiftBeanCountParserUtils.git",
            from: "1.0.0"
        ),
        .package(
            url: "https://github.com/Nef10/WealthsimpleDownloader.git",
            .upToNextMajor(from: "2.0.5")
        ),
    ],
    targets: [
        .target(
            name: "SwiftBeanCountWealthsimpleMapper",
            dependencies: [
                "SwiftBeanCountModel",
                "SwiftBeanCountParserUtils",
                .product(name: "Wealthsimple", package: "WealthsimpleDownloader")
            ]),
        .testTarget(
            name: "SwiftBeanCountWealthsimpleMapperTests",
            dependencies: ["SwiftBeanCountWealthsimpleMapper"]),
    ]
)

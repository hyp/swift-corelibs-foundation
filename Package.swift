// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let coreFoundationBuildSettings: [CSetting] = [
    .headerSearchPath("internalInclude"),
    .define("DEBUG", .when(configuration: .debug)),
    .define("CF_BUILDING_CF"),
    .define("DEPLOYMENT_ENABLE_LIBDISPATCH"),
    .define("DEPLOYMENT_RUNTIME_SWIFT"),
    .define("HAVE_STRUCT_TIMESPEC"),
    .define("SWIFT_CORELIBS_FOUNDATION_HAS_THREADS"),
    .define("_GNU_SOURCE", .when(platforms: [.linux, .android])),
    .unsafeFlags([
        "-Wno-shorten-64-to-32",
        "-Wno-deprecated-declarations",
        "-Wno-unreachable-code",
        "-Wno-conditional-uninitialized",
        "-Wno-unused-variable",
        "-Wno-unused-function",
        "-Wno-microsoft-enum-forward-reference",
        "-Wno-int-conversion",
        "-fconstant-cfstrings",
        "-fexceptions", // TODO: not on OpenBSD
        "-fdollars-in-identifiers",
        "-fno-common",
        "-fcf-runtime-abi=swift",
        "-include",
        "\(Context.packageDirectory)/Sources/CoreFoundation/internalInclude/CoreFoundation_Prefix.h",
        // /EHsc for Windows
    ]),
    .unsafeFlags(["-I/usr/lib/swift"], .when(platforms: [.linux, .android])), // dispatch
    .unsafeFlags(["-I/usr/lib/swift/Block"], .when(platforms: [.linux, .android])) // Block.h
]

// For _CFURLSessionInterface, _CFXMLInterface
let interfaceBuildSettings: [CSetting] = [
    .headerSearchPath("../CoreFoundation/internalInclude"),
    .define("DEBUG", .when(configuration: .debug)),
    .define("CF_BUILDING_CF"),
    .define("DEPLOYMENT_ENABLE_LIBDISPATCH"),
    .define("HAVE_STRUCT_TIMESPEC"),
    .define("SWIFT_CORELIBS_FOUNDATION_HAS_THREADS"),
    .define("_GNU_SOURCE", .when(platforms: [.linux, .android])),
    .unsafeFlags([
        "-Wno-shorten-64-to-32",
        "-Wno-deprecated-declarations",
        "-Wno-unreachable-code",
        "-Wno-conditional-uninitialized",
        "-Wno-unused-variable",
        "-Wno-unused-function",
        "-Wno-microsoft-enum-forward-reference",
        "-Wno-int-conversion",
        "-fconstant-cfstrings",
        "-fexceptions", // TODO: not on OpenBSD
        "-fdollars-in-identifiers",
        "-fno-common",
        "-fcf-runtime-abi=swift"
        // /EHsc for Windows
    ]),
    .unsafeFlags(["-I/usr/lib/swift"], .when(platforms: [.linux, .android])), // dispatch
    .unsafeFlags(["-I/usr/lib/swift/Block"], .when(platforms: [.linux, .android])) // Block.h
]

let swiftBuildSettings: [SwiftSetting] = [
    .define("DEPLOYMENT_RUNTIME_SWIFT"),
    .define("SWIFT_CORELIBS_FOUNDATION_HAS_THREADS"),
]

var dependencies: [Package.Dependency] {
    if Context.environment["SWIFTCI_USE_LOCAL_DEPS"] != nil {
        [
            .package(
                name: "swift-foundation-icu",
                path: "../swift-foundation-icu"),
            .package(
                name: "swift-foundation",
                path: "../swift-foundation")
        ]
    } else {
        [
            .package(
                url: "https://github.com/apple/swift-foundation-icu",
                from: "0.0.9"),
            .package(
                url: "https://github.com/apple/swift-foundation",
                revision: "35d896ab47ab5e487cfce822fbe40d2b278c51d6")
        ]
    }
}

let package = Package(
    name: "swift-corelibs-foundation",
    // Deployment target note: This package only builds for non-Darwin targets.
    platforms: [.macOS("99.9")],
    products: [
        .library(name: "Foundation", targets: ["Foundation"]),
        .library(name: "FoundationXML", targets: ["FoundationXML"]),
        .library(name: "FoundationNetworking", targets: ["FoundationNetworking"]),
        .executable(name: "plutil", targets: ["plutil"]),
    ],
    dependencies: dependencies,
    targets: [
        .target(
            name: "Foundation",
            dependencies: [
                .product(name: "FoundationEssentials", package: "swift-foundation"),
                .product(name: "FoundationInternationalization", package: "swift-foundation"),
                "CoreFoundation"
            ],
            path: "Sources/Foundation",
            swiftSettings: swiftBuildSettings
        ),
        .target(
            name: "FoundationXML",
            dependencies: [
                .product(name: "FoundationEssentials", package: "swift-foundation"),
                "Foundation",
                "CoreFoundation",
                "_CFXMLInterface"
            ],
            path: "Sources/FoundationXML",
            swiftSettings: swiftBuildSettings
        ),
        .target(
            name: "FoundationNetworking",
            dependencies: [
                .product(name: "FoundationEssentials", package: "swift-foundation"),
                "Foundation",
                "CoreFoundation",
                "_CFURLSessionInterface"
            ],
            path: "Sources/FoundationNetworking",
            swiftSettings:swiftBuildSettings
        ),
        .target(
            name: "CoreFoundation",
            dependencies: [
                .product(name: "_FoundationICU", package: "swift-foundation-icu"),
            ],
            path: "Sources/CoreFoundation",
            exclude: ["BlockRuntime"],
            cSettings: coreFoundationBuildSettings
        ),
        .target(
            name: "_CFXMLInterface",
            dependencies: [
                "CoreFoundation",
                "Clibxml2",
            ],
            path: "Sources/_CFXMLInterface",
            cSettings: interfaceBuildSettings
        ),
        .target(
            name: "_CFURLSessionInterface",
            dependencies: [
                "CoreFoundation",
                "Clibcurl",
            ],
            path: "Sources/_CFURLSessionInterface",
            cSettings: interfaceBuildSettings
        ),
        .systemLibrary(
            name: "Clibxml2",
            pkgConfig: "libxml-2.0",
            providers: [
                .brew(["libxml2"]),
                .apt(["libxml2-dev"])
            ]
        ),
        .systemLibrary(
            name: "Clibcurl",
            pkgConfig: "libcurl",
            providers: [
                .brew(["libcurl"]),
                .apt(["libcurl"])
            ]
        ),
        .executableTarget(
            name: "plutil",
            dependencies: [
                "Foundation"
            ]
        ),
        .executableTarget(
            name: "xdgTestHelper",
            dependencies: [
                "Foundation",
                "FoundationXML",
                "FoundationNetworking"
            ]
        ),
        .target(
            // swift-corelibs-foundation has a copy of XCTest's sources so:
            // (1) we do not depend on the toolchain's XCTest, which depends on toolchain's Foundation, which we cannot pull in at the same time as a Foundation package
            // (2) we do not depend on a swift-corelibs-xctest Swift package, which depends on Foundation, which causes a circular dependency in swiftpm
            // We believe Foundation is the only project that needs to take this rather drastic measure.
            name: "XCTest",
            dependencies: [
                "Foundation"
            ],
            path: "Sources/XCTest"
        ),
        .testTarget(
            name: "TestFoundation",
            dependencies: [
                "Foundation",
                "FoundationXML",
                "FoundationNetworking",
                .targetItem(name: "XCTest", condition: .when(platforms: [.linux])),
                "xdgTestHelper"
            ],
            resources: [
                .copy("Foundation/Resources")
            ],
            swiftSettings: [
                .define("NS_FOUNDATION_ALLOWS_TESTABLE_IMPORT")
            ]
        ),
    ]
)

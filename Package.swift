// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppleCalEntryLog",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "CalEntryCore", targets: ["CalEntryCore"]),
        .executable(name: "core-tests", targets: ["CoreTests"])
    ],
    targets: [
        // Pure logic. Deliberately does not import EventKit, so it
        // builds and runs anywhere and can be exercised with synthetic
        // entries -- creationDate is read-only in EventKit, so real
        // test events can never be backdated into a range.
        .target(name: "CalEntryCore"),

        // Not a .testTarget: neither XCTest nor swift-testing ships
        // with the Command Line Tools, and reaching Xcode's copy needs
        // a licence agreement and sudo. A plain executable with a
        // small harness runs on any Mac with swift installed.
        //   swift run core-tests
        .executableTarget(name: "CoreTests", dependencies: ["CalEntryCore"])
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppleCalEntryLog",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "CalEntryCore", targets: ["CalEntryCore"]),
        .library(name: "CalEntryKit", targets: ["CalEntryKit"]),
        .executable(name: "EntryLog", targets: ["EntryLogApp"]),
        .executable(name: "entry-log", targets: ["EntryLogCLI"]),
        .executable(name: "core-tests", targets: ["CoreTests"])
    ],
    targets: [
        // Pure logic. Deliberately does not import EventKit, so it
        // builds and runs anywhere and can be exercised with synthetic
        // entries -- creationDate is read-only in EventKit, so real
        // test events can never be backdated into a range.
        .target(name: "CalEntryCore"),

        // The only place that knows EventKit exists. Conversion
        // and the store query, no decisions.
        .target(name: "CalEntryKit", dependencies: ["CalEntryCore"]),

        // Not a .testTarget: neither XCTest nor swift-testing ships
        // with the Command Line Tools, and reaching Xcode's copy needs
        // a licence agreement and sudo. A plain executable with a
        // small harness runs on any Mac with swift installed.
        //   swift run core-tests
        .executableTarget(
            name: "EntryLogApp",
            dependencies: ["CalEntryCore", "CalEntryKit"]
        ),

        .executableTarget(
            name: "EntryLogCLI",
            dependencies: ["CalEntryCore", "CalEntryKit"]
        ),

        .executableTarget(name: "CoreTests", dependencies: ["CalEntryCore"])
    ]
)

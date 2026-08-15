// swift-tools-version: 6.0

import Foundation
import PackageDescription

func firstExisting(_ paths: [String]) -> String? {
    paths.first { FileManager.default.fileExists(atPath: $0) }
}

let libarchivePrefix = firstExisting([
    "/opt/homebrew/opt/libarchive",
    "/usr/local/opt/libarchive",
]) ?? "/opt/homebrew/opt/libarchive"

let libarchiveIncludeFlags: [SwiftSetting] = [
    .unsafeFlags(["-Xcc", "-I\(libarchivePrefix)/include"]),
]

let package = Package(
    name: "Archivist",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "ArchiveCore", targets: ["ArchiveCore"]),
        .library(name: "ArchiveBackends", targets: ["ArchiveBackends"]),
        .library(name: "ArchiveCLI", targets: ["ArchiveCLI"]),
        .executable(name: "archivemgr", targets: ["archivemgr"]),
        .executable(name: "ArchivistApp", targets: ["ArchivistApp"]),
        .executable(name: "ArchiveTestRunner", targets: ["ArchiveTestRunner"]),
    ],
    targets: [
        .target(
            name: "CLibArchive",
            path: "Sources/CLibArchive",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
                .unsafeFlags(["-I\(libarchivePrefix)/include"]),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-L\(libarchivePrefix)/lib",
                    "-Xlinker", "-rpath", "-Xlinker", "\(libarchivePrefix)/lib",
                ]),
                .linkedLibrary("archive"),
            ]
        ),
        .target(
            name: "ArchiveCore",
            dependencies: [],
            path: "Sources/ArchiveCore",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
        .target(
            name: "ArchiveBackends",
            dependencies: ["ArchiveCore", "CLibArchive"],
            path: "Sources/ArchiveBackends",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
            ] + libarchiveIncludeFlags
        ),
        .target(
            name: "ArchiveCLI",
            dependencies: ["ArchiveCore", "ArchiveBackends"],
            path: "Sources/ArchiveCLI",
            swiftSettings: libarchiveIncludeFlags
        ),
        .executableTarget(
            name: "archivemgr",
            dependencies: ["ArchiveCLI"],
            path: "Sources/archivemgr",
            swiftSettings: libarchiveIncludeFlags
        ),
        .executableTarget(
            name: "ArchivistApp",
            dependencies: ["ArchiveCore", "ArchiveBackends"],
            path: "Sources/ArchivistApp",
            swiftSettings: libarchiveIncludeFlags
        ),
        .executableTarget(
            name: "ArchiveTestRunner",
            dependencies: ["ArchiveCore", "ArchiveBackends", "ArchiveCLI"],
            path: "Sources/ArchiveTestRunner",
            swiftSettings: libarchiveIncludeFlags
        ),
    ]
)

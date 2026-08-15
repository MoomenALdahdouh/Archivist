import Foundation
import ArchiveCore

public enum DefaultBackends {
    public static func sevenZipAvailable() -> Bool {
        HelperLocator.find(names: ["Archivist7z", "7zz", "7z"]) != nil
    }

    public static func unrarAvailable() -> Bool {
        HelperLocator.find(names: ["ArchivistUnrar", "unrar"]) != nil
    }

    public static func registry() -> BackendRegistry {
        BackendRegistry(backends: [
            LibArchiveBackend(),
            SevenZipBackend(),
            UnRARBackend(),
            DiskImageBackend(),
        ])
    }

    public static func makeEngine() -> ArchiveEngine {
        ArchiveEngine(
            registry: BackendRegistry(backends: [
                LibArchiveBackend(),
                SevenZipBackend(),
                UnRARBackend(),
                DiskImageBackend(),
            ])
        )
    }
}

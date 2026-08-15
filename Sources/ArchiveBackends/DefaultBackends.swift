import Foundation
import ArchiveCore

public enum DefaultBackends {
    public static func sevenZipAvailable() -> Bool {
        HelperLocator.find(names: ["Archivist7z", "7zz", "7z"]) != nil
    }

    public static func unrarAvailable() -> Bool {
        HelperLocator.find(names: ["ArchivistUnrar", "unrar"]) != nil
    }

    public static func rarCreateAvailable() -> Bool {
        HelperLocator.find(names: ["ArchivistRar", "rar"]) != nil
    }

    public static func registry() -> BackendRegistry {
        BackendRegistry(backends: [
            UnRARBackend(),
            SevenZipBackend(),
            LibArchiveBackend(),
            DiskImageBackend(),
        ])
    }

    public static func makeEngine() -> ArchiveEngine {
        ArchiveEngine(registry: registry())
    }
}

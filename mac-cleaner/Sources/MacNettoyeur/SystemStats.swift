import Darwin
import Foundation

struct DiskStats {
    let total: Int64
    let available: Int64

    var used: Int64 { total - available }
    var fraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

struct MemoryStats {
    let total: UInt64
    let used: UInt64

    var fraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

enum SystemStats {
    static func disk() -> DiskStats? {
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity,
              let available = values.volumeAvailableCapacityForImportantUsage else { return nil }
        return DiskStats(total: Int64(total), available: available)
    }

    /// Mémoire utilisée au sens du Moniteur d'activité : mémoire des apps + câblée + compressée.
    static func memory() -> MemoryStats {
        let total = ProcessInfo.processInfo.physicalMemory
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPointer, &count)
            }
        }
        guard result == KERN_SUCCESS else { return MemoryStats(total: total, used: 0) }

        let pageSize = UInt64(sysconf(_SC_PAGESIZE))
        let internalPages = UInt64(stats.internal_page_count)
        let appPages = internalPages - min(UInt64(stats.purgeable_count), internalPages)
        let usedPages = appPages + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)
        return MemoryStats(total: total, used: min(usedPages * pageSize, total))
    }

    static func loadAverage() -> Double {
        var loads = [Double](repeating: 0, count: 3)
        return getloadavg(&loads, 3) > 0 ? loads[0] : 0
    }

    static var cpuCount: Int { ProcessInfo.processInfo.activeProcessorCount }

    static var uptimeDescription: String {
        let seconds = Int(ProcessInfo.processInfo.systemUptime)
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        if days > 0 { return "\(days) j \(hours) h" }
        return "\(hours) h \((seconds % 3_600) / 60) min"
    }
}

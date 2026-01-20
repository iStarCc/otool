import Foundation

// MARK: - Mach-O Constants

/// Mach-O 魔数
public enum MachOMagic: UInt32 {
    case magic32 = 0xfeedface      // 32位大端
    case magic64 = 0xfeedfacf      // 64位大端
    case cigam32 = 0xcefaedfe      // 32位小端
    case cigam64 = 0xcffaedfe      // 64位小端
    case fatMagic = 0xcafebabe     // Fat binary 大端
    case fatCigam = 0xbebafeca     // Fat binary 小端
    
    var is64Bit: Bool {
        return self == .magic64 || self == .cigam64
    }
    
    var needsSwap: Bool {
        return self == .cigam32 || self == .cigam64 || self == .fatCigam
    }
}

/// CPU 类型
public enum CPUType: Int32 {
    case any = -1
    case vax = 1
    case mc680x0 = 6
    case i386 = 7
    case x86_64 = 0x01000007
    case arm = 12
    case arm64 = 0x0100000c
    case arm64_32 = 0x0200000c
    case powerpc = 18
    case powerpc64 = 0x01000012
    
    var description: String {
        switch self {
        case .i386: return "i386"
        case .x86_64: return "x86_64"
        case .arm: return "arm"
        case .arm64: return "arm64"
        case .arm64_32: return "arm64_32"
        case .powerpc: return "ppc"
        case .powerpc64: return "ppc64"
        default: return "unknown(\(self.rawValue))"
        }
    }
}

/// Load Command 类型
public enum LoadCommandType: UInt32 {
    case segment = 0x1              // LC_SEGMENT
    case symtab = 0x2              // LC_SYMTAB
    case thread = 0x4              // LC_THREAD
    case unixthread = 0x5          // LC_UNIXTHREAD
    case loadDylib = 0xc           // LC_LOAD_DYLIB
    case idDylib = 0xd             // LC_ID_DYLIB
    case loadDylinker = 0xe        // LC_LOAD_DYLINKER
    case idDylinker = 0xf          // LC_ID_DYLINKER
    case segment64 = 0x19          // LC_SEGMENT_64
    case uuid = 0x1b               // LC_UUID
    case rpath = 0x8000001c        // LC_RPATH
    case codeSignature = 0x1d      // LC_CODE_SIGNATURE
    case loadWeakDylib = 0x80000018 // LC_LOAD_WEAK_DYLIB
    case reexportDylib = 0x8000001f // LC_REEXPORT_DYLIB
    case lazyLoadDylib = 0x20      // LC_LAZY_LOAD_DYLIB
    case encryptionInfo = 0x21     // LC_ENCRYPTION_INFO
    case dyldInfo = 0x22           // LC_DYLD_INFO
    case dyldInfoOnly = 0x80000022 // LC_DYLD_INFO_ONLY
    case versionMinMacosx = 0x24   // LC_VERSION_MIN_MACOSX
    case versionMinIphoneos = 0x25 // LC_VERSION_MIN_IPHONEOS
    case sourceVersion = 0x2a      // LC_SOURCE_VERSION
    case main = 0x80000028         // LC_MAIN
    case dataInCode = 0x29         // LC_DATA_IN_CODE
    case buildVersion = 0x32       // LC_BUILD_VERSION
}

// MARK: - Mach-O Structures

/// Mach-O Header (32位)
public struct MachHeader {
    public let magic: UInt32        // 魔数
    public let cputype: Int32       // CPU 类型
    public let cpusubtype: Int32    // CPU 子类型
    public let filetype: UInt32     // 文件类型
    public let ncmds: UInt32        // Load commands 数量
    public let sizeofcmds: UInt32   // Load commands 总大小
    public let flags: UInt32        // 标志
    
    public static let size = 28
}

/// Mach-O Header (64位)
public struct MachHeader64 {
    public let magic: UInt32        // 魔数
    public let cputype: Int32       // CPU 类型
    public let cpusubtype: Int32    // CPU 子类型
    public let filetype: UInt32     // 文件类型
    public let ncmds: UInt32        // Load commands 数量
    public let sizeofcmds: UInt32   // Load commands 总大小
    public let flags: UInt32        // 标志
    public let reserved: UInt32     // 保留字段
    
    public static let size = 32
}

/// Load Command
public struct LoadCommand {
    public let cmd: UInt32          // 命令类型
    public let cmdsize: UInt32      // 命令大小
    
    public static let size = 8
}

/// Dylib Command
public struct DylibCommand {
    public let cmd: UInt32          // 命令类型
    public let cmdsize: UInt32      // 命令大小
    public let nameOffset: UInt32   // 名称偏移
    public let timestamp: UInt32    // 时间戳
    public let currentVersion: UInt32   // 当前版本
    public let compatibilityVersion: UInt32 // 兼容版本
    
    public static let size = 24
    
    public var currentVersionString: String {
        let major = (currentVersion >> 16) & 0xffff
        let minor = (currentVersion >> 8) & 0xff
        let patch = currentVersion & 0xff
        return "\(major).\(minor).\(patch)"
    }
    
    public var compatibilityVersionString: String {
        let major = (compatibilityVersion >> 16) & 0xffff
        let minor = (compatibilityVersion >> 8) & 0xff
        let patch = compatibilityVersion & 0xff
        return "\(major).\(minor).\(patch)"
    }
}

// MARK: - Helper Extensions

extension Data {
    /// 从指定位置读取值
    func read<T>(_ type: T.Type, at offset: Int, swapBytes: Bool = false) -> T? {
        let size = MemoryLayout<T>.size
        guard offset + size <= count else { return nil }
        
        let value = subdata(in: offset..<offset + size).withUnsafeBytes { ptr in
            ptr.load(as: T.self)
        }
        
        if swapBytes {
            // 对于常见的整数类型进行字节序转换
            if let val = value as? UInt32 {
                return val.byteSwapped as? T
            } else if let val = value as? Int32 {
                return val.byteSwapped as? T
            } else if let val = value as? UInt64 {
                return val.byteSwapped as? T
            } else if let val = value as? Int64 {
                return val.byteSwapped as? T
            } else if let val = value as? UInt16 {
                return val.byteSwapped as? T
            } else if let val = value as? Int16 {
                return val.byteSwapped as? T
            }
        }
        return value
    }
    
    /// 读取 C 字符串
    func readCString(at offset: Int, maxLength: Int = 1024) -> String? {
        guard offset < count else { return nil }
        
        var length = 0
        let maxLen = Swift.min(maxLength, count - offset)
        
        for i in 0..<maxLen {
            if self[offset + i] == 0 {
                break
            }
            length += 1
        }
        
        guard length > 0 else { return nil }
        let stringData = subdata(in: offset..<offset + length)
        return String(data: stringData, encoding: .utf8)
    }
}

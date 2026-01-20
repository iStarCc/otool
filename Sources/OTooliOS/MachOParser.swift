import Foundation

/// Mach-O 解析器错误类型
public enum MachOParserError: Error, LocalizedError {
    case fileNotFound
    case invalidMagicNumber
    case unsupportedArchitecture
    case corruptedFile
    case readError(String)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "文件未找到"
        case .invalidMagicNumber:
            return "无效的 Mach-O 魔数"
        case .unsupportedArchitecture:
            return "不支持的架构"
        case .corruptedFile:
            return "文件已损坏"
        case .readError(let message):
            return "读取错误: \(message)"
        }
    }
}

/// Mach-O 文件解析器
public class MachOParser {
    
    public init() {}
    
    /// 解析指定路径的 Mach-O 文件
    /// - Parameter path: 文件路径
    /// - Returns: MachOInfo 对象
    /// - Throws: MachOParserError
    public func parse(fileAt path: String) throws -> MachOInfo {
        let url = URL(fileURLWithPath: path)
        return try parse(url: url)
    }
    
    /// 解析 URL 指定的 Mach-O 文件
    /// - Parameter url: 文件 URL
    /// - Returns: MachOInfo 对象
    /// - Throws: MachOParserError
    public func parse(url: URL) throws -> MachOInfo {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw MachOParserError.fileNotFound
        }
        
        let data = try Data(contentsOf: url)
        return try parse(data: data)
    }
    
    /// 解析 Data 中的 Mach-O 文件
    /// - Parameter data: 文件数据
    /// - Returns: MachOInfo 对象
    /// - Throws: MachOParserError
    public func parse(data: Data) throws -> MachOInfo {
        guard data.count >= 4 else {
            throw MachOParserError.corruptedFile
        }
        
        // 读取魔数
        guard let magicValue: UInt32 = data.read(UInt32.self, at: 0),
              let magic = MachOMagic(rawValue: magicValue) else {
            throw MachOParserError.invalidMagicNumber
        }
        
        // 检查是否为 Fat binary
        if magic == .fatMagic || magic == .fatCigam {
            // 简化处理：解析第一个架构
            return try parseFatBinary(data: data, needsSwap: magic.needsSwap)
        }
        
        // 解析单一架构的 Mach-O
        return try parseMachO(data: data, offset: 0, magic: magic)
    }
    
    /// 解析 Fat Binary
    private func parseFatBinary(data: Data, needsSwap: Bool) throws -> MachOInfo {
        // 读取架构数量
        guard let nfatArch: UInt32 = data.read(UInt32.self, at: 4, swapBytes: needsSwap) else {
            throw MachOParserError.corruptedFile
        }
        
        guard nfatArch > 0 else {
            throw MachOParserError.corruptedFile
        }
        
        // 读取第一个架构的偏移和大小
        let archOffset = 8
        guard let offset: UInt32 = data.read(UInt32.self, at: archOffset + 8, swapBytes: needsSwap) else {
            throw MachOParserError.corruptedFile
        }
        
        // 读取该架构的魔数
        guard let magicValue: UInt32 = data.read(UInt32.self, at: Int(offset)),
              let magic = MachOMagic(rawValue: magicValue) else {
            throw MachOParserError.invalidMagicNumber
        }
        
        return try parseMachO(data: data, offset: Int(offset), magic: magic)
    }
    
    /// 解析单一架构的 Mach-O 文件
    private func parseMachO(data: Data, offset: Int, magic: MachOMagic) throws -> MachOInfo {
        let needsSwap = magic.needsSwap
        let is64Bit = magic.is64Bit
        
        // 读取 Header
        let headerSize = is64Bit ? MachHeader64.size : MachHeader.size
        guard offset + headerSize <= data.count else {
            throw MachOParserError.corruptedFile
        }
        
        let cputype: Int32
        let ncmds: UInt32
        let filetype: UInt32
        
        if is64Bit {
            guard let ct: Int32 = data.read(Int32.self, at: offset + 4, swapBytes: needsSwap),
                  let ft: UInt32 = data.read(UInt32.self, at: offset + 12, swapBytes: needsSwap),
                  let nc: UInt32 = data.read(UInt32.self, at: offset + 16, swapBytes: needsSwap) else {
                throw MachOParserError.corruptedFile
            }
            cputype = ct
            filetype = ft
            ncmds = nc
        } else {
            guard let ct: Int32 = data.read(Int32.self, at: offset + 4, swapBytes: needsSwap),
                  let ft: UInt32 = data.read(UInt32.self, at: offset + 12, swapBytes: needsSwap),
                  let nc: UInt32 = data.read(UInt32.self, at: offset + 16, swapBytes: needsSwap) else {
                throw MachOParserError.corruptedFile
            }
            cputype = ct
            filetype = ft
            ncmds = nc
        }
        
        let architecture = CPUType(rawValue: cputype)?.description ?? "unknown"
        
        // 解析 Load Commands
        var currentOffset = offset + headerSize
        var dynamicLibraries: [DylibInfo] = []
        var rpaths: [String] = []
        
        for _ in 0..<ncmds {
            guard let cmd: UInt32 = data.read(UInt32.self, at: currentOffset, swapBytes: needsSwap),
                  let cmdsize: UInt32 = data.read(UInt32.self, at: currentOffset + 4, swapBytes: needsSwap) else {
                throw MachOParserError.corruptedFile
            }
            
            // 解析不同类型的 Load Command
            if let loadCmd = LoadCommandType(rawValue: cmd) {
                switch loadCmd {
                case .loadDylib, .loadWeakDylib, .reexportDylib, .lazyLoadDylib, .idDylib:
                    if let dylib = try parseDylibCommand(data: data, offset: currentOffset, needsSwap: needsSwap, loadType: loadCmd) {
                        dynamicLibraries.append(dylib)
                    }
                case .rpath:
                    if let rpath = parseRpathCommand(data: data, offset: currentOffset, needsSwap: needsSwap) {
                        rpaths.append(rpath)
                    }
                default:
                    break
                }
            }
            
            currentOffset += Int(cmdsize)
        }
        
        return MachOInfo(
            architecture: architecture,
            is64Bit: is64Bit,
            fileType: filetype,
            dynamicLibraries: dynamicLibraries,
            rpaths: rpaths
        )
    }
    
    /// 解析 Dylib Command
    private func parseDylibCommand(data: Data, offset: Int, needsSwap: Bool, loadType: LoadCommandType) throws -> DylibInfo? {
        guard let _: UInt32 = data.read(UInt32.self, at: offset, swapBytes: needsSwap),
              let _: UInt32 = data.read(UInt32.self, at: offset + 4, swapBytes: needsSwap),
              let nameOffset: UInt32 = data.read(UInt32.self, at: offset + 8, swapBytes: needsSwap),
              let currentVersion: UInt32 = data.read(UInt32.self, at: offset + 16, swapBytes: needsSwap),
              let compatibilityVersion: UInt32 = data.read(UInt32.self, at: offset + 20, swapBytes: needsSwap) else {
            return nil
        }
        
        // 读取动态库路径
        let pathOffset = offset + Int(nameOffset)
        guard let path = data.readCString(at: pathOffset) else {
            return nil
        }
        
        // 转换版本号
        let currentVersionStr = formatVersion(currentVersion)
        let compatibilityVersionStr = formatVersion(compatibilityVersion)
        
        // 确定加载类型
        let dylibLoadType: DylibInfo.LoadType
        switch loadType {
        case .loadDylib:
            dylibLoadType = .load
        case .loadWeakDylib:
            dylibLoadType = .weakLoad
        case .reexportDylib:
            dylibLoadType = .reexport
        case .lazyLoadDylib:
            dylibLoadType = .lazyLoad
        case .idDylib:
            dylibLoadType = .id
        default:
            dylibLoadType = .load
        }
        
        return DylibInfo(
            path: path,
            currentVersion: currentVersionStr,
            compatibilityVersion: compatibilityVersionStr,
            loadType: dylibLoadType
        )
    }
    
    /// 解析 RPath Command
    private func parseRpathCommand(data: Data, offset: Int, needsSwap: Bool) -> String? {
        guard let pathOffset: UInt32 = data.read(UInt32.self, at: offset + 8, swapBytes: needsSwap) else {
            return nil
        }
        
        let rpathOffset = offset + Int(pathOffset)
        return data.readCString(at: rpathOffset)
    }
    
    /// 格式化版本号
    private func formatVersion(_ version: UInt32) -> String {
        let major = (version >> 16) & 0xffff
        let minor = (version >> 8) & 0xff
        let patch = version & 0xff
        return "\(major).\(minor).\(patch)"
    }
}

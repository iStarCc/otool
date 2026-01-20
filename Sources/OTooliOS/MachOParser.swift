import Foundation

/// Mach-O 解析器错误类型
public enum MachOParserError: Error, LocalizedError {
    case fileNotFound
    case invalidMagicNumber
    case unsupportedArchitecture
    case corruptedFile
    case readError(String)
    case notAnAppBundle
    case infoPlistNotFound
    case executableNotFoundInPlist
    
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
        case .notAnAppBundle:
            return "不是有效的 .app bundle"
        case .infoPlistNotFound:
            return "Info.plist 文件未找到"
        case .executableNotFoundInPlist:
            return "Info.plist 中未找到 CFBundleExecutable"
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
    
    /// 智能解析：自动识别 .app bundle 或可执行文件
    /// - Parameter path: .app bundle 路径或可执行文件路径
    /// - Returns: MachOInfo 对象
    /// - Throws: MachOParserError
    public func parseAuto(at path: String) throws -> MachOInfo {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw MachOParserError.fileNotFound
        }
        
        // 如果是 .app bundle，解析主可执行文件
        if isDirectory.boolValue && path.hasSuffix(".app") {
            return try parseAppBundle(at: path)
        }
        
        // 否则作为普通文件解析
        return try parse(fileAt: path)
    }
    
    /// 解析 .app bundle 中的主可执行文件
    /// - Parameter appPath: .app bundle 路径
    /// - Returns: MachOInfo 对象
    /// - Throws: MachOParserError
    public func parseAppBundle(at appPath: String) throws -> MachOInfo {
        let executablePath = try Self.findMainExecutable(in: appPath)
        return try parse(fileAt: executablePath)
    }
    
    /// 在 .app bundle 中查找主可执行文件
    /// - Parameter appPath: .app bundle 路径
    /// - Returns: 主可执行文件的完整路径
    /// - Throws: MachOParserError
    public static func findMainExecutable(in appPath: String) throws -> String {
        let fileManager = FileManager.default
        
        // 检查路径是否存在
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: appPath, isDirectory: &isDirectory) else {
            throw MachOParserError.fileNotFound
        }
        
        // 检查是否为目录
        guard isDirectory.boolValue else {
            throw MachOParserError.notAnAppBundle
        }
        
        // 检查是否以 .app 结尾
        guard appPath.hasSuffix(".app") else {
            throw MachOParserError.notAnAppBundle
        }
        
        // 构建 Info.plist 路径
        let infoPlistPath = (appPath as NSString).appendingPathComponent("Info.plist")
        
        // 检查 Info.plist 是否存在
        guard fileManager.fileExists(atPath: infoPlistPath) else {
            throw MachOParserError.infoPlistNotFound
        }
        
        // 读取 Info.plist
        guard let plistData = fileManager.contents(atPath: infoPlistPath),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] else {
            throw MachOParserError.readError("无法读取 Info.plist")
        }
        
        // 获取 CFBundleExecutable
        guard let executableName = plist["CFBundleExecutable"] as? String else {
            throw MachOParserError.executableNotFoundInPlist
        }
        
        // 构建主可执行文件路径
        let executablePath = (appPath as NSString).appendingPathComponent(executableName)
        
        // 检查主可执行文件是否存在
        guard fileManager.fileExists(atPath: executablePath) else {
            throw MachOParserError.fileNotFound
        }
        
        return executablePath
    }
}

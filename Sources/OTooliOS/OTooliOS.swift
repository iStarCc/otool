import Foundation

/// OTooliOS 库的公共接口
public struct OTooliOS {
    
    /// 库版本
    public static let version = "1.0.0"
    
    /// 快速解析文件并获取动态库列表
    /// - Parameter path: 文件路径
    /// - Returns: 动态库路径数组
    /// - Throws: MachOParserError
    public static func getDynamicLibraries(from path: String) throws -> [String] {
        let parser = MachOParser()
        let info = try parser.parse(fileAt: path)
        return info.dynamicLibraries.map { $0.path }
    }
    
    /// 快速解析文件并获取详细信息
    /// - Parameter path: 文件路径
    /// - Returns: MachOInfo 对象
    /// - Throws: MachOParserError
    public static func parseFile(_ path: String) throws -> MachOInfo {
        let parser = MachOParser()
        return try parser.parse(fileAt: path)
    }
    
    /// 智能解析：自动识别 .app bundle、.framework 或可执行文件
    /// - Parameter path: .app bundle 路径、.framework 路径或可执行文件路径
    /// - Returns: MachOInfo 对象
    /// - Throws: MachOParserError
    public static func parse(_ path: String) throws -> MachOInfo {
        let parser = MachOParser()
        return try parser.parseAuto(at: path)
    }
    
    /// 解析 .app bundle 中的主可执行文件
    /// - Parameter appPath: .app bundle 路径
    /// - Returns: MachOInfo 对象
    /// - Throws: MachOParserError
    public static func parseAppBundle(_ appPath: String) throws -> MachOInfo {
        let parser = MachOParser()
        return try parser.parseAppBundle(at: appPath)
    }
    
    /// 获取 .app bundle 的主可执行文件路径
    /// - Parameter appPath: .app bundle 路径
    /// - Returns: 主可执行文件的完整路径
    /// - Throws: MachOParserError
    public static func getMainExecutablePath(from appPath: String) throws -> String {
        return try MachOParser.findMainExecutable(in: appPath)
    }
    
    /// 解析 .framework 中的主二进制文件
    /// - Parameter frameworkPath: .framework 路径
    /// - Returns: MachOInfo 对象
    /// - Throws: MachOParserError
    public static func parseFramework(_ frameworkPath: String) throws -> MachOInfo {
        let parser = MachOParser()
        return try parser.parseFramework(at: frameworkPath)
    }
    
    /// 获取 .framework 的主二进制文件路径
    /// - Parameter frameworkPath: .framework 路径
    /// - Returns: 主二进制文件的完整路径
    /// - Throws: MachOParserError
    public static func getFrameworkBinaryPath(from frameworkPath: String) throws -> String {
        return try MachOParser.findFrameworkBinary(in: frameworkPath)
    }
}

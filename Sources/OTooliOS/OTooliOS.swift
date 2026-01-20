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
}

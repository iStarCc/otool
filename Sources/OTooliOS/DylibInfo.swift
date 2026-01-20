import Foundation

/// 动态库信息
public struct DylibInfo {
    /// 动态库路径
    public let path: String
    
    /// 当前版本
    public let currentVersion: String
    
    /// 兼容版本
    public let compatibilityVersion: String
    
    /// 加载类型
    public let loadType: LoadType
    
    public enum LoadType: String {
        case load = "LC_LOAD_DYLIB"
        case weakLoad = "LC_LOAD_WEAK_DYLIB"
        case reexport = "LC_REEXPORT_DYLIB"
        case lazyLoad = "LC_LAZY_LOAD_DYLIB"
        case id = "LC_ID_DYLIB"
        
        var description: String {
            switch self {
            case .load: return "加载"
            case .weakLoad: return "弱加载"
            case .reexport: return "重导出"
            case .lazyLoad: return "延迟加载"
            case .id: return "标识"
            }
        }
    }
    
    public init(path: String, currentVersion: String, compatibilityVersion: String, loadType: LoadType) {
        self.path = path
        self.currentVersion = currentVersion
        self.compatibilityVersion = compatibilityVersion
        self.loadType = loadType
    }
}

/// Mach-O 文件信息
public struct MachOInfo {
    /// CPU 架构
    public let architecture: String
    
    /// 是否为 64 位
    public let is64Bit: Bool
    
    /// 文件类型
    public let fileType: UInt32
    
    /// 动态库列表
    public let dynamicLibraries: [DylibInfo]
    
    /// RPath 列表
    public let rpaths: [String]
    
    public init(architecture: String, is64Bit: Bool, fileType: UInt32, dynamicLibraries: [DylibInfo], rpaths: [String]) {
        self.architecture = architecture
        self.is64Bit = is64Bit
        self.fileType = fileType
        self.dynamicLibraries = dynamicLibraries
        self.rpaths = rpaths
    }
    
    /// 格式化输出（类似 otool -L）
    public var formattedOutput: String {
        var output = ""
        
        // 显示所有动态库
        for (index, dylib) in dynamicLibraries.enumerated() {
            if index == 0 {
                output += "\(dylib.path):\n"
            } else {
                output += "\t\(dylib.path)"
                if !dylib.currentVersion.isEmpty {
                    output += " (compatibility version \(dylib.compatibilityVersion), current version \(dylib.currentVersion))"
                }
                output += "\n"
            }
        }
        
        return output
    }
    
    /// 详细信息
    public var detailedOutput: String {
        var output = ""
        output += "架构: \(architecture) (\(is64Bit ? "64位" : "32位"))\n"
        output += "文件类型: \(fileType)\n"
        
        if !rpaths.isEmpty {
            output += "\nRPaths:\n"
            for rpath in rpaths {
                output += "  \(rpath)\n"
            }
        }
        
        output += "\n动态库依赖 (\(dynamicLibraries.count)):\n"
        for (index, dylib) in dynamicLibraries.enumerated() {
            if index == 0 && dylib.loadType == .id {
                output += "  [ID] \(dylib.path)\n"
            } else {
                output += "  [\(dylib.loadType.description)] \(dylib.path)\n"
                output += "      当前版本: \(dylib.currentVersion)\n"
                output += "      兼容版本: \(dylib.compatibilityVersion)\n"
            }
        }
        
        return output
    }
}

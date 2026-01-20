import Foundation
import OTooliOS

/// 演示如何解析 .app bundle 和可执行文件的示例

func parseExample() {
    let paths = [
        "/Applications/Calculator.app",
        "/usr/bin/ls"
    ]
    
    for path in paths {
        guard FileManager.default.fileExists(atPath: path) else { continue }
        
        do {
            print("=== 解析: \(path) ===")
            
            // 使用智能解析（推荐）
            let info = try OTooliOS.parse(path)
            
            print("架构: \(info.architecture)")
            print("位数: \(info.is64Bit ? "64位" : "32位")")
            print("动态库数量: \(info.dynamicLibraries.count)")
            
            // 检测 Swift
            let hasSwift = info.dynamicLibraries.contains { $0.path.contains("libswift") }
            if hasSwift {
                print("Swift: ✅")
            }
            
            // 显示前 5 个依赖
            print("\n前 5 个依赖:")
            for dylib in info.dynamicLibraries.prefix(5) {
                print("  \(dylib.path)")
            }
            
            print()
            
        } catch {
            print("错误: \(error.localizedDescription)\n")
        }
    }
}

// 运行示例
// parseExample()

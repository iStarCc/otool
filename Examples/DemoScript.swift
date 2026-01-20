#!/usr/bin/env swift

// 演示脚本：展示 OTooliOS 的所有功能
// 使用方法: swift Examples/DemoScript.swift

import Foundation
#if canImport(OTooliOS)
import OTooliOS
#endif

print("=== OTooliOS 功能演示 ===\n")

// 配置
let testPaths = [
    "/Applications/Calculator.app",
    "/System/Applications/Calculator.app",
    "/Applications/TextEdit.app",
    "/System/Applications/TextEdit.app",
    "/bin/ls",
    "/usr/lib/libSystem.dylib"
]

// 查找可用的测试路径
func findAvailablePath() -> (String, Bool) {
    for path in testPaths {
        if FileManager.default.fileExists(atPath: path) {
            let isApp = path.hasSuffix(".app")
            return (path, isApp)
        }
    }
    return ("", false)
}

let (testPath, isApp) = findAvailablePath()

if testPath.isEmpty {
    print("⚠️  未找到可用的测试文件")
    print("请确保系统中存在以下任一文件：")
    for path in testPaths {
        print("  - \(path)")
    }
    exit(1)
}

print("📁 测试路径: \(testPath)")
print("📦 类型: \(isApp ? ".app Bundle" : "Mach-O 文件")")
print()

// 演示 1: 基本解析
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("演示 1: 基本文件解析")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

#if canImport(OTooliOS)
do {
    // 使用智能解析
    print("🔍 智能解析...")
    if isApp {
        let execPath = try OTooliOS.getMainExecutablePath(from: testPath)
        print("✅ 主可执行文件: \(execPath)")
    }
    
    let info = try OTooliOS.parse(testPath)
    
    print("\n📊 基本信息:")
    print("  架构: \(info.architecture)")
    print("  位数: \(info.is64Bit ? "64位" : "32位")")
    print("  文件类型: \(info.fileType)")
    print("  动态库数量: \(info.dynamicLibraries.count)")
    print("  RPath 数量: \(info.rpaths.count)")
    
} catch {
    print("❌ 解析失败: \(error)")
}
#else
print("⚠️  OTooliOS 库未导入，请在项目中运行此脚本")
#endif

// 演示 2: 动态库依赖分析
print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("演示 2: 动态库依赖分析")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

#if canImport(OTooliOS)
do {
    let info = try OTooliOS.parse(testPath)
    
    print("\n📚 动态库依赖 (前 10 个):")
    for (index, dylib) in info.dynamicLibraries.prefix(10).enumerated() {
        let typeIcon = dylib.loadType == .id ? "🆔" : 
                      dylib.loadType == .weakLoad ? "⚡" : "📦"
        print("\n  \(index + 1). \(typeIcon) \(dylib.path)")
        print("     类型: \(dylib.loadType.rawValue)")
        print("     当前版本: \(dylib.currentVersion)")
        print("     兼容版本: \(dylib.compatibilityVersion)")
    }
    
    if info.dynamicLibraries.count > 10 {
        print("\n  ... 还有 \(info.dynamicLibraries.count - 10) 个库")
    }
    
} catch {
    print("❌ 分析失败: \(error)")
}
#endif

// 演示 3: 依赖分类统计
print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("演示 3: 依赖分类统计")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

#if canImport(OTooliOS)
do {
    let info = try OTooliOS.parse(testPath)
    
    var systemFrameworks = 0
    var systemLibs = 0
    var swiftLibs = 0
    var customLibs = 0
    
    for dylib in info.dynamicLibraries {
        let path = dylib.path
        
        if path.contains("libswift") {
            swiftLibs += 1
        } else if path.contains(".framework/") {
            systemFrameworks += 1
        } else if path.hasPrefix("/usr/lib/") || path.hasPrefix("/System/Library/") {
            systemLibs += 1
        } else {
            customLibs += 1
        }
    }
    
    print("\n📊 依赖统计:")
    print("  🔷 系统框架: \(systemFrameworks)")
    print("  📚 系统库: \(systemLibs)")
    print("  🔶 Swift 库: \(swiftLibs)")
    print("  🔸 自定义库: \(customLibs)")
    print("  ━━━━━━━━━━━━━━━")
    print("  📦 总计: \(info.dynamicLibraries.count)")
    
    if swiftLibs > 0 {
        print("\n  ✨ 检测到 Swift 运行时")
    }
    
} catch {
    print("❌ 统计失败: \(error)")
}
#endif

// 演示 4: RPath 信息
print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("演示 4: RPath 信息")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

#if canImport(OTooliOS)
do {
    let info = try OTooliOS.parse(testPath)
    
    if info.rpaths.isEmpty {
        print("\n  ℹ️  未找到 RPath")
    } else {
        print("\n🔗 RPath 列表:")
        for (index, rpath) in info.rpaths.enumerated() {
            print("  \(index + 1). \(rpath)")
        }
    }
    
} catch {
    print("❌ 查询失败: \(error)")
}
#endif

// 演示 5: 格式化输出（类似 otool -L）
print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("演示 5: 格式化输出（类似 otool -L）")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

#if canImport(OTooliOS)
do {
    let info = try OTooliOS.parse(testPath)
    print("\n" + info.formattedOutput)
    
} catch {
    print("❌ 输出失败: \(error)")
}
#endif

// 演示总结
print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("✅ 演示完成")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("\n💡 提示:")
print("  - 查看 README.md 了解基本用法")
print("  - 查看 USAGE.md 了解详细文档")
print("  - 查看 Examples/ 目录获取更多示例")
print()

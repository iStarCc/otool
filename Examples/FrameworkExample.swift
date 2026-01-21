import Foundation
import OTooliOS

/// .framework 解析示例
///
/// 本示例展示如何使用 OTooliOS 解析 .framework 文件夹

func parseFrameworkExample() {
    // 示例1: 使用智能解析（自动识别 .framework）
    let frameworkPath = "/System/Library/Frameworks/UIKit.framework"
    
    do {
        let info = try OTooliOS.parse(frameworkPath)
        print("Framework: \(frameworkPath)")
        print("架构: \(info.architecture)")
        print("依赖的动态库数量: \(info.dynamicLibraries.count)")
        
        print("\n依赖的动态库:")
        for dylib in info.dynamicLibraries {
            print("  - \(dylib.path)")
            print("    版本: \(dylib.currentVersion)")
            print("    兼容版本: \(dylib.compatibilityVersion)")
        }
    } catch {
        print("解析失败: \(error)")
    }
    
    // 示例2: 使用专门的 framework 解析方法
    let foundationPath = "/System/Library/Frameworks/Foundation.framework"
    
    do {
        let info = try OTooliOS.parseFramework(foundationPath)
        print("\n\nFramework: \(foundationPath)")
        print("架构: \(info.architecture)")
        print("64位: \(info.is64Bit ? "是" : "否")")
    } catch {
        print("解析失败: \(error)")
    }
    
    // 示例3: 获取 framework 的主二进制文件路径
    let webkitPath = "/System/Library/Frameworks/WebKit.framework"
    
    do {
        let binaryPath = try OTooliOS.getFrameworkBinaryPath(from: webkitPath)
        print("\n\n二进制文件路径: \(binaryPath)")
        
        // 然后解析这个二进制文件
        let info = try OTooliOS.parseFile(binaryPath)
        print("RPATHs:")
        for rpath in info.rpaths {
            print("  - \(rpath)")
        }
    } catch {
        print("获取路径失败: \(error)")
    }
}

// iOS 应用中的实际示例
func parseAppFrameworks() {
    // 获取应用 bundle 中的 Frameworks 目录
    guard let bundlePath = Bundle.main.bundlePath as String? else {
        print("无法获取 bundle 路径")
        return
    }
    
    let frameworksPath = (bundlePath as NSString).appendingPathComponent("Frameworks")
    
    // 检查 Frameworks 目录是否存在
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: frameworksPath, isDirectory: &isDirectory),
          isDirectory.boolValue else {
        print("Frameworks 目录不存在")
        return
    }
    
    // 遍历所有 .framework
    do {
        let contents = try FileManager.default.contentsOfDirectory(atPath: frameworksPath)
        let frameworks = contents.filter { $0.hasSuffix(".framework") }
        
        print("应用包含的 Frameworks:")
        for framework in frameworks {
            let fullPath = (frameworksPath as NSString).appendingPathComponent(framework)
            
            do {
                let info = try OTooliOS.parseFramework(fullPath)
                print("\n\(framework)")
                print("  架构: \(info.architecture)")
                print("  依赖数量: \(info.dynamicLibraries.count)")
                
                // 检查是否依赖其他自定义 framework
                let customDeps = info.dynamicLibraries.filter { 
                    $0.path.contains("@rpath") 
                }
                if !customDeps.isEmpty {
                    print("  动态依赖:")
                    for dep in customDeps {
                        print("    - \(dep.path)")
                    }
                }
            } catch {
                print("\n\(framework) - 解析失败: \(error)")
            }
        }
    } catch {
        print("读取目录失败: \(error)")
    }
}

// Framework 结构说明
/*
 .framework 的典型结构:
 
 iOS/tvOS/watchOS Framework (扁平结构):
 MyFramework.framework/
 ├── MyFramework           ← 主二进制文件 (Mach-O)
 ├── Headers/
 │   └── MyFramework.h
 ├── Modules/
 │   └── module.modulemap
 ├── Info.plist
 └── _CodeSignature/
 
 macOS Framework (版本化结构):
 MyFramework.framework/
 ├── MyFramework          → Versions/Current/MyFramework (符号链接)
 ├── Headers              → Versions/Current/Headers
 ├── Resources            → Versions/Current/Resources
 └── Versions/
     ├── A/
     │   ├── MyFramework  ← 主二进制文件
     │   ├── Headers/
     │   └── Resources/
     └── Current          → A (符号链接)
 
 OTooliOS 会自动处理这两种结构！
 */

// 常见的系统 Framework 路径
let commonSystemFrameworks = [
    "/System/Library/Frameworks/UIKit.framework",
    "/System/Library/Frameworks/Foundation.framework",
    "/System/Library/Frameworks/CoreFoundation.framework",
    "/System/Library/Frameworks/AVFoundation.framework",
    "/System/Library/Frameworks/CoreGraphics.framework",
    "/System/Library/Frameworks/CoreData.framework",
    "/System/Library/Frameworks/CoreLocation.framework",
    "/System/Library/Frameworks/WebKit.framework",
    "/System/Library/Frameworks/Network.framework",
    "/System/Library/Frameworks/Security.framework"
]

// 批量解析系统 frameworks
func analyzeSystemFrameworks() {
    print("系统 Frameworks 分析:\n")
    
    for frameworkPath in commonSystemFrameworks {
        guard FileManager.default.fileExists(atPath: frameworkPath) else {
            continue
        }
        
        do {
            let info = try OTooliOS.parse(frameworkPath)
            let frameworkName = (frameworkPath as NSString).lastPathComponent
            
            print("\(frameworkName)")
            print("  架构: \(info.architecture)")
            print("  依赖数量: \(info.dynamicLibraries.count)")
            
            // 找出依赖的其他系统 frameworks
            let systemDeps = info.dynamicLibraries.filter {
                $0.path.contains("/System/Library/Frameworks/")
            }
            if !systemDeps.isEmpty {
                print("  依赖的系统框架:")
                for dep in systemDeps.prefix(5) {
                    let depName = dep.path.components(separatedBy: "/").last ?? dep.path
                    print("    - \(depName)")
                }
                if systemDeps.count > 5 {
                    print("    ... 还有 \(systemDeps.count - 5) 个")
                }
            }
            print("")
        } catch {
            print("\(frameworkPath) - 解析失败: \(error.localizedDescription)\n")
        }
    }
}

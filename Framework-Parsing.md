# Framework 解析指南

本文档详细说明如何使用 OTooliOS 解析 .framework 文件夹。

## Framework 结构简介

.framework 是 Apple 平台上的动态库打包格式，包含二进制代码、头文件和资源。

### iOS/tvOS/watchOS Framework（扁平结构）

```
MyFramework.framework/
├── MyFramework           ← 主二进制文件 (Mach-O)
├── Headers/              ← 公共头文件
│   ├── MyFramework.h
│   └── MyHeader.h
├── Modules/              ← Swift/ObjC 模块
│   └── module.modulemap
├── Info.plist            ← Framework 元数据
└── _CodeSignature/       ← 代码签名
    └── CodeResources
```

### macOS Framework（版本化结构）

```
MyFramework.framework/
├── MyFramework           → Versions/Current/MyFramework (符号链接)
├── Headers               → Versions/Current/Headers
├── Resources             → Versions/Current/Resources
└── Versions/
    ├── A/                ← 版本 A
    │   ├── MyFramework   ← 主二进制文件
    │   ├── Headers/
    │   ├── Resources/
    │   └── Modules/
    ├── B/                ← 版本 B（如果有）
    └── Current           → A (符号链接)
```

## 使用方法

### 1. 智能解析（推荐）

`parse()` 方法会自动识别 .framework 并解析其主二进制文件：

```swift
import OTooliOS

let frameworkPath = "/path/to/MyFramework.framework"

do {
    // 自动识别并解析
    let info = try OTooliOS.parse(frameworkPath)
    
    print("架构: \(info.architecture)")
    print("64位: \(info.is64Bit ? "是" : "否")")
    print("依赖的动态库数量: \(info.dynamicLibraries.count)")
    
    // 打印依赖
    for dylib in info.dynamicLibraries {
        print("\(dylib.path) - \(dylib.currentVersion)")
    }
} catch {
    print("解析失败: \(error)")
}
```

### 2. 专门的 Framework 解析方法

使用 `parseFramework()` 明确表示解析的是 framework：

```swift
do {
    let info = try OTooliOS.parseFramework("/path/to/MyFramework.framework")
    print("架构: \(info.architecture)")
} catch {
    print("解析失败: \(error)")
}
```

### 3. 获取二进制文件路径

如果只想获取 framework 中的二进制文件路径，而不立即解析：

```swift
do {
    let binaryPath = try OTooliOS.getFrameworkBinaryPath(
        from: "/path/to/MyFramework.framework"
    )
    print("二进制文件: \(binaryPath)")
    
    // 然后可以做其他操作，比如检查文件大小
    let attrs = try FileManager.default.attributesOfItem(atPath: binaryPath)
    print("大小: \(attrs[.size] ?? 0) 字节")
} catch {
    print("获取路径失败: \(error)")
}
```

## 使用 CLI 工具

命令行工具支持直接解析 .framework：

```bash
# 解析系统 framework
otool-cli /System/Library/Frameworks/UIKit.framework

# 详细模式
otool-cli -v /path/to/MyFramework.framework

# 只显示动态库依赖
otool-cli -L /path/to/MyFramework.framework
```

### 输出示例

```
正在解析: /path/to/MyFramework.framework
主二进制文件: /path/to/MyFramework.framework/MyFramework

架构: arm64
64位: 是
文件类型: 6 (MH_DYLIB)

动态库依赖 (10):
  /System/Library/Frameworks/Foundation.framework/Foundation
    当前版本: 1953.0.0
    兼容版本: 300.0.0
    
  /usr/lib/libobjc.A.dylib
    当前版本: 228.0.0
    兼容版本: 1.0.0
  ...
```

## 常见场景

### 分析应用的 Embedded Frameworks

```swift
func analyzeAppFrameworks(appPath: String) {
    let frameworksPath = (appPath as NSString)
        .appendingPathComponent("Frameworks")
    
    guard let frameworks = try? FileManager.default
        .contentsOfDirectory(atPath: frameworksPath) else {
        print("Frameworks 目录不存在")
        return
    }
    
    for framework in frameworks where framework.hasSuffix(".framework") {
        let fullPath = (frameworksPath as NSString)
            .appendingPathComponent(framework)
        
        do {
            let info = try OTooliOS.parseFramework(fullPath)
            print("\n\(framework)")
            print("  架构: \(info.architecture)")
            print("  依赖数量: \(info.dynamicLibraries.count)")
            
            // 检查 @rpath 依赖
            let rpathDeps = info.dynamicLibraries.filter { 
                $0.path.contains("@rpath")
            }
            if !rpathDeps.isEmpty {
                print("  @rpath 依赖:")
                for dep in rpathDeps {
                    print("    - \(dep.path)")
                }
            }
        } catch {
            print("\(framework) 解析失败: \(error)")
        }
    }
}
```

### 检查 Framework 的架构兼容性

```swift
func checkArchitecture(frameworkPath: String, 
                       requiredArch: String) -> Bool {
    do {
        let info = try OTooliOS.parseFramework(frameworkPath)
        return info.architecture.contains(requiredArch)
    } catch {
        print("检查失败: \(error)")
        return false
    }
}

// 使用示例
let isARM64 = checkArchitecture(
    frameworkPath: "/path/to/MyFramework.framework",
    requiredArch: "arm64"
)
print("支持 ARM64: \(isARM64)")
```

### 对比不同版本的 Framework

```swift
func compareFrameworks(path1: String, path2: String) {
    do {
        let info1 = try OTooliOS.parseFramework(path1)
        let info2 = try OTooliOS.parseFramework(path2)
        
        print("架构对比:")
        print("  版本1: \(info1.architecture)")
        print("  版本2: \(info2.architecture)")
        
        let deps1 = Set(info1.dynamicLibraries.map { $0.path })
        let deps2 = Set(info2.dynamicLibraries.map { $0.path })
        
        let newDeps = deps2.subtracting(deps1)
        let removedDeps = deps1.subtracting(deps2)
        
        if !newDeps.isEmpty {
            print("\n新增依赖:")
            for dep in newDeps {
                print("  + \(dep)")
            }
        }
        
        if !removedDeps.isEmpty {
            print("\n移除依赖:")
            for dep in removedDeps {
                print("  - \(dep)")
            }
        }
    } catch {
        print("对比失败: \(error)")
    }
}
```

## Framework 查找策略

OTooliOS 使用以下策略查找 framework 中的主二进制文件：

1. **直接查找**：在 framework 根目录查找与 framework 同名的文件
   - 例如：`MyFramework.framework/MyFramework`

2. **版本化目录**：在 `Versions/Current/` 目录查找（macOS）
   - 例如：`MyFramework.framework/Versions/Current/MyFramework`

3. **遍历版本**：遍历 `Versions/` 下的所有版本目录
   - 例如：`MyFramework.framework/Versions/A/MyFramework`

4. **Info.plist**：读取 Info.plist 中的 `CFBundleExecutable` 字段
   - 在多个可能的位置查找 Info.plist
   - 根据 `CFBundleExecutable` 的值查找二进制文件

5. **符号链接解析**：自动解析符号链接到实际文件

6. **Mach-O 验证**：验证找到的文件是否为有效的 Mach-O 二进制

## 错误处理

```swift
do {
    let info = try OTooliOS.parseFramework(frameworkPath)
    // 处理结果...
} catch MachOParserError.fileNotFound {
    print("Framework 不存在")
} catch MachOParserError.notAFramework {
    print("路径不是有效的 .framework bundle")
} catch MachOParserError.frameworkBinaryNotFound {
    print("无法找到 framework 的主二进制文件")
    print("可能原因:")
    print("- Framework 结构不标准")
    print("- 二进制文件存储在 dyld shared cache 中（系统 framework）")
    print("- 文件权限问题")
} catch MachOParserError.invalidMagicNumber {
    print("不是有效的 Mach-O 文件")
} catch {
    print("未知错误: \(error)")
}
```

## 注意事项

### 系统 Framework

macOS 上的很多系统 framework 的二进制文件存储在 **dyld shared cache** 中，而不是独立文件。这些 framework 可能无法直接解析：

```
/System/Library/Frameworks/Foundation.framework/Foundation
  → 符号链接指向 Versions/Current/Foundation
  → 但实际二进制在 /System/Library/dyld/dyld_shared_cache_*
```

对于这类 framework，建议：
- 在 iOS/tvOS/watchOS 真机或模拟器上测试
- 解析应用内嵌的 framework，而不是系统 framework
- 使用 Xcode 中的 framework 副本

### XCFramework

XCFramework 是更新的打包格式，包含多个平台的 framework：

```
MyFramework.xcframework/
├── ios-arm64/
│   └── MyFramework.framework/
├── ios-arm64_x86_64-simulator/
│   └── MyFramework.framework/
└── Info.plist
```

要解析 XCFramework，需要先选择目标平台，然后解析对应的 .framework：

```swift
let xcframeworkPath = "/path/to/MyFramework.xcframework"
let frameworkPath = "\(xcframeworkPath)/ios-arm64/MyFramework.framework"
let info = try OTooliOS.parseFramework(frameworkPath)
```

## 示例项目

查看 `Examples/FrameworkExample.swift` 获取更多实际应用示例。

## 相关文档

- [快速开始指南](QuickStart-iOS.md)
- [iOS 集成文档](iOS-Integration.md)
- [使用手册](USAGE.md)

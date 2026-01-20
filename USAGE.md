# OTool iOS 使用指南

本文档提供了 OTool iOS 库的详细使用说明和示例。

## 快速开始

### 安装

将此 Swift Package 添加到你的项目：

```swift
// Package.swift
dependencies: [
    .package(url: "path/to/OTooliOS", from: "1.0.0")
]
```

### 基本导入

```swift
import OTooliOS
```

## 核心功能

### 1. 解析 Mach-O 文件

```swift
let parser = MachOParser()

do {
    let info = try parser.parse(fileAt: "/path/to/binary")
    
    print("架构: \(info.architecture)")
    print("是否64位: \(info.is64Bit)")
    print("文件类型: \(info.fileType)")
    
    // 遍历动态库
    for dylib in info.dynamicLibraries {
        print("库: \(dylib.path)")
        print("当前版本: \(dylib.currentVersion)")
        print("兼容版本: \(dylib.compatibilityVersion)")
        print("加载类型: \(dylib.loadType)")
    }
    
    // 查看 RPath
    for rpath in info.rpaths {
        print("RPath: \(rpath)")
    }
    
} catch let error as MachOParserError {
    print("解析失败: \(error.localizedDescription)")
}
```

### 2. 快速获取动态库列表

```swift
do {
    let libraries = try OTooliOS.getDynamicLibraries(from: "/path/to/binary")
    for lib in libraries {
        print(lib)
    }
} catch {
    print("错误: \(error)")
}
```

### 3. 格式化输出（类似 otool -L）

```swift
let info = try OTooliOS.parseFile("/path/to/binary")

// 简洁输出（类似 otool -L）
print(info.formattedOutput)

// 详细输出
print(info.detailedOutput)
```

## 命令行工具

### 编译

```bash
swift build -c release
```

### 使用

```bash
# 基本用法
swift run otool-cli /path/to/binary

# 详细模式
swift run otool-cli -v /path/to/binary

# 显示帮助
swift run otool-cli --help
```

### 示例输出

```
正在解析: /usr/lib/libSystem.dylib

/usr/lib/libSystem.dylib:
	/usr/lib/system/libcache.dylib (compatibility version 1.0.0, current version 85.0.0)
	/usr/lib/system/libcommonCrypto.dylib (compatibility version 1.0.0, current version 60178.0.0)
	/usr/lib/system/libcompiler_rt.dylib (compatibility version 1.0.0, current version 101.2.0)
	...
```

## 在 iOS 应用中使用

### SwiftUI 示例

```swift
import SwiftUI
import OTooliOS

struct ContentView: View {
    @State private var dylibInfo: String = ""
    
    var body: some View {
        VStack {
            Button("解析当前应用") {
                parseSelf()
            }
            .padding()
            
            ScrollView {
                Text(dylibInfo)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
        }
    }
    
    func parseSelf() {
        guard let executablePath = Bundle.main.executablePath else {
            dylibInfo = "无法获取可执行文件路径"
            return
        }
        
        do {
            let info = try OTooliOS.parseFile(executablePath)
            dylibInfo = info.detailedOutput
        } catch {
            dylibInfo = "解析失败: \(error.localizedDescription)"
        }
    }
}
```

### UIKit 示例

```swift
import UIKit
import OTooliOS

class ViewController: UIViewController {
    
    private let textView = UITextView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 设置 UI
        textView.frame = view.bounds
        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        view.addSubview(textView)
        
        // 解析
        parseExecutable()
    }
    
    private func parseExecutable() {
        guard let path = Bundle.main.executablePath else { return }
        
        do {
            let info = try OTooliOS.parseFile(path)
            textView.text = info.detailedOutput
        } catch {
            textView.text = "错误: \(error)"
        }
    }
}
```

## 高级用法

### 检查特定依赖

```swift
func checkDependency(binaryPath: String, libraryName: String) -> Bool {
    do {
        let libraries = try OTooliOS.getDynamicLibraries(from: binaryPath)
        return libraries.contains { $0.contains(libraryName) }
    } catch {
        return false
    }
}

// 使用
if checkDependency(binaryPath: "/path/to/app", libraryName: "libswift") {
    print("应用依赖 Swift 运行时")
}
```

### 批量分析

```swift
func analyzeDependencies(in directory: String) {
    let fileManager = FileManager.default
    
    guard let enumerator = fileManager.enumerator(atPath: directory) else {
        return
    }
    
    for case let file as String in enumerator {
        let fullPath = (directory as NSString).appendingPathComponent(file)
        
        do {
            let info = try OTooliOS.parseFile(fullPath)
            print("\n文件: \(file)")
            print("架构: \(info.architecture)")
            print("依赖数: \(info.dynamicLibraries.count)")
        } catch {
            // 跳过非 Mach-O 文件
            continue
        }
    }
}
```

### 比较两个二进制文件的依赖

```swift
func compareDependencies(file1: String, file2: String) throws {
    let libs1 = try OTooliOS.getDynamicLibraries(from: file1)
    let libs2 = try OTooliOS.getDynamicLibraries(from: file2)
    
    let set1 = Set(libs1)
    let set2 = Set(libs2)
    
    let common = set1.intersection(set2)
    let only1 = set1.subtracting(set2)
    let only2 = set2.subtracting(set1)
    
    print("共同依赖 (\(common.count)):")
    common.forEach { print("  \($0)") }
    
    print("\n仅 \(file1) 依赖 (\(only1.count)):")
    only1.forEach { print("  \($0)") }
    
    print("\n仅 \(file2) 依赖 (\(only2.count)):")
    only2.forEach { print("  \($0)") }
}
```

## 错误处理

所有可能的错误类型：

```swift
public enum MachOParserError: Error {
    case fileNotFound           // 文件不存在
    case invalidMagicNumber     // 不是有效的 Mach-O 文件
    case unsupportedArchitecture // 不支持的架构
    case corruptedFile          // 文件损坏
    case readError(String)      // 读取错误
}
```

完整的错误处理示例：

```swift
do {
    let info = try OTooliOS.parseFile(path)
    // 处理结果
} catch MachOParserError.fileNotFound {
    print("文件不存在")
} catch MachOParserError.invalidMagicNumber {
    print("不是 Mach-O 文件")
} catch MachOParserError.unsupportedArchitecture {
    print("不支持的架构")
} catch MachOParserError.corruptedFile {
    print("文件已损坏")
} catch MachOParserError.readError(let message) {
    print("读取错误: \(message)")
} catch {
    print("未知错误: \(error)")
}
```

## 支持的架构

- x86 (32位)
- x86_64 (64位)
- ARM (32位)
- ARM64 (64位)
- ARM64_32
- PowerPC
- PowerPC64

## 支持的文件格式

- 标准 Mach-O 文件（32位和64位）
- Fat Binary（多架构）
- Framework 二进制文件
- Dynamic Libraries (.dylib)
- 可执行文件

## 性能建议

1. **缓存结果**: 如果需要多次访问同一文件的信息，建议缓存 `MachOInfo` 对象
2. **异步处理**: 对于大文件或批量处理，建议在后台线程执行
3. **错误处理**: 始终使用 try-catch 块处理可能的错误

```swift
// 异步处理示例
DispatchQueue.global(qos: .userInitiated).async {
    do {
        let info = try OTooliOS.parseFile(path)
        DispatchQueue.main.async {
            // 更新 UI
        }
    } catch {
        DispatchQueue.main.async {
            // 显示错误
        }
    }
}
```

## 测试

运行测试：

```bash
swift test
```

## 许可证

MIT License

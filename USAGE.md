# OTool iOS 使用指南

本文档提供了 OTool iOS 库的完整使用说明，包括基础用法、iOS 集成和高级示例。

## 目录

- [快速开始](#快速开始)
- [基础用法](#基础用法)
- [命令行工具](#命令行工具)
- [iOS 集成](#ios-集成)
- [高级用法](#高级用法)
- [性能优化](#性能优化)
- [错误处理](#错误处理)

---

## 快速开始

### 5 分钟上手

```swift
import OTooliOS

// 智能解析（自动识别 .app bundle 或可执行文件）
let info = try OTooliOS.parse("/Applications/Calculator.app")

// 查看基本信息
print("架构: \(info.architecture)")
print("动态库数量: \(info.dynamicLibraries.count)")
```

### 在 iOS 项目中使用

```swift
// 分析当前应用
if let path = Bundle.main.executablePath {
    let info = try OTooliOS.parse(path)
    print("我的应用依赖 \(info.dynamicLibraries.count) 个动态库")
}
```

---

## 基础用法

### 1. 解析文件

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

### 4. 智能解析（.app Bundle 或可执行文件）

```swift
// 推荐：使用智能解析，自动识别类型
let info = try OTooliOS.parse("/Applications/Calculator.app")
let info2 = try OTooliOS.parse("/usr/bin/ls")

// 或者明确指定解析 .app bundle
let info = try OTooliOS.parseAppBundle("/path/to/MyApp.app")

// 获取 .app 的主可执行文件路径
let execPath = try OTooliOS.getMainExecutablePath(from: "/path/to/MyApp.app")
```

---

## 命令行工具

### 编译

```bash
swift build -c release
```

### 使用

```bash
# 解析可执行文件或 .app bundle（自动识别）
swift run otool-cli /path/to/binary
swift run otool-cli /Applications/Calculator.app

# 详细模式
swift run otool-cli -v /path/to/MyApp.app
```

### 示例输出

```text
正在解析: /usr/lib/libSystem.dylib

/usr/lib/libSystem.dylib:
  /usr/lib/system/libcache.dylib (compatibility version 1.0.0, current version 85.0.0)
  /usr/lib/system/libcommonCrypto.dylib (compatibility version 1.0.0, current version 60178.0.0)
  /usr/lib/system/libcompiler_rt.dylib (compatibility version 1.0.0, current version 101.2.0)
  ...
```

---

## iOS 集成

### 安装

#### 方式一：Swift Package Manager（推荐）

1. 打开 Xcode 项目
2. `File` → `Add Package Dependencies...`
3. 输入本仓库路径
4. 选择 `OTooliOS` 添加到项目

#### 方式二：Package.swift

```swift
dependencies: [
    .package(path: "../otool-ios")
]
```

### ⚠️ iOS 沙盒限制

未越狱的 iOS 设备只能访问：

- ✅ 应用自身的可执行文件
- ✅ 应用 Bundle 内的框架
- ✅ 应用沙盒内的文件
- ❌ 系统目录（如 `/usr/lib/`）
- ❌ 其他应用的文件

### SwiftUI 示例

```swift
import SwiftUI
import OTooliOS

struct ContentView: View {
    @State private var analysisResult = ""
    @State private var dylibCount = 0
    
    var body: some View {
        VStack {
            Text("依赖库: \(dylibCount)")
                .font(.title)
            
            Button("分析当前应用") {
                analyzeApp()
            }
            .padding()
            
            ScrollView {
                Text(analysisResult)
                    .font(.system(.body, design: .monospaced))
            }
        }
    }
    
    func analyzeApp() {
        guard let path = Bundle.main.executablePath else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let info = try OTooliOS.parse(path)
                DispatchQueue.main.async {
                    dylibCount = info.dynamicLibraries.count
                    analysisResult = info.detailedOutput
                }
            } catch {
                DispatchQueue.main.async {
                    analysisResult = "错误: \(error.localizedDescription)"
                }
            }
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
        
        textView.frame = view.bounds
        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        view.addSubview(textView)
        
        parseExecutable()
    }
    
    private func parseExecutable() {
        guard let path = Bundle.main.executablePath else { return }
        
        do {
            let info = try OTooliOS.parse(path)
            textView.text = info.detailedOutput
        } catch {
            textView.text = "错误: \(error)"
        }
    }
}
```

### 实用工具类

```swift
import OTooliOS

class AppAnalyzer {
    static func analyze() {
        guard let path = Bundle.main.executablePath else { return }
        
        do {
            let info = try OTooliOS.parse(path)
            
            print("📱 应用分析")
            print("架构: \(info.architecture)")
            print("依赖数: \(info.dynamicLibraries.count)")
            
            // 检查 Swift
            let hasSwift = info.dynamicLibraries.contains { 
                $0.path.contains("swift") 
            }
            print("Swift: \(hasSwift ? "✅" : "❌")")
            
        } catch {
            print("错误: \(error)")
        }
    }
}
```

---

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
            let info = try OTooliOS.parse(fullPath)
            print("\n文件: \(file)")
            print("架构: \(info.architecture)")
            print("依赖数: \(info.dynamicLibraries.count)")
        } catch {
            continue
        }
    }
}
```

### 比较依赖

```swift
func compareDependencies(file1: String, file2: String) throws {
    let libs1 = try OTooliOS.getDynamicLibraries(from: file1)
    let libs2 = try OTooliOS.getDynamicLibraries(from: file2)
    
    let set1 = Set(libs1)
    let set2 = Set(libs2)
    
    let common = set1.intersection(set2)
    let only1 = set1.subtracting(set2)
    let only2 = set2.subtracting(set1)
    
    print("共同依赖: \(common.count)")
    print("仅 \(file1): \(only1.count)")
    print("仅 \(file2): \(only2.count)")
}
```

### 检测 Swift 依赖

```swift
let info = try OTooliOS.parse("/path/to/MyApp.app")
let hasSwift = info.dynamicLibraries.contains { $0.path.contains("libswift") }
print(hasSwift ? "使用了 Swift" : "未使用 Swift")
```

### 依赖分类统计

```swift
let info = try OTooliOS.parse("/Applications/MyApp.app")
let frameworks = info.dynamicLibraries.filter { $0.path.contains(".framework/") }
let systemLibs = info.dynamicLibraries.filter { $0.path.hasPrefix("/usr/lib/") }

print("系统框架: \(frameworks.count)")
print("系统库: \(systemLibs.count)")
```

### 生成依赖报告

```swift
func generateReport() -> String {
    guard let path = Bundle.main.executablePath,
          let info = try? OTooliOS.parse(path) else {
        return "无法生成报告"
    }
    
    return """
    📊 应用依赖报告
    ════════════════════
    架构：\(info.architecture)
    总依赖：\(info.dynamicLibraries.count)
    
    主要依赖：
    \(info.dynamicLibraries.prefix(10).map { "• \($0.path)" }.joined(separator: "\n"))
    """
}
```

---

## 性能优化

### 1. 异步处理

```swift
// ✅ 推荐：后台线程执行
DispatchQueue.global(qos: .userInitiated).async {
    do {
        let info = try OTooliOS.parse(path)
        DispatchQueue.main.async {
            // 更新 UI
        }
    } catch {
        // 处理错误
    }
}

// ❌ 避免：主线程阻塞
let info = try OTooliOS.parse(path)
```

### 2. 缓存结果

```swift
class AnalysisCache {
    private var cache: [String: MachOInfo] = [:]
    
    func getInfo(for path: String) throws -> MachOInfo {
        if let cached = cache[path] {
            return cached
        }
        
        let info = try OTooliOS.parse(path)
        cache[path] = info
        return info
    }
}
```

### 3. 性能建议

- 对大文件使用异步处理
- 需要多次访问时缓存结果
- 只在必要时执行解析

---

## 错误处理

### 错误类型

```swift
public enum MachOParserError: Error {
    case fileNotFound                // 文件不存在
    case invalidMagicNumber          // 不是有效的 Mach-O 文件
    case unsupportedArchitecture     // 不支持的架构
    case corruptedFile               // 文件损坏
    case readError(String)           // 读取错误
    case notAnAppBundle              // 不是有效的 .app bundle
    case infoPlistNotFound           // Info.plist 文件未找到
    case executableNotFoundInPlist   // Info.plist 中未找到 CFBundleExecutable
}
```

### 完整错误处理

```swift
do {
    let info = try OTooliOS.parse(path)
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
} catch MachOParserError.notAnAppBundle {
    print("不是有效的 .app bundle")
} catch MachOParserError.infoPlistNotFound {
    print("Info.plist 文件未找到")
} catch MachOParserError.executableNotFoundInPlist {
    print("Info.plist 中未找到主可执行文件信息")
} catch {
    print("未知错误: \(error)")
}
```

### .app Bundle 错误处理

```swift
do {
    let info = try OTooliOS.parseAppBundle("/path/to/MyApp.app")
    print("解析成功")
} catch MachOParserError.notAnAppBundle {
    print("不是有效的 .app bundle")
} catch MachOParserError.infoPlistNotFound {
    print(".app bundle 中缺少 Info.plist")
} catch MachOParserError.executableNotFoundInPlist {
    print("Info.plist 中未指定主可执行文件")
} catch MachOParserError.fileNotFound {
    print("主可执行文件不存在")
} catch {
    print("未知错误: \(error.localizedDescription)")
}
```

---

## 支持的格式

- ✅ 标准 Mach-O 文件（32位和64位）
- ✅ Fat Binary（多架构）
- ✅ .app Bundle（iOS/macOS 应用）
- ✅ Framework 二进制文件
- ✅ Dynamic Libraries (.dylib)
- ✅ 可执行文件

## 支持的架构

- x86 (32位)
- x86_64 (64位)
- ARM (32位)
- ARM64 (64位)
- ARM64_32
- PowerPC
- PowerPC64

---

## 测试

运行测试：

```bash
swift test
```

---

## 常见问题

**Q: 为什么在 iOS 上无法访问系统库？**  
A: 未越狱的 iOS 设备受沙盒限制，只能访问应用自己的文件。

**Q: 如何分析 .app bundle？**  
A: 使用 `OTooliOS.parse("/path/to/App.app")`，会自动查找并解析主可执行文件。

**Q: 可以分析从网络下载的文件吗？**  
A: 可以，只要文件保存在应用的沙盒目录内。

**Q: 性能如何？**  
A: 解析速度很快，但建议在后台线程执行以避免阻塞 UI。

---

## 完整示例

查看 `Examples/` 目录获取完整示例：

- `AppBundleExample.swift` - 基本使用示例
- `DemoScript.swift` - 完整演示脚本
- `iOSApp/` - iOS 应用集成示例

---

## 许可证

MIT License

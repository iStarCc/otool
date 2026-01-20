# iOS 项目快速开始指南

## 5 分钟集成 OTool iOS 到你的 iOS 项目

### 步骤 1: 添加依赖

在 Xcode 中：
1. 打开你的项目
2. `File` → `Add Package Dependencies...`
3. 输入路径：`file:///Users/kcui/otool-ios`
4. 点击 `Add Package`

### 步骤 2: 导入库

```swift
import OTooliOS
```

### 步骤 3: 使用（三种方式）

#### 方式一：最简单（一行代码）

```swift
// 获取当前应用的所有动态库
if let libraries = try? OTooliOS.getDynamicLibraries(
    from: Bundle.main.executablePath ?? ""
) {
    print(libraries)
}
```

#### 方式二：获取详细信息

```swift
if let path = Bundle.main.executablePath,
   let info = try? OTooliOS.parseFile(path) {
    print("架构：\(info.architecture)")
    print("依赖数：\(info.dynamicLibraries.count)")
    print(info.detailedOutput)
}
```

#### 方式三：完整的 SwiftUI 界面

复制 `Examples/iOSApp/` 目录下的三个文件到你的项目：
- `DylibAnalyzerApp.swift`
- `DylibAnalyzerView.swift`
- `DylibAnalyzerViewModel.swift`

然后直接使用：

```swift
import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            DylibAnalyzerView() // 就这么简单！
        }
    }
}
```

### 实用工具类（复制即用）

```swift
import OTooliOS

class AppAnalyzer {
    static func analyze() {
        guard let path = Bundle.main.executablePath else { return }
        
        do {
            let info = try OTooliOS.parseFile(path)
            
            print("📱 应用分析")
            print("━━━━━━━━━━━━━━━━")
            print("架构: \(info.architecture)")
            print("依赖数: \(info.dynamicLibraries.count)")
            
            // 获取系统框架
            let frameworks = info.dynamicLibraries
                .filter { $0.path.contains(".framework") }
                .map { $0.path }
            print("\n系统框架: \(frameworks.count) 个")
            
            // 检查是否使用 Swift
            let usesSwift = info.dynamicLibraries
                .contains { $0.path.contains("swift") }
            print("使用 Swift: \(usesSwift ? "是" : "否")")
            
        } catch {
            print("分析失败: \(error)")
        }
    }
}

// 使用
AppAnalyzer.analyze()
```

### 常见用法示例

#### 检查特定依赖

```swift
func checkDependency(_ name: String) -> Bool {
    guard let path = Bundle.main.executablePath,
          let libs = try? OTooliOS.getDynamicLibraries(from: path) else {
        return false
    }
    return libs.contains { $0.contains(name) }
}

// 使用
if checkDependency("AFNetworking") {
    print("应用使用了 AFNetworking")
}
```

#### 获取系统框架列表

```swift
func getSystemFrameworks() -> [String] {
    guard let path = Bundle.main.executablePath,
          let info = try? OTooliOS.parseFile(path) else {
        return []
    }
    
    return info.dynamicLibraries
        .filter { $0.path.contains("/System/Library/Frameworks/") }
        .map { $0.path.components(separatedBy: "/")
            .first { $0.hasSuffix(".framework") }?
            .replacingOccurrences(of: ".framework", with: "") ?? ""
        }
        .filter { !$0.isEmpty }
}

// 使用
let frameworks = getSystemFrameworks()
print("系统框架：\(frameworks)")
```

#### 生成依赖报告

```swift
func generateReport() -> String {
    guard let path = Bundle.main.executablePath,
          let info = try? OTooliOS.parseFile(path) else {
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

// 使用
print(generateReport())
```

### ⚠️ 重要提醒

未越狱的 iOS 设备只能访问：
- ✅ 应用自己的可执行文件
- ✅ 应用 Bundle 内的框架
- ✅ 应用沙盒内的文件
- ❌ 系统目录（如 `/usr/lib/`）
- ❌ 其他应用的文件

### 调试技巧

```swift
#if DEBUG
func printDebugInfo() {
    print("Bundle Path:", Bundle.main.bundlePath)
    print("Executable:", Bundle.main.executablePath ?? "N/A")
    print("Frameworks:", Bundle.main.privateFrameworksPath ?? "N/A")
}
#endif
```

### 性能建议

```swift
// ✅ 好的做法：异步执行
DispatchQueue.global(qos: .userInitiated).async {
    if let path = Bundle.main.executablePath,
       let info = try? OTooliOS.parseFile(path) {
        DispatchQueue.main.async {
            // 更新 UI
        }
    }
}

// ❌ 不好的做法：在主线程执行
let info = try? OTooliOS.parseFile(Bundle.main.executablePath ?? "")
```

### 完整示例项目

查看 `Examples/iOSApp/` 目录获取完整的 SwiftUI 示例应用，包括：
- 美观的用户界面
- 统计卡片展示
- 详细/简洁视图切换
- 分享和复制功能
- 完整的错误处理

### 获取帮助

- 📖 详细文档：查看 `iOS-Integration.md`
- 💡 使用示例：查看 `Examples/Example.swift`
- 📚 API 文档：查看 `USAGE.md`

就这么简单！现在你可以在 iOS 应用中分析动态库依赖了 🎉

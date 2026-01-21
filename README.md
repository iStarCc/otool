# OTool iOS

一个用 Swift 实现的 Mach-O 文件解析工具，类似于系统的 `otool -L` 命令。可以查看二进制文件的动态库依赖关系。

## 功能特性

- 📦 解析 Mach-O 文件格式（32位和64位）
- 🔗 查看动态库依赖（类似 `otool -L`）
- 📱 支持 iOS 和 macOS
- 🛠️ 提供命令行工具和库
- 🎯 支持解析 .app bundle 中的主可执行文件
- 🔄 支持 Fat Binary（多架构）
- 📚 支持解析 .framework 文件夹

## 快速开始

### 作为库使用

```swift
import OTooliOS

// 智能解析（自动识别类型）
let info = try OTooliOS.parse("/Applications/Calculator.app")

print("架构: \(info.architecture)")
print("动态库数量: \(info.dynamicLibraries.count)")
```

### 解析 Framework

```swift
// 解析 .framework 文件夹
let frameworkPath = "/path/to/MyFramework.framework"
let info = try OTooliOS.parseFramework(frameworkPath)
print("架构: \(info.architecture)")
```

### iOS 应用中使用

```swift
// 分析当前应用
if let path = Bundle.main.executablePath {
    let info = try OTooliOS.parse(path)
    print("依赖 \(info.dynamicLibraries.count) 个动态库")
}
```

### 命令行工具

```bash
# 解析文件（自动识别 .app、.framework 或可执行文件）
swift run otool-cli /Applications/Calculator.app
swift run otool-cli /path/to/MyFramework.framework
swift run otool-cli /usr/bin/ls

# 详细信息
swift run otool-cli -v /path/to/MyApp.app
```

## 项目结构

```text
OTooliOS/
├── Sources/
│   ├── OTooliOS/          # 核心库
│   │   ├── MachOParser.swift
│   │   ├── MachOStructs.swift
│   │   └── DylibInfo.swift
│   └── OToolCLI/          # 命令行工具
│       └── main.swift
├── Tests/
│   └── OTooliOSTests/
└── Package.swift
```

## 技术实现

本项目实现了 Mach-O 文件格式的解析，包括：

- Mach-O Header 解析
- Load Commands 读取
- 动态库路径提取
- 版本信息解析

## 兼容性

- iOS 15.0+
- macOS 12.0+
- Swift 5.9+

## 文档

- 📘 [使用指南 (USAGE.md)](USAGE.md) - 完整的使用文档，包含基础用法、iOS 集成和高级示例
- 📚 [Framework 解析指南 (Framework-Parsing.md)](Framework-Parsing.md) - .framework 文件夹解析详细说明
- 🚀 [快速开始 (QuickStart-iOS.md)](QuickStart-iOS.md) - iOS 应用快速集成指南
- 📱 [iOS 集成文档 (iOS-Integration.md)](iOS-Integration.md) - 详细的 iOS 集成说明

## License

MIT

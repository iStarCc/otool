# OTool iOS

一个用 Swift 实现的 Mach-O 文件解析工具，类似于系统的 `otool -L` 命令。可以查看二进制文件的动态库依赖关系。

## 功能特性

- 📦 解析 Mach-O 文件格式（32位和64位）
- 🔗 查看动态库依赖（类似 `otool -L`）
- 📱 支持 iOS 和 macOS
- 🛠️ 提供命令行工具和库

## 使用方法

### 作为库使用

```swift
import OTooliOS

let parser = MachOParser()
do {
    let info = try parser.parse(fileAt: "/path/to/binary")
    print("架构: \(info.architecture)")
    print("动态库依赖:")
    for dylib in info.dynamicLibraries {
        print("  \(dylib.path) (版本: \(dylib.version))")
    }
} catch {
    print("解析失败: \(error)")
}
```

### 命令行工具

```bash
swift run otool-cli /path/to/binary
```

## 项目结构

```
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

## License

MIT

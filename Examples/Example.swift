import Foundation
import OTooliOS

// MARK: - 使用示例

/// 示例 1: 基本使用 - 解析单个文件
func example1_BasicUsage() {
    print("=== 示例 1: 基本使用 ===\n")
    
    let parser = MachOParser()
    
    // 解析系统库
    let path = "/usr/lib/libSystem.dylib"
    
    do {
        let info = try parser.parse(fileAt: path)
        
        print("文件: \(path)")
        print("架构: \(info.architecture)")
        print("64位: \(info.is64Bit)")
        print("\n动态库依赖:")
        
        for dylib in info.dynamicLibraries {
            print("  - \(dylib.path)")
            print("    版本: \(dylib.currentVersion)")
        }
    } catch {
        print("错误: \(error)")
    }
}

/// 示例 2: 快速获取动态库列表
func example2_QuickAccess() {
    print("\n=== 示例 2: 快速获取动态库 ===\n")
    
    let path = "/usr/lib/libc.dylib"
    
    do {
        let libraries = try OTooliOS.getDynamicLibraries(from: path)
        
        print("文件: \(path)")
        print("依赖的动态库:")
        for lib in libraries {
            print("  - \(lib)")
        }
    } catch {
        print("错误: \(error)")
    }
}

/// 示例 3: 详细输出（类似 otool -L）
func example3_DetailedOutput() {
    print("\n=== 示例 3: 详细输出 ===\n")
    
    let path = "/usr/lib/libSystem.dylib"
    
    do {
        let info = try OTooliOS.parseFile(path)
        print(info.formattedOutput)
    } catch {
        print("错误: \(error)")
    }
}

/// 示例 4: 解析应用程序 Bundle
func example4_ParseAppBundle() {
    print("\n=== 示例 4: 解析应用程序 ===\n")
    
    // 获取当前进程的可执行文件路径
    if let executablePath = Bundle.main.executablePath {
        do {
            let info = try OTooliOS.parseFile(executablePath)
            print(info.detailedOutput)
        } catch {
            print("错误: \(error)")
        }
    } else {
        print("无法获取可执行文件路径")
    }
}

/// 示例 5: 检查特定库依赖
func example5_CheckDependency() {
    print("\n=== 示例 5: 检查特定依赖 ===\n")
    
    let path = "/usr/lib/libSystem.dylib"
    let searchFor = "libobjc"
    
    do {
        let libraries = try OTooliOS.getDynamicLibraries(from: path)
        
        let found = libraries.contains { $0.contains(searchFor) }
        
        if found {
            print("✅ 文件 \(path) 依赖 \(searchFor)")
            
            // 显示匹配的库
            let matches = libraries.filter { $0.contains(searchFor) }
            for match in matches {
                print("  - \(match)")
            }
        } else {
            print("❌ 文件 \(path) 不依赖 \(searchFor)")
        }
    } catch {
        print("错误: \(error)")
    }
}

/// 示例 6: 批量处理多个文件
func example6_BatchProcessing() {
    print("\n=== 示例 6: 批量处理 ===\n")
    
    let paths = [
        "/usr/lib/libSystem.dylib",
        "/usr/lib/libc.dylib",
        "/usr/lib/libz.dylib"
    ]
    
    for path in paths {
        guard FileManager.default.fileExists(atPath: path) else {
            print("⚠️  文件不存在: \(path)")
            continue
        }
        
        do {
            let libraries = try OTooliOS.getDynamicLibraries(from: path)
            print("📦 \(path)")
            print("   依赖数量: \(libraries.count)")
        } catch {
            print("❌ \(path): \(error)")
        }
    }
}

/// 示例 7: 错误处理
func example7_ErrorHandling() {
    print("\n=== 示例 7: 错误处理 ===\n")
    
    let invalidPath = "/tmp/nonexistent.dylib"
    let parser = MachOParser()
    
    do {
        _ = try parser.parse(fileAt: invalidPath)
    } catch let error as MachOParserError {
        switch error {
        case .fileNotFound:
            print("文件未找到: \(invalidPath)")
        case .invalidMagicNumber:
            print("无效的 Mach-O 文件")
        case .unsupportedArchitecture:
            print("不支持的架构")
        case .corruptedFile:
            print("文件已损坏")
        case .readError(let message):
            print("读取错误: \(message)")
        }
    } catch {
        print("未知错误: \(error)")
    }
}

// MARK: - iOS 应用示例

#if os(iOS)
import UIKit

/// iOS 应用中的使用示例
class OToolViewController: UIViewController {
    
    private let textView = UITextView()
    private let parseButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // 配置文本视图
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)
        
        // 配置按钮
        parseButton.setTitle("解析当前应用", for: .normal)
        parseButton.addTarget(self, action: #selector(parseCurrentApp), for: .touchUpInside)
        parseButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(parseButton)
        
        // 布局
        NSLayoutConstraint.activate([
            parseButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            parseButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            textView.topAnchor.constraint(equalTo: parseButton.bottomAnchor, constant: 20),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }
    
    @objc private func parseCurrentApp() {
        guard let executablePath = Bundle.main.executablePath else {
            textView.text = "无法获取应用可执行文件路径"
            return
        }
        
        do {
            let info = try OTooliOS.parseFile(executablePath)
            textView.text = info.detailedOutput
        } catch {
            textView.text = "解析失败: \(error.localizedDescription)"
        }
    }
}
#endif

// MARK: - 主程序

/// 运行所有示例
func runAllExamples() {
    example1_BasicUsage()
    example2_QuickAccess()
    example3_DetailedOutput()
    example4_ParseAppBundle()
    example5_CheckDependency()
    example6_BatchProcessing()
    example7_ErrorHandling()
}

// 如果直接运行此文件
#if !os(iOS)
// runAllExamples()
#endif

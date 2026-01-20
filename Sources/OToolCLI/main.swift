import Foundation
import OTooliOS

// MARK: - 命令行工具

/// 打印使用说明
func printUsage() {
    print("""
    使用方法: otool-cli [选项] <文件路径>
    
    选项:
      -L              显示动态库依赖（默认）
      -v, --verbose   显示详细信息
      -h, --help      显示此帮助信息
      
    示例:
      otool-cli /path/to/binary
      otool-cli -v /path/to/app
      otool-cli -L /usr/lib/libSystem.dylib
    """)
}

/// 主函数
func main() {
    let arguments = CommandLine.arguments
    
    // 去掉程序名
    let args = Array(arguments.dropFirst())
    
    // 检查参数
    if args.isEmpty || args.contains("-h") || args.contains("--help") {
        printUsage()
        exit(args.isEmpty ? 1 : 0)
    }
    
    // 解析选项
    var verbose = false
    var filePath: String?
    
    for arg in args {
        if arg == "-v" || arg == "--verbose" {
            verbose = true
        } else if arg == "-L" {
            // -L 是默认行为
            continue
        } else if !arg.hasPrefix("-") {
            filePath = arg
            break
        }
    }
    
    guard let path = filePath else {
        print("错误: 未指定文件路径")
        printUsage()
        exit(1)
    }
    
    // 解析文件
    let parser = MachOParser()
    
    do {
        print("正在解析: \(path)")
        print()
        
        let info = try parser.parse(fileAt: path)
        
        if verbose {
            // 详细模式
            print(info.detailedOutput)
        } else {
            // 简洁模式（类似 otool -L）
            print(info.formattedOutput)
        }
        
    } catch let error as MachOParserError {
        print("解析错误: \(error.localizedDescription)")
        exit(1)
    } catch {
        print("未知错误: \(error.localizedDescription)")
        exit(1)
    }
}

// 运行主函数
main()

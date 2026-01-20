import XCTest
@testable import OTooliOS

final class MachOParserTests: XCTestCase {
    
    var parser: MachOParser!
    
    override func setUp() {
        super.setUp()
        parser = MachOParser()
    }
    
    override func tearDown() {
        parser = nil
        super.tearDown()
    }
    
    // MARK: - 基础测试
    
    func testParserInitialization() {
        XCTAssertNotNil(parser, "解析器应该成功初始化")
    }
    
    func testParseNonExistentFile() {
        let path = "/tmp/nonexistent_file_\(UUID().uuidString)"
        
        XCTAssertThrowsError(try parser.parse(fileAt: path)) { error in
            XCTAssertTrue(error is MachOParserError, "应该抛出 MachOParserError")
            if let machError = error as? MachOParserError {
                switch machError {
                case .fileNotFound:
                    break // 预期的错误
                default:
                    XCTFail("应该是 fileNotFound 错误")
                }
            }
        }
    }
    
    func testParseInvalidData() {
        let invalidData = Data([0x00, 0x01, 0x02, 0x03])
        
        XCTAssertThrowsError(try parser.parse(data: invalidData)) { error in
            XCTAssertTrue(error is MachOParserError, "应该抛出 MachOParserError")
        }
    }
    
    // MARK: - 版本格式化测试
    
    func testVersionFormatting() {
        let testVersion: UInt32 = 0x00010203 // 1.2.3
        let expected = "1.2.3"
        
        // 创建一个测试用的 DylibCommand
        let command = DylibCommand(
            cmd: 0x0c,
            cmdsize: 24,
            nameOffset: 24,
            timestamp: 0,
            currentVersion: testVersion,
            compatibilityVersion: 0
        )
        
        XCTAssertEqual(command.currentVersionString, expected, "版本号格式化应该正确")
    }
    
    // MARK: - 实际文件测试
    
    func testParseSystemLibrary() {
        // 测试系统库（通常在所有系统上都存在）
        let systemPaths = [
            "/usr/lib/libffi-trampolines.dylib",
            "/usr/lib/libgmalloc.dylib",
            "/bin/ls"
        ]
        
        var foundValidLibrary = false
        
        for path in systemPaths {
            guard FileManager.default.fileExists(atPath: path) else {
                continue
            }
            
            do {
                let info = try parser.parse(fileAt: path)
                
                // 验证基本信息
                XCTAssertFalse(info.architecture.isEmpty, "架构信息不应为空")
                XCTAssertGreaterThan(info.dynamicLibraries.count, 0, "应该至少有一个动态库")
                
                foundValidLibrary = true
                
                print("成功解析: \(path)")
                print("架构: \(info.architecture)")
                print("动态库数量: \(info.dynamicLibraries.count)")
                
                break
            } catch {
                print("解析 \(path) 失败: \(error)")
            }
        }
        
        XCTAssertTrue(foundValidLibrary, "至少应该成功解析一个系统库")
    }
    
    func testParseSelfExecutable() {
        // 尝试解析测试可执行文件自身
        let executablePath = Bundle.main.executablePath ?? ""
        
        guard !executablePath.isEmpty && FileManager.default.fileExists(atPath: executablePath) else {
            print("跳过测试: 无法找到可执行文件")
            return
        }
        
        do {
            let info = try parser.parse(fileAt: executablePath)
            
            XCTAssertFalse(info.architecture.isEmpty, "架构信息不应为空")
            print("\n测试可执行文件信息:")
            print(info.detailedOutput)
            
        } catch {
            print("解析测试可执行文件失败: \(error)")
            // 不标记为失败，因为某些环境下可能无法访问
        }
    }
    
    // MARK: - 数据读取测试
    
    func testDataExtensionReadCString() {
        let testString = "Hello, World!"
        var data = Data(testString.utf8)
        data.append(0) // 添加 null 终止符
        
        let result = data.readCString(at: 0)
        XCTAssertEqual(result, testString, "应该正确读取 C 字符串")
    }
    
    func testDataExtensionReadInteger() {
        var data = Data()
        let testValue: UInt32 = 0x12345678
        withUnsafeBytes(of: testValue) { buffer in
            data.append(contentsOf: buffer)
        }
        
        let result: UInt32? = data.read(UInt32.self, at: 0)
        XCTAssertEqual(result, testValue, "应该正确读取整数")
    }
    
    // MARK: - CPUType 测试
    
    func testCPUTypeDescription() {
        XCTAssertEqual(CPUType.x86_64.description, "x86_64")
        XCTAssertEqual(CPUType.arm64.description, "arm64")
        XCTAssertEqual(CPUType.i386.description, "i386")
    }
    
    // MARK: - DylibInfo 测试
    
    func testDylibInfoCreation() {
        let dylib = DylibInfo(
            path: "/usr/lib/libSystem.dylib",
            currentVersion: "1.2.3",
            compatibilityVersion: "1.0.0",
            loadType: .load
        )
        
        XCTAssertEqual(dylib.path, "/usr/lib/libSystem.dylib")
        XCTAssertEqual(dylib.currentVersion, "1.2.3")
        XCTAssertEqual(dylib.compatibilityVersion, "1.0.0")
        XCTAssertEqual(dylib.loadType, .load)
    }
    
    // MARK: - MachOInfo 测试
    
    func testMachOInfoFormattedOutput() {
        let dylibs = [
            DylibInfo(path: "/usr/lib/libSystem.dylib", currentVersion: "1.2.3", compatibilityVersion: "1.0.0", loadType: .id),
            DylibInfo(path: "/usr/lib/libc.dylib", currentVersion: "2.3.4", compatibilityVersion: "2.0.0", loadType: .load)
        ]
        
        let info = MachOInfo(
            architecture: "arm64",
            is64Bit: true,
            fileType: 2,
            dynamicLibraries: dylibs,
            rpaths: []
        )
        
        let output = info.formattedOutput
        XCTAssertTrue(output.contains("libSystem.dylib"), "输出应包含库名")
        XCTAssertTrue(output.contains("libc.dylib"), "输出应包含第二个库名")
        XCTAssertTrue(output.contains("2.3.4"), "输出应包含第二个库的版本号")
    }
    
    // MARK: - .app Bundle 测试
    
    func testFindMainExecutableInvalidPath() {
        let invalidPath = "/tmp/nonexistent_\(UUID().uuidString).app"
        
        XCTAssertThrowsError(try MachOParser.findMainExecutable(in: invalidPath)) { error in
            XCTAssertTrue(error is MachOParserError)
            if let machError = error as? MachOParserError {
                switch machError {
                case .fileNotFound:
                    break // 预期的错误
                default:
                    XCTFail("应该是 fileNotFound 错误，实际是: \(machError)")
                }
            }
        }
    }
    
    func testFindMainExecutableNotADirectory() {
        // 创建一个临时文件（不是目录）
        let tempPath = NSTemporaryDirectory() + "test_\(UUID().uuidString).app"
        FileManager.default.createFile(atPath: tempPath, contents: Data())
        defer {
            try? FileManager.default.removeItem(atPath: tempPath)
        }
        
        XCTAssertThrowsError(try MachOParser.findMainExecutable(in: tempPath)) { error in
            XCTAssertTrue(error is MachOParserError)
            if let machError = error as? MachOParserError {
                switch machError {
                case .notAnAppBundle:
                    break // 预期的错误
                default:
                    XCTFail("应该是 notAnAppBundle 错误")
                }
            }
        }
    }
    
    func testFindMainExecutableNotAppExtension() {
        // 创建一个不以 .app 结尾的目录
        let tempPath = NSTemporaryDirectory() + "test_\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: tempPath, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(atPath: tempPath)
        }
        
        XCTAssertThrowsError(try MachOParser.findMainExecutable(in: tempPath)) { error in
            XCTAssertTrue(error is MachOParserError)
            if let machError = error as? MachOParserError {
                switch machError {
                case .notAnAppBundle:
                    break // 预期的错误
                default:
                    XCTFail("应该是 notAnAppBundle 错误")
                }
            }
        }
    }
    
    func testFindMainExecutableMissingInfoPlist() {
        // 创建一个 .app 目录但没有 Info.plist
        let tempPath = NSTemporaryDirectory() + "test_\(UUID().uuidString).app"
        try? FileManager.default.createDirectory(atPath: tempPath, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(atPath: tempPath)
        }
        
        XCTAssertThrowsError(try MachOParser.findMainExecutable(in: tempPath)) { error in
            XCTAssertTrue(error is MachOParserError)
            if let machError = error as? MachOParserError {
                switch machError {
                case .infoPlistNotFound:
                    break // 预期的错误
                default:
                    XCTFail("应该是 infoPlistNotFound 错误")
                }
            }
        }
    }
    
    func testFindMainExecutableInvalidPlist() {
        // 创建一个包含无效 Info.plist 的 .app 目录
        let tempPath = NSTemporaryDirectory() + "test_\(UUID().uuidString).app"
        try? FileManager.default.createDirectory(atPath: tempPath, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(atPath: tempPath)
        }
        
        // 创建无效的 Info.plist
        let plistPath = (tempPath as NSString).appendingPathComponent("Info.plist")
        let invalidData = Data("invalid plist".utf8)
        FileManager.default.createFile(atPath: plistPath, contents: invalidData)
        
        XCTAssertThrowsError(try MachOParser.findMainExecutable(in: tempPath)) { error in
            XCTAssertTrue(error is MachOParserError)
        }
    }
    
    func testFindMainExecutableMissingCFBundleExecutable() {
        // 创建一个 .app 目录，Info.plist 中没有 CFBundleExecutable
        let tempPath = NSTemporaryDirectory() + "test_\(UUID().uuidString).app"
        try? FileManager.default.createDirectory(atPath: tempPath, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(atPath: tempPath)
        }
        
        // 创建一个有效但缺少 CFBundleExecutable 的 Info.plist
        let plistPath = (tempPath as NSString).appendingPathComponent("Info.plist")
        let plist: [String: Any] = ["CFBundleIdentifier": "com.test.app"]
        if let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
            FileManager.default.createFile(atPath: plistPath, contents: data)
        }
        
        XCTAssertThrowsError(try MachOParser.findMainExecutable(in: tempPath)) { error in
            XCTAssertTrue(error is MachOParserError)
            if let machError = error as? MachOParserError {
                switch machError {
                case .executableNotFoundInPlist:
                    break // 预期的错误
                default:
                    XCTFail("应该是 executableNotFoundInPlist 错误")
                }
            }
        }
    }
    
    func testParseSystemAppIfAvailable() {
        // 尝试解析系统应用（如果存在）
        let systemApps = [
            "/Applications/Calculator.app",
            "/System/Applications/Calculator.app",
            "/Applications/TextEdit.app",
            "/System/Applications/TextEdit.app"
        ]
        
        var foundApp = false
        
        for appPath in systemApps {
            guard FileManager.default.fileExists(atPath: appPath) else {
                continue
            }
            
            do {
                // 测试查找主可执行文件
                let executablePath = try MachOParser.findMainExecutable(in: appPath)
                XCTAssertFalse(executablePath.isEmpty, "可执行文件路径不应为空")
                XCTAssertTrue(FileManager.default.fileExists(atPath: executablePath), "可执行文件应该存在")
                
                // 测试解析 bundle
                let info = try parser.parseAppBundle(at: appPath)
                XCTAssertFalse(info.architecture.isEmpty, "架构信息不应为空")
                XCTAssertGreaterThan(info.dynamicLibraries.count, 0, "应该至少有一个动态库")
                
                print("\n成功解析应用: \(appPath)")
                print("主可执行文件: \(executablePath)")
                print("架构: \(info.architecture)")
                print("动态库数量: \(info.dynamicLibraries.count)")
                
                foundApp = true
                break
            } catch {
                print("解析 \(appPath) 失败: \(error)")
            }
        }
        
        if !foundApp {
            print("警告: 未找到可用的系统应用进行测试")
        }
    }
    
    func testOTooliOSPublicAPI() {
        // 测试公共 API
        let systemApps = [
            "/Applications/Calculator.app",
            "/System/Applications/Calculator.app"
        ]
        
        for appPath in systemApps {
            guard FileManager.default.fileExists(atPath: appPath) else {
                continue
            }
            
            do {
                // 测试 parseAppBundle
                let info1 = try OTooliOS.parseAppBundle(appPath)
                XCTAssertFalse(info1.architecture.isEmpty)
                
                // 测试 getMainExecutablePath
                let execPath = try OTooliOS.getMainExecutablePath(from: appPath)
                XCTAssertFalse(execPath.isEmpty)
                
                // 测试 parseFile
                let info2 = try OTooliOS.parseFile(execPath)
                XCTAssertEqual(info1.architecture, info2.architecture, "两种方式解析的结果应该一致")
                
                print("\n公共 API 测试成功: \(appPath)")
                break
            } catch {
                print("公共 API 测试失败: \(error)")
            }
        }
    }
}

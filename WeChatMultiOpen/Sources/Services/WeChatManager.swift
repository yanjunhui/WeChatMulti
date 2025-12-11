//
//  WeChatManager.swift
//  WeChatMultiOpen
//
//  Created by Yanjunhui
//

import Foundation
import AppKit
import Combine

/// 微信管理器
/// 负责管理微信多开的核心功能，包括启动、监控和终止微信实例
///
/// 微信多开原理说明：
/// 微信 Mac 版使用单实例检测机制，直接使用 open -n 无法启动多个实例。
/// 解决方案：为每个实例创建一个独立的应用副本，修改其 Bundle Identifier，
/// 从而让 macOS 将其识别为不同的应用。
final class WeChatManager: ObservableObject {

    // MARK: - 单例

    static let shared = WeChatManager()

    // MARK: - 发布的属性

    /// 当前运行的微信实例列表
    @Published private(set) var instances: [WeChatInstance] = []

    /// 微信是否已安装
    @Published private(set) var isWeChatInstalled: Bool = false

    /// 微信应用路径
    @Published private(set) var wechatPath: String?

    /// 错误信息
    @Published var errorMessage: String?

    /// 是否正在启动新实例
    @Published private(set) var isLaunching: Bool = false

    /// 可用的微信副本列表
    @Published private(set) var availableCopies: [WeChatCopy] = []

    /// 自定义名称映射（Bundle ID -> 自定义名称）
    @Published private(set) var customNames: [String: String] = [:]

    // MARK: - 私有属性

    /// 进程监控器
    private let processMonitor = ProcessMonitor.shared

    /// 自定义名称存储路径
    private var customNamesPath: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("WeChatMultiOpen/customNames.json")
    }

    /// 监控定时器
    private var monitorTimer: Timer?

    /// 状态更新定时器
    private var statusUpdateTimer: Timer?

    /// Combine取消令牌集合
    private var cancellables = Set<AnyCancellable>()

    /// 微信副本存储目录
    private var copiesDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("WeChatMultiOpen/Copies")
    }

    // MARK: - 初始化

    private init() {
        checkWeChatInstallation()
        setupCopiesDirectory()
        loadAvailableCopies()
        loadCustomNames()
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - 公共方法

    /// 启动一个新的微信实例
    /// - Returns: 是否成功启动
    @discardableResult
    func launchNewInstance() -> Bool {
        guard !isLaunching else {
            errorMessage = "正在启动中，请稍候..."
            return false
        }

        guard isWeChatInstalled else {
            errorMessage = "未找到微信应用，请确认微信已安装"
            return false
        }

        isLaunching = true
        errorMessage = nil

        // "新建微信"按钮的逻辑：
        // 始终创建新副本并启动，已有的未运行副本需要用户手动点击启动
        createAndLaunchNewCopy()

        return true
    }

    /// 启动原版微信
    private func launchOriginalWeChat() {
        guard let path = wechatPath else {
            isLaunching = false
            errorMessage = "未找到微信应用"
            return
        }

        let url = URL(fileURLWithPath: path)

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = false  // 如果已运行则激活
        configuration.activates = true
        configuration.hides = false

        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { [weak self] app, error in
            DispatchQueue.main.async {
                self?.isLaunching = false

                if let error = error {
                    self?.errorMessage = "启动失败: \(error.localizedDescription)"
                } else if app != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self?.refreshInstances()
                    }
                }
            }
        }
    }

    /// 启动指定的微信副本
    func launchCopy(_ copy: WeChatCopy) {
        let url = URL(fileURLWithPath: copy.path)

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = false  // 如果已运行则激活
        configuration.activates = true
        configuration.hides = false

        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { [weak self] app, error in
            DispatchQueue.main.async {
                self?.isLaunching = false

                if let error = error {
                    self?.errorMessage = "启动失败: \(error.localizedDescription)"
                } else if app != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self?.refreshInstances()
                    }
                }
            }
        }
    }

    /// 创建新的微信副本
    func createNewCopy(completion: @escaping (Result<WeChatCopy, Error>) -> Void) {
        guard let sourcePath = wechatPath else {
            completion(.failure(WeChatError.wechatNotInstalled))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                let copyNumber = self.getNextCopyNumber()
                let copyName = "WeChat_\(copyNumber).app"
                let copyPath = self.copiesDirectory.appendingPathComponent(copyName)

                // 如果目标已存在，先删除
                if FileManager.default.fileExists(atPath: copyPath.path) {
                    try FileManager.default.removeItem(at: copyPath)
                }

                // 复制微信应用
                try FileManager.default.copyItem(
                    atPath: sourcePath,
                    toPath: copyPath.path
                )

                // 移除隔离属性（解决"无法打开"问题）
                self.removeQuarantineAttribute(at: copyPath.path)

                // 修改 Info.plist 中的 Bundle Identifier
                let infoPlistPath = copyPath.appendingPathComponent("Contents/Info.plist")
                if var plist = NSDictionary(contentsOf: infoPlistPath) as? [String: Any] {
                    let newBundleId = "com.tencent.xinWeChat.copy\(copyNumber)"
                    plist["CFBundleIdentifier"] = newBundleId
                    plist["CFBundleName"] = "微信副本\(copyNumber)"
                    plist["CFBundleDisplayName"] = "微信副本\(copyNumber)"

                    let plistData = try PropertyListSerialization.data(
                        fromPropertyList: plist,
                        format: .xml,
                        options: 0
                    )
                    try plistData.write(to: infoPlistPath)
                }

                // 重新签名（使用 ad-hoc 签名）
                let signTask = Process()
                signTask.launchPath = "/usr/bin/codesign"
                signTask.arguments = [
                    "--force",
                    "--deep",
                    "--sign", "-",
                    copyPath.path
                ]
                signTask.standardOutput = FileHandle.nullDevice
                signTask.standardError = FileHandle.nullDevice
                try signTask.run()
                signTask.waitUntilExit()

                // 清除 Launch Services 缓存，让系统识别新应用
                self.resetLaunchServices()

                let copy = WeChatCopy(
                    id: copyNumber,
                    name: "微信副本\(copyNumber)",
                    path: copyPath.path,
                    bundleIdentifier: "com.tencent.xinWeChat.copy\(copyNumber)",
                    createdAt: Date()
                )

                DispatchQueue.main.async {
                    self.availableCopies.append(copy)
                    self.saveCopiesMetadata()
                    completion(.success(copy))
                }

            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// 移除文件的隔离属性
    private func removeQuarantineAttribute(at path: String) {
        let task = Process()
        task.launchPath = "/usr/bin/xattr"
        task.arguments = ["-rd", "com.apple.quarantine", path]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
    }

    /// 重置 Launch Services 数据库
    private func resetLaunchServices() {
        let task = Process()
        task.launchPath = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        task.arguments = ["-kill", "-r", "-domain", "local", "-domain", "system", "-domain", "user"]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
    }

    /// 删除微信副本
    func deleteCopy(_ copy: WeChatCopy) {
        do {
            try FileManager.default.removeItem(atPath: copy.path)
            availableCopies.removeAll { $0.id == copy.id }
            saveCopiesMetadata()
        } catch {
            errorMessage = "删除副本失败: \(error.localizedDescription)"
        }
    }

    /// 终止指定的微信实例
    @discardableResult
    func terminateInstance(_ instance: WeChatInstance) -> Bool {
        guard let pid = instance.processId else {
            return false
        }

        if let app = processMonitor.getRunningApplication(pid: pid) {
            let terminated = app.terminate()
            if terminated {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.refreshInstances()
                }
                return true
            }
        }

        let result = processMonitor.terminateProcess(pid: pid)

        if result {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.refreshInstances()
            }
        }

        return result
    }

    /// 启动指定的实例
    /// - Parameter instance: 要启动的实例
    func launchInstance(_ instance: WeChatInstance) {
        guard !instance.isRunning else { return }

        isLaunching = true
        errorMessage = nil

        if instance.isOriginal {
            // 启动原版微信
            launchOriginalWeChat()
        } else if let copyPath = instance.copyPath {
            // 启动副本
            let copy = WeChatCopy(
                id: instance.instanceNumber,
                name: instance.displayName,
                path: copyPath,
                bundleIdentifier: instance.bundleIdentifier,
                createdAt: Date()
            )
            launchCopy(copy)
        } else {
            isLaunching = false
            errorMessage = "无法启动：找不到应用路径"
        }
    }

    /// 终止所有微信实例
    func terminateAllInstances() {
        for instance in instances {
            terminateInstance(instance)
        }
    }

    /// 刷新实例列表
    /// 合并运行中的进程、原版微信和已创建的副本
    func refreshInstances() {
        let pids = processMonitor.getRunningWeChatProcessIds()

        // 获取运行中进程的 Bundle ID 集合
        var runningBundleIds: [String: pid_t] = [:]
        for pid in pids {
            if let bundleId = getBundleIdentifier(for: pid) {
                runningBundleIds[bundleId] = pid
            }
        }

        var updatedInstances: [WeChatInstance] = []

        // 1. 添加运行中的进程
        for pid in pids {
            let bundleId = getBundleIdentifier(for: pid) ?? "com.tencent.xinWeChat"
            let instanceNumber = getInstanceNumber(for: bundleId)
            let launchTime = processMonitor.getProcessLaunchTime(pid: pid) ?? Date()

            // 查找对应的副本路径
            let copyPath = availableCopies.first { $0.bundleIdentifier == bundleId }?.path

            var instance = WeChatInstance(
                processId: pid,
                launchTime: launchTime,
                bundleIdentifier: bundleId,
                instanceNumber: instanceNumber
            )
            instance.copyPath = copyPath
            instance.cpuUsage = processMonitor.getProcessCPUUsage(pid: pid)
            instance.memoryUsage = processMonitor.getProcessMemoryUsage(pid: pid)
            instance.customName = customNames[bundleId]

            updatedInstances.append(instance)
        }

        // 2. 添加原版微信（如果未运行且已安装）
        let originalBundleId = "com.tencent.xinWeChat"
        if runningBundleIds[originalBundleId] == nil && isWeChatInstalled, let originalPath = wechatPath {
            var instance = WeChatInstance(
                bundleIdentifier: originalBundleId,
                copyPath: originalPath,
                instanceNumber: 0
            )
            instance.customName = customNames[originalBundleId]
            updatedInstances.append(instance)
        }

        // 3. 添加未运行的副本
        for copy in availableCopies {
            // 如果这个副本没有在运行
            if runningBundleIds[copy.bundleIdentifier] == nil {
                let instanceNumber = getInstanceNumber(for: copy.bundleIdentifier)
                var instance = WeChatInstance(
                    bundleIdentifier: copy.bundleIdentifier,
                    copyPath: copy.path,
                    instanceNumber: instanceNumber
                )
                instance.customName = customNames[copy.bundleIdentifier]
                updatedInstances.append(instance)
            }
        }

        // 4. 保留"创建中"的占位实例（如果对应的副本还没有出现在列表中）
        for existingInstance in instances where existingInstance.isCreating {
            // 检查是否已经有对应编号的真实实例（运行中或未运行的副本）
            let hasRealInstance = updatedInstances.contains { instance in
                instance.instanceNumber == existingInstance.instanceNumber && !instance.isCreating
            }
            if !hasRealInstance {
                updatedInstances.append(existingInstance)
            }
        }

        // 按照 Bundle ID 的副本编号排序（原版排第一，然后按副本编号升序）
        updatedInstances.sort { lhs, rhs in
            let lhsOrder = getSortOrder(for: lhs.bundleIdentifier)
            let rhsOrder = getSortOrder(for: rhs.bundleIdentifier)
            return lhsOrder < rhsOrder
        }

        instances = updatedInstances
    }

    /// 根据 Bundle ID 获取排序顺序
    private func getSortOrder(for bundleId: String) -> Int {
        if bundleId == "com.tencent.xinWeChat" {
            return 0  // 原版排第一
        } else if bundleId.hasPrefix("com.tencent.xinWeChat.copy") {
            let suffix = bundleId.replacingOccurrences(of: "com.tencent.xinWeChat.copy", with: "")
            return Int(suffix) ?? 999
        }
        return 999
    }

    /// 根据进程ID获取 Bundle Identifier
    private func getBundleIdentifier(for pid: pid_t) -> String? {
        if let app = NSRunningApplication(processIdentifier: pid) {
            return app.bundleIdentifier
        }
        return nil
    }

    /// 更新实例的运行状态信息
    func updateInstancesStatus() {
        var updatedInstances: [WeChatInstance] = []

        for var instance in instances {
            if let pid = instance.processId, instance.isRunning {
                instance.isRunning = processMonitor.isProcessRunning(pid: pid)
                instance.cpuUsage = processMonitor.getProcessCPUUsage(pid: pid)
                instance.memoryUsage = processMonitor.getProcessMemoryUsage(pid: pid)
            }
            updatedInstances.append(instance)
        }

        instances = updatedInstances
    }

    /// 激活指定的微信实例窗口
    /// 使用 NSWorkspace.openApplication API，当应用已运行时会自动激活到前台
    func activateInstance(_ instance: WeChatInstance) {
        print("🔍 [开始激活] \(instance.displayName)")

        // 确定应用路径
        let appPath: String
        if instance.isOriginal {
            // 原版微信
            guard let path = wechatPath else {
                print("⚠️ [激活失败] 未找到微信应用路径")
                return
            }
            appPath = path
        } else {
            // 副本
            guard let copyPath = instance.copyPath else {
                print("⚠️ [激活失败] 未找到副本路径")
                return
            }
            appPath = copyPath
        }

        let appURL = URL(fileURLWithPath: appPath)

        // 配置：不创建新实例，激活已有实例
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = false  // 关键设置！
        configuration.activates = true                        // 激活到前台
        configuration.hides = false                           // 不隐藏

        print("  → 使用 NSWorkspace.openApplication 激活...")

        // 使用官方 API 打开/激活应用
        // 如果应用已运行 → 激活到前台
        // 如果应用未运行 → 启动应用
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { app, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("⚠️ [激活失败] \(error.localizedDescription)")
                } else if app != nil {
                    print("✓ [激活完成] 「\(instance.displayName)」窗口已置顶")
                }
            }
        }
    }

    // MARK: - 私有方法

    /// 检查微信安装状态
    private func checkWeChatInstallation() {
        wechatPath = processMonitor.getWeChatAppPath()
        isWeChatInstalled = wechatPath != nil
    }

    /// 设置副本存储目录
    private func setupCopiesDirectory() {
        do {
            try FileManager.default.createDirectory(
                at: copiesDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            print("创建副本目录失败: \(error)")
        }
    }

    /// 加载可用的微信副本列表
    private func loadAvailableCopies() {
        let metadataPath = copiesDirectory.appendingPathComponent("metadata.json")

        guard FileManager.default.fileExists(atPath: metadataPath.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: metadataPath)
            let copies = try JSONDecoder().decode([WeChatCopy].self, from: data)

            // 验证副本是否存在
            availableCopies = copies.filter { copy in
                FileManager.default.fileExists(atPath: copy.path)
            }
        } catch {
            print("加载副本元数据失败: \(error)")
        }
    }

    /// 保存副本元数据
    private func saveCopiesMetadata() {
        let metadataPath = copiesDirectory.appendingPathComponent("metadata.json")

        do {
            let data = try JSONEncoder().encode(availableCopies)
            try data.write(to: metadataPath)
        } catch {
            print("保存副本元数据失败: \(error)")
        }
    }

    /// 加载自定义名称
    private func loadCustomNames() {
        guard FileManager.default.fileExists(atPath: customNamesPath.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: customNamesPath)
            customNames = try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            print("加载自定义名称失败: \(error)")
        }
    }

    /// 保存自定义名称
    private func saveCustomNames() {
        do {
            let data = try JSONEncoder().encode(customNames)
            try data.write(to: customNamesPath)
        } catch {
            print("保存自定义名称失败: \(error)")
        }
    }

    /// 设置实例的自定义名称
    /// - Parameters:
    ///   - bundleId: Bundle Identifier
    ///   - name: 自定义名称（传空字符串或nil则恢复默认）
    func setCustomName(for bundleId: String, name: String?) {
        if let name = name, !name.isEmpty {
            customNames[bundleId] = name
        } else {
            customNames.removeValue(forKey: bundleId)
        }
        saveCustomNames()
        refreshInstances()
    }

    /// 查找可用的微信副本（未运行的）
    private func findAvailableCopy() -> WeChatCopy? {
        let runningBundleIds = Set(
            NSWorkspace.shared.runningApplications
                .compactMap { $0.bundleIdentifier }
                .filter { $0.hasPrefix("com.tencent.xinWeChat") }
        )

        return availableCopies.first { copy in
            !runningBundleIds.contains(copy.bundleIdentifier)
        }
    }

    /// 创建并启动新的微信副本
    private func createAndLaunchNewCopy() {
        // 获取下一个副本编号
        let nextNumber = getNextCopyNumber()

        // 先在 UI 上创建一个"创建中"的占位实例
        let creatingInstance = WeChatInstance(creatingInstanceNumber: nextNumber)
        DispatchQueue.main.async {
            self.instances.append(creatingInstance)
        }

        createNewCopy { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let copy):
                // 启动副本，占位实例会在 refreshInstances 检测到真实实例后自动移除
                self.launchCopy(copy)
            case .failure(let error):
                // 创建失败时移除占位实例
                DispatchQueue.main.async {
                    self.instances.removeAll { $0.isCreating && $0.instanceNumber == nextNumber }
                    self.isLaunching = false
                    self.errorMessage = "创建副本失败: \(error.localizedDescription)"
                }
            }
        }
    }

    /// 获取下一个副本编号
    private func getNextCopyNumber() -> Int {
        let existingNumbers = availableCopies.map { $0.id }
        var nextNumber = 1  // 从1开始
        while existingNumbers.contains(nextNumber) {
            nextNumber += 1
        }
        return nextNumber
    }

    /// 开始监控
    private func startMonitoring() {
        refreshInstances()

        monitorTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.refreshInstances()
        }

        statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateInstancesStatus()
        }

        setupWorkspaceNotifications()
    }

    /// 停止监控
    private func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil

        statusUpdateTimer?.invalidate()
        statusUpdateTimer = nil

        cancellables.removeAll()
    }

    /// 设置工作空间通知监听
    private func setupWorkspaceNotifications() {
        let notificationCenter = NSWorkspace.shared.notificationCenter

        notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)
            .sink { [weak self] notification in
                if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                   let bundleId = app.bundleIdentifier,
                   bundleId.hasPrefix("com.tencent.xinWeChat") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.refreshInstances()
                    }
                }
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)
            .sink { [weak self] notification in
                if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                   let bundleId = app.bundleIdentifier,
                   bundleId.hasPrefix("com.tencent.xinWeChat") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.refreshInstances()
                    }
                }
            }
            .store(in: &cancellables)
    }

    /// 根据 Bundle ID 获取实例序号
    private func getInstanceNumber(for bundleId: String) -> Int {
        // 原版微信返回 0
        if bundleId == "com.tencent.xinWeChat" {
            return 0
        }
        // 副本微信返回副本编号
        if bundleId.hasPrefix("com.tencent.xinWeChat.copy") {
            let suffix = bundleId.replacingOccurrences(of: "com.tencent.xinWeChat.copy", with: "")
            return Int(suffix) ?? 999
        }
        return 999
    }

    // MARK: - 版本管理

    /// 获取原版微信版本号
    func getOriginalWeChatVersion() -> String? {
        guard let path = wechatPath else { return nil }
        let infoPlistPath = URL(fileURLWithPath: path).appendingPathComponent("Contents/Info.plist")
        guard let plist = NSDictionary(contentsOf: infoPlistPath) as? [String: Any] else { return nil }
        return plist["CFBundleShortVersionString"] as? String
    }

    /// 获取克隆体版本号
    func getCopyVersion(_ copy: WeChatCopy) -> String? {
        let infoPlistPath = URL(fileURLWithPath: copy.path).appendingPathComponent("Contents/Info.plist")
        guard let plist = NSDictionary(contentsOf: infoPlistPath) as? [String: Any] else { return nil }
        return plist["CFBundleShortVersionString"] as? String
    }

    /// 检查是否有克隆体需要升级
    /// - Returns: 需要升级的克隆体列表
    func getOutdatedCopies() -> [WeChatCopy] {
        guard let originalVersion = getOriginalWeChatVersion() else { return [] }

        return availableCopies.filter { copy in
            guard let copyVersion = getCopyVersion(copy) else { return true }
            return copyVersion != originalVersion
        }
    }

    /// 检查是否有克隆体需要升级
    var hasOutdatedCopies: Bool {
        return !getOutdatedCopies().isEmpty
    }

    /// 升级单个克隆体
    /// - Parameters:
    ///   - copy: 要升级的克隆体
    ///   - completion: 完成回调
    func upgradeCopy(_ copy: WeChatCopy, completion: @escaping (Bool, String?) -> Void) {
        guard let sourcePath = wechatPath else {
            completion(false, "未找到原版微信")
            return
        }

        // 检查该克隆体是否正在运行
        let isRunning = instances.contains { $0.bundleIdentifier == copy.bundleIdentifier && $0.isRunning }
        if isRunning {
            completion(false, "请先终止该克隆体后再升级")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                let copyPath = URL(fileURLWithPath: copy.path)

                // 1. 备份原有的 Bundle ID 信息
                let bundleIdentifier = copy.bundleIdentifier
                let copyNumber = copy.id

                // 2. 删除旧的克隆体应用
                if FileManager.default.fileExists(atPath: copy.path) {
                    try FileManager.default.removeItem(atPath: copy.path)
                }

                // 3. 复制新版微信
                try FileManager.default.copyItem(
                    atPath: sourcePath,
                    toPath: copyPath.path
                )

                // 4. 移除隔离属性
                self.removeQuarantineAttribute(at: copyPath.path)

                // 5. 修改 Info.plist，恢复原有的 Bundle ID
                let infoPlistPath = copyPath.appendingPathComponent("Contents/Info.plist")
                if var plist = NSDictionary(contentsOf: infoPlistPath) as? [String: Any] {
                    plist["CFBundleIdentifier"] = bundleIdentifier
                    plist["CFBundleName"] = "微信副本\(copyNumber)"
                    plist["CFBundleDisplayName"] = "微信副本\(copyNumber)"

                    let plistData = try PropertyListSerialization.data(
                        fromPropertyList: plist,
                        format: .xml,
                        options: 0
                    )
                    try plistData.write(to: infoPlistPath)
                }

                // 6. 重新签名（使用 ad-hoc 签名）
                let signTask = Process()
                signTask.launchPath = "/usr/bin/codesign"
                signTask.arguments = [
                    "--force",
                    "--deep",
                    "--sign", "-",
                    copyPath.path
                ]
                signTask.standardOutput = FileHandle.nullDevice
                signTask.standardError = FileHandle.nullDevice
                try signTask.run()
                signTask.waitUntilExit()

                // 7. 刷新 Launch Services
                self.resetLaunchServices()

                DispatchQueue.main.async {
                    completion(true, nil)
                }

            } catch {
                DispatchQueue.main.async {
                    completion(false, "升级失败: \(error.localizedDescription)")
                }
            }
        }
    }

    /// 升级所有过期的克隆体
    /// - Parameter completion: 完成回调，返回成功数量和失败信息
    func upgradeAllOutdatedCopies(completion: @escaping (Int, Int, String?) -> Void) {
        let outdatedCopies = getOutdatedCopies()

        if outdatedCopies.isEmpty {
            completion(0, 0, nil)
            return
        }

        // 检查是否有运行中的克隆体
        let runningOutdated = outdatedCopies.filter { copy in
            instances.contains { $0.bundleIdentifier == copy.bundleIdentifier && $0.isRunning }
        }

        if !runningOutdated.isEmpty {
            let names = runningOutdated.map { customNames[$0.bundleIdentifier] ?? $0.name }.joined(separator: ", ")
            completion(0, outdatedCopies.count, "请先终止以下运行中的克隆体: \(names)")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var successCount = 0
            var failCount = 0
            var errorMessages: [String] = []

            let group = DispatchGroup()

            for copy in outdatedCopies {
                group.enter()

                self.upgradeCopy(copy) { success, error in
                    if success {
                        successCount += 1
                    } else {
                        failCount += 1
                        if let error = error {
                            errorMessages.append("\(copy.name): \(error)")
                        }
                    }
                    group.leave()
                }

                // 等待当前升级完成再进行下一个，避免并发问题
                group.wait()
            }

            DispatchQueue.main.async {
                self.refreshInstances()
                let errorMessage = errorMessages.isEmpty ? nil : errorMessages.joined(separator: "\n")
                completion(successCount, failCount, errorMessage)
            }
        }
    }

    // MARK: - 存储空间管理

    /// 存储空间统计结果
    struct StorageStats {
        /// 克隆体应用占用空间
        var copiesSize: Int64 = 0
        /// Container 数据占用空间
        var containerSize: Int64 = 0
        /// 总占用空间
        var totalSize: Int64 { copiesSize + containerSize }

        /// 格式化的克隆体应用大小
        var formattedCopiesSize: String {
            ByteCountFormatter.string(fromByteCount: copiesSize, countStyle: .file)
        }

        /// 格式化的 Container 数据大小
        var formattedContainerSize: String {
            ByteCountFormatter.string(fromByteCount: containerSize, countStyle: .file)
        }

        /// 格式化的总大小
        var formattedTotalSize: String {
            ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        }
    }

    /// 计算所有克隆体占用的存储空间
    /// - Returns: 存储空间统计
    func calculateStorageStats() -> StorageStats {
        var stats = StorageStats()

        // 1. 计算副本应用目录大小
        stats.copiesSize = calculateDirectorySize(at: copiesDirectory)

        // 2. 计算所有副本的 Container 数据大小
        let containersPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers")

        for copy in availableCopies {
            let containerPath = containersPath.appendingPathComponent(copy.bundleIdentifier)
            if FileManager.default.fileExists(atPath: containerPath.path) {
                stats.containerSize += calculateDirectorySize(at: containerPath)
            }
        }

        return stats
    }

    /// 异步计算存储空间统计
    /// - Parameter completion: 完成回调
    func calculateStorageStatsAsync(completion: @escaping (StorageStats) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let stats = self.calculateStorageStats()
            DispatchQueue.main.async {
                completion(stats)
            }
        }
    }

    /// 计算目录大小
    /// - Parameter url: 目录路径
    /// - Returns: 目录大小（字节）
    private func calculateDirectorySize(at url: URL) -> Int64 {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return 0
        }

        var totalSize: Int64 = 0

        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles],
            errorHandler: nil
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                if resourceValues.isDirectory == false {
                    totalSize += Int64(resourceValues.fileSize ?? 0)
                }
            } catch {
                // 忽略无法访问的文件
            }
        }

        return totalSize
    }

    /// 清空所有克隆体数据
    /// - Parameter completion: 完成回调，返回是否成功
    func clearAllCloneData(completion: @escaping (Bool, String?) -> Void) {
        // 检查是否有运行中的克隆体
        let runningClones = instances.filter { $0.isRunning && !$0.isOriginal }
        if !runningClones.isEmpty {
            completion(false, "请先终止所有运行中的微信克隆体")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var hasError = false
            var errorMessages: [String] = []

            // 1. 删除所有副本的 Container 数据
            let containersPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Containers")

            for copy in self.availableCopies {
                let containerPath = containersPath.appendingPathComponent(copy.bundleIdentifier)
                if FileManager.default.fileExists(atPath: containerPath.path) {
                    do {
                        try FileManager.default.removeItem(at: containerPath)
                    } catch {
                        hasError = true
                        errorMessages.append("删除 \(copy.name) 数据失败: \(error.localizedDescription)")
                    }
                }
            }

            // 2. 删除副本应用目录中的所有副本
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: self.copiesDirectory,
                    includingPropertiesForKeys: nil
                )
                for item in contents {
                    // 保留 metadata.json 文件，但删除所有 .app 目录
                    if item.pathExtension == "app" {
                        try FileManager.default.removeItem(at: item)
                    }
                }
            } catch {
                hasError = true
                errorMessages.append("删除副本应用失败: \(error.localizedDescription)")
            }

            // 3. 清空副本列表和自定义名称
            DispatchQueue.main.async {
                self.availableCopies.removeAll()
                self.saveCopiesMetadata()

                // 只清除副本的自定义名称，保留原版微信的
                let originalName = self.customNames["com.tencent.xinWeChat"]
                self.customNames.removeAll()
                if let name = originalName {
                    self.customNames["com.tencent.xinWeChat"] = name
                }
                self.saveCustomNames()

                // 刷新实例列表
                self.refreshInstances()

                if hasError {
                    completion(false, errorMessages.joined(separator: "\n"))
                } else {
                    completion(true, nil)
                }
            }
        }
    }
}

// MARK: - 微信副本模型

struct WeChatCopy: Identifiable, Codable {
    let id: Int
    let name: String
    let path: String
    let bundleIdentifier: String
    let createdAt: Date
}

// MARK: - 错误类型

enum WeChatError: LocalizedError {
    case wechatNotInstalled
    case copyFailed
    case launchFailed

    var errorDescription: String? {
        switch self {
        case .wechatNotInstalled:
            return "微信未安装"
        case .copyFailed:
            return "创建微信副本失败"
        case .launchFailed:
            return "启动微信失败"
        }
    }
}

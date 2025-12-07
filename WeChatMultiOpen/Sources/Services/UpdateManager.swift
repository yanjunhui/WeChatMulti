//
//  UpdateManager.swift
//  WeChatMultiOpen
//
//  Created by Yanjunhui
//

import Foundation
import AppKit
import Combine

/// GitHub Release 信息模型
struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let body: String
    let htmlUrl: String
    let publishedAt: String
    let draft: Bool
    let prerelease: Bool
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
        case draft
        case prerelease
        case assets
    }
}

/// GitHub Release 资源文件模型
struct GitHubAsset: Codable {
    let name: String
    let size: Int
    let downloadCount: Int
    let browserDownloadUrl: String

    enum CodingKeys: String, CodingKey {
        case name
        case size
        case downloadCount = "download_count"
        case browserDownloadUrl = "browser_download_url"
    }
}

/// 更新信息模型
struct UpdateInfo {
    let version: String
    let releaseNotes: String
    let downloadUrl: String
    let publishDate: Date
    let assetUrl: String?
    let assetName: String?
    let assetSize: Int?
}

/// 更新检查结果
enum UpdateCheckResult {
    case available(UpdateInfo)
    case upToDate
    case error(Error)
}

/// 更新检查错误类型
enum UpdateError: LocalizedError {
    case networkError(Error)
    case invalidResponse
    case parseError
    case noReleaseFound
    case invalidVersion

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .invalidResponse:
            return "服务器响应无效"
        case .parseError:
            return "解析数据失败"
        case .noReleaseFound:
            return "未找到发布版本"
        case .invalidVersion:
            return "版本号格式无效"
        }
    }
}

/// 更新管理器
/// 负责检查 GitHub Releases 获取应用更新
final class UpdateManager: ObservableObject {

    // MARK: - 单例

    static let shared = UpdateManager()

    // MARK: - 配置

    /// GitHub 仓库拥有者
    private let repoOwner: String = "yanjunhui"

    /// GitHub 仓库名称
    private let repoName: String = "WeChatMulti"

    /// GitHub API 基础 URL
    private let githubAPIBase = "https://api.github.com"

    // MARK: - 发布的属性

    /// 是否正在检查更新
    @Published private(set) var isChecking: Bool = false

    /// 最新的更新信息（如果有可用更新）
    @Published private(set) var availableUpdate: UpdateInfo?

    /// 错误信息
    @Published var errorMessage: String?

    /// 上次检查时间
    @Published private(set) var lastCheckTime: Date?

    /// 是否有可用更新
    var hasUpdate: Bool {
        return availableUpdate != nil
    }

    // MARK: - 私有属性

    /// 当前应用版本
    private var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    /// UserDefaults 键
    private let lastCheckTimeKey = "UpdateManager.lastCheckTime"
    private let ignoredVersionKey = "UpdateManager.ignoredVersion"
    private let repoOwnerKey = "UpdateManager.repoOwner"
    private let repoNameKey = "UpdateManager.repoName"

    /// 被忽略的版本
    private var ignoredVersion: String? {
        get { UserDefaults.standard.string(forKey: ignoredVersionKey) }
        set { UserDefaults.standard.set(newValue, forKey: ignoredVersionKey) }
    }

    // MARK: - 初始化

    private init() {
        // 从 UserDefaults 恢复上次检查时间
        if let timeInterval = UserDefaults.standard.object(forKey: lastCheckTimeKey) as? TimeInterval {
            lastCheckTime = Date(timeIntervalSince1970: timeInterval)
        }
    }

    // MARK: - 公开方法

    /// 配置 GitHub 仓库信息
    /// - Parameters:
    ///   - owner: 仓库拥有者用户名
    ///   - repo: 仓库名称
    func configure(owner: String, repo: String) {
        UserDefaults.standard.set(owner, forKey: repoOwnerKey)
        UserDefaults.standard.set(repo, forKey: repoNameKey)
    }

    /// 获取配置的仓库拥有者
    func getRepoOwner() -> String {
        return UserDefaults.standard.string(forKey: repoOwnerKey) ?? repoOwner
    }

    /// 获取配置的仓库名称
    func getRepoName() -> String {
        return UserDefaults.standard.string(forKey: repoNameKey) ?? repoName
    }

    /// 检查更新
    /// - Parameter includePrerelease: 是否包含预发布版本
    /// - Returns: 更新检查结果
    @MainActor
    func checkForUpdates(includePrerelease: Bool = false) async -> UpdateCheckResult {
        guard !isChecking else {
            return .upToDate
        }

        isChecking = true
        errorMessage = nil

        defer {
            isChecking = false
            lastCheckTime = Date()
            UserDefaults.standard.set(lastCheckTime?.timeIntervalSince1970, forKey: lastCheckTimeKey)
        }

        do {
            let release = try await fetchLatestRelease(includePrerelease: includePrerelease)

            // 解析版本号（移除 v 前缀）
            let remoteVersion = release.tagName.hasPrefix("v")
                ? String(release.tagName.dropFirst())
                : release.tagName

            // 比较版本
            if isNewerVersion(remoteVersion, than: currentVersion) {
                // 检查是否被用户忽略
                if ignoredVersion == remoteVersion {
                    return .upToDate
                }

                // 解析发布日期
                let dateFormatter = ISO8601DateFormatter()
                let publishDate = dateFormatter.date(from: release.publishedAt) ?? Date()

                // 查找 DMG 或 ZIP 资源
                let asset = release.assets.first { asset in
                    let name = asset.name.lowercased()
                    return name.hasSuffix(".dmg") || name.hasSuffix(".zip")
                }

                let updateInfo = UpdateInfo(
                    version: remoteVersion,
                    releaseNotes: release.body,
                    downloadUrl: release.htmlUrl,
                    publishDate: publishDate,
                    assetUrl: asset?.browserDownloadUrl,
                    assetName: asset?.name,
                    assetSize: asset?.size
                )

                availableUpdate = updateInfo
                return .available(updateInfo)
            } else {
                availableUpdate = nil
                return .upToDate
            }
        } catch {
            errorMessage = error.localizedDescription
            return .error(error)
        }
    }

    /// 静默检查更新（不更新 UI 状态，用于后台检查）
    /// - Parameter includePrerelease: 是否包含预发布版本
    /// - Returns: 更新信息（如果有可用更新）
    func checkForUpdatesSilently(includePrerelease: Bool = false) async -> UpdateInfo? {
        do {
            let release = try await fetchLatestRelease(includePrerelease: includePrerelease)

            let remoteVersion = release.tagName.hasPrefix("v")
                ? String(release.tagName.dropFirst())
                : release.tagName

            if isNewerVersion(remoteVersion, than: currentVersion) {
                if ignoredVersion == remoteVersion {
                    return nil
                }

                let dateFormatter = ISO8601DateFormatter()
                let publishDate = dateFormatter.date(from: release.publishedAt) ?? Date()

                let asset = release.assets.first { asset in
                    let name = asset.name.lowercased()
                    return name.hasSuffix(".dmg") || name.hasSuffix(".zip")
                }

                return UpdateInfo(
                    version: remoteVersion,
                    releaseNotes: release.body,
                    downloadUrl: release.htmlUrl,
                    publishDate: publishDate,
                    assetUrl: asset?.browserDownloadUrl,
                    assetName: asset?.name,
                    assetSize: asset?.size
                )
            }
        } catch {
            // 静默模式下忽略错误
        }

        return nil
    }

    /// 打开下载页面
    func openDownloadPage() {
        guard let update = availableUpdate,
              let url = URL(string: update.downloadUrl) else {
            // 如果没有更新信息，打开仓库 releases 页面
            let owner = getRepoOwner()
            let repo = getRepoName()
            if let url = URL(string: "https://github.com/\(owner)/\(repo)/releases") {
                NSWorkspace.shared.open(url)
            }
            return
        }
        NSWorkspace.shared.open(url)
    }

    /// 直接下载更新文件（在浏览器中打开）
    func downloadUpdateInBrowser() {
        guard let update = availableUpdate,
              let assetUrl = update.assetUrl,
              let url = URL(string: assetUrl) else {
            openDownloadPage()
            return
        }
        NSWorkspace.shared.open(url)
    }

    // MARK: - 下载更新

    /// 下载进度（0.0 - 1.0）
    @Published private(set) var downloadProgress: Double = 0

    /// 是否正在下载
    @Published private(set) var isDownloading: Bool = false

    /// 下载错误信息
    @Published var downloadError: String?

    /// 当前下载任务
    private var downloadTask: URLSessionDownloadTask?

    /// 下载代理
    private var downloadDelegate: DownloadDelegate?

    /// 下载更新文件到本地并自动打开
    @MainActor
    func downloadAndInstallUpdate() async {
        guard let update = availableUpdate,
              let assetUrl = update.assetUrl,
              let url = URL(string: assetUrl) else {
            openDownloadPage()
            return
        }

        // 重置状态
        isDownloading = true
        downloadProgress = 0
        downloadError = nil

        do {
            // 创建下载目录
            let downloadDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            let fileName = update.assetName ?? "WeChatMultiOpen-\(update.version).dmg"
            let destinationUrl = downloadDir.appendingPathComponent(fileName)

            // 如果文件已存在，先删除
            if FileManager.default.fileExists(atPath: destinationUrl.path) {
                try FileManager.default.removeItem(at: destinationUrl)
            }

            // 下载文件
            let localUrl = try await downloadFile(from: url, to: destinationUrl)

            isDownloading = false
            downloadProgress = 1.0

            // 下载完成，打开文件
            await openDownloadedFile(at: localUrl)

        } catch {
            isDownloading = false
            downloadError = "下载失败: \(error.localizedDescription)"
        }
    }

    /// 下载文件
    private func downloadFile(from url: URL, to destinationUrl: URL) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = DownloadDelegate(
                destinationUrl: destinationUrl,
                onProgress: { [weak self] progress in
                    Task { @MainActor in
                        self?.downloadProgress = progress
                    }
                },
                onComplete: { result in
                    continuation.resume(with: result)
                }
            )

            self.downloadDelegate = delegate

            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            let task = session.downloadTask(with: url)
            self.downloadTask = task
            task.resume()
        }
    }

    /// 取消下载
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        downloadProgress = 0
    }

    /// 更新已准备就绪，等待重启
    @Published private(set) var updateReady: Bool = false

    /// 处理下载的文件并自动安装
    @MainActor
    private func openDownloadedFile(at url: URL) async {
        let fileName = url.lastPathComponent.lowercased()

        if fileName.hasSuffix(".dmg") {
            // 挂载 DMG 并提取 .app
            await installFromDMG(at: url)
        } else if fileName.hasSuffix(".zip") {
            // 解压 ZIP 并安装
            await installFromZIP(at: url)
        } else {
            // 其他文件类型，在 Finder 中显示
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    /// 从 DMG 安装
    @MainActor
    private func installFromDMG(at dmgUrl: URL) async {
        do {
            // 挂载 DMG
            let mountPoint = try await mountDMG(at: dmgUrl)

            defer {
                // 卸载 DMG
                unmountDMG(at: mountPoint)
            }

            // 查找 .app 文件
            let contents = try FileManager.default.contentsOfDirectory(at: mountPoint, includingPropertiesForKeys: nil)
            guard let appUrl = contents.first(where: { $0.pathExtension == "app" }) else {
                downloadError = "DMG 中未找到应用程序"
                return
            }

            // 执行安装
            try await performInstallation(from: appUrl)

        } catch {
            downloadError = "安装失败: \(error.localizedDescription)"
        }
    }

    /// 从 ZIP 安装
    @MainActor
    private func installFromZIP(at zipUrl: URL) async {
        do {
            // 创建临时解压目录
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            defer {
                // 清理临时目录
                try? FileManager.default.removeItem(at: tempDir)
            }

            // 解压 ZIP
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-o", zipUrl.path, "-d", tempDir.path]
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                downloadError = "解压失败"
                return
            }

            // 查找 .app 文件
            let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            guard let appUrl = contents.first(where: { $0.pathExtension == "app" }) else {
                downloadError = "ZIP 中未找到应用程序"
                return
            }

            // 执行安装
            try await performInstallation(from: appUrl)

        } catch {
            downloadError = "安装失败: \(error.localizedDescription)"
        }
    }

    /// 挂载 DMG
    private func mountDMG(at url: URL) async throws -> URL {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["attach", url.path, "-nobrowse", "-readonly", "-plist"]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw UpdateError.invalidResponse
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]],
              let mountPoint = entities.first(where: { $0["mount-point"] != nil })?["mount-point"] as? String else {
            throw UpdateError.invalidResponse
        }

        return URL(fileURLWithPath: mountPoint)
    }

    /// 卸载 DMG
    private func unmountDMG(at mountPoint: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["detach", mountPoint.path, "-quiet"]
        try? process.run()
        process.waitUntilExit()
    }

    /// 下载的新版本应用路径（用于手动安装回退）
    private var downloadedAppUrl: URL?

    /// 执行安装（复制到应用程序目录）
    @MainActor
    private func performInstallation(from newAppUrl: URL) async throws {
        let fileManager = FileManager.default

        // 获取当前应用路径
        guard let currentAppUrl = Bundle.main.bundleURL as URL? else {
            throw UpdateError.invalidResponse
        }

        let appName = currentAppUrl.lastPathComponent
        let applicationsDir = URL(fileURLWithPath: "/Applications")
        let targetUrl = applicationsDir.appendingPathComponent(appName)

        // 检查当前应用是否在 /Applications 目录
        let isInApplications = currentAppUrl.path.hasPrefix("/Applications")

        // 如果不在 Applications 目录，直接替换当前位置
        let installUrl = isInApplications ? targetUrl : currentAppUrl

        // 检查是否需要管理员权限
        let needsAdminRights = !fileManager.isWritableFile(atPath: installUrl.deletingLastPathComponent().path)

        if needsAdminRights {
            // 需要管理员权限，尝试获取授权
            let authorized = await requestAdminAuthorization(for: installUrl)

            if !authorized {
                // 授权失败，保存新版本路径用于手动安装
                let manualInstallUrl = try saveForManualInstall(from: newAppUrl, appName: appName)
                downloadedAppUrl = manualInstallUrl

                // 显示手动安装提示
                showManualInstallPrompt(newAppUrl: manualInstallUrl, targetUrl: installUrl)
                return
            }
        }

        // 创建备份路径
        let backupUrl = currentAppUrl.deletingLastPathComponent().appendingPathComponent("\(appName).backup")

        // 创建更新脚本
        let scriptPath = fileManager.temporaryDirectory.appendingPathComponent("update_app.sh")
        let script: String

        if needsAdminRights {
            // 需要管理员权限的脚本（使用 osascript 提权）
            script = createAdminUpdateScript(
                newAppPath: newAppUrl.path,
                targetPath: installUrl.path,
                backupPath: backupUrl.path,
                appBundleId: Bundle.main.bundleIdentifier ?? "com.yanjunhui.WeChatMultiOpen"
            )
        } else {
            // 普通脚本
            script = createUpdateScript(
                newAppPath: newAppUrl.path,
                targetPath: installUrl.path,
                backupPath: backupUrl.path,
                appBundleId: Bundle.main.bundleIdentifier ?? "com.yanjunhui.WeChatMultiOpen"
            )
        }

        try script.write(to: scriptPath, atomically: true, encoding: .utf8)

        // 设置脚本可执行权限
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

        // 标记更新已准备就绪
        updateReady = true

        // 提示用户重启
        showRestartPrompt(scriptPath: scriptPath.path)
    }

    /// 请求管理员授权
    @MainActor
    private func requestAdminAuthorization(for targetUrl: URL) async -> Bool {
        let alert = NSAlert()
        alert.messageText = "需要管理员权限"
        alert.informativeText = "应用安装在受保护的目录中，更新需要管理员权限。\n\n点击「授权」后，系统会要求您输入密码。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "授权")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            // 用户同意授权，测试是否能获取权限
            return await testAdminAuthorization()
        }

        return false
    }

    /// 测试管理员授权
    private func testAdminAuthorization() async -> Bool {
        // 使用 osascript 测试是否能获取管理员权限
        let script = """
        do shell script "echo test" with administrator privileges
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// 保存新版本到下载目录供手动安装
    private func saveForManualInstall(from sourceUrl: URL, appName: String) throws -> URL {
        let downloadDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let destUrl = downloadDir.appendingPathComponent(appName)

        // 如果已存在，先删除
        if FileManager.default.fileExists(atPath: destUrl.path) {
            try FileManager.default.removeItem(at: destUrl)
        }

        // 复制到下载目录
        try FileManager.default.copyItem(at: sourceUrl, to: destUrl)

        return destUrl
    }

    /// 显示手动安装提示
    @MainActor
    private func showManualInstallPrompt(newAppUrl: URL, targetUrl: URL) {
        let alert = NSAlert()
        alert.messageText = "需要手动安装"
        alert.informativeText = """
        未能获取管理员权限，无法自动更新。

        新版本已保存到「下载」文件夹：
        \(newAppUrl.path)

        请手动将其拖拽到「应用程序」文件夹替换旧版本。
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开下载文件夹")
        alert.addButton(withTitle: "稍后处理")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            // 在 Finder 中显示新版本
            NSWorkspace.shared.activateFileViewerSelecting([newAppUrl])
        }
    }

    /// 创建需要管理员权限的更新脚本
    private func createAdminUpdateScript(newAppPath: String, targetPath: String, backupPath: String, appBundleId: String) -> String {
        return """
        #!/bin/bash

        # 等待应用退出
        sleep 1

        # 等待应用进程完全退出
        while pgrep -f "\(appBundleId)" > /dev/null; do
            sleep 0.5
        done

        # 使用 osascript 执行需要管理员权限的操作
        osascript -e 'do shell script "
        # 删除旧备份
        rm -rf \\"\(backupPath)\\"

        # 备份当前版本
        if [ -d \\"\(targetPath)\\" ]; then
            mv \\"\(targetPath)\\" \\"\(backupPath)\\"
        fi

        # 复制新版本
        cp -R \\"\(newAppPath)\\" \\"\(targetPath)\\"

        # 设置权限
        chmod -R 755 \\"\(targetPath)\\"
        xattr -cr \\"\(targetPath)\\"
        " with administrator privileges'

        # 检查是否成功
        if [ $? -eq 0 ]; then
            # 启动新版本
            sleep 0.5
            open "\(targetPath)"

            # 清理备份
            sleep 10
            rm -rf "\(backupPath)"
        else
            # 失败时恢复备份
            if [ -d "\(backupPath)" ]; then
                rm -rf "\(targetPath)"
                mv "\(backupPath)" "\(targetPath)"
            fi
            # 显示错误
            osascript -e 'display alert "更新失败" message "无法完成更新，请手动安装。"'
        fi

        # 删除脚本自身
        rm -f "$0"
        """
    }

    /// 创建更新脚本
    private func createUpdateScript(newAppPath: String, targetPath: String, backupPath: String, appBundleId: String) -> String {
        return """
        #!/bin/bash

        # 等待应用退出
        sleep 1

        # 等待应用进程完全退出
        while pgrep -f "\(appBundleId)" > /dev/null; do
            sleep 0.5
        done

        # 删除旧备份
        rm -rf "\(backupPath)"

        # 备份当前版本
        if [ -d "\(targetPath)" ]; then
            mv "\(targetPath)" "\(backupPath)"
        fi

        # 复制新版本
        cp -R "\(newAppPath)" "\(targetPath)"

        # 设置权限
        chmod -R 755 "\(targetPath)"
        xattr -cr "\(targetPath)"

        # 启动新版本
        sleep 0.5
        open "\(targetPath)"

        # 清理备份（可选，延迟删除）
        sleep 10
        rm -rf "\(backupPath)"

        # 删除脚本自身
        rm -f "$0"
        """
    }

    /// 显示重启提示
    @MainActor
    private func showRestartPrompt(scriptPath: String) {
        let alert = NSAlert()
        alert.messageText = "更新已准备就绪"
        alert.informativeText = "新版本已下载完成，点击「立即重启」完成更新。\n\n应用将自动关闭并重新启动，您的数据不会丢失。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "立即重启")
        alert.addButton(withTitle: "稍后重启")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            // 执行更新脚本并退出应用
            launchUpdateScript(at: scriptPath)
        }
    }

    /// 启动更新脚本并退出应用
    private func launchUpdateScript(at scriptPath: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptPath]
        process.standardOutput = nil
        process.standardError = nil

        do {
            try process.run()
            // 退出当前应用
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApplication.shared.terminate(nil)
            }
        } catch {
            downloadError = "启动更新失败: \(error.localizedDescription)"
        }
    }

    /// 手动触发重启更新
    func restartToUpdate() {
        let scriptPath = FileManager.default.temporaryDirectory.appendingPathComponent("update_app.sh")
        if FileManager.default.fileExists(atPath: scriptPath.path) {
            launchUpdateScript(at: scriptPath.path)
        }
    }

    /// 忽略当前版本更新
    func ignoreCurrentUpdate() {
        if let update = availableUpdate {
            ignoredVersion = update.version
            availableUpdate = nil
        }
    }

    /// 重置忽略的版本
    func resetIgnoredVersion() {
        ignoredVersion = nil
    }

    /// 获取当前应用版本
    func getCurrentVersion() -> String {
        return currentVersion
    }

    /// 获取格式化的上次检查时间
    func getFormattedLastCheckTime() -> String? {
        guard let lastCheckTime = lastCheckTime else {
            return nil
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastCheckTime, relativeTo: Date())
    }

    // MARK: - 私有方法

    /// 从 GitHub API 获取最新 Release
    private func fetchLatestRelease(includePrerelease: Bool) async throws -> GitHubRelease {
        let owner = getRepoOwner()
        let repo = getRepoName()

        // 如果需要包含预发布版本，获取所有 releases 然后筛选
        let urlString: String
        if includePrerelease {
            urlString = "\(githubAPIBase)/repos/\(owner)/\(repo)/releases"
        } else {
            urlString = "\(githubAPIBase)/repos/\(owner)/\(repo)/releases/latest"
        }

        guard let url = URL(string: urlString) else {
            throw UpdateError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UpdateError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 404 {
                throw UpdateError.noReleaseFound
            }
            throw UpdateError.invalidResponse
        }

        let decoder = JSONDecoder()

        if includePrerelease {
            // 解析 releases 数组
            let releases = try decoder.decode([GitHubRelease].self, from: data)

            // 筛选第一个非 draft 的 release
            guard let release = releases.first(where: { !$0.draft }) else {
                throw UpdateError.noReleaseFound
            }
            return release
        } else {
            // 直接解析单个 release
            return try decoder.decode(GitHubRelease.self, from: data)
        }
    }

    /// 比较版本号，判断 version1 是否比 version2 更新
    /// 支持格式: 1.0.0, 1.0, 1.0.0-beta.1 等
    private func isNewerVersion(_ version1: String, than version2: String) -> Bool {
        // 分离主版本号和预发布标签
        let (v1Main, v1Pre) = separateVersionComponents(version1)
        let (v2Main, v2Pre) = separateVersionComponents(version2)

        // 分割版本号
        let v1Parts = v1Main.split(separator: ".").compactMap { Int($0) }
        let v2Parts = v2Main.split(separator: ".").compactMap { Int($0) }

        // 补齐位数
        let maxLength = max(v1Parts.count, v2Parts.count)
        var v1Padded = v1Parts
        var v2Padded = v2Parts

        while v1Padded.count < maxLength { v1Padded.append(0) }
        while v2Padded.count < maxLength { v2Padded.append(0) }

        // 逐位比较
        for i in 0..<maxLength {
            if v1Padded[i] > v2Padded[i] {
                return true
            } else if v1Padded[i] < v2Padded[i] {
                return false
            }
        }

        // 主版本号相同，比较预发布标签
        // 没有预发布标签的版本比有预发布标签的版本更新
        // 例如: 1.0.0 > 1.0.0-beta.1
        if v1Pre == nil && v2Pre != nil {
            return true
        }
        if v1Pre != nil && v2Pre == nil {
            return false
        }

        // 两个都有预发布标签，进行字符串比较
        if let pre1 = v1Pre, let pre2 = v2Pre {
            return pre1 > pre2
        }

        return false
    }

    /// 分离版本号的主版本和预发布标签
    private func separateVersionComponents(_ version: String) -> (main: String, prerelease: String?) {
        let parts = version.split(separator: "-", maxSplits: 1)
        if parts.count == 2 {
            return (String(parts[0]), String(parts[1]))
        }
        return (version, nil)
    }
}

// MARK: - 下载代理

/// 下载任务代理
private class DownloadDelegate: NSObject, URLSessionDownloadDelegate {

    let destinationUrl: URL
    let onProgress: (Double) -> Void
    let onComplete: (Result<URL, Error>) -> Void

    init(destinationUrl: URL, onProgress: @escaping (Double) -> Void, onComplete: @escaping (Result<URL, Error>) -> Void) {
        self.destinationUrl = destinationUrl
        self.onProgress = onProgress
        self.onComplete = onComplete
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            // 移动文件到目标位置
            try FileManager.default.moveItem(at: location, to: destinationUrl)
            onComplete(.success(destinationUrl))
        } catch {
            onComplete(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            onProgress(progress)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            onComplete(.failure(error))
        }
    }
}

// MARK: - 便捷扩展

extension UpdateInfo {

    /// 格式化的发布日期
    var formattedPublishDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: publishDate)
    }

    /// 格式化的资源文件大小
    var formattedAssetSize: String? {
        guard let size = assetSize else { return nil }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

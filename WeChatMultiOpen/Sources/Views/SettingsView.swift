//
//  SettingsView.swift
//  WeChatMultiOpen
//
//  Created by Yanjunhui
//

import SwiftUI
import ServiceManagement

/// 设置视图
/// 提供应用程序的各项设置选项
struct SettingsView: View {

    // MARK: - 属性

    /// 关闭窗口
    @Environment(\.dismiss) private var dismiss

    /// 开机自启设置
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false

    /// 显示菜单栏图标
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon: Bool = true

    /// 关闭窗口时隐藏到菜单栏
    @AppStorage("hideToMenuBarOnClose") private var hideToMenuBarOnClose: Bool = true

    /// 启动时检查微信状态
    @AppStorage("checkWeChatOnLaunch") private var checkWeChatOnLaunch: Bool = true

    /// 启动后自动隐藏主窗口
    @AppStorage("hideWindowOnLaunch") private var hideWindowOnLaunch: Bool = false

    /// 终止实例前需要确认
    @AppStorage("confirmBeforeTerminate") private var confirmBeforeTerminate: Bool = true

    /// 开机自启管理器
    @StateObject private var launchManager = LaunchAtLoginManager.shared

    /// 微信管理器
    private let wechatManager = WeChatManager.shared

    /// 存储空间统计
    @State private var storageStats: WeChatManager.StorageStats?

    /// 是否正在计算存储空间
    @State private var isCalculatingStorage: Bool = false

    /// 是否显示清空确认弹窗
    @State private var showClearConfirmation: Bool = false

    /// 是否正在清空数据
    @State private var isClearing: Bool = false

    /// 清空错误信息
    @State private var clearErrorMessage: String?

    /// 是否显示清空错误提示
    @State private var showClearError: Bool = false

    /// 是否显示升级确认弹窗
    @State private var showUpgradeConfirmation: Bool = false

    /// 是否正在升级
    @State private var isUpgrading: Bool = false

    /// 升级结果信息
    @State private var upgradeResultMessage: String?

    /// 是否显示升级结果提示
    @State private var showUpgradeResult: Bool = false

    /// 升级结果是否成功
    @State private var upgradeResultSuccess: Bool = false

    /// 过期克隆体数量
    @State private var outdatedCount: Int = 0

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView

            Divider()

            // 设置内容
            ScrollView {
                VStack(spacing: 20) {
                    // 通用设置
                    settingsSection(title: "通用", icon: "gearshape") {
                        settingsToggle(
                            title: "开机时自动启动",
                            description: "登录系统时自动启动微信多开助手",
                            isOn: $launchAtLogin
                        )
                        .onChange(of: launchAtLogin) { newValue in
                            launchManager.setLaunchAtLogin(enabled: newValue)
                        }

                        Divider()
                            .padding(.vertical, 4)

                        settingsToggle(
                            title: "启动时检查微信状态",
                            description: "应用启动时自动检查当前运行的微信实例",
                            isOn: $checkWeChatOnLaunch
                        )
                    }

                    // 窗口设置
                    settingsSection(title: "窗口", icon: "macwindow") {
                        settingsToggle(
                            title: "显示菜单栏图标",
                            description: "在菜单栏显示快捷操作图标",
                            isOn: $showMenuBarIcon
                        )

                        Divider()
                            .padding(.vertical, 4)

                        settingsToggle(
                            title: "关闭窗口时隐藏到菜单栏",
                            description: "关闭主窗口时不退出应用，保留菜单栏图标",
                            isOn: $hideToMenuBarOnClose
                        )
                        .disabled(!showMenuBarIcon)

                        Divider()
                            .padding(.vertical, 4)

                        settingsToggle(
                            title: "启动后自动隐藏主窗口",
                            description: "应用启动后自动隐藏主窗口，只显示菜单栏图标",
                            isOn: $hideWindowOnLaunch
                        )
                        .disabled(!showMenuBarIcon)
                    }

                    // 安全设置
                    settingsSection(title: "安全", icon: "shield") {
                        settingsToggle(
                            title: "终止实例前确认",
                            description: "终止微信实例前显示确认对话框",
                            isOn: $confirmBeforeTerminate
                        )
                    }

                    // 版本管理
                    settingsSection(title: "版本管理", icon: "arrow.triangle.2.circlepath") {
                        versionManagementContent
                    }

                    // 存储空间管理
                    settingsSection(title: "存储空间", icon: "internaldrive") {
                        storageManagementContent
                    }

                    // 关于
                    settingsSection(title: "关于", icon: "info.circle") {
                        aboutContent
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 480, height: 640)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            calculateStorage()
            checkOutdatedCopies()
        }
        .sheet(isPresented: $showClearConfirmation) {
            ClearDataConfirmationSheet(
                onCancel: {
                    showClearConfirmation = false
                },
                onConfirm: {
                    clearAllData()
                }
            )
        }
        .sheet(isPresented: $showUpgradeConfirmation) {
            UpgradeConfirmationSheet(
                outdatedCount: outdatedCount,
                originalVersion: wechatManager.getOriginalWeChatVersion() ?? "未知",
                onCancel: {
                    showUpgradeConfirmation = false
                },
                onConfirm: {
                    upgradeAllCopies()
                }
            )
        }
        .alert("清空失败", isPresented: $showClearError) {
            Button("确定") {
                showClearError = false
            }
        } message: {
            Text(clearErrorMessage ?? "发生未知错误")
        }
        .alert(upgradeResultSuccess ? "升级完成" : "升级失败", isPresented: $showUpgradeResult) {
            Button("确定") {
                showUpgradeResult = false
            }
        } message: {
            Text(upgradeResultMessage ?? "")
        }
    }

    // MARK: - 子视图

    /// 标题栏
    private var headerView: some View {
        HStack {
            Text("设置")
                .font(.system(size: 16, weight: .semibold))

            Spacer()

            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(NSColor.controlBackgroundColor))
    }

    /// 设置区块
    private func settingsSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 区块标题
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)

                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
            }

            // 区块内容
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
        }
    }

    /// 设置开关项
    private func settingsToggle(
        title: String,
        description: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }

    /// 版本管理内容
    private var versionManagementContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 原版微信版本
            HStack {
                Text("原版微信版本")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                Spacer()

                Text(wechatManager.getOriginalWeChatVersion() ?? "未安装")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
            }

            Divider()

            // 克隆体状态
            HStack {
                Text("克隆体状态")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                Spacer()

                if wechatManager.availableCopies.isEmpty {
                    Text("无克隆体")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                } else if outdatedCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("\(outdatedCount) 个需要升级")
                            .foregroundColor(.orange)
                    }
                    .font(.system(size: 13, weight: .medium))
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("全部最新")
                            .foregroundColor(.green)
                    }
                    .font(.system(size: 13, weight: .medium))
                }
            }

            // 克隆体版本列表（如果有过期的）
            if !wechatManager.availableCopies.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(wechatManager.availableCopies, id: \.id) { copy in
                        HStack {
                            Text(wechatManager.customNames[copy.bundleIdentifier] ?? copy.name)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)

                            Spacer()

                            let copyVersion = wechatManager.getCopyVersion(copy) ?? "未知"
                            let isOutdated = copyVersion != (wechatManager.getOriginalWeChatVersion() ?? "")

                            Text(copyVersion)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(isOutdated ? .orange : .primary)

                            if isOutdated {
                                Image(systemName: "arrow.up.circle")
                                    .font(.system(size: 10))
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }

            Divider()

            // 操作按钮
            HStack {
                Button(action: {
                    checkOutdatedCopies()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("检查更新")
                    }
                    .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button(action: {
                    showUpgradeConfirmation = true
                }) {
                    HStack(spacing: 4) {
                        if isUpgrading {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.up.circle")
                        }
                        Text("升级全部克隆体")
                    }
                    .font(.system(size: 12))
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.small)
                .disabled(outdatedCount == 0 || isUpgrading)
            }

            // 提示信息
            Text("升级会保留所有聊天记录和登录状态")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    /// 存储空间管理内容
    private var storageManagementContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 克隆体数量
            HStack {
                Text("克隆体数量")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(wechatManager.availableCopies.count) 个")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
            }

            Divider()

            // 存储空间统计
            if isCalculatingStorage {
                HStack {
                    Text("正在计算存储空间...")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    Spacer()

                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.8)
                }
            } else if let stats = storageStats {
                // 克隆体应用大小
                HStack {
                    Text("克隆体应用")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(stats.formattedCopiesSize)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                }

                Divider()

                // 聊天数据大小
                HStack {
                    Text("聊天记录及缓存")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(stats.formattedContainerSize)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                }

                Divider()

                // 总占用空间
                HStack {
                    Text("总占用空间")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)

                    Spacer()

                    Text(stats.formattedTotalSize)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.orange)
                }
            } else {
                HStack {
                    Text("存储空间")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("计算") {
                        calculateStorage()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Divider()

            // 操作按钮
            HStack {
                Button(action: {
                    calculateStorage()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("刷新")
                    }
                    .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isCalculatingStorage)

                Spacer()

                Button(action: {
                    showClearConfirmation = true
                }) {
                    HStack(spacing: 4) {
                        if isClearing {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "trash")
                        }
                        Text("清空所有克隆数据")
                    }
                    .font(.system(size: 12))
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.small)
                .disabled(wechatManager.availableCopies.isEmpty || isClearing)
            }
        }
    }

    /// 关于内容
    private var aboutContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("版本")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                Spacer()

                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
            }

            Divider()

            HStack {
                Text("开发者")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                Spacer()

                Text("Yanjunhui")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
            }

            Divider()

            // 免责声明
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Text("免责声明")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("本应用只是为了方便启动多个微信，仅仅是对微信应用做了一个完整复制，没有对微信程序本身做任何修改，而且多个克隆体之间完全数据隔离，理论上没有任何安全风险。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text("但是最终解释权归腾讯所有，个人不承担任何账号安全相关责任，如有侵权，强大的腾讯法务请速联系 i@yanjunhui.com，我将速删!")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .lineSpacing(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.orange.opacity(0.06))
            )
        }
    }

    // MARK: - 私有方法

    /// 计算存储空间
    private func calculateStorage() {
        isCalculatingStorage = true
        wechatManager.calculateStorageStatsAsync { stats in
            self.storageStats = stats
            self.isCalculatingStorage = false
        }
    }

    /// 清空所有克隆数据
    private func clearAllData() {
        showClearConfirmation = false
        isClearing = true

        wechatManager.clearAllCloneData { success, errorMessage in
            isClearing = false
            if success {
                // 重新计算存储空间
                calculateStorage()
                // 更新过期计数
                checkOutdatedCopies()
            } else {
                clearErrorMessage = errorMessage
                showClearError = true
            }
        }
    }

    /// 检查过期克隆体
    private func checkOutdatedCopies() {
        outdatedCount = wechatManager.getOutdatedCopies().count
    }

    /// 升级所有克隆体
    private func upgradeAllCopies() {
        showUpgradeConfirmation = false
        isUpgrading = true

        wechatManager.upgradeAllOutdatedCopies { successCount, failCount, errorMessage in
            isUpgrading = false

            if let error = errorMessage, failCount > 0 {
                upgradeResultSuccess = false
                upgradeResultMessage = error
            } else if successCount > 0 {
                upgradeResultSuccess = true
                upgradeResultMessage = "成功升级 \(successCount) 个克隆体"
            } else {
                upgradeResultSuccess = true
                upgradeResultMessage = "没有需要升级的克隆体"
            }

            showUpgradeResult = true
            checkOutdatedCopies()
        }
    }
}

// MARK: - 升级确认弹窗

/// 升级确认弹窗
struct UpgradeConfirmationSheet: View {
    let outdatedCount: Int
    let originalVersion: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // 图标
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)

            // 标题
            Text("升级克隆体")
                .font(.system(size: 18, weight: .semibold))

            // 说明
            VStack(spacing: 8) {
                Text("将 \(outdatedCount) 个克隆体升级到最新版本")
                    .font(.system(size: 14))
                    .foregroundColor(.primary)

                Text("目标版本: \(originalVersion)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            // 提示信息
            VStack(alignment: .leading, spacing: 6) {
                Label("聊天记录将完整保留", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Label("登录状态将完整保留", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Label("需要先终止运行中的克隆体", systemImage: "info.circle.fill")
                    .foregroundColor(.orange)
            }
            .font(.system(size: 13))

            // 按钮
            HStack(spacing: 16) {
                Button("取消") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.bordered)

                Button("开始升级") {
                    onConfirm()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            .padding(.top, 8)
        }
        .padding(30)
        .frame(width: 380)
    }
}

// MARK: - 清空数据确认弹窗

/// 清空数据确认弹窗
struct ClearDataConfirmationSheet: View {
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @State private var isConfirmed: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            // 警告图标
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)

            // 标题
            Text("确认清空所有克隆数据")
                .font(.system(size: 18, weight: .semibold))

            // 说明
            VStack(spacing: 8) {
                Text("此操作将删除：")
                    .font(.system(size: 14))
                    .foregroundColor(.primary)

                VStack(alignment: .leading, spacing: 4) {
                    Label("所有微信克隆体应用", systemImage: "app.badge.checkmark")
                    Label("所有克隆体的聊天记录", systemImage: "message")
                    Label("所有克隆体的缓存数据", systemImage: "folder")
                }
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            }

            Text("此操作不可恢复！")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.red)

            // 确认勾选
            HStack(spacing: 8) {
                Toggle("", isOn: $isConfirmed)
                    .toggleStyle(.checkbox)
                    .labelsHidden()

                Text("将清空所有微信克隆及相关数据，无法恢复")
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
            }
            .padding(.top, 8)

            // 按钮
            HStack(spacing: 16) {
                Button("取消") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.bordered)

                Button("清空") {
                    onConfirm()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(!isConfirmed)
            }
            .padding(.top, 8)
        }
        .padding(30)
        .frame(width: 420)
    }
}

// MARK: - 预览

#Preview {
    SettingsView()
}

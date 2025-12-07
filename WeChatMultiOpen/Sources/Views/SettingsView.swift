//
//  SettingsView.swift
//  WeChatMultiOpen
//
//  Created by Yanjunhui
//

import SwiftUI
import ServiceManagement

/// 设置视图
/// 提供应用程序的各项设置选项，采用现代化卡片式设计
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

    /// 启动时检查更新
    @AppStorage("checkUpdateOnLaunch") private var checkUpdateOnLaunch: Bool = true

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

    /// 更新管理器
    @StateObject private var updateManager = UpdateManager.shared

    /// 是否显示更新弹窗
    @State private var showUpdateSheet: Bool = false

    /// 显示已是最新版本状态
    @State private var showUpToDate: Bool = false

    /// 当前选中的设置分类
    @State private var selectedCategory: SettingsCategory = .general

    // MARK: - 设置分类

    enum SettingsCategory: String, CaseIterable {
        case general = "通用"
        case window = "窗口"
        case version = "版本"
        case storage = "存储"
        case about = "关于"

        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .window: return "macwindow"
            case .version: return "arrow.triangle.2.circlepath"
            case .storage: return "internaldrive"
            case .about: return "info.circle"
            }
        }
    }

    // MARK: - 视图

    var body: some View {
        HStack(spacing: 0) {
            // 左侧导航栏
            sidebarView

            // 分隔线
            Divider()

            // 右侧内容区域
            contentView
        }
        .frame(width: 640, height: 520)
        .background(settingsBackground)
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
        .sheet(isPresented: $showUpdateSheet) {
            if let update = updateManager.availableUpdate {
                UpdateAvailableSheet(
                    updateInfo: update,
                    onDismiss: {
                        showUpdateSheet = false
                    },
                    onDownload: {
                        updateManager.openDownloadPage()
                        showUpdateSheet = false
                    },
                    onIgnore: {
                        updateManager.ignoreCurrentUpdate()
                        showUpdateSheet = false
                    }
                )
            }
        }
    }

    // MARK: - 背景

    private var settingsBackground: some View {
        Group {
            if #available(macOS 26.0, *) {
                Rectangle()
                    .fill(.regularMaterial)
            } else {
                Color(NSColor.windowBackgroundColor)
            }
        }
    }

    // MARK: - 左侧导航栏

    /// 关闭按钮悬停状态
    @State private var isCloseButtonHovered: Bool = false

    private var sidebarView: some View {
        VStack(spacing: 4) {
            // 系统风格关闭按钮 - 位于左上角（与系统窗口按钮位置一致）
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 1.0, green: 0.38, blue: 0.34))
                            .frame(width: 12, height: 12)

                        if isCloseButtonHovered {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(Color(red: 0.4, green: 0.0, blue: 0.0))
                        }
                    }
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isCloseButtonHovered = hovering
                }
                .help("关闭设置")

                Spacer()
            }
            .padding(.leading, 13)
            .padding(.top, 12)

            // 标题
            HStack {
                Text("设置")
                    .font(AppTheme.Fonts.title)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)

            // 导航项
            ForEach(SettingsCategory.allCases, id: \.self) { category in
                sidebarItem(category)
            }

            Spacer()
        }
        .frame(width: 160)
        .background(sidebarBackground)
    }

    private func sidebarItem(_ category: SettingsCategory) -> some View {
        Button(action: {
            withAnimation(AppTheme.Animations.fast) {
                selectedCategory = category
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: category.icon)
                    .font(.system(size: 14))
                    .frame(width: 20)

                Text(category.rawValue)
                    .font(AppTheme.Fonts.body)

                Spacer()

                // 关于页面有更新时显示小红点
                if category == .about && updateManager.hasUpdate {
                    Circle()
                        .fill(AppTheme.Colors.danger)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedCategory == category ? AppTheme.Colors.primary.opacity(0.15) : Color.clear)
            )
            .foregroundColor(selectedCategory == category ? AppTheme.Colors.primary : .primary)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }

    private var sidebarBackground: some View {
        Group {
            if #available(macOS 26.0, *) {
                Rectangle()
                    .fill(.ultraThinMaterial)
            } else {
                Rectangle()
                    .fill(AppTheme.Colors.cardBackground.opacity(0.5))
            }
        }
    }

    // MARK: - 右侧内容区域

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                switch selectedCategory {
                case .general:
                    generalSettings
                case .window:
                    windowSettings
                case .version:
                    versionSettings
                case .storage:
                    storageSettings
                case .about:
                    aboutSettings
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 通用设置

    private var generalSettings: some View {
        VStack(spacing: 16) {
            settingsSectionHeader(title: "通用设置", icon: "gearshape")

            settingsCard {
                VStack(spacing: 0) {
                    settingsToggleRow(
                        title: "开机时自动启动",
                        description: "登录系统时自动启动微信多开助手",
                        icon: "power",
                        isOn: $launchAtLogin
                    )
                    .onChange(of: launchAtLogin) { newValue in
                        launchManager.setLaunchAtLogin(enabled: newValue)
                    }

                    settingsDivider

                    settingsToggleRow(
                        title: "启动时检查微信状态",
                        description: "应用启动时自动检查当前运行的微信实例",
                        icon: "checkmark.circle",
                        isOn: $checkWeChatOnLaunch
                    )

                    settingsDivider

                    settingsToggleRow(
                        title: "终止实例前确认",
                        description: "终止微信实例前显示确认对话框",
                        icon: "exclamationmark.shield",
                        isOn: $confirmBeforeTerminate
                    )
                }
            }
        }
    }

    // MARK: - 窗口设置

    private var windowSettings: some View {
        VStack(spacing: 16) {
            settingsSectionHeader(title: "窗口设置", icon: "macwindow")

            settingsCard {
                VStack(spacing: 0) {
                    settingsToggleRow(
                        title: "显示菜单栏图标",
                        description: "在菜单栏显示快捷操作图标",
                        icon: "menubar.rectangle",
                        isOn: $showMenuBarIcon
                    )

                    settingsDivider

                    settingsToggleRow(
                        title: "关闭窗口时隐藏到菜单栏",
                        description: "关闭主窗口时不退出应用，保留菜单栏图标",
                        icon: "eye.slash",
                        isOn: $hideToMenuBarOnClose,
                        disabled: !showMenuBarIcon
                    )

                    settingsDivider

                    settingsToggleRow(
                        title: "启动后自动隐藏主窗口",
                        description: "应用启动后自动隐藏主窗口，只显示菜单栏图标",
                        icon: "rectangle.on.rectangle.slash",
                        isOn: $hideWindowOnLaunch,
                        disabled: !showMenuBarIcon
                    )

                    settingsDivider

                    settingsToggleRow(
                        title: "启动时检查更新",
                        description: "应用启动时自动检查 GitHub 上是否有新版本",
                        icon: "arrow.down.circle",
                        isOn: $checkUpdateOnLaunch
                    )
                }
            }
        }
    }

    // MARK: - 版本管理

    private var versionSettings: some View {
        VStack(spacing: 16) {
            settingsSectionHeader(title: "版本管理", icon: "arrow.triangle.2.circlepath")

            // 版本信息卡片
            settingsCard {
                VStack(spacing: 0) {
                    // 原版微信版本
                    settingsInfoRow(
                        title: "原版微信版本",
                        value: wechatManager.getOriginalWeChatVersion() ?? "未安装",
                        icon: "app.badge"
                    )

                    settingsDivider

                    // 克隆体状态
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Colors.primary)
                                .frame(width: 24)

                            Text("克隆体状态")
                                .font(AppTheme.Fonts.body)
                        }

                        Spacer()

                        if wechatManager.availableCopies.isEmpty {
                            Text("无克隆体")
                                .font(AppTheme.Fonts.body)
                                .foregroundColor(.secondary)
                        } else if outdatedCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(AppTheme.Colors.warning)
                                Text("\(outdatedCount) 个需要升级")
                                    .foregroundColor(AppTheme.Colors.warning)
                            }
                            .font(AppTheme.Fonts.body)
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppTheme.Colors.success)
                                Text("全部最新")
                                    .foregroundColor(AppTheme.Colors.success)
                            }
                            .font(AppTheme.Fonts.body)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                }
            }

            // 克隆体列表
            if !wechatManager.availableCopies.isEmpty {
                settingsCard {
                    VStack(spacing: 0) {
                        ForEach(Array(wechatManager.availableCopies.enumerated()), id: \.element.id) { index, copy in
                            if index > 0 {
                                settingsDivider
                            }

                            let copyVersion = wechatManager.getCopyVersion(copy) ?? "未知"
                            let isOutdated = copyVersion != (wechatManager.getOriginalWeChatVersion() ?? "")

                            HStack {
                                Text(wechatManager.customNames[copy.bundleIdentifier] ?? copy.name)
                                    .font(AppTheme.Fonts.body)
                                    .foregroundColor(.primary)

                                Spacer()

                                HStack(spacing: 6) {
                                    Text(copyVersion)
                                        .font(AppTheme.Fonts.body)
                                        .foregroundColor(isOutdated ? AppTheme.Colors.warning : .secondary)

                                    if isOutdated {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(AppTheme.Colors.warning)
                                    }
                                }
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }

            // 操作按钮
            HStack(spacing: 12) {
                Button(action: {
                    checkOutdatedCopies()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("检查更新")
                    }
                    .font(AppTheme.Fonts.body)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(action: {
                    showUpgradeConfirmation = true
                }) {
                    HStack(spacing: 6) {
                        if isUpgrading {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                        }
                        Text("升级全部克隆体")
                    }
                    .font(AppTheme.Fonts.body)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.Colors.primary)
                .disabled(outdatedCount == 0 || isUpgrading)
            }

            // 提示信息
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                Text("升级会保留所有聊天记录和登录状态")
                    .font(AppTheme.Fonts.caption)
            }
            .foregroundColor(.secondary)
        }
    }

    // MARK: - 存储设置

    private var storageSettings: some View {
        VStack(spacing: 16) {
            settingsSectionHeader(title: "存储空间", icon: "internaldrive")

            settingsCard {
                VStack(spacing: 0) {
                    // 克隆体数量
                    settingsInfoRow(
                        title: "克隆体数量",
                        value: "\(wechatManager.availableCopies.count) 个",
                        icon: "doc.on.doc"
                    )

                    settingsDivider

                    // 存储空间统计
                    if isCalculatingStorage {
                        HStack {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.8)
                                Text("正在计算存储空间...")
                                    .font(AppTheme.Fonts.body)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                    } else if let stats = storageStats {
                        settingsInfoRow(
                            title: "克隆体应用",
                            value: stats.formattedCopiesSize,
                            icon: "app"
                        )

                        settingsDivider

                        settingsInfoRow(
                            title: "聊天记录及缓存",
                            value: stats.formattedContainerSize,
                            icon: "message"
                        )

                        settingsDivider

                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "chart.pie")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.Colors.warning)
                                    .frame(width: 24)

                                Text("总占用空间")
                                    .font(AppTheme.Fonts.subtitle)
                            }

                            Spacer()

                            Text(stats.formattedTotalSize)
                                .font(AppTheme.Fonts.subtitle)
                                .foregroundColor(AppTheme.Colors.warning)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                    }
                }
            }

            // 操作按钮
            HStack(spacing: 12) {
                Button(action: {
                    calculateStorage()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("刷新")
                    }
                    .font(AppTheme.Fonts.body)
                }
                .buttonStyle(.bordered)
                .disabled(isCalculatingStorage)

                Spacer()

                Button(action: {
                    showClearConfirmation = true
                }) {
                    HStack(spacing: 6) {
                        if isClearing {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "trash")
                        }
                        Text("清空所有克隆数据")
                    }
                    .font(AppTheme.Fonts.body)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.Colors.danger)
                .disabled(wechatManager.availableCopies.isEmpty || isClearing)
            }
        }
    }

    // MARK: - 关于设置

    private var aboutSettings: some View {
        VStack(spacing: 16) {
            settingsSectionHeader(title: "关于", icon: "info.circle")

            // 应用信息卡片
            settingsCard {
                VStack(spacing: 16) {
                    // 应用图标和名称
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(AppTheme.Colors.primaryGradient)
                                .frame(width: 64, height: 64)

                            Image(systemName: "square.stack.3d.up.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 8, x: 0, y: 4)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("微信多开")
                                .font(AppTheme.Fonts.title)

                            Text("版本 \(updateManager.getCurrentVersion())")
                                .font(AppTheme.Fonts.body)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    Divider()
                        .padding(.horizontal, 16)

                    // 更新检查
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("检查更新")
                                .font(AppTheme.Fonts.body)

                            if updateManager.hasUpdate, let update = updateManager.availableUpdate {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(AppTheme.Colors.danger)
                                        .frame(width: 6, height: 6)
                                    Text("发现新版本 v\(update.version)")
                                }
                                .font(AppTheme.Fonts.caption)
                                .foregroundColor(AppTheme.Colors.danger)
                            } else if showUpToDate {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 10))
                                    Text("已是最新版本")
                                }
                                .font(AppTheme.Fonts.caption)
                                .foregroundColor(AppTheme.Colors.success)
                            } else if let lastCheck = updateManager.getFormattedLastCheckTime() {
                                Text("上次检查: \(lastCheck)")
                                    .font(AppTheme.Fonts.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        if updateManager.isChecking {
                            ProgressView()
                                .controlSize(.small)
                        } else if updateManager.hasUpdate, let update = updateManager.availableUpdate {
                            Button(action: {
                                showUpdateSheet = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text("v\(update.version) 可用")
                                }
                                .font(AppTheme.Fonts.body)
                                .foregroundColor(AppTheme.Colors.success)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button(action: {
                                checkForAppUpdate()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("检查")
                                }
                                .font(AppTheme.Fonts.body)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.horizontal, 16)

                    Divider()
                        .padding(.horizontal, 16)

                    // 开发者信息
                    HStack {
                        Text("开发者")
                            .font(AppTheme.Fonts.body)
                            .foregroundColor(.secondary)

                        Spacer()

                        Image("github")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let url = URL(string: "https://github.com/yanjunhui/WeChatMulti") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .help("访问 GitHub 项目主页")
                }
            }

            // 免责声明
            settingsCard {
                VStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.warning)
                        Text("免责声明")
                            .font(AppTheme.Fonts.subtitle)
                    }

                    Text("本应用只是为了方便启动多个微信，仅仅是对微信应用做了一个完整复制，没有对微信程序本身做任何修改，而且多个克隆体之间完全数据隔离，理论上没有任何安全风险。")
                        .font(AppTheme.Fonts.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Text("但是最终解释权归腾讯所有，个人不承担任何账号安全相关责任，如有侵权，强大的腾讯法务请速联系 i@yanjunhui.com，我将速删!")
                        .font(AppTheme.Fonts.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
            }
        }
    }

    // MARK: - 可复用组件

    /// 设置区块标题
    private func settingsSectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.Colors.primary)

            Text(title)
                .font(AppTheme.Fonts.largeTitle)

            Spacer()
        }
    }

    /// 设置卡片容器
    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    private var cardBackground: some View {
        Group {
            if #available(macOS 26.0, *) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.Colors.cardBackground)
            }
        }
    }

    /// 设置开关行
    private func settingsToggleRow(
        title: String,
        description: String,
        icon: String,
        isOn: Binding<Bool>,
        disabled: Bool = false
    ) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(disabled ? .secondary.opacity(0.5) : AppTheme.Colors.primary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.Fonts.body)
                        .foregroundColor(disabled ? .secondary : .primary)

                    Text(description)
                        .font(AppTheme.Fonts.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(disabled)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
    }

    /// 设置信息行
    private func settingsInfoRow(title: String, value: String, icon: String) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.primary)
                    .frame(width: 24)

                Text(title)
                    .font(AppTheme.Fonts.body)
            }

            Spacer()

            Text(value)
                .font(AppTheme.Fonts.body)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }

    /// 设置分隔线
    private var settingsDivider: some View {
        Divider()
            .padding(.leading, 48)
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
                calculateStorage()
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

    /// 检查应用更新
    private func checkForAppUpdate() {
        showUpToDate = false
        updateManager.resetIgnoredVersion()

        Task {
            let result = await updateManager.checkForUpdates()

            switch result {
            case .available:
                showUpdateSheet = true
            case .upToDate:
                showUpToDate = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    showUpToDate = false
                }
            case .error:
                break
            }
        }
    }
}

// MARK: - 升级确认弹窗

struct UpgradeConfirmationSheet: View {
    let outdatedCount: Int
    let originalVersion: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // 图标
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.info.opacity(0.15))
                    .frame(width: 64, height: 64)

                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(AppTheme.Colors.info)
            }

            // 标题
            VStack(spacing: 8) {
                Text("升级克隆体")
                    .font(AppTheme.Fonts.title)

                Text("将 \(outdatedCount) 个克隆体升级到 \(originalVersion)")
                    .font(AppTheme.Fonts.body)
                    .foregroundColor(.secondary)
            }

            // 提示信息
            VStack(alignment: .leading, spacing: 8) {
                Label("聊天记录将完整保留", systemImage: "checkmark.circle.fill")
                    .foregroundColor(AppTheme.Colors.success)
                Label("登录状态将完整保留", systemImage: "checkmark.circle.fill")
                    .foregroundColor(AppTheme.Colors.success)
                Label("需要先终止运行中的克隆体", systemImage: "info.circle.fill")
                    .foregroundColor(AppTheme.Colors.warning)
            }
            .font(AppTheme.Fonts.body)

            // 按钮
            HStack(spacing: 12) {
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
                .tint(AppTheme.Colors.primary)
            }
        }
        .padding(32)
        .frame(width: 380)
    }
}

// MARK: - 清空数据确认弹窗

struct ClearDataConfirmationSheet: View {
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @State private var isConfirmed: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            // 警告图标
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.danger.opacity(0.15))
                    .frame(width: 64, height: 64)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(AppTheme.Colors.danger)
            }

            // 标题
            VStack(spacing: 8) {
                Text("确认清空所有克隆数据")
                    .font(AppTheme.Fonts.title)

                Text("此操作将删除所有微信克隆体和相关数据")
                    .font(AppTheme.Fonts.body)
                    .foregroundColor(.secondary)
            }

            // 警告列表
            VStack(alignment: .leading, spacing: 6) {
                Label("所有微信克隆体应用", systemImage: "app.badge.checkmark")
                Label("所有克隆体的聊天记录", systemImage: "message")
                Label("所有克隆体的缓存数据", systemImage: "folder")
            }
            .font(AppTheme.Fonts.body)
            .foregroundColor(.secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.Colors.danger.opacity(0.08))
            )

            Text("此操作不可恢复！")
                .font(AppTheme.Fonts.subtitle)
                .foregroundColor(AppTheme.Colors.danger)

            // 确认勾选
            HStack(spacing: 8) {
                Toggle("", isOn: $isConfirmed)
                    .toggleStyle(.checkbox)
                    .labelsHidden()

                Text("我已了解将清空所有微信克隆及相关数据")
                    .font(AppTheme.Fonts.caption)
            }

            // 按钮
            HStack(spacing: 12) {
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
                .tint(AppTheme.Colors.danger)
                .disabled(!isConfirmed)
            }
        }
        .padding(32)
        .frame(width: 420)
    }
}

// MARK: - 更新可用弹窗

struct UpdateAvailableSheet: View {
    let updateInfo: UpdateInfo
    let onDismiss: () -> Void
    let onDownload: () -> Void
    let onIgnore: () -> Void

    @StateObject private var updateManager = UpdateManager.shared

    var body: some View {
        VStack(spacing: 24) {
            // 图标
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.info.opacity(0.15))
                    .frame(width: 64, height: 64)

                Image(systemName: "arrow.down.app.fill")
                    .font(.system(size: 28))
                    .foregroundColor(AppTheme.Colors.info)
            }

            // 标题
            VStack(spacing: 4) {
                Text("发现新版本")
                    .font(AppTheme.Fonts.title)

                Text("v\(updateInfo.version)")
                    .font(AppTheme.Fonts.subtitle)
                    .foregroundColor(AppTheme.Colors.primary)
            }

            // 发布信息
            HStack(spacing: 16) {
                Label(updateInfo.formattedPublishDate, systemImage: "calendar")
                    .font(AppTheme.Fonts.caption)
                    .foregroundColor(.secondary)

                if let size = updateInfo.formattedAssetSize {
                    Label(size, systemImage: "arrow.down.circle")
                        .font(AppTheme.Fonts.caption)
                        .foregroundColor(.secondary)
                }
            }

            // 更新说明
            if !updateInfo.releaseNotes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("更新说明")
                        .font(AppTheme.Fonts.subtitle)

                    ScrollView {
                        Text(updateInfo.releaseNotes)
                            .font(AppTheme.Fonts.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 120)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.Colors.cardBackground)
                )
            }

            // 下载进度
            if updateManager.isDownloading {
                VStack(spacing: 8) {
                    ProgressView(value: updateManager.downloadProgress)
                        .progressViewStyle(.linear)

                    HStack {
                        Text("正在下载...")
                            .font(AppTheme.Fonts.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("\(Int(updateManager.downloadProgress * 100))%")
                            .font(AppTheme.Fonts.caption)
                    }
                }
            }

            // 下载错误
            if let error = updateManager.downloadError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppTheme.Colors.danger)
                    Text(error)
                        .foregroundColor(AppTheme.Colors.danger)
                }
                .font(AppTheme.Fonts.caption)
            }

            // 按钮
            VStack(spacing: 12) {
                if updateManager.updateReady {
                    Button(action: {
                        updateManager.restartToUpdate()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle.fill")
                            Text("立即重启")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.Colors.success)
                    .controlSize(.large)

                    Button("稍后重启") {
                        onDismiss()
                    }
                    .buttonStyle(.bordered)

                } else if updateManager.isDownloading {
                    Button(action: {
                        updateManager.cancelDownload()
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("取消下载")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                } else {
                    Button(action: {
                        Task {
                            await updateManager.downloadAndInstallUpdate()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("下载并安装")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.Colors.primary)
                    .controlSize(.large)

                    HStack(spacing: 12) {
                        Button("稍后提醒") {
                            onDismiss()
                        }
                        .buttonStyle(.bordered)

                        Button("忽略此版本") {
                            onIgnore()
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(32)
        .frame(width: 400)
    }
}

// MARK: - 预览

#Preview {
    SettingsView()
}

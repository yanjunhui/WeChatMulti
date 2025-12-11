//
//  MenuBarManager.swift
//  WeChatMultiOpen
//
//  Created by Yanjunhui
//

import Foundation
import AppKit
import SwiftUI
import Combine
import ServiceManagement

/// 菜单栏管理器
/// 负责管理应用在菜单栏的图标和快捷菜单
final class MenuBarManager: NSObject, ObservableObject {

    // MARK: - 单例

    static let shared = MenuBarManager()

    // MARK: - 属性

    /// 状态栏项目
    private var statusItem: NSStatusItem?

    /// 菜单
    private var menu: NSMenu?

    /// 微信管理器
    private let wechatManager = WeChatManager.shared

    /// 开机启动管理器
    private let launchManager = LaunchAtLoginManager.shared

    /// Combine取消令牌集合
    private var cancellables = Set<AnyCancellable>()

    /// 是否显示菜单栏图标
    @Published var isVisible: Bool = false

    /// 显示主窗口回调
    var onShowMainWindow: (() -> Void)?

    // MARK: - 初始化

    private override init() {
        super.init()
        setupBindings()
    }

    // MARK: - 公共方法

    /// 设置菜单栏
    func setup() {
        guard statusItem == nil else { return }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = createStatusBarImage()
            button.image?.isTemplate = false  // 不使用模板模式，保留图标原始颜色
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        createMenu()
        isVisible = true
    }

    /// 移除菜单栏
    func remove() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
        isVisible = false
    }

    /// 更新菜单栏图标和菜单
    func update() {
        updateStatusBarImage()
        updateMenu()
    }

    // MARK: - 私有方法

    /// 设置数据绑定
    private func setupBindings() {
        // 监听实例变化，更新菜单栏
        wechatManager.$instances
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.update()
            }
            .store(in: &cancellables)

        // 监听开机启动状态变化，更新菜单栏
        launchManager.$isEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenu()
            }
            .store(in: &cancellables)
    }

    /// 创建状态栏图标 - 使用微信多开应用图标
    private func createStatusBarImage() -> NSImage {
        // 方法1: 从应用程序获取图标（最可靠的方式）
        if let appIcon = NSApp.applicationIconImage {
            let icon = appIcon.copy() as! NSImage
            icon.size = NSSize(width: 18, height: 18)
            print("✓ [状态栏图标] 成功获取应用图标，尺寸: \(icon.size)")
            return icon
        }

        // 方法2: 从 Bundle 路径获取
        if let bundlePath = Bundle.main.bundlePath as String? {
            let icon = NSWorkspace.shared.icon(forFile: bundlePath)
            icon.size = NSSize(width: 18, height: 18)
            print("✓ [状态栏图标] 从 Bundle 路径获取图标，尺寸: \(icon.size)")
            return icon
        }

        // 如果都失败，创建一个默认图标
        print("⚠️ [状态栏图标] 无法获取应用图标，使用默认图标")
        let defaultImage = NSImage(size: NSSize(width: 18, height: 18))
        return defaultImage
    }

    /// 更新状态栏图标
    private func updateStatusBarImage() {
        guard let button = statusItem?.button else { return }

        // 统计运行中的微信数量
        let runningCount = wechatManager.instances.filter { $0.isRunning }.count

        if runningCount > 0 {
            // 创建带数字的图标
            let image = createStatusBarImageWithCount(count: runningCount)
            button.image = image
        } else {
            button.image = createStatusBarImage()
        }
    }

    /// 创建带数字计数的状态栏图标
    private func createStatusBarImageWithCount(count: Int) -> NSImage {
        // 获取应用图标
        var appIcon: NSImage?

        // 方法1: 从应用程序获取图标（最可靠的方式）
        if let icon = NSApp.applicationIconImage {
            appIcon = icon
            print("✓ [带计数图标] 成功获取应用图标")
        }
        // 方法2: 从 Bundle 路径获取
        else if let bundlePath = Bundle.main.bundlePath as String? {
            appIcon = NSWorkspace.shared.icon(forFile: bundlePath)
            print("✓ [带计数图标] 从 Bundle 路径获取图标")
        }

        guard let baseIcon = appIcon else {
            print("⚠️ [带计数图标] 无法获取应用图标")
            return NSImage(size: NSSize(width: 28, height: 18))
        }

        let size = NSSize(width: 28, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            // 绘制应用图标
            let iconRect = NSRect(x: 0, y: 0, width: 18, height: 18)
            baseIcon.draw(in: iconRect)

            // 在图标右侧绘制数字
            let countString = count > 9 ? "9+" : "\(count)"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: NSColor.labelColor  // 使用系统颜色，自动适配主题
            ]
            let attributedString = NSAttributedString(string: countString, attributes: attributes)
            let textSize = attributedString.size()
            let textRect = NSRect(
                x: size.width - textSize.width - 1,
                y: (size.height - textSize.height) / 2,  // 垂直居中
                width: textSize.width,
                height: textSize.height
            )
            attributedString.draw(in: textRect)

            return true
        }

        return image
    }

    /// 状态栏按钮点击
    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // 右键显示菜单
            showMenu()
        } else {
            // 左键切换菜单显示
            showMenu()
        }
    }

    /// 显示菜单
    private func showMenu() {
        updateMenu()
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    /// 创建菜单
    private func createMenu() {
        menu = NSMenu()
        updateMenu()
    }

    /// 更新菜单内容
    private func updateMenu() {
        guard let menu = menu else { return }

        menu.removeAllItems()

        // 实例列表（显示所有实例，包括未启动的）
        let instances = wechatManager.instances.filter { !$0.isCreating }
        if instances.isEmpty {
            let emptyItem = NSMenuItem(title: "暂无微信实例", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for instance in instances {
                // 根据运行状态显示不同的信息
                let statusText: String
                if instance.isRunning {
                    statusText = instance.processId.map { "PID: \($0)" } ?? ""
                } else {
                    statusText = "未启动"
                }

                let item = NSMenuItem(
                    title: "\(instance.displayName) (\(statusText))",
                    action: #selector(activateInstance(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = instance

                // 根据运行状态设置图标和启用状态
                // 获取微信应用图标
                let appIcon = getAppIcon(for: instance)

                if instance.isRunning {
                    // 运行中：显示应用图标，可点击
                    item.image = appIcon
                    item.isEnabled = true
                } else {
                    // 未启动：显示半透明的应用图标，禁用（灰色显示）
                    if let icon = appIcon {
                        let dimmedIcon = icon.copy() as! NSImage
                        dimmedIcon.isTemplate = false
                        item.image = dimmedIcon
                    }
                    item.isEnabled = false
                }

                menu.addItem(item)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // 开机启动
        let launchAtLoginItem = NSMenuItem(
            title: "开机启动",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        launchAtLoginItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(launchAtLoginItem)

        menu.addItem(NSMenuItem.separator())

        // 控制台
        let showWindowItem = NSMenuItem(
            title: "控制台",
            action: #selector(showMainWindow),
            keyEquivalent: "o"
        )
        showWindowItem.target = self
        showWindowItem.keyEquivalentModifierMask = [.command]
        menu.addItem(showWindowItem)

        menu.addItem(NSMenuItem.separator())

        // 退出
        let quitItem = NSMenuItem(
            title: "退出",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.keyEquivalentModifierMask = [.command]
        menu.addItem(quitItem)
    }

    /// 获取应用图标
    /// 原版微信使用微信自己的图标，克隆实例使用本应用图标
    private func getAppIcon(for instance: WeChatInstance) -> NSImage? {
        let icon: NSImage

        if instance.isOriginal {
            // 原版微信：使用微信应用的图标
            guard let wechatPath = wechatManager.wechatPath else { return nil }
            icon = NSWorkspace.shared.icon(forFile: wechatPath)
        } else {
            // 克隆实例：使用微信多开应用的图标
            guard let appIcon = NSApp.applicationIconImage else { return nil }
            icon = appIcon.copy() as! NSImage
        }

        // 设置合适的尺寸（菜单栏标准尺寸）
        icon.size = NSSize(width: 18, height: 18)

        return icon
    }

    // MARK: - 菜单动作

    /// 激活实例
    @objc private func activateInstance(_ sender: NSMenuItem) {
        guard let instance = sender.representedObject as? WeChatInstance else { return }
        wechatManager.activateInstance(instance)
    }

    /// 检查是否启用开机启动
    private func isLaunchAtLoginEnabled() -> Bool {
        return launchManager.isEnabled
    }

    /// 切换开机启动
    @objc private func toggleLaunchAtLogin() {
        // 切换状态
        let newState = !launchManager.isEnabled
        launchManager.setLaunchAtLogin(enabled: newState)

        // 如果设置失败，显示错误
        if let error = launchManager.errorMessage {
            let alert = NSAlert()
            alert.messageText = "开机启动设置失败"
            alert.informativeText = error
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.runModal()
        } else {
            print("✓ [开机启动] 已\(newState ? "启用" : "禁用")")
        }

        // 菜单会通过监听 launchManager.$isEnabled 自动更新
    }

    /// 显示主窗口
    @objc private func showMainWindow() {
        onShowMainWindow?()
    }

    /// 退出应用
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

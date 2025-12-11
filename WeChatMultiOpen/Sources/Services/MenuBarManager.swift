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
            button.image?.isTemplate = true
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
    }

    /// 创建状态栏图标 - 两个重叠的消息气泡，体现"多开"含义
    private func createStatusBarImage() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            NSColor.black.setStroke()

            // 后面的气泡（稍大，位置偏右上）
            let backBubblePath = NSBezierPath()
            backBubblePath.move(to: NSPoint(x: 6, y: 5))
            backBubblePath.line(to: NSPoint(x: 6, y: 14))
            backBubblePath.curve(to: NSPoint(x: 10, y: 17),
                                controlPoint1: NSPoint(x: 6, y: 15.5),
                                controlPoint2: NSPoint(x: 8, y: 17))
            backBubblePath.line(to: NSPoint(x: 15, y: 17))
            backBubblePath.curve(to: NSPoint(x: 18, y: 14),
                                controlPoint1: NSPoint(x: 17, y: 17),
                                controlPoint2: NSPoint(x: 18, y: 15.5))
            backBubblePath.line(to: NSPoint(x: 18, y: 9))
            backBubblePath.curve(to: NSPoint(x: 15, y: 6),
                                controlPoint1: NSPoint(x: 18, y: 7.5),
                                controlPoint2: NSPoint(x: 17, y: 6))
            backBubblePath.line(to: NSPoint(x: 10, y: 6))
            backBubblePath.curve(to: NSPoint(x: 6, y: 5),
                                controlPoint1: NSPoint(x: 8, y: 6),
                                controlPoint2: NSPoint(x: 6, y: 5.5))
            backBubblePath.close()
            backBubblePath.lineWidth = 1.5
            backBubblePath.stroke()

            // 前面的气泡（主气泡，位置偏左下）
            let frontBubblePath = NSBezierPath()
            frontBubblePath.move(to: NSPoint(x: 0, y: 1))
            frontBubblePath.line(to: NSPoint(x: 0, y: 10))
            frontBubblePath.curve(to: NSPoint(x: 3, y: 13),
                                 controlPoint1: NSPoint(x: 0, y: 11.5),
                                 controlPoint2: NSPoint(x: 1.5, y: 13))
            frontBubblePath.line(to: NSPoint(x: 9, y: 13))
            frontBubblePath.curve(to: NSPoint(x: 12, y: 10),
                                 controlPoint1: NSPoint(x: 10.5, y: 13),
                                 controlPoint2: NSPoint(x: 12, y: 11.5))
            frontBubblePath.line(to: NSPoint(x: 12, y: 5))
            frontBubblePath.curve(to: NSPoint(x: 9, y: 2),
                                 controlPoint1: NSPoint(x: 12, y: 3.5),
                                 controlPoint2: NSPoint(x: 10.5, y: 2))
            frontBubblePath.line(to: NSPoint(x: 3, y: 2))
            frontBubblePath.curve(to: NSPoint(x: 0, y: 1),
                                 controlPoint1: NSPoint(x: 1.5, y: 2),
                                 controlPoint2: NSPoint(x: 0, y: 1.5))
            frontBubblePath.close()
            frontBubblePath.fill()

            return true
        }

        image.isTemplate = true
        return image
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

    /// 创建带数字计数的状态栏图标（无背景，仅数字）
    private func createStatusBarImageWithCount(count: Int) -> NSImage {
        let size = NSSize(width: 28, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in

            // 绘制两个重叠的气泡图标（与原图标相同）
            NSColor.black.setFill()
            NSColor.black.setStroke()

            // 后面的气泡
            let backBubblePath = NSBezierPath()
            backBubblePath.move(to: NSPoint(x: 6, y: 5))
            backBubblePath.line(to: NSPoint(x: 6, y: 14))
            backBubblePath.curve(to: NSPoint(x: 10, y: 17),
                                controlPoint1: NSPoint(x: 6, y: 15.5),
                                controlPoint2: NSPoint(x: 8, y: 17))
            backBubblePath.line(to: NSPoint(x: 15, y: 17))
            backBubblePath.curve(to: NSPoint(x: 18, y: 14),
                                controlPoint1: NSPoint(x: 17, y: 17),
                                controlPoint2: NSPoint(x: 18, y: 15.5))
            backBubblePath.line(to: NSPoint(x: 18, y: 9))
            backBubblePath.curve(to: NSPoint(x: 15, y: 6),
                                controlPoint1: NSPoint(x: 18, y: 7.5),
                                controlPoint2: NSPoint(x: 17, y: 6))
            backBubblePath.line(to: NSPoint(x: 10, y: 6))
            backBubblePath.curve(to: NSPoint(x: 6, y: 5),
                                controlPoint1: NSPoint(x: 8, y: 6),
                                controlPoint2: NSPoint(x: 6, y: 5.5))
            backBubblePath.close()
            backBubblePath.lineWidth = 1.5
            backBubblePath.stroke()

            // 前面的气泡
            let frontBubblePath = NSBezierPath()
            frontBubblePath.move(to: NSPoint(x: 0, y: 1))
            frontBubblePath.line(to: NSPoint(x: 0, y: 10))
            frontBubblePath.curve(to: NSPoint(x: 3, y: 13),
                                 controlPoint1: NSPoint(x: 0, y: 11.5),
                                 controlPoint2: NSPoint(x: 1.5, y: 13))
            frontBubblePath.line(to: NSPoint(x: 9, y: 13))
            frontBubblePath.curve(to: NSPoint(x: 12, y: 10),
                                 controlPoint1: NSPoint(x: 10.5, y: 13),
                                 controlPoint2: NSPoint(x: 12, y: 11.5))
            frontBubblePath.line(to: NSPoint(x: 12, y: 5))
            frontBubblePath.curve(to: NSPoint(x: 9, y: 2),
                                 controlPoint1: NSPoint(x: 12, y: 3.5),
                                 controlPoint2: NSPoint(x: 10.5, y: 2))
            frontBubblePath.line(to: NSPoint(x: 3, y: 2))
            frontBubblePath.curve(to: NSPoint(x: 0, y: 1),
                                 controlPoint1: NSPoint(x: 1.5, y: 2),
                                 controlPoint2: NSPoint(x: 0, y: 1.5))
            frontBubblePath.close()
            frontBubblePath.fill()

            // 在图标右上角绘制数字（无背景）
            let countString = count > 9 ? "9+" : "\(count)"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: NSColor.black
            ]
            let attributedString = NSAttributedString(string: countString, attributes: attributes)
            let textSize = attributedString.size()
            let textRect = NSRect(
                x: size.width - textSize.width - 1,
                y: size.height - textSize.height,
                width: textSize.width,
                height: textSize.height
            )
            attributedString.draw(in: textRect)

            return true
        }

        image.isTemplate = true
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

        // 标题
        let titleItem = NSMenuItem(title: "微信多开助手", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        // 实例列表（只显示运行中的实例）
        let runningInstances = wechatManager.instances.filter { $0.isRunning && !$0.isCreating }
        if runningInstances.isEmpty {
            let emptyItem = NSMenuItem(title: "没有运行中的微信", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for instance in runningInstances {
                let pidText = instance.processId.map { "PID: \($0)" } ?? ""
                let item = NSMenuItem(
                    title: "\(instance.displayName) (\(pidText))",
                    action: #selector(activateInstance(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = instance
                item.image = NSImage(systemSymbolName: "message.fill", accessibilityDescription: nil)
                menu.addItem(item)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // 启动新实例
        let launchItem = NSMenuItem(
            title: "启动新微信",
            action: #selector(launchNewInstance),
            keyEquivalent: "n"
        )
        launchItem.target = self
        launchItem.keyEquivalentModifierMask = [.command]
        launchItem.isEnabled = wechatManager.isWeChatInstalled
        menu.addItem(launchItem)

        // 终止所有实例
        if !runningInstances.isEmpty {
            let terminateAllItem = NSMenuItem(
                title: "终止所有微信",
                action: #selector(terminateAllInstances),
                keyEquivalent: ""
            )
            terminateAllItem.target = self
            menu.addItem(terminateAllItem)
        }

        menu.addItem(NSMenuItem.separator())

        // 显示主窗口
        let showWindowItem = NSMenuItem(
            title: "显示主窗口",
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

    // MARK: - 菜单动作

    /// 激活实例
    @objc private func activateInstance(_ sender: NSMenuItem) {
        guard let instance = sender.representedObject as? WeChatInstance else { return }
        wechatManager.activateInstance(instance)
    }

    /// 启动新实例
    @objc private func launchNewInstance() {
        wechatManager.launchNewInstance()
    }

    /// 终止所有实例
    @objc private func terminateAllInstances() {
        let alert = NSAlert()
        alert.messageText = "确认终止所有微信实例"
        alert.informativeText = "确定要终止所有 \(wechatManager.instances.count) 个微信实例吗？未保存的数据可能会丢失。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "终止")
        alert.addButton(withTitle: "取消")

        if alert.runModal() == .alertFirstButtonReturn {
            wechatManager.terminateAllInstances()
        }
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

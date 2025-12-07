//
//  AppDelegate.swift
//  WeChatMultiOpen
//
//  Created by Yanjunhui
//

import Foundation
import AppKit
import SwiftUI

// MARK: - 通知名称扩展

extension Notification.Name {
    /// 显示更新弹窗的通知
    static let showUpdateSheet = Notification.Name("showUpdateSheet")
}

/// 应用程序代理
/// 处理应用程序生命周期事件和窗口管理
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - 属性

    /// 主窗口
    var mainWindow: NSWindow?

    /// 菜单栏管理器
    private let menuBarManager = MenuBarManager.shared

    /// 微信管理器
    private let wechatManager = WeChatManager.shared

    /// 更新管理器
    private let updateManager = UpdateManager.shared

    /// 是否显示菜单栏图标
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon: Bool = true

    /// 关闭窗口时隐藏到菜单栏
    @AppStorage("hideToMenuBarOnClose") private var hideToMenuBarOnClose: Bool = true

    /// 启动后自动隐藏主窗口
    @AppStorage("hideWindowOnLaunch") private var hideWindowOnLaunch: Bool = false

    /// 启动时检查更新
    @AppStorage("checkUpdateOnLaunch") private var checkUpdateOnLaunch: Bool = true

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 检查是否已有实例在运行，禁止多开
        if checkIfAlreadyRunning() {
            return
        }

        // 设置菜单栏
        if showMenuBarIcon {
            menuBarManager.setup()
            menuBarManager.onShowMainWindow = { [weak self] in
                self?.showMainWindow()
            }
        }

        // 创建主窗口
        createMainWindow()

        // 根据设置决定是否显示主窗口
        if hideWindowOnLaunch && showMenuBarIcon {
            mainWindow?.orderOut(nil)
        } else {
            mainWindow?.makeKeyAndOrderFront(nil)
        }

        // 激活应用
        NSApp.activate(ignoringOtherApps: true)

        // 启动时检查更新（延迟 2 秒，避免影响启动速度）
        if checkUpdateOnLaunch {
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await checkForUpdatesOnLaunch()
            }
        }
    }

    /// 检查应用是否已经在运行
    /// - Returns: true 表示已有实例在运行，当前实例应退出
    private func checkIfAlreadyRunning() -> Bool {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.yanjunhui.WeChatMultiOpen"
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)

        // 如果有超过一个实例在运行（包括当前实例）
        if runningApps.count > 1 {
            // 找到已经在运行的实例（不是当前进程）
            let currentPid = ProcessInfo.processInfo.processIdentifier
            if let existingApp = runningApps.first(where: { $0.processIdentifier != currentPid }) {
                // 激活已有实例的窗口
                existingApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])

                // 直接退出当前实例
                NSApp.terminate(nil)
                return true
            }
        }

        return false
    }

    /// 启动时检查更新
    @MainActor
    private func checkForUpdatesOnLaunch() async {
        if let _ = await updateManager.checkForUpdatesSilently() {
            // 通过通知让 ContentView 显示更新弹窗
            NotificationCenter.default.post(name: .showUpdateSheet, object: nil)
            // 确保主窗口可见
            showMainWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 清理资源
        menuBarManager.remove()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 如果显示菜单栏图标且设置为隐藏到菜单栏，则不退出
        if showMenuBarIcon && hideToMenuBarOnClose {
            return false
        }
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // 关闭所有窗口，确保设置窗口等不会阻止退出
        for window in NSApp.windows {
            window.close()
        }
        return .terminateNow
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 点击 Dock 图标时显示主窗口
        if !flag {
            showMainWindow()
        }
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    // MARK: - 窗口管理

    /// 创建主窗口
    private func createMainWindow() {
        let contentView = ContentView()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "微信多开"
        window.center()
        window.setFrameAutosaveName("MainWindow")
        window.contentView = NSHostingView(rootView: contentView)
        window.minSize = NSSize(width: 420, height: 360)
        window.isReleasedWhenClosed = false
        window.delegate = self

        // 设置窗口外观
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible

        mainWindow = window
    }

    /// 显示主窗口
    func showMainWindow() {
        if mainWindow == nil {
            createMainWindow()
        }

        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 隐藏主窗口
    func hideMainWindow() {
        mainWindow?.orderOut(nil)
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // 如果设置为隐藏到菜单栏，则隐藏窗口而不是关闭
        if showMenuBarIcon && hideToMenuBarOnClose {
            sender.orderOut(nil)
            return false
        }
        return true
    }

    func windowWillClose(_ notification: Notification) {
        // 窗口关闭时的处理
    }
}

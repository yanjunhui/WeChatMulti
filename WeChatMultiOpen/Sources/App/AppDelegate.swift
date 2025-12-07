//
//  AppDelegate.swift
//  WeChatMultiOpen
//
//  Created by Yanjunhui
//

import Foundation
import AppKit
import SwiftUI

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

    /// 是否显示菜单栏图标
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon: Bool = true

    /// 关闭窗口时隐藏到菜单栏
    @AppStorage("hideToMenuBarOnClose") private var hideToMenuBarOnClose: Bool = true

    /// 启动后自动隐藏主窗口
    @AppStorage("hideWindowOnLaunch") private var hideWindowOnLaunch: Bool = false

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
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

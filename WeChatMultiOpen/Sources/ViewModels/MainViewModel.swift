//
//  MainViewModel.swift
//  WeChatMultiOpen
//
//  Created by Yanjunhui
//

import Foundation
import SwiftUI
import Combine

/// 主视图模型
/// 管理主界面的状态和用户交互逻辑
@MainActor
final class MainViewModel: ObservableObject {

    // MARK: - 发布的属性

    /// 微信实例列表
    @Published var instances: [WeChatInstance] = []

    /// 微信是否已安装
    @Published var isWeChatInstalled: Bool = false

    /// 微信应用路径
    @Published var wechatPath: String?

    /// 错误信息
    @Published var errorMessage: String?

    /// 是否显示错误提示
    @Published var showError: Bool = false

    /// 是否正在启动新实例
    @Published var isLaunching: Bool = false

    /// 是否显示设置窗口
    @Published var showSettings: Bool = false

    /// 是否显示关于窗口
    @Published var showAbout: Bool = false

    /// 选中的实例（用于上下文菜单等操作）
    @Published var selectedInstance: WeChatInstance?

    /// 是否显示终止所有确认对话框
    @Published var showTerminateAllConfirmation: Bool = false

    /// 是否显示终止单个确认对话框
    @Published var showTerminateConfirmation: Bool = false

    /// 是否显示删除副本确认对话框
    @Published var showDeleteConfirmation: Bool = false

    // MARK: - 私有属性

    /// 微信管理器
    private let wechatManager = WeChatManager.shared

    /// Combine取消令牌集合
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 计算属性

    /// 运行中的实例数量
    var runningInstanceCount: Int {
        return instances.filter { $0.isRunning }.count
    }

    /// 是否有实例（包括运行中和未运行的副本）
    var hasInstances: Bool {
        return !instances.isEmpty
    }

    /// 是否有运行中的实例
    var hasRunningInstances: Bool {
        return instances.contains { $0.isRunning }
    }

    /// 副本数量（不包括原版微信）
    var copyCount: Int {
        return instances.filter { !$0.isOriginal }.count
    }

    /// 状态描述文本
    var statusText: String {
        if !isWeChatInstalled {
            return "微信未安装"
        } else {
            let runningCount = runningInstanceCount
            let copiesCount = copyCount
            if runningCount == 0 {
                if copiesCount == 0 {
                    return "点击下方按钮启动微信"
                } else {
                    return "有 \(copiesCount) 个副本可用"
                }
            } else {
                return "正在运行 \(runningCount) 个微信"
            }
        }
    }

    // MARK: - 初始化

    init() {
        setupBindings()
    }

    // MARK: - 公共方法

    /// 启动新的微信实例
    func launchNewInstance() {
        wechatManager.launchNewInstance()
    }

    /// 终止指定的微信实例
    func terminateInstance(_ instance: WeChatInstance) {
        wechatManager.terminateInstance(instance)
    }

    /// 终止所有微信实例
    func terminateAllInstances() {
        wechatManager.terminateAllInstances()
    }

    /// 刷新实例列表
    func refreshInstances() {
        wechatManager.refreshInstances()
    }

    /// 激活指定的微信实例窗口
    func activateInstance(_ instance: WeChatInstance) {
        wechatManager.activateInstance(instance)
    }

    /// 复制进程ID到剪贴板
    func copyProcessId(_ instance: WeChatInstance) {
        guard let pid = instance.processId else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("\(pid)", forType: .string)
    }

    /// 重命名实例
    func renameInstance(_ instance: WeChatInstance, to name: String) {
        wechatManager.setCustomName(for: instance.bundleIdentifier, name: name.isEmpty ? nil : name)
    }

    /// 启动指定实例
    func launchInstance(_ instance: WeChatInstance) {
        wechatManager.launchInstance(instance)
    }

    /// 删除副本
    func deleteInstance(_ instance: WeChatInstance) {
        // 查找对应的副本
        if let copy = wechatManager.availableCopies.first(where: { $0.bundleIdentifier == instance.bundleIdentifier }) {
            wechatManager.deleteCopy(copy)
        }
        selectedInstance = nil
        showDeleteConfirmation = false
    }

    /// 显示终止单个实例确认对话框
    func showTerminateConfirmationDialog(for instance: WeChatInstance) {
        selectedInstance = instance
        showTerminateConfirmation = true
    }

    /// 显示删除副本确认对话框
    func showDeleteConfirmationDialog(for instance: WeChatInstance) {
        selectedInstance = instance
        showDeleteConfirmation = true
    }

    /// 确认删除副本
    func confirmDeleteInstance() {
        if let instance = selectedInstance {
            deleteInstance(instance)
        }
        selectedInstance = nil
        showDeleteConfirmation = false
    }

    /// 确认终止单个实例
    func confirmTerminateInstance() {
        if let instance = selectedInstance {
            terminateInstance(instance)
        }
        selectedInstance = nil
        showTerminateConfirmation = false
    }

    /// 显示终止所有实例确认对话框
    func showTerminateAllConfirmationDialog() {
        showTerminateAllConfirmation = true
    }

    /// 确认终止所有实例
    func confirmTerminateAllInstances() {
        terminateAllInstances()
        showTerminateAllConfirmation = false
    }

    /// 取消操作
    func cancelOperation() {
        selectedInstance = nil
        showTerminateConfirmation = false
        showTerminateAllConfirmation = false
        showDeleteConfirmation = false
    }

    /// 清除错误
    func clearError() {
        errorMessage = nil
        showError = false
    }

    /// 打开微信官方下载页面
    func openWeChatDownloadPage() {
        if let url = URL(string: "https://mac.weixin.qq.com/") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 在Finder中显示微信应用
    func showWeChatInFinder() {
        if let path = wechatPath {
            NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
        }
    }

    // MARK: - 私有方法

    /// 设置数据绑定
    private func setupBindings() {
        // 绑定实例列表
        wechatManager.$instances
            .receive(on: DispatchQueue.main)
            .assign(to: &$instances)

        // 绑定微信安装状态
        wechatManager.$isWeChatInstalled
            .receive(on: DispatchQueue.main)
            .assign(to: &$isWeChatInstalled)

        // 绑定微信路径
        wechatManager.$wechatPath
            .receive(on: DispatchQueue.main)
            .assign(to: &$wechatPath)

        // 绑定错误信息
        wechatManager.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                if let message = message {
                    self?.errorMessage = message
                    self?.showError = true
                }
            }
            .store(in: &cancellables)

        // 绑定启动状态
        wechatManager.$isLaunching
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLaunching)
    }
}

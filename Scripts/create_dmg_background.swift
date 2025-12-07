#!/usr/bin/env swift
//
//  create_dmg_background.swift
//  Created by Yanjunhui
//

import Cocoa

// 创建背景图
func createDMGBackground() {
    let width: CGFloat = 660
    let height: CGFloat = 400

    // 创建图像
    let image = NSImage(size: NSSize(width: width, height: height))

    image.lockFocus()

    // 默认浅灰色背景
    NSColor(white: 0.95, alpha: 1.0).setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()

    // 绘制箭头
    let arrowPath = NSBezierPath()
    let arrowCenterY: CGFloat = height / 2 + 20
    let arrowStartX: CGFloat = 240
    let arrowEndX: CGFloat = 420
    let arrowHeadSize: CGFloat = 30

    // 箭头线
    arrowPath.move(to: NSPoint(x: arrowStartX, y: arrowCenterY))
    arrowPath.line(to: NSPoint(x: arrowEndX - arrowHeadSize, y: arrowCenterY))

    // 箭头头部
    arrowPath.move(to: NSPoint(x: arrowEndX - arrowHeadSize, y: arrowCenterY + arrowHeadSize / 2))
    arrowPath.line(to: NSPoint(x: arrowEndX, y: arrowCenterY))
    arrowPath.line(to: NSPoint(x: arrowEndX - arrowHeadSize, y: arrowCenterY - arrowHeadSize / 2))

    arrowPath.lineWidth = 4
    arrowPath.lineCapStyle = .round
    arrowPath.lineJoinStyle = .round

    NSColor(white: 0.5, alpha: 0.8).setStroke()
    arrowPath.stroke()

    // 绘制提示文字
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center

    let titleAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 14, weight: .regular),
        .foregroundColor: NSColor(white: 0.4, alpha: 1.0),
        .paragraphStyle: paragraphStyle
    ]

    let title = "拖动应用到「应用程序」文件夹完成安装"
    let titleRect = NSRect(x: 0, y: 60, width: width, height: 30)
    title.draw(in: titleRect, withAttributes: titleAttributes)

    image.unlockFocus()

    // 保存为 PNG
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Error: Failed to create PNG data")
        return
    }

    let outputPath = "/tmp/dmg_background.png"
    do {
        try pngData.write(to: URL(fileURLWithPath: outputPath))
        print("Background image created: \(outputPath)")
    } catch {
        print("Error saving image: \(error)")
    }
}

createDMGBackground()

#!/bin/bash
#
#  create_dmg.sh
#  Created by Yanjunhui
#
#  用于创建带引导背景的 DMG 安装包
#

set -e

# 配置参数
APP_NAME="微信多开"
VERSION="${1:-1.0.0}"
DMG_NAME="${APP_NAME}_v${VERSION}.dmg"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="/tmp/dmg_build_$$"
TEMP_DMG="/tmp/${APP_NAME}_temp_$$.dmg"
OUTPUT_DIR="${2:-$HOME/Desktop}"
OUTPUT_DMG="${OUTPUT_DIR}/${DMG_NAME}"
BACKGROUND_IMAGE="${SCRIPT_DIR}/dmg_background.png"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查应用路径
APP_PATH=""
if [ -n "$3" ]; then
    APP_PATH="$3"
elif [ -f "$HOME/Desktop/${APP_NAME}.app/Contents/Info.plist" ]; then
    APP_PATH="$HOME/Desktop/${APP_NAME}.app"
else
    echo_error "未找到应用，请指定应用路径"
    echo "用法: $0 <版本号> [输出目录] [应用路径]"
    echo "示例: $0 1.0.2"
    echo "示例: $0 1.0.2 ~/Desktop ~/Desktop/微信多开.app"
    exit 1
fi

echo_info "开始创建 DMG: ${DMG_NAME}"
echo_info "应用路径: ${APP_PATH}"
echo_info "输出目录: ${OUTPUT_DIR}"

# 检查背景图是否存在，不存在则生成
if [ ! -f "$BACKGROUND_IMAGE" ]; then
    echo_info "生成背景图..."
    swift "${SCRIPT_DIR}/create_dmg_background.swift"
    if [ -f "/tmp/dmg_background.png" ]; then
        cp /tmp/dmg_background.png "$BACKGROUND_IMAGE"
    fi
fi

# 清理旧文件
echo_info "清理临时文件..."
rm -rf "$BUILD_DIR"
rm -f "$TEMP_DMG"
rm -f "$OUTPUT_DMG"

# 创建构建目录
echo_info "准备构建目录..."
mkdir -p "$BUILD_DIR/.background"
cp "$BACKGROUND_IMAGE" "$BUILD_DIR/.background/background.png"
cp -R "$APP_PATH" "$BUILD_DIR/"
ln -s /Applications "$BUILD_DIR/应用程序"

# 计算需要的磁盘大小
APP_SIZE=$(du -sm "$APP_PATH" | cut -f1)
DMG_SIZE=$((APP_SIZE + 20))  # 额外 20MB 空间

# 创建可写 DMG
echo_info "创建临时 DMG..."
hdiutil create -volname "$APP_NAME" -srcfolder "$BUILD_DIR" -ov -format UDRW -size ${DMG_SIZE}m "$TEMP_DMG"

# 挂载 DMG
echo_info "挂载 DMG..."
MOUNT_OUTPUT=$(hdiutil attach "$TEMP_DMG" -readwrite -noverify -noautoopen)
VOLUME_PATH=$(echo "$MOUNT_OUTPUT" | grep -o '/Volumes/.*' | head -1)
VOLUME_NAME=$(basename "$VOLUME_PATH")

echo_info "挂载点: $VOLUME_PATH"

# 配置 DMG 窗口外观（使用深色模式让文字变白）
echo_info "配置窗口外观..."

# 方法：将背景设为纯黑色，Finder 会自动使用白色文字
osascript << EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {100, 100, 760, 500}
        set viewOptions to icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 100
        set text size of viewOptions to 13
        set background picture of viewOptions to file ".background:background.png"
        set position of item "${APP_NAME}.app" of container window to {150, 200}
        set position of item "应用程序" of container window to {510, 200}
        close
        open
        update without registering applications
        delay 3
        close
    end tell
end tell
EOF

# 卸载 DMG
echo_info "卸载临时 DMG..."
sync
sleep 2
hdiutil detach "$VOLUME_PATH" -force

# 转换为压缩格式
echo_info "压缩 DMG..."
hdiutil convert "$TEMP_DMG" -format UDZO -o "$OUTPUT_DMG"

# 清理临时文件
echo_info "清理临时文件..."
rm -rf "$BUILD_DIR"
rm -f "$TEMP_DMG"

# 显示结果
DMG_SIZE=$(ls -lh "$OUTPUT_DMG" | awk '{print $5}')
echo ""
echo_info "✅ DMG 创建完成!"
echo_info "📦 文件: $OUTPUT_DMG"
echo_info "📊 大小: $DMG_SIZE"

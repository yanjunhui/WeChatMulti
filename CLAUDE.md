# 微信多开 - 项目规则

## 项目概述

微信多开是一款 macOS 应用，允许用户同时运行多个微信实例。

## 技术栈

- **语言**: Swift 5.9+
- **UI 框架**: SwiftUI
- **最低支持版本**: macOS 13.0+
- **架构**: MVVM

## 项目结构

```
WeChatMulti/
├── WeChatMultiOpen/
│   ├── Sources/
│   │   ├── App/              # 应用入口
│   │   ├── Views/            # 视图组件
│   │   ├── ViewModels/       # 视图模型
│   │   ├── Models/           # 数据模型
│   │   ├── Services/         # 服务层
│   │   └── Theme/            # 主题样式
│   └── Resources/            # 资源文件
├── Scripts/                  # 脚本工具
│   ├── create_dmg.sh         # DMG 打包脚本
│   ├── create_dmg_background.swift  # 背景图生成脚本
│   └── dmg_background.png    # DMG 背景图
└── README.md
```

## DMG 打包规则

### 使用打包脚本

```bash
# 基本用法（应用需放在桌面）
./Scripts/create_dmg.sh <版本号>

# 示例
./Scripts/create_dmg.sh 1.0.2

# 指定输出目录和应用路径
./Scripts/create_dmg.sh <版本号> <输出目录> <应用路径>

# 示例
./Scripts/create_dmg.sh 1.0.2 ~/Desktop ~/Desktop/微信多开.app
```

### 打包流程

1. 在 Xcode 中 Archive 并导出应用到桌面
2. 运行打包脚本：`./Scripts/create_dmg.sh 版本号`
3. DMG 文件将生成在桌面

### DMG 规格

- **窗口尺寸**: 660 x 400
- **背景**: 深色渐变 + 箭头引导
- **图标大小**: 100px
- **应用位置**: 左侧 (150, 200)
- **Applications 位置**: 右侧 (510, 200)

### 重新生成背景图

如需修改背景图样式，编辑 `Scripts/create_dmg_background.swift` 后运行：

```bash
swift Scripts/create_dmg_background.swift
```

## 版本发布流程

1. 更新 `project.pbxproj` 中的 `MARKETING_VERSION`
2. 提交代码并创建 tag：
   ```bash
   git add .
   git commit -m "chore: 更新版本号至 x.x.x"
   git tag vx.x.x
   git push && git push origin vx.x.x
   ```
3. 在 Xcode 中 Archive 并导出应用
4. 运行 DMG 打包脚本
5. 在 GitHub Releases 页面上传 DMG 文件

## 代码规范

- 文件头部版权注释：`Created by Yanjunhui`
- 单文件代码行数不超过 800 行
- 使用中文注释
- 遵循 SwiftUI 最佳实践

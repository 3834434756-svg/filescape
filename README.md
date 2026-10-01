# Filescape

一个**不用文件夹列表**看文件的 iOS 文件管理器。

系统文件管理器是"列表 + 一层层下钻"。Filescape 不是 —— 它把文件按类型聚成**星团**，散落在一张可缩放平移的画布上，捏合缩放、拖动平移、长按弹环形菜单。四个视角回答四个不同的问题：

| 视角 | 回答的问题 | 形态 |
|---|---|---|
| **星图** | 我的文件是怎么分布的？ | 按类型分簇的卡片，散在可缩放画布上 |
| **时间** | 我最近动过什么？ | 按天切分的横带，越新越靠上 |
| **类型** | 哪类东西占了地方？ | 每类一张大卡，先给结论再给细节 |
| **清单** | 到底有哪些文件？ | 紧凑列表，扫一遍看全 |

## 能力边界（先看这个）

**Filescape 只能访问它自己的沙盒目录。** 这不是权限没申请，是 iOS 的内核级沙盒设计 —— 任何 App 都读不了别人的文件，读 `/var`、`/System` 这些系统目录必须越狱。Filza 能浏览整个文件系统，是因为它运行在越狱设备上，能力来自 root 权限，不是来自某个 API。

所以"像 Filza 一样但不要越狱"在技术上不成立。Filescape 做的是**非越狱条件下真能落地的那部分**：

| 能做 | 做不到 |
|---|---|
| 浏览、整理自己的沙盒目录 | 浏览系统目录（/var、/System） |
| 从 iCloud / 「文件」App 导入 | 读取其他 App 的私有数据 |
| 用数据线从电脑拖文件进去 | 访问相册、通讯录等 |
| 预览图片 / PDF / 文本 / Office / 视频 | 越权读取任何东西 |

## 怎么把文件放进来

1. **App 内导入** —— 右下角「+」→「从「文件」导入」，从 iCloud Drive 或本机「文件」App 里选，支持多选。
2. **数据线** —— 连上电脑，在 Finder（macOS）或爱思助手 / iMazing（Windows）里找到 Filescape，直接把文件拖进目录。这一条靠 `UIFileSharingEnabled` 实现。

## 构建

产物是**未签名 IPA**，全流程跑在 GitHub 托管的 macOS runner 上，本机不需要 Mac、不需要 Xcode。

推送到 `main` 自动触发，也可以在 Actions 页面手动 Run。构建约 5–15 分钟，完成后：

- Actions 页面的 Artifacts 里能下到 `unsigned-ipa`
- Releases 里也能下到（`build-<run号>`），Release 下载不需要登录

本地构建（需要 Mac + Xcode）：

```bash
brew install xcodegen
xcodegen generate
open Filescape.xcodeproj
```

## 安装

**未签名 IPA 不能直接装。** 必须重签，两条路：

| 方式 | 工具 | 有效期 | 需要付费账号 |
|---|---|---|---|
| 免费 Apple ID 自签 | Sideloadly / AltStore / SideStore | 7 天 | ❌ |
| 自备证书 Ad-Hoc 签名 | 自己的开发者证书 | 1 年 | ✅ $99/年 |

免费自签的限制是 Apple 定的：7 天到期要重签，同时最多 3 个自签 App。任何云打包方案都绕不过去。

## 工程结构

```
filescape/
├── project.yml                    # XcodeGen 工程定义（不用手写 pbxproj）
├── Sources/
│   ├── FilescapeApp.swift         # 入口
│   ├── Models/
│   │   ├── FileKind.swift         # 类型分类 + 配色
│   │   ├── FileItem.swift         # 文件模型
│   │   └── FileStore.swift        # 数据层 + 全部文件操作
│   ├── Views/
│   │   ├── RootView.swift         # 主界面 + 顶栏 + 悬浮操作
│   │   ├── CanvasView.swift       # 星图（核心）
│   │   ├── ChronoView.swift       # 时间轴
│   │   ├── KindBoardView.swift    # 类型看板
│   │   ├── RosterView.swift       # 清单
│   │   ├── FileCardView.swift     # 文件卡片
│   │   ├── RadialMenu.swift       # 环形操作菜单
│   │   ├── InspectorPanel.swift   # 详情 / 重命名 / 新建
│   │   ├── PreviewSheet.swift     # QuickLook 预览
│   │   └── Components.swift       # 复用组件
│   └── Support/
│       ├── Theme.swift            # 视觉主题
│       ├── ThumbnailProvider.swift# 缩略图 + 缓存
│       └── DocumentPicker.swift   # 系统文件选择器
├── Resources/
│   ├── Info.plist                 # 开启文件共享与就地打开
│   └── Assets.xcassets/           # AppIcon
└── .github/workflows/build-ipa.yml
```

## 技术要点

- **SwiftUI，iOS 16.0+**，无第三方依赖。
- **工程用 XcodeGen 生成** —— `pbxproj` 是二进制混乱的 XML，多人协作时冲突不断。`project.yml` 是唯一事实来源，工程文件不进版本库。
- **星图布局是确定性伪随机** —— 卡片位置由路径字符串 hash 出偏移量。用真随机的话每次刷新卡片都会乱跳。
- **缩略图走 QuickLookThumbnailing** —— 不按扩展名分支自己解码，PDF / Office / 视频封面都能出图，且系统负责降采样。
- **打包必须 `zip -y`** —— `.app` 里的 framework 大量用符号链接，展平后装到手机上直接报错。

## 许可

自用 / 小范围测试。不适合上架 App Store。

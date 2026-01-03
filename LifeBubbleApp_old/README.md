# LifeBubble iOS App

让梦想轻盈地浮现，用指尖点亮每一天。

## 📱 项目说明

这是 LifeBubble 的 iOS 原生应用，使用 SwiftUI 构建，完全遵循产品设计文档的视觉和交互要求。

## 🚀 在 Xcode 中运行

### 方法一：创建新项目并导入文件

1. **打开 Xcode**，选择 `Create a new Xcode project`

2. **选择模板**：
   - iOS → App
   - 点击 Next

3. **配置项目**：
   - Product Name: `LifeBubble`
   - Team: 选择你的开发团队（或 None）
   - Organization Identifier: `com.yourname`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - 取消勾选 Core Data、Tests
   - 点击 Next，选择保存位置

4. **导入文件**：
   - 在 Finder 中打开 `/Users/xinyao/Desktop/dream/LifeBubbleApp/`
   - 将以下文件拖入 Xcode 项目中（选择 Copy items if needed）：
     ```
     LifeBubbleApp/
     ├── LifeBubbleApp.swift
     ├── ContentView.swift
     └── Views/
         ├── SplashView.swift
         ├── HomeView.swift
         ├── ChatView.swift
         ├── CalendarView.swift
         ├── ArchiveView.swift
         └── MainTabView.swift
     ```

5. **删除默认文件**：
   - 删除 Xcode 自动生成的旧 `ContentView.swift`（如果提示冲突）
   - 保留我们提供的新文件

6. **运行项目**：
   - 选择模拟器：iPhone 15 Pro（推荐）
   - 点击 ▶️ Run 按钮
   - 或使用快捷键：`Cmd + R`

### 方法二：使用命令行（需要 Xcode Command Line Tools）

```bash
# 进入项目目录
cd /Users/xinyao/Desktop/dream

# 使用 swift package 创建项目（如果需要）
# 或直接在 Finder 中双击 .xcodeproj 文件打开
```

## 📂 项目结构

```
LifeBubbleApp/
├── LifeBubbleApp.swift      # 应用入口、状态管理、数据模型
├── ContentView.swift         # 根视图、页面路由
└── Views/
    ├── SplashView.swift      # 启动页（呼吸入口）
    ├── HomeView.swift        # 主页（泡泡海）
    ├── ChatView.swift        # AI对话（灵感共振）
    ├── CalendarView.swift    # 日历（生命星图）
    ├── ArchiveView.swift     # 档案（内在星系）
    └── MainTabView.swift     # 备选导航方案
```

## ✨ 核心功能

### 1. 呼吸入口 (SplashView)
- 中心光球呼吸动画
- 长按1秒触发粒子破碎效果
- 平滑过渡到主页

### 2. 当下泡泡海 (HomeView)
- 核心泡泡（大）+ 琐事泡泡（小）
- 浮动动画模拟物理效果
- 点击泡泡 → 粒子流动画 → 自动移除
- 底部发射台唤起 AI 对话
- 右下角档案入口脉动提示

### 3. AI 灵感共振室 (ChatView)
- AI 母体泡泡状态变化（思考时变蓝）
- 实时对话交互
- 打字中指示器（三点跳动）
- 玻璃拟态对话气泡

### 4. 生命星图 (CalendarView)
- 31天圆环日历阵列
- 今天：明亮脉动光环
- 过去：实心（完成）/半透明（未完成）
- 未来：虚线幽灵泡泡
- 星空背景动画

### 5. 内在星系 (ArchiveView)
- 成就星星（3种大小）
- 点击星星查看详情弹窗
- 身份卡片展示
- 统计面板（完成数、里程碑、连续天数）
- 星云脉动背景

## 🎨 设计特点

- **色彩体系**：米色背景、柔和渐变、玻璃拟态材质
- **呼吸感**：6-8秒周期的背景律动
- **流畅动画**：所有交互都有丝滑的过渡效果
- **触觉反馈**：点击、长按都有震动反馈
- **响应式设计**：适配不同尺寸的 iPhone

## 🔧 技术栈

- **SwiftUI**：声明式 UI 框架
- **纯原生**：零第三方依赖
- **状态管理**：ObservableObject + @Published
- **动画系统**：隐式动画 + 显式动画
- **渐变效果**：Linear/Radial Gradient
- **模糊效果**：Ultra Thin Material
- **触觉反馈**：UIImpactFeedbackGenerator

## 📱 推荐测试设备

- iPhone 15 Pro (模拟器)
- iPhone 14 Pro (模拟器)
- 真机测试效果更佳

## ⚠️ 注意事项

1. **最低系统要求**：iOS 16.0+
2. **Xcode 版本**：Xcode 15.0+
3. **开发语言**：Swift 5.9+

## 🎯 下一步开发

当前版本是完整的 UI 原型，包含所有界面和交互动画。后续可以添加：

1. **SpriteKit 物理引擎**：实现真实的泡泡碰撞和重力感应
2. **AI 集成**：接入 Claude API 实现真实对话
3. **数据持久化**：使用 SwiftData 或 Core Data 保存用户数据
4. **iCloud 同步**：跨设备数据同步
5. **通知提醒**：每日提醒功能
6. **订阅系统**：StoreKit 2 集成

## 📝 许可证

本项目仅供学习和演示使用。

---

**开发者**: Claude
**版本**: v1.0
**日期**: 2026-01-01

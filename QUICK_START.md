# 🚀 快速启动指南

## 1️⃣ 立即运行测试

```bash
cd /Users/xinyao/Desktop/dream/LifeBubbleApp
open LifeBubble.xcodeproj
```

在 Xcode 中按 **⌘ + R** 运行。

---

## 2️⃣ 体验新功能

### Splash 页面
1. 启动 App 后会看到打字机效果的每日寄语
2. **长按**中心的金色肥皂泡光球
3. 保持按住 2.5 秒，观察泡泡膨胀填满屏幕
4. 看到彩色碎片爆炸效果后，进入主页

### Home 页面
1. 观察泡泡的**自然漂浮**（受空气流动影响）
2. **轻触泡泡**：戳破 → 流沙粒子飞向右下角
3. **拖拽并快速甩向边缘**：推迟到明天（显示提示）
4. **长按底部发射台**：创建新泡泡（跳转到聊天页面）

### Calendar 页面
1. 点击顶部导航栏的日历图标
2. 观察不同日期的视觉效果：
   - **今天**: 明亮脉动的肥皂泡
   - **过去已完成**: 褪色金色
   - **未来**: 虚线幽灵泡泡
3. 点击今天或已完成的日期 → Zoom In 动画 → 返回主页

---

## 3️⃣ 添加音频文件（可选）

### 创建音频资源文件夹
```bash
mkdir -p LifeBubbleApp/Resources/Sounds
```

### 准备音频文件
将以下文件放入 `LifeBubbleApp/Resources/Sounds/`:
- `pop.mp3` - 泡泡破裂音效
- `create.mp3` - 创建泡泡音效
- `transition.mp3` - 转场音效
- `complete.mp3` - 完成任务音效

### 在 Xcode 中添加资源
1. 在 Xcode 项目导航器中右键点击 `LifeBubbleApp`
2. 选择 `Add Files to "LifeBubbleApp"...`
3. 选择 `Sounds` 文件夹
4. 确保勾选 `Copy items if needed`

---

## 4️⃣ 自定义调整

### 修改泡泡颜色
编辑 `SoapBubbleShader.swift`:
```swift
// 核心泡泡颜色
static func core(size: CGFloat) -> some View {
    SoapBubbleView(
        size: size,
        baseColors: [
            Color(hex: "你的颜色1"),
            Color(hex: "你的颜色2"),
            Color(hex: "你的颜色3"),
            Color(hex: "你的颜色4")
        ],
        intensity: 1.0
    )
}
```

### 调整物理参数
编辑 `BubbleScene.swift`:
```swift
// 重力强度
physicsWorld.gravity = CGVector(dx: 0, dy: -0.2)  // 减小 = 更漂浮

// 漂浮场强度
noiseField.strength = 0.3      // 增大 = 更活跃
turbulenceField.strength = 0.15 // 增大 = 更随机

// 软碰撞强度
repulsionField.strength = -1.5  // 减小绝对值 = 更软
```

### 修改手势阈值
编辑 `BubbleScene.swift`:
```swift
// 推迟手势
let isFlingGesture = velocity > 800 && distance > 100
// 减小数值 = 更容易触发
```

---

## 5️⃣ 故障排查

### 问题：泡泡不显示
**解决方案**: 检查 `AppState` 中 `bubbles` 数组是否有数据
```swift
// LifeBubbleApp.swift 中
init() {
    bubbles = [
        Bubble(text: "测试泡泡", type: .core, position: CGPoint(x: 0.5, y: 0.3))
    ]
}
```

### 问题：粒子效果卡顿
**解决方案**: 减少粒子数量
```swift
// BezierParticleFlow.swift
for i in 0..<25 {  // 改为 15
```

### 问题：SpriteKit 泡泡位置不正确
**解决方案**: 调整坐标转换
```swift
// BubbleScene.swift
let skPosition = CGPoint(
    x: bubble.position.x * size.width,
    y: (1.0 - bubble.position.y) * size.height  // Y 轴翻转
)
```

### 问题：音频不播放
**检查**:
1. 文件是否添加到 Xcode 项目
2. 文件扩展名是否正确（.mp3）
3. `SoundManager.isSoundEnabled` 是否为 `true`

---

## 6️⃣ 性能优化建议

### 限制泡泡数量
```swift
// AppState.swift
func addBubble(_ bubble: Bubble) {
    guard bubbles.count < 15 else { return }  // 最多 15 个
    bubbles.append(bubble)
}
```

### 优化粒子系统
使用 CAEmitterLayer 替代自定义粒子:
```swift
let emitter = CAEmitterLayer()
emitter.emitterPosition = startPoint
emitter.emitterShape = .point
// ... 配置 emitterCells
```

---

## 7️⃣ 关键文件速查

| 功能 | 文件路径 |
|------|----------|
| 肥皂泡材质 | `Components/SoapBubbleShader.swift` |
| 打字机效果 | `Components/TypewriterText.swift` |
| SpriteKit 节点 | `SpriteKit/BubbleNode.swift` |
| 物理场景 | `SpriteKit/BubbleScene.swift` |
| 声音管理 | `Managers/SoundManager.swift` |
| Splash 页面 | `Views/SplashView.swift` |
| Home 页面 | `Views/HomeView.swift` |
| Calendar 页面 | `Views/CalendarView.swift` |

---

## 📞 技术支持

遇到问题？检查这些常见原因：

1. ✅ Xcode 版本 ≥ 15.0
2. ✅ iOS 部署目标 ≥ 17.0
3. ✅ 所有新文件已添加到项目
4. ✅ Build Clean（⌘ + Shift + K）
5. ✅ 重启 Xcode

---

**祝你的梦想像泡泡一样轻盈地浮现！** ✨

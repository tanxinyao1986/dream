# Dream - AI生命伴侣 iOS App

一款集**目标管理**与**心理疗愈**于一体的AI生命伴侣应用。

## 🎯 核心功能

1. **阶段性目标管理** - 帮助用户梳理和追踪长期目标
2. **每日任务清单** - 将大目标分解为可执行的每日小任务
3. **完成度追踪** - 记录每日、每周、每月的任务完成情况
4. **AI智能总结** - 提供个性化的反思和鼓励
5. **心理疗愈陪伴** - AI对话支持，提供情感支持

## 📁 项目文件

```
dream/
├── .env                    # Supabase 配置（不提交到 Git）
├── .mcp.json              # MCP 服务器配置
├── .gitignore             # Git 忽略文件
├── database_schema.md     # 数据库设计文档
├── supabase_setup.sql     # 数据库初始化 SQL 脚本
└── README.md              # 项目说明文档
```

## 🚀 快速开始

### 1. 配置 Supabase

#### 步骤 1：运行 SQL 脚本

1. 登录 [Supabase Dashboard](https://supabase.com/dashboard)
2. 选择 **dream** 项目
3. 点击左侧菜单的 **SQL Editor**
4. 点击 **New Query**
5. 复制 `supabase_setup.sql` 的全部内容
6. 粘贴到编辑器中
7. 点击 **Run** 执行

#### 步骤 2：启用用户认证

1. 在 Supabase Dashboard 中，点击 **Authentication**
2. 点击 **Providers**
3. 启用 **Email** 认证（已默认启用）
4. 可选：启用其他登录方式（Apple、Google 等）

#### 步骤 3：验证数据库

1. 点击 **Table Editor**
2. 应该能看到以下表：
   - users
   - goals
   - daily_tasks
   - daily_reflections
   - weekly_summaries
   - monthly_summaries
   - ai_conversations

### 2. iOS 项目集成

#### 安装 Supabase Swift SDK

使用 Swift Package Manager：

1. 在 Xcode 中打开项目
2. File → Add Package Dependencies
3. 输入：`https://github.com/supabase/supabase-swift`
4. 添加以下包：
   - Supabase
   - Auth
   - PostgREST
   - Storage
   - Realtime

#### 创建 Supabase 客户端

创建 `SupabaseManager.swift`：

\`\`\`swift
import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        // 从环境变量或配置文件读取
        guard let supabaseURL = ProcessInfo.processInfo.environment["SUPABASE_URL"],
              let supabaseKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"],
              let url = URL(string: supabaseURL) else {
            fatalError("Missing Supabase configuration")
        }

        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: supabaseKey
        )
    }
}
\`\`\`

## 📊 数据库结构

详细的数据库设计请查看 [database_schema.md](./database_schema.md)

### 核心表

- **users** - 用户信息
- **goals** - 阶段性目标
- **daily_tasks** - 每日任务
- **daily_reflections** - 每日反思
- **weekly_summaries** - 周总结
- **monthly_summaries** - 月总结
- **ai_conversations** - AI对话记录

## 🔐 安全性

- ✅ 所有表都启用了 Row Level Security (RLS)
- ✅ 用户只能访问自己的数据
- ✅ API 密钥存储在 `.env` 文件中（不提交到 Git）
- ✅ 使用 Supabase Auth 进行用户认证

## 📝 环境变量

`.env` 文件内容：

\`\`\`
SUPABASE_URL=https://fvvxpizfqoeknubjjcpr.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here
\`\`\`

**重要：** 不要将 `.env` 文件提交到 Git！

## 🛠️ 技术栈

- **前端**: Swift / SwiftUI
- **后端**: Supabase
- **数据库**: PostgreSQL
- **认证**: Supabase Auth
- **AI**: OpenAI / Claude API（待集成）

## 📱 功能规划

### Phase 1 - MVP（最小可行产品）
- [x] 数据库设计
- [ ] 用户注册/登录
- [ ] 创建和管理目标
- [ ] 每日任务清单
- [ ] 任务完成追踪

### Phase 2 - AI 集成
- [ ] AI 对话功能
- [ ] 智能目标建议
- [ ] 每日/周/月总结生成

### Phase 3 - 高级功能
- [ ] 数据可视化
- [ ] 社交分享
- [ ] 提醒通知
- [ ] 数据导出

## 📄 许可证

私有项目

## 👨‍💻 开发者

开发中...

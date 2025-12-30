# Dream App - 数据库设计

## 概述
一款集目标管理与心理疗愈于一体的AI生命伴侣

## 核心功能
1. 用户认证系统
2. 阶段性目标管理
3. 每日任务清单
4. 完成情况追踪
5. 周/月总结与AI分析

---

## 数据库表结构

### 1. users（用户表）
用户基本信息和认证

| 字段名 | 类型 | 说明 |
|--------|------|------|
| id | UUID | 主键 |
| email | VARCHAR | 邮箱（唯一） |
| display_name | VARCHAR | 显示名称 |
| avatar_url | TEXT | 头像URL |
| created_at | TIMESTAMP | 创建时间 |
| updated_at | TIMESTAMP | 更新时间 |

### 2. goals（阶段性目标表）
用户的长期/阶段性目标

| 字段名 | 类型 | 说明 |
|--------|------|------|
| id | UUID | 主键 |
| user_id | UUID | 用户ID（外键） |
| title | VARCHAR | 目标标题 |
| description | TEXT | 目标描述 |
| start_date | DATE | 开始日期 |
| target_date | DATE | 目标完成日期 |
| status | VARCHAR | 状态：planning, active, completed, archived |
| category | VARCHAR | 分类：career, health, learning, personal等 |
| priority | INTEGER | 优先级（1-5） |
| created_at | TIMESTAMP | 创建时间 |
| updated_at | TIMESTAMP | 更新时间 |

### 3. daily_tasks（每日任务表）
从目标分解的每日任务

| 字段名 | 类型 | 说明 |
|--------|------|------|
| id | UUID | 主键 |
| user_id | UUID | 用户ID（外键） |
| goal_id | UUID | 关联的目标ID（外键，可为空） |
| title | VARCHAR | 任务标题 |
| description | TEXT | 任务描述 |
| scheduled_date | DATE | 计划日期 |
| is_completed | BOOLEAN | 是否完成 |
| completed_at | TIMESTAMP | 完成时间 |
| priority | INTEGER | 优先级（1-5） |
| estimated_minutes | INTEGER | 预计耗时（分钟） |
| actual_minutes | INTEGER | 实际耗时（分钟） |
| created_at | TIMESTAMP | 创建时间 |
| updated_at | TIMESTAMP | 更新时间 |

### 4. daily_reflections（每日反思记录）
每日的总结和AI反馈

| 字段名 | 类型 | 说明 |
|--------|------|------|
| id | UUID | 主键 |
| user_id | UUID | 用户ID（外键） |
| reflection_date | DATE | 反思日期（唯一） |
| total_tasks | INTEGER | 当日总任务数 |
| completed_tasks | INTEGER | 完成任务数 |
| completion_rate | DECIMAL | 完成率 |
| user_mood | VARCHAR | 用户心情：great, good, okay, bad |
| user_notes | TEXT | 用户笔记 |
| ai_reflection | TEXT | AI生成的反思/鼓励 |
| created_at | TIMESTAMP | 创建时间 |
| updated_at | TIMESTAMP | 更新时间 |

### 5. weekly_summaries（周总结表）
每周自动生成的总结

| 字段名 | 类型 | 说明 |
|--------|------|------|
| id | UUID | 主键 |
| user_id | UUID | 用户ID（外键） |
| week_start | DATE | 周开始日期 |
| week_end | DATE | 周结束日期 |
| total_tasks | INTEGER | 总任务数 |
| completed_tasks | INTEGER | 完成任务数 |
| completion_rate | DECIMAL | 完成率 |
| top_categories | JSONB | 主要完成的目标分类 |
| ai_insights | TEXT | AI生成的周总结洞察 |
| highlights | TEXT | 本周亮点 |
| created_at | TIMESTAMP | 创建时间 |

### 6. monthly_summaries（月总结表）
每月自动生成的总结

| 字段名 | 类型 | 说明 |
|--------|------|------|
| id | UUID | 主键 |
| user_id | UUID | 用户ID（外键） |
| month | INTEGER | 月份（1-12） |
| year | INTEGER | 年份 |
| total_tasks | INTEGER | 总任务数 |
| completed_tasks | INTEGER | 完成任务数 |
| completion_rate | DECIMAL | 完成率 |
| goals_completed | INTEGER | 完成的目标数 |
| achievements | JSONB | 主要成就列表 |
| ai_insights | TEXT | AI生成的月总结洞察 |
| mood_trend | VARCHAR | 心情趋势 |
| created_at | TIMESTAMP | 创建时间 |

### 7. ai_conversations（AI对话记录）
用于心理疗愈的AI对话

| 字段名 | 类型 | 说明 |
|--------|------|------|
| id | UUID | 主键 |
| user_id | UUID | 用户ID（外键） |
| session_id | UUID | 会话ID（可用于分组对话） |
| user_message | TEXT | 用户消息 |
| ai_response | TEXT | AI回复 |
| context_type | VARCHAR | 上下文类型：goal_planning, daily_check, emotional_support等 |
| created_at | TIMESTAMP | 创建时间 |

---

## 表关系

```
users
  ├── goals (一对多)
  ├── daily_tasks (一对多)
  ├── daily_reflections (一对多)
  ├── weekly_summaries (一对多)
  ├── monthly_summaries (一对多)
  └── ai_conversations (一对多)

goals
  └── daily_tasks (一对多)
```

---

## 安全策略（Row Level Security）

所有表都需要启用 RLS，确保用户只能访问自己的数据：
- users: 用户只能读取和更新自己的信息
- goals/tasks/reflections/summaries: 只能访问 user_id = auth.uid() 的数据
- ai_conversations: 只能访问自己的对话记录

---

## 索引建议

- `daily_tasks.user_id` + `scheduled_date` （查询某天的任务）
- `daily_tasks.goal_id` （查询目标的所有任务）
- `goals.user_id` + `status` （查询用户的活跃目标）
- `daily_reflections.user_id` + `reflection_date` （查询每日反思）
- `ai_conversations.user_id` + `session_id` （查询对话会话）

-- Dream App - Supabase 数据库初始化脚本
-- 在 Supabase SQL Editor 中运行此脚本

-- ============================================
-- 1. 启用必要的扩展
-- ============================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- 2. 创建 users 表（扩展 Supabase auth.users）
-- ============================================
CREATE TABLE public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL UNIQUE,
    display_name VARCHAR(100),
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 3. 创建 goals 表（阶段性目标）
-- ============================================
CREATE TABLE public.goals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    start_date DATE NOT NULL,
    target_date DATE,
    status VARCHAR(20) DEFAULT 'planning' CHECK (status IN ('planning', 'active', 'completed', 'archived')),
    category VARCHAR(50),
    priority INTEGER DEFAULT 3 CHECK (priority BETWEEN 1 AND 5),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 4. 创建 daily_tasks 表（每日任务）
-- ============================================
CREATE TABLE public.daily_tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    goal_id UUID REFERENCES public.goals(id) ON DELETE SET NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    scheduled_date DATE NOT NULL,
    is_completed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMP WITH TIME ZONE,
    priority INTEGER DEFAULT 3 CHECK (priority BETWEEN 1 AND 5),
    estimated_minutes INTEGER,
    actual_minutes INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 5. 创建 daily_reflections 表（每日反思）
-- ============================================
CREATE TABLE public.daily_reflections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    reflection_date DATE NOT NULL,
    total_tasks INTEGER DEFAULT 0,
    completed_tasks INTEGER DEFAULT 0,
    completion_rate DECIMAL(5,2),
    user_mood VARCHAR(20) CHECK (user_mood IN ('great', 'good', 'okay', 'bad')),
    user_notes TEXT,
    ai_reflection TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, reflection_date)
);

-- ============================================
-- 6. 创建 weekly_summaries 表（周总结）
-- ============================================
CREATE TABLE public.weekly_summaries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    week_start DATE NOT NULL,
    week_end DATE NOT NULL,
    total_tasks INTEGER DEFAULT 0,
    completed_tasks INTEGER DEFAULT 0,
    completion_rate DECIMAL(5,2),
    top_categories JSONB,
    ai_insights TEXT,
    highlights TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, week_start)
);

-- ============================================
-- 7. 创建 monthly_summaries 表（月总结）
-- ============================================
CREATE TABLE public.monthly_summaries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    month INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
    year INTEGER NOT NULL,
    total_tasks INTEGER DEFAULT 0,
    completed_tasks INTEGER DEFAULT 0,
    completion_rate DECIMAL(5,2),
    goals_completed INTEGER DEFAULT 0,
    achievements JSONB,
    ai_insights TEXT,
    mood_trend VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, year, month)
);

-- ============================================
-- 8. 创建 ai_conversations 表（AI对话）
-- ============================================
CREATE TABLE public.ai_conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    session_id UUID NOT NULL,
    user_message TEXT NOT NULL,
    ai_response TEXT NOT NULL,
    context_type VARCHAR(50) CHECK (context_type IN ('goal_planning', 'daily_check', 'emotional_support', 'reflection')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 9. 创建索引
-- ============================================

-- daily_tasks 索引
CREATE INDEX idx_daily_tasks_user_date ON public.daily_tasks(user_id, scheduled_date);
CREATE INDEX idx_daily_tasks_goal ON public.daily_tasks(goal_id);
CREATE INDEX idx_daily_tasks_completed ON public.daily_tasks(user_id, is_completed);

-- goals 索引
CREATE INDEX idx_goals_user_status ON public.goals(user_id, status);
CREATE INDEX idx_goals_user_category ON public.goals(user_id, category);

-- daily_reflections 索引
CREATE INDEX idx_reflections_user_date ON public.daily_reflections(user_id, reflection_date);

-- ai_conversations 索引
CREATE INDEX idx_conversations_user_session ON public.ai_conversations(user_id, session_id);
CREATE INDEX idx_conversations_user_created ON public.ai_conversations(user_id, created_at DESC);

-- ============================================
-- 10. 创建更新 updated_at 的函数
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 为需要的表添加触发器
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_goals_updated_at BEFORE UPDATE ON public.goals
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_daily_tasks_updated_at BEFORE UPDATE ON public.daily_tasks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_daily_reflections_updated_at BEFORE UPDATE ON public.daily_reflections
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 11. 启用 Row Level Security (RLS)
-- ============================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_reflections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weekly_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.monthly_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_conversations ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 12. 创建 RLS 策略
-- ============================================

-- users 表策略
CREATE POLICY "用户可以查看自己的信息" ON public.users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "用户可以更新自己的信息" ON public.users
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "用户可以插入自己的信息" ON public.users
    FOR INSERT WITH CHECK (auth.uid() = id);

-- goals 表策略
CREATE POLICY "用户可以查看自己的目标" ON public.goals
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "用户可以创建自己的目标" ON public.goals
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "用户可以更新自己的目标" ON public.goals
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "用户可以删除自己的目标" ON public.goals
    FOR DELETE USING (auth.uid() = user_id);

-- daily_tasks 表策略
CREATE POLICY "用户可以查看自己的任务" ON public.daily_tasks
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "用户可以创建自己的任务" ON public.daily_tasks
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "用户可以更新自己的任务" ON public.daily_tasks
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "用户可以删除自己的任务" ON public.daily_tasks
    FOR DELETE USING (auth.uid() = user_id);

-- daily_reflections 表策略
CREATE POLICY "用户可以查看自己的反思" ON public.daily_reflections
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "用户可以创建自己的反思" ON public.daily_reflections
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "用户可以更新自己的反思" ON public.daily_reflections
    FOR UPDATE USING (auth.uid() = user_id);

-- weekly_summaries 表策略
CREATE POLICY "用户可以查看自己的周总结" ON public.weekly_summaries
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "系统可以创建周总结" ON public.weekly_summaries
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- monthly_summaries 表策略
CREATE POLICY "用户可以查看自己的月总结" ON public.monthly_summaries
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "系统可以创建月总结" ON public.monthly_summaries
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ai_conversations 表策略
CREATE POLICY "用户可以查看自己的对话" ON public.ai_conversations
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "用户可以创建对话" ON public.ai_conversations
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================
-- 13. 创建自动填充 users 表的触发器函数
-- ============================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.users (id, email, display_name)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1))
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建触发器：当新用户在 auth.users 中创建时，自动在 public.users 中创建记录
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- 完成！
-- ============================================
-- 数据库初始化完成
-- 现在你可以在 iOS App 中使用 Supabase SDK 连接数据库了

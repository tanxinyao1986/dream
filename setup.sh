#!/bin/bash

# LifeBubble 自动设置脚本
# 这个脚本会帮你自动准备好项目文件

echo "======================================"
echo "  LifeBubble 自动设置脚本"
echo "======================================"
echo ""

# 设置颜色
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 1. 检查文件是否存在
echo -e "${BLUE}[1/5]${NC} 检查文件..."
if [ ! -f "/Users/xinyao/Desktop/dream/CompleteApp.swift" ]; then
    echo -e "${RED}错误: 找不到 CompleteApp.swift${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} CompleteApp.swift 文件存在"
echo ""

# 2. 创建新的项目目录
echo -e "${BLUE}[2/5]${NC} 创建项目目录..."
PROJECT_DIR="/Users/xinyao/Desktop/LifeBubbleNew"

if [ -d "$PROJECT_DIR" ]; then
    echo -e "${RED}警告: 项目目录已存在，将被删除${NC}"
    rm -rf "$PROJECT_DIR"
fi

mkdir -p "$PROJECT_DIR/LifeBubble"
echo -e "${GREEN}✓${NC} 项目目录创建完成"
echo ""

# 3. 复制文件
echo -e "${BLUE}[3/5]${NC} 复制代码文件..."
cp "/Users/xinyao/Desktop/dream/CompleteApp.swift" "$PROJECT_DIR/LifeBubble/LifeBubbleApp.swift"
echo -e "${GREEN}✓${NC} 代码文件复制完成"
echo ""

# 4. 创建 Assets 目录
echo -e "${BLUE}[4/5]${NC} 创建资源目录..."
mkdir -p "$PROJECT_DIR/LifeBubble/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$PROJECT_DIR/LifeBubble/Assets.xcassets/AccentColor.colorset"

# 创建 Assets Contents.json
cat > "$PROJECT_DIR/LifeBubble/Assets.xcassets/Contents.json" << 'EOF'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# 创建 AppIcon Contents.json
cat > "$PROJECT_DIR/LifeBubble/Assets.xcassets/AppIcon.appiconset/Contents.json" << 'EOF'
{
  "images" : [
    {
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

echo -e "${GREEN}✓${NC} 资源目录创建完成"
echo ""

# 5. 打开文件夹
echo -e "${BLUE}[5/5]${NC} 准备打开项目..."
echo ""
echo -e "${GREEN}======================================"
echo -e "  设置完成！"
echo -e "======================================${NC}"
echo ""
echo "项目文件已准备好在："
echo -e "${BLUE}$PROJECT_DIR${NC}"
echo ""
echo "📋 接下来你需要手动完成以下步骤："
echo ""
echo "1️⃣  打开 Xcode"
echo "2️⃣  点击 'Create a new Xcode project'"
echo "3️⃣  选择 iOS → App → Next"
echo "4️⃣  配置："
echo "    - Product Name: LifeBubble"
echo "    - Interface: SwiftUI"
echo "    - Language: Swift"
echo "5️⃣  保存位置选择：桌面"
echo "6️⃣  在 Xcode 中删除默认的 .swift 文件"
echo "7️⃣  将 $PROJECT_DIR/LifeBubble/LifeBubbleApp.swift 拖入项目"
echo "8️⃣  按 Cmd+R 运行"
echo ""
echo "现在为你打开项目文件夹..."

# 打开 Finder
open "$PROJECT_DIR"

echo ""
echo -e "${GREEN}✓${NC} 完成！请查看打开的 Finder 窗口"

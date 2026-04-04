#!/bin/bash
# Mac 批量传输文件到 Steam Deck 的脚本

# 源文件夹（本地要传输的文件夹）
SOURCE_DIR="./send_to_deck/"

# Steam Deck 的 IP 地址，如果变化请在这里修改
DECK_IP="192.168.3.23"

# 私钥文件路径
PRIVATE_KEY="./mac-to-deck"

echo "======================================================="
echo "        Steam Deck 批量文件传输工具 (rsync)"
echo "======================================================="

# 检查源文件夹是否存在
if [ ! -d "$SOURCE_DIR" ]; then
    echo "错误：未找到传输文件夹 '$SOURCE_DIR'！"
    echo "正在为您创建该文件夹..."
    mkdir -p "$SOURCE_DIR"
    echo "文件夹已创建。请将您要传输的文件放入 '$SOURCE_DIR' 文件夹中，然后再次运行本脚本。"
    exit 1
fi

# 检查私钥文件
if [ ! -f "$PRIVATE_KEY" ]; then
    echo "错误：未找到私钥文件 '$PRIVATE_KEY'！请确保此脚本与密钥在同一目录。"
    exit 1
fi

# 确保私钥权限正确
chmod 600 "$PRIVATE_KEY"

# 检查源文件夹是否为空
if [ -z "$(ls -A "$SOURCE_DIR")" ]; then
    echo "提示：'$SOURCE_DIR' 文件夹是空的，没有文件需要传输。"
    echo "请先将文件放入该文件夹中。"
    exit 0
fi

echo "正在准备将 '$SOURCE_DIR' 中的所有文件同步到 Steam Deck (IP: $DECK_IP) 的桌面上..."
echo "-------------------------------------------------------"

# 使用 rsync 进行同步，它比 scp 更快，支持断点续传和增量同步
# -a: 归档模式，保留权限、属性等
# -v: 显示详细信息
# -h: 人类可读的格式
# -P: 显示传输进度
# -e: 指定使用 ssh 及其参数
rsync -avhP -e "ssh -i $PRIVATE_KEY -o StrictHostKeyChecking=no" "$SOURCE_DIR" deck@"$DECK_IP":~/Desktop/

if [ $? -eq 0 ]; then
    echo "-------------------------------------------------------"
    echo "✅ 所有文件已成功传输到 Steam Deck 的桌面！"
else
    echo "-------------------------------------------------------"
    echo "❌ 传输过程中出现错误，请检查网络连接或 IP 地址是否正确。"
fi

#!/bin/bash
# Mac 连接 Steam Deck 的快捷 SSH 脚本

# Steam Deck 的 IP 地址 (如果 IP 变动，请在这里修改)
# 您可以在 Steam Deck 的 设置 -> 互联网 中查看到 IP 地址
DECK_IP="192.168.3.23"

# 使用的私钥文件路径（指向当前目录下的 mac-to-deck）
PRIVATE_KEY="./mac-to-deck"

echo "======================================================="
echo "        Mac to Steam Deck SSH 连接工具"
echo "======================================================="

# 检查私钥文件是否存在
if [ ! -f "$PRIVATE_KEY" ]; then
    echo "错误：未找到私钥文件 $PRIVATE_KEY ！"
    echo "请确保此脚本与 mac-to-deck 位于同一目录。"
    exit 1
fi

# 确保私钥权限正确 (SSH 要求私钥权限不能过于开放)
chmod 600 "$PRIVATE_KEY"

# 如果还没有设置 IP，提示用户输入
if [[ "$DECK_IP" == "192.168.x.x" || -z "$DECK_IP" ]]; then
    read -p "请输入您的 Steam Deck 的 IP 地址: " DECK_IP
    
    # 简单的 IP 格式校验
    if [[ ! "$DECK_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "IP 地址格式似乎不正确，请重新运行脚本并输入正确的 IP。"
        exit 1
    fi
    
    # 可选：将输入的 IP 保存回脚本，方便下次使用
    sed -i '' "s/DECK_IP=\"192.168.x.x\"/DECK_IP=\"$DECK_IP\"/g" "$0"
    echo "已将 IP $DECK_IP 保存，下次将直接连接。"
fi

while true; do
    echo "正在连接到 Steam Deck (IP: $DECK_IP) ..."
    echo "-------------------------------------------------------"

    # 执行 SSH 连接，加入 ConnectTimeout 快速失败机制
    # 增加 ServerAliveInterval=60 和 ServerAliveCountMax=120 以保持连接不断开
    ssh -i "$PRIVATE_KEY" \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=5 \
        -o ServerAliveInterval=60 \
        -o ServerAliveCountMax=120 \
        deck@"$DECK_IP"
        
    SSH_EXIT_CODE=$?
    
    # 如果正常退出（exit 0）或者是被手动中断（130/255），则跳出循环结束脚本
    if [ $SSH_EXIT_CODE -eq 0 ] || [ $SSH_EXIT_CODE -eq 130 ] || [ $SSH_EXIT_CODE -eq 255 ]; then
        echo "-------------------------------------------------------"
        echo "已断开与 Steam Deck 的连接。"
        break
    else
        # 连接失败时的交互逻辑
        echo "-------------------------------------------------------"
        echo "❌ 连接失败！可能是 IP 地址 ($DECK_IP) 已变更，或者 Steam Deck 未开机/未联网。"
        echo "请在 Steam Deck 的 设置 -> 互联网 中确认当前的 IP 地址。"
        
        read -p "请输入新的 IP 地址重新连接 (或者直接按回车键/输入 'q' 退出): " NEW_IP
        
        if [[ -z "$NEW_IP" || "$NEW_IP" == "q" || "$NEW_IP" == "Q" ]]; then
            echo "已取消连接，退出脚本。"
            break
        fi
        
        # 校验新输入的 IP 格式
        if [[ "$NEW_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            # 将新 IP 保存回脚本
            sed -i '' "s/DECK_IP=\"$DECK_IP\"/DECK_IP=\"$NEW_IP\"/g" "$0"
            DECK_IP="$NEW_IP"
            echo "已将 IP 更新为 $DECK_IP，正在重试..."
        else
            echo "输入的 IP 格式不正确，退出脚本。"
            break
        fi
    fi
done

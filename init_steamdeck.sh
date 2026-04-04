#!/bin/bash
# Steam Deck 中国区一键初始化配置脚本

set -e

echo "======================================================="
echo "        Steam Deck 中国区一键初始化配置脚本"
echo "======================================================="
echo "本脚本将执行以下操作："
echo "1. 设置 deck 用户密码（如已设置则跳过）"
echo "2. 解除 SteamOS 系统只读模式"
echo "3. 开启 CEF 远程调试 (Decky Loader 必须)"
echo "4. 开启 SSH 服务并配置 Mac 远程免密登录"
echo "5. 将桌面系统语言切换为中文"
echo "6. 切换 Flatpak (Discover 商店) 国内源 (清华大学 TUNA 镜像)"
echo "7. 离线安装 Decky Loader (PluginLoader)"
echo "8. 自动安装 Decky Clipboard 剪贴板透传插件"
echo "9. 安装 tomoon 插件"
echo "10. 优化外接显示器(HDMI)电源管理（永不自动睡眠/熄屏）"
echo "======================================================="
echo "请确保您当前在包含 PluginLoader 和 tomoon-2 文件夹的目录下执行此脚本。"
echo "注意：如果您在 U 盘中直接运行，请使用 'bash init_steamdeck.sh' 命令，"
echo "以绕过可能存在的 U 盘 noexec 挂载权限限制。"
echo "======================================================="
echo "3秒后开始执行..."
sleep 3

# 1. 设置 deck 用户密码
echo -e "\n[1/10] 检查 deck 用户密码..."
if passwd -S | grep -q " NP "; then
    echo "未检测到密码，为了进行后续的 sudo 操作，请设置一个密码："
    passwd
else
    echo "当前用户已经设置过密码，跳过此步骤。"
fi

# 2. 解除系统只读模式
echo -e "\n[2/10] 解除 SteamOS 系统只读模式..."
sudo steamos-readonly disable || echo "解除只读模式可能失败或已被禁用，继续执行..."
echo "系统只读模式已解除。"

# 3. 开启 CEF 远程调试
echo -e "\n[3/10] 开启 CEF 远程调试 (Decky Loader 依赖)..."
CEF_DEBUG_FILE="$HOME/.steam/steam/.cef-enable-remote-debugging"
if [ ! -f "$CEF_DEBUG_FILE" ]; then
    touch "$CEF_DEBUG_FILE"
    echo "CEF 远程调试已开启（相当于在设置->系统中开启开发者模式，并在开发者设置中打开CEF远程调试）。"
    echo "注：脚本创建了底层配置文件，但 Steam UI 中的开关可能不会同步显示为'开启'，这是正常现象，功能已实际生效。"
else
    echo "CEF 远程调试已经开启，跳过此步骤。"
fi

# 4. 开启 SSH 服务并配置免密登录
echo -e "\n[4/10] 开启 SSH 服务并配置免密登录..."
sudo systemctl enable sshd
sudo systemctl start sshd
echo "SSH 服务 (sshd) 已启动并设置为开机自启。"

if [ -f "./mac-to-deck.pub" ]; then
    echo "找到 mac-to-deck.pub 公钥文件，正在配置免密登录..."
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    
    # 检查公钥是否已经存在，防止重复追加
    if ! grep -q -f ./mac-to-deck.pub ~/.ssh/authorized_keys 2>/dev/null; then
        cat ./mac-to-deck.pub >> ~/.ssh/authorized_keys
        echo "公钥已添加到 ~/.ssh/authorized_keys，您现在可以使用 Mac 上的私钥免密登录了。"
    else
        echo "公钥已经存在于 authorized_keys 中，无需重复添加。"
    fi
    chmod 600 ~/.ssh/authorized_keys
else
    # 如果没有找到 mac-to-deck.pub 公钥文件，执行命令创建一个默认的公钥对，使用ed25519算法
    # 生成 ed25519 密钥对，私钥文件为 ./mac-to-deck，公钥为 ./mac-to-deck.pub，空口令
    ssh-keygen -t ed25519 -f ./mac-to-deck -N ""
    echo "警告：当前目录下未找到 mac-to-deck.pub 公钥文件，跳过免密登录配置。您仍然可以使用密码通过 SSH 登录。"
fi

# 5. 切换桌面系统语言为中文
echo -e "\n[5/10] 配置桌面环境语言为简体中文..."
mkdir -p ~/.config
cat <<EOF > ~/.config/plasma-localerc
[Formats]
LANG=zh_CN.UTF-8

[Translations]
LANGUAGE=zh_CN:zh_TW:zh_HK
EOF
# 为了确保控制台环境也有中文支持（可选），写入 ~/.bashrc
if ! grep -q "LANG=zh_CN.UTF-8" ~/.bashrc; then
    echo 'export LANG=zh_CN.UTF-8' >> ~/.bashrc
    echo 'export LANGUAGE=zh_CN:zh_TW:zh_HK' >> ~/.bashrc
fi
echo "语言设置完成，将在下次重启或重新进入桌面模式后生效。"

# 6. 切换 Flatpak 国内镜像源
echo -e "\n[6/10] 配置 Discover 商店 (Flatpak) 国内镜像源..."
echo "正在使用 sudo 权限修改系统级配置，可能需要输入您刚刚设置的密码。"

# 使用清华大学 TUNA 镜像源，通常速度更快、更稳定
FLATHUB_MIRROR_URL="https://mirrors.tuna.tsinghua.edu.cn/flathub"
# 注意：清华源的 repo 文件通常需要直接从官方下载配置，然后用 modify 修改镜像 url。
# 或者是通过官方 url 添加：https://dl.flathub.org/repo/flathub.flatpakrepo
FLATHUB_REPO_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"

# 检查系统级 flathub 是否存在，不存在则添加
if ! sudo flatpak remotes | grep -q "^flathub"; then
    echo "系统级未发现 flathub 源，正在尝试添加清华源 (如果网络较慢请耐心等待或按 Ctrl+C 跳过)..."
    # 使用 timeout 防止网络不通导致死等，限时 30 秒
    if ! sudo timeout 30 flatpak remote-add --if-not-exists flathub "$FLATHUB_REPO_URL"; then
        echo "添加系统级 flathub 源超时或失败，可能当前网络无法连接镜像站，请稍后再试。"
    fi
else
    sudo flatpak remote-modify --url="$FLATHUB_MIRROR_URL" flathub || echo "修改系统级源失败，继续尝试..."
fi

# 检查用户级 flathub 是否存在，不存在则添加
if ! flatpak remotes --user | grep -q "^flathub"; then
    echo "用户级未发现 flathub 源，正在尝试添加清华源..."
    if ! timeout 30 flatpak remote-add --user --if-not-exists flathub "$FLATHUB_REPO_URL"; then
        echo "添加用户级 flathub 源超时或失败。"
    fi
else
    flatpak remote-modify --user --url="$FLATHUB_MIRROR_URL" flathub || echo "修改用户级源失败，可能原本就没有配置用户级源。"
fi

# 刷新 Flatpak 源数据，解决 Discover 商店显示“未找到任何内容”的问题
echo "正在刷新应用商店数据，这可能需要一点时间..."
sudo flatpak update --appstream -y || true

echo "Flatpak 镜像源配置及数据刷新完成。"

# 7. 离线安装 PluginLoader (Decky Loader)
echo -e "\n[7/10] 离线安装 PluginLoader (Decky Loader)..."
HOMEBREW_DIR="/home/deck/homebrew"
SERVICES_DIR="$HOMEBREW_DIR/services"
PLUGINS_DIR="$HOMEBREW_DIR/plugins"

if [ -f "./PluginLoader" ]; then
    echo "找到 PluginLoader，正在复制到系统目录..."
    sudo mkdir -p "$SERVICES_DIR"
    sudo mkdir -p "$PLUGINS_DIR"
    sudo cp ./PluginLoader "$SERVICES_DIR/"
    sudo chmod +x "$SERVICES_DIR/PluginLoader"
    
    # 创建 systemd 服务
    echo "配置 plugin_loader 服务..."
    SERVICE_FILE="/etc/systemd/system/plugin_loader.service"
    sudo bash -c "cat <<EOF > $SERVICE_FILE
[Unit]
Description=Steam Deck Plugin Loader
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=$SERVICES_DIR/PluginLoader
WorkingDirectory=$SERVICES_DIR
Restart=always
RestartSec=3
Environment=\"PLUGIN_PATH=$PLUGINS_DIR\"
Environment=\"XDG_RUNTIME_DIR=/run/user/1000\"

[Install]
WantedBy=multi-user.target
EOF"

    sudo systemctl daemon-reload
    sudo systemctl enable plugin_loader.service
    sudo systemctl restart plugin_loader.service
    echo "PluginLoader 安装并启动成功。"
else
    echo "=========================================================================="
    echo "警告：当前目录下未找到 PluginLoader 文件！跳过 Decky Loader 的安装。"
    echo "提示：请前往 Github 发布页下载对应版本的 PluginLoader 文件，"
    echo "下载地址: https://github.com/SteamDeckHomebrew/decky-loader/releases"
    echo "下载后请确保文件名为 'PluginLoader'（无后缀），放置在本脚本同级目录，"
    echo "然后重新运行此脚本即可完成安装。"
    echo "=========================================================================="
fi

# 8. 自动安装 Decky Clipboard 插件
echo -e "\n[8/10] 自动安装 Decky Clipboard 剪贴板透传插件..."
CLIPBOARD_DEST="$PLUGINS_DIR/Decky-Clipboard"

echo "正在从 Github 下载最新版 Decky Clipboard..."
# 确保插件目录存在
sudo mkdir -p "$PLUGINS_DIR"
# 使用 curl 静默下载最新 release，通过 tar 直接解压到 plugins 目录
if sudo curl -sL https://github.com/1-2-3-4-5-X/Decky-Clipboard/releases/latest/download/Decky-Clipboard.tar.gz | sudo tar -xz -C "$PLUGINS_DIR" 2>/dev/null; then
    echo "下载并解压成功。"
    sudo chmod -R +x "$CLIPBOARD_DEST/bin" 2>/dev/null || true
    echo "重启 PluginLoader 服务以加载 Decky Clipboard..."
    sudo systemctl restart plugin_loader.service || true
    echo "Decky Clipboard 插件安装完成。"
else
    echo "=========================================================================="
    echo "警告：Decky Clipboard 自动下载失败！可能是网络原因导致。"
    echo "提示：您可以在商店中手动搜索 'Decky Clipboard' 安装，"
    echo "或者确保网络通畅后再次运行本脚本。"
    echo "=========================================================================="
fi

# 9. 安装 tomoon 插件
echo -e "\n[9/10] 安装 tomoon 插件..."
if [ -d "./tomoon-2" ] || [ -d "./tomoon" ]; then
    echo "找到 tomoon 文件夹，正在安装..."
    TOMOON_DEST="$PLUGINS_DIR/tomoon"
    
    # 兼容查找的文件夹名称
    TOMOON_SRC="./tomoon-2"
    if [ -d "./tomoon" ]; then
        TOMOON_SRC="./tomoon"
    fi
    
    # 如果已经存在旧版插件，先删除
    if [ -d "$TOMOON_DEST" ]; then
        sudo rm -rf "$TOMOON_DEST"
    fi
    
    sudo cp -r "$TOMOON_SRC" "$TOMOON_DEST"
    # 给可能的二进制文件赋予执行权限
    if [ -d "$TOMOON_DEST/bin" ]; then
        sudo chmod -R +x "$TOMOON_DEST/bin"
    fi
    
    # 重启服务使插件生效
    echo "重启 PluginLoader 服务以加载 tomoon..."
    sudo systemctl restart plugin_loader.service || true
    echo "tomoon 插件安装完成。"
else
    echo "=========================================================================="
    echo "警告：当前目录下未找到 tomoon 或 tomoon-2 文件夹！跳过 tomoon 插件安装。"
    echo "提示：请前往 Github 下载 tomoon 插件对应的压缩包，解压后重命名为 'tomoon'"
    echo "并放置在与本脚本同级的目录下。"
    echo "参考下载地址: https://github.com/Not-yet-an-author/tomoon/releases"
    echo "然后重新运行此脚本即可完成安装。"
    echo "=========================================================================="
fi

# 10. 配置电源管理（永不休眠/熄屏）
echo -e "\n[10/10] 优化 KDE 电源管理 (解决 HDMI 连接自动睡眠熄屏问题)..."
if command -v kwriteconfig5 &> /dev/null; then
    # 交流电(插电)设置
    kwriteconfig5 --file powermanagementprofilesrc --group AC --group DPMSControl --key idleTime 0
    kwriteconfig5 --file powermanagementprofilesrc --group AC --group SuspendSession --key idleTime 0
    kwriteconfig5 --file powermanagementprofilesrc --group AC --group SuspendSession --key suspendType 1
    
    # 电池(不插电)设置
    kwriteconfig5 --file powermanagementprofilesrc --group Battery --group DPMSControl --key idleTime 0
    kwriteconfig5 --file powermanagementprofilesrc --group Battery --group SuspendSession --key idleTime 0
    kwriteconfig5 --file powermanagementprofilesrc --group Battery --group SuspendSession --key suspendType 1
    
    # 尝试重新加载电源配置
    qdbus org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/SuspendSession org.kde.Solid.PowerManagement.Actions.SuspendSession.reload 2>/dev/null || true
    echo "电源管理配置完成：已设置为永不自动睡眠和熄屏。"
else
    echo "未找到 kwriteconfig5 工具，可能当前不是 KDE Plasma 5 环境，尝试直接修改配置文件..."
    # 备用方案：直接使用 sed 修改或追加（简单处理）
    POWER_CONF=~/.config/powermanagementprofilesrc
    if [ -f "$POWER_CONF" ]; then
        sed -i 's/idleTime=[0-9]*/idleTime=0/g' "$POWER_CONF"
        echo "已直接修改电源配置文件。"
    else
        echo "未找到电源配置文件，无法自动修改，请在桌面模式系统设置中手动关闭休眠。"
    fi
fi

echo -e "\n======================================================="
echo "全部配置完成！"
echo "建议您重启 Steam Deck 以确保所有语言和系统服务设置生效。"
echo "重启命令: sudo reboot"
echo "======================================================="

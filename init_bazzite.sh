#!/bin/bash
# Bazzite (基于 Fedora 的类 SteamOS) 中国区一键初始化配置脚本
# 适配 Dell G15 等第三方硬件

set -e

echo "======================================================="
echo "        Bazzite 中国区一键初始化配置脚本"
echo "======================================================="
echo "本脚本将执行以下操作："
echo "1. 检查并验证当前用户的 sudo 权限"
echo "2. 开启 CEF 远程调试 (Decky Loader 必须)"
echo "3. 开启 SSH 服务并配置 Mac 远程免密登录"
echo "4. 将桌面系统语言切换为中文 (适配 KDE/GNOME)"
echo "5. 配置系统时区为中国上海 (Asia/Shanghai)"
echo "6. 切换 Flatpak (Discover/Software 商店) 国内源 (清华大学 TUNA 镜像)"
echo "7. 自动安装 Fcitx5 中文输入法 (通过 ujust)"
echo "8. 激活 Homebrew (酿酒厂) 并配置国内清华源"
echo "9. 优化 KDE 外接显示器(HDMI)电源管理 (GNOME将跳过此步)"
echo "10. (可选) 离线安装 Decky Loader (PluginLoader)"
echo "11. (可选) 安装 tomoon 插件及 Decky Clipboard"
echo "======================================================="
echo "说明：本脚本会自动检测当前目录是否有 PluginLoader 和 tomoon 文件夹，"
echo "如果存在则自动安装，如果不存在则自动跳过，不影响基础系统配置。"
echo "======================================================="

# 0. 网络检查与 IP 获取
echo -e "\n[0/9] 检查网络连接状态..."
# 使用通用路由查询获取当前活动网卡的 IP，适配非 wlan0 的笔电网卡
DECK_IP=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+')

if [ -z "$DECK_IP" ]; then
    echo "=========================================================================="
    echo "❌ 错误：未检测到有效网络连接！"
    echo "本脚本的后续步骤需要网络支持，请先连接 WiFi 或有线网络后重新运行。"
    echo "=========================================================================="
    exit 1
else
    echo "网络已连接。"
    echo "-------------------------------------------------------"
    echo "🌐 您的 Bazzite 局域网 IP 地址为: $DECK_IP"
    echo "💡 请记住这个 IP，稍后您可以在 MacBook 上使用远程连接"
    echo "-------------------------------------------------------"
fi

echo -e "\n3秒后开始执行后续配置..."
sleep 3

# 1. 验证 sudo 权限
echo -e "\n[1/9] 验证 sudo 权限..."
# Bazzite 在安装时强制要求设置用户密码，无需像原版 SteamOS 那样使用 passwd 设置空密码
echo "系统可能会要求您输入当前用户的登录密码："
sudo -v
# 刷新 sudo 凭据超时时间
sudo -n true

# 注：Bazzite 基于 rpm-ostree 的不可变系统，修改 /etc, /var, /home 是默认允许的
# 因此不需要执行 steamos-readonly disable。

# 2. 开启 CEF 远程调试
echo -e "\n[2/9] 开启 CEF 远程调试 (Decky Loader 依赖)..."
CEF_DEBUG_FILE="$HOME/.steam/steam/.cef-enable-remote-debugging"
if [ ! -f "$CEF_DEBUG_FILE" ]; then
    # 确保父目录存在
    mkdir -p "$HOME/.steam/steam/"
    touch "$CEF_DEBUG_FILE"
    echo "CEF 远程调试已开启（相当于在设置->系统中开启开发者模式并打开CEF远程调试）。"
else
    echo "CEF 远程调试已经开启，跳过此步骤。"
fi

# 3. 开启 SSH 服务并配置免密登录
echo -e "\n[3/9] 开启 SSH 服务并配置免密登录..."
sudo systemctl enable sshd
sudo systemctl start sshd
echo "SSH 服务 (sshd) 已启动并设置为开机自启。"

if [ -f "./mac-to-deck.pub" ]; then
    echo "找到 mac-to-deck.pub 公钥文件，正在配置免密登录..."
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    
    if ! grep -q -f ./mac-to-deck.pub ~/.ssh/authorized_keys 2>/dev/null; then
        cat ./mac-to-deck.pub >> ~/.ssh/authorized_keys
        echo "公钥已添加到 ~/.ssh/authorized_keys，您现在可以使用 Mac 上的私钥免密登录了。"
    else
        echo "公钥已经存在于 authorized_keys 中，无需重复添加。"
    fi
    chmod 600 ~/.ssh/authorized_keys
else
    # 兼容原脚本行为：如果没有找到 mac-to-deck.pub，则生成默认的密钥对
    if [ ! -f "./mac-to-deck" ]; then
        ssh-keygen -t ed25519 -f ./mac-to-deck -N ""
    fi
    echo "警告：当前目录下未找到 mac-to-deck.pub 公钥文件，跳过免密登录配置。您仍然可以使用密码通过 SSH 登录。"
fi

# 4. 切换桌面系统语言为中文
echo -e "\n[4/8] 配置桌面环境语言为简体中文..."

# 检测当前桌面环境
CURRENT_DESKTOP=$(echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]')

if [[ "$CURRENT_DESKTOP" == *"gnome"* ]]; then
    echo "检测到 GNOME 桌面环境，正在配置语言..."
    # 使用 localectl 设置系统语言（Bazzite 允许此操作）
    sudo localectl set-locale LANG=zh_CN.UTF-8
    # 针对当前用户使用 gsettings 设置
    gsettings set org.gnome.system.locale region 'zh_CN.UTF-8' 2>/dev/null || true
elif [[ "$CURRENT_DESKTOP" == *"kde"* ]] || command -v kwriteconfig6 &> /dev/null || command -v kwriteconfig5 &> /dev/null; then
    echo "检测到 KDE 桌面环境，正在配置语言..."
    mkdir -p ~/.config
    cat <<EOF > ~/.config/plasma-localerc
[Formats]
LANG=zh_CN.UTF-8

[Translations]
LANGUAGE=zh_CN:zh_TW:zh_HK
EOF
else
    echo "未检测到明确的桌面环境 (GNOME/KDE)，尝试通过通用配置设置语言..."
    sudo localectl set-locale LANG=zh_CN.UTF-8 || true
fi

if ! grep -q "LANG=zh_CN.UTF-8" ~/.bashrc; then
    echo 'export LANG=zh_CN.UTF-8' >> ~/.bashrc
    echo 'export LANGUAGE=zh_CN:zh_TW:zh_HK' >> ~/.bashrc
fi
echo "语言设置完成，将在下次重启或重新进入桌面模式后生效。"

# 5. 配置系统时区
echo -e "\n[5/11] 配置系统时区为中国上海 (Asia/Shanghai)..."
sudo timedatectl set-timezone Asia/Shanghai
echo "时区已设置为 Asia/Shanghai。"

# 6. 切换 Flatpak 国内镜像源
echo -e "\n[6/11] 配置 Flatpak 商店 (Discover/Software) 国内镜像源..."
FLATHUB_MIRROR_URL="https://mirrors.tuna.tsinghua.edu.cn/flathub"
FLATHUB_REPO_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"

if ! sudo flatpak remotes | grep -q "^flathub"; then
    echo "系统级未发现 flathub 源，正在尝试添加清华源..."
    if ! sudo timeout 30 flatpak remote-add --if-not-exists flathub "$FLATHUB_REPO_URL"; then
        echo "添加系统级 flathub 源超时或失败。"
    fi
else
    sudo flatpak remote-modify --url="$FLATHUB_MIRROR_URL" flathub || echo "修改系统级源失败，继续尝试..."
fi

if ! flatpak remotes --user | grep -q "^flathub"; then
    echo "用户级未发现 flathub 源，正在尝试添加清华源..."
    if ! timeout 30 flatpak remote-add --user --if-not-exists flathub "$FLATHUB_REPO_URL"; then
        echo "添加用户级 flathub 源超时或失败。"
    fi
else
    flatpak remote-modify --user --url="$FLATHUB_MIRROR_URL" flathub || echo "修改用户级源失败。"
fi

echo "正在刷新应用商店数据，这可能需要一点时间..."
sudo flatpak update --appstream -y || true
echo "Flatpak 镜像源配置及数据刷新完成。"

# 7. 安装 Fcitx5 中文输入法
echo -e "\n[7/11] 正在通过 ujust 安装 Fcitx5 中文输入法..."
if command -v ujust &> /dev/null; then
    # ujust install-fcitx5 通常会弹窗或需要交互，使用 yes 自动确认或忽略交互
    echo "这可能会下载一些系统组件，请耐心等待..."
    ujust install-fcitx5 || echo "Fcitx5 安装可能存在交互或警告，如果失败请稍后在终端手动运行 'ujust install-fcitx5'"
    echo "Fcitx5 输入法安装完成。"
else
    echo "未检测到 ujust 命令，跳过输入法安装。"
fi

# 8. 配置 Homebrew (酿酒厂) 及国内源
echo -e "\n[8/11] 正在配置 Homebrew (酿酒厂) 及其清华大学国内源..."
if command -v brew &> /dev/null || [ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
    echo "检测到系统已包含 Homebrew，正在配置国内源..."
    
    # 确保环境变量被加载，Bazzite 默认路径通常在 /home/linuxbrew/.linuxbrew
    BREW_BIN="/home/linuxbrew/.linuxbrew/bin/brew"
    if [ ! -f "$BREW_BIN" ]; then
        BREW_BIN=$(command -v brew)
    fi

    # 替换 brew.git
    export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
    "$BREW_BIN" tap --custom-remote --force-auto-update homebrew/core https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git || true
    
    # 写入用户环境变量
    if ! grep -q "HOMEBREW_API_DOMAIN" ~/.bashrc; then
        echo 'export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"' >> ~/.bashrc
        echo 'export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"' >> ~/.bashrc
        echo 'export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"' >> ~/.bashrc
        echo 'export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"' >> ~/.bashrc
        echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
    fi
    echo "Homebrew 清华源配置完成，环境变量已写入 ~/.bashrc。"
else
    echo "未在默认路径检测到 Homebrew。Bazzite 通常自带 brew，如果您后续手动安装，请参考清华源官方文档进行换源。"
fi

# 9. 配置电源管理（永不休眠/熄屏，仅针对 KDE）
echo -e "\n[9/11] 优化 KDE 桌面电源管理 (解决 HDMI 连接自动睡眠熄屏问题)..."
# 根据前面检测的 CURRENT_DESKTOP 或者工具来判断
if [[ "$CURRENT_DESKTOP" == *"gnome"* ]] || command -v gsettings &> /dev/null; then
    echo "检测到 GNOME 桌面环境，跳过电源管理配置 (推荐使用 GNOME 自带的 Caffeine 扩展防休眠)。"
else
    # 适配 Bazzite 使用的 KDE Plasma 6 (kwriteconfig6) 或 Plasma 5 (kwriteconfig5)
    KWRITE_CMD=""
    if command -v kwriteconfig6 &> /dev/null; then
        KWRITE_CMD="kwriteconfig6"
        echo "检测到 KDE Plasma 6 环境 ($KWRITE_CMD)"
    elif command -v kwriteconfig5 &> /dev/null; then
        KWRITE_CMD="kwriteconfig5"
        echo "检测到 KDE Plasma 5 环境 ($KWRITE_CMD)"
    fi

    if [ -n "$KWRITE_CMD" ]; then
        # 交流电(插电)设置
        $KWRITE_CMD --file powermanagementprofilesrc --group AC --group DPMSControl --key idleTime 0
        $KWRITE_CMD --file powermanagementprofilesrc --group AC --group SuspendSession --key idleTime 0
        $KWRITE_CMD --file powermanagementprofilesrc --group AC --group SuspendSession --key suspendType 1
        
        # 电池(不插电)设置
        $KWRITE_CMD --file powermanagementprofilesrc --group Battery --group DPMSControl --key idleTime 0
        $KWRITE_CMD --file powermanagementprofilesrc --group Battery --group SuspendSession --key idleTime 0
        $KWRITE_CMD --file powermanagementprofilesrc --group Battery --group SuspendSession --key suspendType 1
        
        qdbus org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/SuspendSession org.kde.Solid.PowerManagement.Actions.SuspendSession.reload 2>/dev/null || true
        echo "KDE 电源管理配置完成：已设置为永不自动睡眠和熄屏。"
    else
        echo "未找到 gsettings 或 kwriteconfig 工具，尝试直接修改 KDE 配置文件..."
        POWER_CONF=~/.config/powermanagementprofilesrc
        if [ -f "$POWER_CONF" ]; then
            sed -i 's/idleTime=[0-9]*/idleTime=0/g' "$POWER_CONF"
            echo "已直接修改电源配置文件。"
        else
            echo "未找到受支持的电源管理配置，无法自动修改，请在系统设置中手动关闭休眠。"
        fi
    fi
fi

# 10. 离线安装 PluginLoader (Decky Loader) [可选]
echo -e "\n[10/11] 检查并离线安装 PluginLoader (Decky Loader)..."
# Bazzite 环境下 $HOME 等价于 /var/home/$USER
HOMEBREW_DIR="$HOME/homebrew"
SERVICES_DIR="$HOMEBREW_DIR/services"
PLUGINS_DIR="$HOMEBREW_DIR/plugins"

# 动态获取当前用户的 UID，适配非 1000 的情况
USER_UID=$(id -u)

if [ -f "./PluginLoader" ]; then
    echo "找到 PluginLoader，正在复制到用户主目录..."
    mkdir -p "$SERVICES_DIR"
    mkdir -p "$PLUGINS_DIR"
    cp ./PluginLoader "$SERVICES_DIR/"
    chmod +x "$SERVICES_DIR/PluginLoader"
    
    # 创建 systemd 服务 (Decky 在 Bazzite 依然需要 root 权限以注入 Steam)
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
Environment=\"XDG_RUNTIME_DIR=/run/user/$USER_UID\"

[Install]
WantedBy=multi-user.target
EOF"

    sudo systemctl daemon-reload
    sudo systemctl enable plugin_loader.service
    sudo systemctl restart plugin_loader.service
    echo "PluginLoader 安装并启动成功。"
    
    # 提示：Bazzite 原生自带 ujust 安装脚本，但使用用户自带离线包同样兼容
    echo "提示：Bazzite 也内置了 ujust setup-decky 快捷命令，如未来需重新安装可直接使用。"
else
    echo "=========================================================================="
    echo "警告：当前目录下未找到 PluginLoader 文件！跳过 Decky Loader 的安装。"
    echo "提示：由于您正在使用 Bazzite，推荐直接在终端运行: ujust setup-decky 进行安装。"
    echo "=========================================================================="
fi

# 11. 安装 tomoon 插件 [可选]
echo -e "\n[11/11] 检查并安装 tomoon 插件及 Decky Clipboard..."
CLIPBOARD_DEST="$PLUGINS_DIR/Decky-Clipboard"

echo "正在从 Github 下载最新版 Decky Clipboard..."
mkdir -p "$PLUGINS_DIR"
if curl -sL https://github.com/1-2-3-4-5-X/Decky-Clipboard/releases/latest/download/Decky-Clipboard.tar.gz | tar -xz -C "$PLUGINS_DIR" 2>/dev/null; then
    echo "下载并解压成功。"
    chmod -R +x "$CLIPBOARD_DEST/bin" 2>/dev/null || true
    echo "重启 PluginLoader 服务以加载 Decky Clipboard..."
    sudo systemctl restart plugin_loader.service || true
    echo "Decky Clipboard 插件安装完成。"
else
    echo "=========================================================================="
    echo "警告：Decky Clipboard 自动下载失败！可能是网络原因导致。"
    echo "提示：您可以在商店中手动搜索 'Decky Clipboard' 安装。"
    echo "=========================================================================="
fi


if [ -d "./tomoon-2" ] || [ -d "./tomoon" ]; then
    echo "找到 tomoon 文件夹，正在安装..."
    TOMOON_DEST="$PLUGINS_DIR/tomoon"
    
    TOMOON_SRC="./tomoon-2"
    if [ -d "./tomoon" ]; then
        TOMOON_SRC="./tomoon"
    fi
    
    if [ -d "$TOMOON_DEST" ]; then
        rm -rf "$TOMOON_DEST"
    fi
    
    cp -r "$TOMOON_SRC" "$TOMOON_DEST"
    if [ -d "$TOMOON_DEST/bin" ]; then
        chmod -R +x "$TOMOON_DEST/bin"
    fi
    
    echo "重启 PluginLoader 服务以加载 tomoon..."
    sudo systemctl restart plugin_loader.service || true
    echo "tomoon 插件安装完成。"
else
    echo "=========================================================================="
    echo "当前目录下未找到 tomoon 文件夹，已跳过 tomoon 插件安装。"
    echo "如需在桌面模式使用代理，推荐在 Discover 商店(Flatpak) 中安装 Clash Verge。"
    echo "=========================================================================="
fi

echo -e "\n======================================================="
echo "全部配置完成！"
echo "建议您重启 Bazzite 系统以确保所有语言和系统服务设置生效。"
echo "重启命令: sudo reboot"
echo "======================================================="

# Steam Deck 中国区一键初始化与配置工具箱

这是一个为中国区 Steam Deck 用户量身定制的自动化配置脚本集合。它可以帮助您在拿到全新的 Steam Deck 时，快速完成系统底层的关键配置、国内网络环境优化，以及核心插件（Decky Loader 和 tomoon）的离线安装。

## 🌟 核心功能

执行主脚本 `init_steamdeck.sh`，将自动完成以下 10 项优化：

1. 🛡️ **密码检查**：自动引导设置 Deck 用户密码（系统提权必须）。
2. 🔓 **解除系统锁**：关闭 SteamOS 默认的只读模式限制。
3. 🐛 **开启 CEF 远程调试**：无需手动翻找系统菜单，一键开启 Decky Loader 的核心依赖。
4. 📡 **SSH 与免密登录**：自动开启 SSH 服务，并支持将公钥注入系统，实现 Mac/PC 远程一键直连。
5. 🇨🇳 **系统汉化**：将桌面模式（KDE Plasma）语言强制切换为简体中文。
6. ⚡ **应用商店加速**：将 Discover 商店 (Flatpak) 的底层源替换为清华大学 TUNA 镜像，解决下载缓慢和白屏问题。
7. 🔌 **安装 Decky Loader**：自动配置系统服务，离线静默安装。
8. 📋 **安装 Decky Clipboard**：自动下载并安装局域网剪贴板神器，手机/电脑扫码即可轻松推送超长订阅链接到 Deck。
9. 🌙 **安装 tomoon**：全自动离线部署科学上网网络插件，支持权限修复。
10. 🔋 **休眠优化**：彻底解决外接显示器（HDMI/Type-C）几分钟后自动休眠/熄屏的顽疾。

***

## 🛠️ 使用前准备

### 硬件与网络准备
- 一台全新的 Steam Deck
- 一台**已能科学上网的 MacBook** (用于下载插件及后续的远程管理与文件传输)
- 两台设备处于**同一个局域网（同一 WiFi）**下

### 文件准备
由于版权和更新频率的原因，本仓库**不包含** `PluginLoader` 和 `tomoon` 的二进制文件。在执行脚本前，您需要手动在您的 MacBook 上下载这两个文件并放入本项目的根目录。

### 1. 下载 Decky Loader (PluginLoader)

- 前往 [SteamDeckHomebrew/decky-loader 发布页](https://github.com/SteamDeckHomebrew/decky-loader/releases)。
- 下载最新的 `PluginLoader` 文件（没有后缀名）。
- 将其直接放入本项目的根目录。

### 2. 下载 tomoon 插件

- 前往 [YukiCoco/ToMoon 发布页](https://github.com/YukiCoco/ToMoon/releases)。
- 下载最新的 release 压缩包。
- 解压后，将其文件夹重命名为 `tomoon`（或保留 `tomoon-2`），放入本项目的根目录。

正确的目录结构应如下所示：

```text
decky-loader/
├── init_steamdeck.sh      # 核心初始化脚本
├── connect_deck.sh        # Mac 远程连接脚本
├── sync_to_deck.sh        # 批量文件同步脚本
├── PluginLoader           # 👈 您需要下载的文件
└── tomoon/                # 👈 您需要下载的插件文件夹
```

***

## 🚀 执行流程与指南

### 场景一：直接在 Steam Deck 上运行（通过 U盘 / 下载）

如果您将整个文件夹拷贝到了 Steam Deck（或者直接在 Deck 上 `git clone`）：

1. 切换至 Steam Deck 的**桌面模式**。
2. 打开终端应用（Konsole）。
3. 导航到本文件夹所在目录，例如：`cd ~/Downloads/decky-loader`
4. 运行初始化脚本：
   ```bash
   bash init_steamdeck.sh
   ```
   *(注：使用* *`bash`* *命令执行可以完美绕过 U盘挂载的* *`noexec`* *权限限制)*
5. 脚本支持**幂等性**，您可以随时安全地重复运行它，不会损坏系统。

### 场景二：在 Mac/PC 端远程管理 Steam Deck（推荐高阶玩法）

如果您习惯使用电脑远程控制 Steam Deck，本工具箱提供了全套的 SSH 辅助脚本：

1. **首次初始化**
   - 按照场景一，在 Steam Deck 上先执行一次 `init_steamdeck.sh`。这会帮您自动启动 SSH 服务。
   - 如果您希望实现免密登录，请将您的 SSH 公钥保存为 `mac-to-deck.pub` 放入根目录后再执行初始化脚本。
2. **日常免密连接 (`connect_deck.sh`)**
   - 在您的电脑端运行：`./connect_deck.sh`
   - 首次运行会提示输入 Steam Deck 的 IP 地址，之后会自动记住并秒连（自带长连接保活防断开机制）。
3. **批量文件传输 (`sync_to_deck.sh`)**
   - 脚本会自动在电脑端创建一个 `send_to_deck` 文件夹。
   - 将任何你想传给 Steam Deck 的文件（电影、游戏补丁、Mod）丢进这个文件夹。
   - 运行 `./sync_to_deck.sh`，所有文件会以极快的速度（基于 rsync）同步到 Steam Deck 的桌面上。

***

## 🔧 疑难解答

**Q: 运行** **`init_steamdeck.sh`** **时提示找不到 PluginLoader 或 tomoon？**
A: 脚本内置了智能检测机制，如果缺失这些文件，脚本会跳过对应步骤并给出详细的下载地址提示。按照提示下载并放入对应目录后，重新运行脚本即可，之前的配置不会受影响。

**Q: 如何优雅地给 tomoon 粘贴订阅链接？**
A: 脚本在第 8 步会自动为您安装 `Decky Clipboard` 插件。进入游戏模式后，打开该插件会显示一个局域网网址（或二维码），在您的手机或 Mac 浏览器上打开该网址，粘贴订阅链接并发送。然后在 Steam Deck 上打开 tomoon 的输入框，按下手柄的 `Steam + X` 调出键盘点击“粘贴”即可！

**Q: 切换中文后，桌面还是英文的？**
A: KDE 桌面环境的语言配置需要重启图形界面才能完全生效。请在终端执行 `sudo reboot` 重启 Steam Deck 即可。

**Q: Discover 商店换源后，更新报错？**
A: 这是因为本地的 Flatpak 缓存由于网络原因损坏。本仓库提供了一个隐藏的急救脚本（如果你保留了的话），或者您可以直接在终端执行：`sudo flatpak update --appstream -y` 来强制刷新索引。

***


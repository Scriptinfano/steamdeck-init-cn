#!/bin/bash
# 卸载 Decky Loader
# 注意：此脚本仅在能访问github的环境下运行
# 从 GitHub 下载最新的卸载脚本

curl -L https://github.com/SteamDeckHomebrew/decky-installer/releases/latest/download/uninstall.sh -o uninstall.sh
chmod +x uninstall.sh
# 强制将卸载脚本移动到 send_to_deck 目录
mv uninstall.sh send_to_deck/
./sync_to_deck.sh
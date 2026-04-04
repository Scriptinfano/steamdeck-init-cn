# 1. 确保系统级（sudo）已经添加，我们重新再添加一次用户级（--user）
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# 2. 将用户级的下载链接修改为清华镜像
flatpak remote-modify --user --url=https://mirrors.tuna.tsinghua.edu.cn/flathub flathub

# 3. 最关键的一步：不要加 sudo！用普通用户的身份刷新当前用户的缓存数据
flatpak update --appstream --user -y
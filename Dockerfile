# docker buildx build --platform linux/amd64,linux/arm64 -t registry.cn-wulanchabu.aliyuncs.com/personal-pan/workspace --push .

# 使用 Debian 11 (Bullseye) 官方基础镜像
FROM debian:bullseye-slim

WORKDIR /root

# 设置非交互式安装以避免 apt-get 时出现询问
ENV DEBIAN_FRONTEND=noninteractive

# 安装必要软件
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    gnupg \
    dirmngr \
    lsb-release \
    bzip2 \ 
    --fix-missing \
    && rm -rf /var/lib/apt/lists/*

# 先备份原有的源
RUN cp /etc/apt/sources.list /etc/apt/sources.list.bak
# 添加阿里云的 Debian 源
RUN echo "deb https://mirrors.aliyun.com/debian/ bullseye main non-free contrib" > /etc/apt/sources.list \
    && echo "deb-src https://mirrors.aliyun.com/debian/ bullseye main non-free contrib" >> /etc/apt/sources.list \
    && echo "deb https://mirrors.aliyun.com/debian-security/ bullseye-security main" >> /etc/apt/sources.list \
    && echo "deb-src https://mirrors.aliyun.com/debian-security/ bullseye-security main" >> /etc/apt/sources.list \
    && echo "deb https://mirrors.aliyun.com/debian/ bullseye-updates main non-free contrib" >> /etc/apt/sources.list \
    && echo "deb-src https://mirrors.aliyun.com/debian/ bullseye-updates main non-free contrib" >> /etc/apt/sources.list \
    && echo "deb https://mirrors.aliyun.com/debian/ bullseye-backports main non-free contrib" >> /etc/apt/sources.list \
    && echo "deb-src https://mirrors.aliyun.com/debian/ bullseye-backports main non-free contrib" >> /etc/apt/sources.list
    

# 更新软件源列表并安装常用软件
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    wget \
    net-tools \
    git \
    vim \
    htop \ 
    tree \
    zsh \
    rsync \
    tmux \
    # 安装 SSH 服务
    openssh-server \
    # 安装 Cron 服务
    cron \
    sudo \ 
    --fix-missing \
    # 清理缓存，减少镜像大小
    && rm -rf /var/lib/apt/lists/*


# 安装 python
RUN apt-get update && apt-get install -y python3 python3-pip \
    && rm -rf /var/lib/apt/lists/*

# 安装OpenJDK 17
RUN apt-get update && \
    apt-get install -y openjdk-17-jdk && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 设置 SSH
RUN mkdir /var/run/sshd
RUN ssh-keygen -A
# 更改 SSH 配置以允许密码认证
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 设置无密码 sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# 设置 Vim 作为默认的编辑器
RUN update-alternatives --set editor /usr/bin/vim.basic

# 设置 zsh 为默认 shell
SHELL ["zsh", "-c"]
RUN chsh -s /usr/bin/zsh root

# oh-my-zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
RUN git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-syntax-highlighting
RUN git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions
RUN git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
RUN git clone https://github.com/zsh-users/zsh-history-substring-search ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-history-substring-search
# set zsh config
RUN cp /root/.zshrc /root/.zshrc.bak
COPY zshrc /root/.zshrc

# 设置 tmux 配置
COPY tmux.conf /root/.tmux.conf

# 安装 conda
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh \
    && bash miniconda.sh -b -p /root/miniconda \
    && rm miniconda.sh

# change permission to all files in /root
RUN chmod -R 755 /root

# 设置 conda 环境变量
ENV PATH="/root/miniconda/bin:$PATH"

# 初始化 Conda
RUN conda init zsh

# 安装 conda-forge 镜像
RUN conda config --add channels conda-forge

EXPOSE 22

# 容器启动时同时运行 SSH 和 Cron 服务
CMD service ssh start && cron && zsh
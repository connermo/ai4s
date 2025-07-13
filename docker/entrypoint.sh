#!/bin/bash

# 获取环境变量
DEV_USER=${DEV_USER:-developer}
DEV_UID=${DEV_UID:-1001}
DEV_GID=${DEV_GID:-1001}
DEV_PASSWORD=${DEV_PASSWORD:-developer123}

echo "=== 容器启动脚本 ==="
echo "用户: $DEV_USER"
echo "UID: $DEV_UID"
echo "GID: $DEV_GID"

echo ""
echo "=== 目录挂载检查 ==="
echo "个人主目录: /home/$DEV_USER $([ -d "/home/$DEV_USER" ] && echo "✓" || echo "✗")"
echo "共享目录: /shared $([ -d "/shared" ] && echo "✓" || echo "✗")"
echo "工作空间: /workspace $([ -d "/workspace" ] && echo "✓" || echo "✗")"
echo ""

# 检查是否以root身份运行
if [ "$(id -u)" != "0" ]; then
    echo "错误: 容器需要以root身份启动才能创建用户"
    exit 1
fi

# 创建用户组
if ! getent group $DEV_USER > /dev/null 2>&1; then
    if groupadd -g $DEV_GID $DEV_USER 2>/dev/null; then
        echo "创建用户组: $DEV_USER ($DEV_GID)"
    else
        echo "警告: 用户组创建失败，可能已存在"
    fi
fi

# 创建用户
if ! id -u $DEV_USER > /dev/null 2>&1; then
    # 先创建用户主目录
    mkdir -p /home/$DEV_USER
    
    if useradd -m -u $DEV_UID -g $DEV_GID -s /bin/bash -d /home/$DEV_USER $DEV_USER 2>/dev/null; then
        echo "创建用户: $DEV_USER ($DEV_UID:$DEV_GID)"
        
        # 设置密码
        if echo "$DEV_USER:$DEV_PASSWORD" | chpasswd; then
            echo "密码设置成功"
        else
            echo "警告: 密码设置失败"
        fi
        
        # 添加到sudo组
        if usermod -aG sudo $DEV_USER 2>/dev/null; then
            echo "添加到sudo组成功"
        fi
        
        # 设置sudo免密
        if echo "$DEV_USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers; then
            echo "sudo免密设置成功"
        fi
    else
        echo "警告: 用户创建失败，可能已存在"
    fi
else
    echo "用户 $DEV_USER 已存在"
fi

# 确保用户主目录权限正确
if chown -R $DEV_UID:$DEV_GID /home/$DEV_USER 2>/dev/null; then
    echo "用户主目录权限设置成功"
else
    echo "警告: 用户主目录权限设置失败"
fi

# 创建必要的目录
mkdir -p /home/$DEV_USER/.jupyter
mkdir -p /home/$DEV_USER/.vscode-server
mkdir -p /home/$DEV_USER/.config/code-server

# 设置目录权限
chown -R $DEV_UID:$DEV_GID /home/$DEV_USER/.jupyter 2>/dev/null
chown -R $DEV_UID:$DEV_GID /home/$DEV_USER/.vscode-server 2>/dev/null
chown -R $DEV_UID:$DEV_GID /home/$DEV_USER/.config 2>/dev/null

# 配置用户bash环境
echo "配置用户bash环境..."

# 创建标准的.bashrc
cat > /home/$DEV_USER/.bashrc << 'EOF'
# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# Custom aliases for development environment
alias python=python3
alias pip=pip3
alias ll='ls -alF --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias h='history'
alias c='clear'
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias ports='netstat -tulpn'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'

# Docker aliases
alias d='docker'
alias dc='docker compose'
alias dps='docker ps'
alias dimg='docker images'

# Development environment info
export PATH="/opt/miniconda3/bin:/opt/miniconda3/condabin:/usr/local/bin:/home/\$USER/.local/bin:\$PATH"
export EDITOR=vim
export PYTHONPATH="/workspace:/shared:\$PYTHONPATH"

# Python 3.11 as default
export PYTHON=/usr/bin/python3.11
alias python=python3.11
alias pip=pip3.11

# Conda initialization (optional, base environment only)
if [ -f "/opt/miniconda3/etc/profile.d/conda.sh" ]; then
    . "/opt/miniconda3/etc/profile.d/conda.sh"
    # 设置conda自动完成
    conda config --set auto_activate_base false 2>/dev/null || true
else
    export PATH="/opt/miniconda3/bin:\$PATH"
fi

# CUDA and development tools
export CUDA_HOME=/usr/local/cuda
export PATH=\$CUDA_HOME/bin:\$PATH
export LD_LIBRARY_PATH=\$CUDA_HOME/lib64:\$LD_LIBRARY_PATH

# Node.js and npm
export PATH=/usr/local/lib/nodejs/bin:\$PATH

# Code-server and development services
export PATH=/usr/local/bin:/opt/code-server/bin:\$PATH

# Welcome message
echo "🚀 GPU开发环境已就绪!"
echo "📁 个人目录: /home/\$USER"
echo "📂 共享目录: /shared (只读)"
echo "💼 工作空间: /workspace (读写)"
echo "🐍 Python: \$(python3.11 --version 2>/dev/null || echo 'Not available')"
echo "🐍 Conda: \$(conda --version 2>/dev/null || echo 'Not available')"
echo "🔧 Git: \$(git --version 2>/dev/null || echo 'Not available')"
echo "🎯 CUDA: \$(nvcc --version 2>/dev/null | head -1 || echo 'Not available')"
echo "📝 编辑器: \$EDITOR"
echo ""
echo "💡 快捷命令:"
echo "   ll          - 详细列表"
echo "   python      - Python 3.11"
echo "   gs          - git status"
echo "   ports       - 查看端口"
echo "   gpu         - nvidia-smi"
echo "   workspace   - 切换到工作目录"
echo "   shared      - 切换到共享目录"
echo ""
echo "📦 环境信息:"
echo "   默认Python: 3.11"
echo "   PyTorch: 2.6.0 with CUDA 12.4"
echo "   TensorFlow: 尝试安装（可手动安装特定版本）"
echo "   CUDA: 12.4.1 + cuDNN"
echo "   预装ML/AI包: PyTorch, transformers, OpenCV等"
echo ""
echo "🎯 GPU信息:"
nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv,noheader,nounits 2>/dev/null | head -2 || echo "   GPU信息不可用"
echo ""
EOF

# 创建.bash_aliases文件
cat > /home/$DEV_USER/.bash_aliases << 'EOF'
# 开发相关别名
alias jlab='jupyter lab'
alias jnb='jupyter notebook'
alias tb='tensorboard'
alias code='code-server'

# 系统监控
alias gpu='nvidia-smi'
alias gpuwatch='watch -n 1 nvidia-smi'
alias htop='htop -C'
alias iotop='iotop -o'

# 网络和进程
alias myip='curl -s ifconfig.me'
alias listening='netstat -tlnp'
alias psg='ps aux | grep'

# 文件操作
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias mkdir='mkdir -p'

# 快速导航
alias home='cd ~'
alias shared='cd /shared'
alias workspace='cd /workspace'
alias logs='cd /tmp && ls -la *.log'

# Python开发
alias pyenv='python3 -m venv'
alias pipinstall='pip3 install'
alias piplist='pip3 list'
alias pipshow='pip3 show'

# Conda环境管理（基础功能）
alias condaenv='conda info --envs'
alias condalist='conda list'
alias condainstall='conda install'
alias condaclean='conda clean --all'

# Python包管理
alias piplist='pip list'
alias pipshow='pip show'
alias pipinstall='pip install'

# Jupyter相关
alias jlabstart='jupyter lab --ip=0.0.0.0 --port=8888 --allow-root --no-browser'
alias jnbstart='jupyter notebook --ip=0.0.0.0 --port=8888 --allow-root --no-browser'
EOF

# 创建.profile文件
cat > /home/$DEV_USER/.profile << 'EOF'
# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

# Conda initialization for login shells
if [ -f "/opt/miniconda3/etc/profile.d/conda.sh" ]; then
    . "/opt/miniconda3/etc/profile.d/conda.sh"
fi
export PATH="/opt/miniconda3/bin:/opt/miniconda3/condabin:$PATH"
EOF

# 创建vim配置
cat > /home/$DEV_USER/.vimrc << 'EOF'
" 基本设置
set number              " 显示行号
set relativenumber      " 显示相对行号
set tabstop=4           " tab宽度
set shiftwidth=4        " 自动缩进宽度
set expandtab           " 将tab转换为空格
set autoindent          " 自动缩进
set smartindent         " 智能缩进
set hlsearch            " 高亮搜索结果
set incsearch           " 增量搜索
set ignorecase          " 搜索忽略大小写
set smartcase           " 智能大小写
set showmatch           " 显示匹配的括号
set ruler               " 显示光标位置
set showcmd             " 显示命令
set wildmenu            " 命令行补全
set scrolloff=5         " 滚动时保持5行
set encoding=utf-8      " 设置编码
set fileencodings=utf-8,gbk,gb2312,big5

" 语法高亮
syntax on
filetype plugin indent on

" 颜色方案
set background=dark
if has('termguicolors')
    set termguicolors
endif

" 状态栏
set laststatus=2
set statusline=%F%m%r%h%w\ [FORMAT=%{&ff}]\ [TYPE=%Y]\ [POS=%l,%v][%p%%]\ %{strftime(\"%d/%m/%y\ -\ %H:%M\")}

" Python特定设置
autocmd FileType python setlocal tabstop=4 shiftwidth=4 expandtab
autocmd FileType python setlocal textwidth=79
autocmd FileType python setlocal autoindent
autocmd FileType python setlocal fileformat=unix

" 快捷键
nnoremap <F2> :set number!<CR>
nnoremap <F3> :set paste!<CR>
nnoremap <F4> :set hlsearch!<CR>
EOF

# 设置所有配置文件的权限
chown $DEV_UID:$DEV_GID /home/$DEV_USER/.bashrc 2>/dev/null
chown $DEV_UID:$DEV_GID /home/$DEV_USER/.bash_aliases 2>/dev/null
chown $DEV_UID:$DEV_GID /home/$DEV_USER/.profile 2>/dev/null
chown $DEV_UID:$DEV_GID /home/$DEV_USER/.vimrc 2>/dev/null
chmod 644 /home/$DEV_USER/.bashrc /home/$DEV_USER/.bash_aliases /home/$DEV_USER/.profile /home/$DEV_USER/.vimrc 2>/dev/null

echo "用户bash环境配置完成"

# 初始化用户的conda环境
echo "初始化用户conda环境..."
if [ -f "/opt/miniconda3/bin/conda" ]; then
    # 为用户初始化conda
    su - $DEV_USER -c "/opt/miniconda3/bin/conda init bash" 2>/dev/null || echo "Conda初始化失败，但程序继续"
    
    # 创建用户级conda配置目录
    mkdir -p /home/$DEV_USER/.conda
    chown -R $DEV_UID:$DEV_GID /home/$DEV_USER/.conda 2>/dev/null
    
    # 设置用户级conda配置
    su - $DEV_USER -c "conda config --set auto_activate_base false" 2>/dev/null || true
    su - $DEV_USER -c "conda config --add channels conda-forge" 2>/dev/null || true
    su - $DEV_USER -c "conda config --add channels pytorch" 2>/dev/null || true
    su - $DEV_USER -c "conda config --add channels nvidia" 2>/dev/null || true
    
    echo "Conda环境初始化完成"
else
    echo "警告: Conda未找到，跳过conda初始化"
fi

# 确保挂载目录存在并设置权限
if [ -d "/workspace" ]; then
    chown -R $DEV_UID:$DEV_GID /workspace 2>/dev/null || echo "警告: workspace权限设置失败，但目录可用"
    chmod 755 /workspace 2>/dev/null
    echo "workspace目录权限设置完成"
else
    echo "警告: workspace目录不存在"
fi

if [ -d "/shared" ]; then
    chmod 755 /shared 2>/dev/null
    echo "shared目录权限设置完成"
else
    echo "警告: shared目录不存在"
fi

# 生成Jupyter配置
if id -u $DEV_USER > /dev/null 2>&1; then
    su - $DEV_USER -c "python3 -m jupyter lab --generate-config" 2>/dev/null || echo "警告: Jupyter配置生成失败"
fi

# 配置Jupyter Lab
if mkdir -p /home/$DEV_USER/.jupyter; then
    # 生成密码哈希
    JUPYTER_PASSWORD_HASH=$(python3 -c "from jupyter_server.auth import passwd; print(passwd('$DEV_PASSWORD'))")
    
    cat > /home/$DEV_USER/.jupyter/jupyter_lab_config.py << EOF
c.ServerApp.ip = '0.0.0.0'
c.ServerApp.port = 8888
c.ServerApp.allow_root = True
c.ServerApp.open_browser = False
c.ServerApp.token = ''
c.ServerApp.password = '$JUPYTER_PASSWORD_HASH'
c.ServerApp.allow_origin = '*'
c.ServerApp.allow_remote_access = True
c.ServerApp.root_dir = '/home/$DEV_USER'
c.ServerApp.disable_check_xsrf = True
EOF

    chown $DEV_UID:$DEV_GID /home/$DEV_USER/.jupyter/jupyter_lab_config.py 2>/dev/null
fi

# 配置code-server
if mkdir -p /home/$DEV_USER/.config/code-server; then
    cat > /home/$DEV_USER/.config/code-server/config.yaml << EOF
bind-addr: 0.0.0.0:8080
auth: password
password: $DEV_PASSWORD
cert: false
EOF

    chown -R $DEV_UID:$DEV_GID /home/$DEV_USER/.config/code-server 2>/dev/null
fi

# 启动SSH服务
echo "启动SSH服务..."
if service ssh start; then
    echo "SSH服务启动成功"
else
    echo "警告: SSH服务启动失败，尝试手动启动..."
    /usr/sbin/sshd -D &
fi

# 创建启动脚本
cat > /home/$DEV_USER/start_services.sh << EOF
#!/bin/bash

echo "=== 启动开发环境服务 ==="

# 启动Jupyter Lab
echo "启动Jupyter Lab..."
nohup jupyter lab --config=/home/\$DEV_USER/.jupyter/jupyter_lab_config.py > /tmp/jupyter.log 2>&1 &
echo "Jupyter Lab PID: \$!"

# 启动code-server (VSCode Server)
echo "启动VSCode Server..."
nohup code-server > /tmp/code-server.log 2>&1 &
echo "VSCode Server PID: \$!"

# 启动TensorBoard (可选)
if [ -d "/home/\$DEV_USER/logs" ]; then
    echo "启动TensorBoard..."
    nohup tensorboard --logdir=/home/\$DEV_USER/logs --host=0.0.0.0 --port=6006 > /tmp/tensorboard.log 2>&1 &
    echo "TensorBoard PID: \$!"
fi

echo "=== 服务启动完成 ==="
echo "SSH: 端口 22 (用户名: $DEV_USER, 密码: $DEV_PASSWORD)"
echo "VSCode Server: 端口 8080 (密码: $DEV_PASSWORD)"
echo "Jupyter Lab: 端口 8888 (密码: $DEV_PASSWORD)"
echo "TensorBoard: 端口 6006 (无需认证)"
echo ""
echo "日志文件位置:"
echo "  Jupyter Lab: /tmp/jupyter.log"
echo "  VSCode Server: /tmp/code-server.log"
echo "  TensorBoard: /tmp/tensorboard.log"
EOF

# 设置启动脚本权限
if [ -f /home/$DEV_USER/start_services.sh ]; then
    chmod +x /home/$DEV_USER/start_services.sh
    chown $DEV_UID:$DEV_GID /home/$DEV_USER/start_services.sh 2>/dev/null
fi

# 创建欢迎信息
if mkdir -p /home/$DEV_USER; then
    cat > /home/$DEV_USER/README.md << EOF
# 开发环境使用指南

## 服务访问

- **SSH**: 使用用户名 \`$DEV_USER\` 和密码 \`$DEV_PASSWORD\` 登录
- **VSCode Server**: 浏览器访问 http://host:port，密码: \`$DEV_PASSWORD\`
- **Jupyter Lab**: 浏览器访问 http://host:port，密码: \`$DEV_PASSWORD\`
- **TensorBoard**: 浏览器访问 http://host:port (无需认证)

## 目录结构

- \`/home/$DEV_USER\`: 个人主目录 (读写，私有)
- \`/shared\`: 共享只读目录 (所有用户共享，只读)
- \`/workspace\`: 共享工作区 (所有用户共享，可读写)

## 启动服务

运行以下命令启动所有服务:
\`\`\`bash
./start_services.sh
\`\`\`

## 预装软件

- Python 3 + 常用AI/ML库 (TensorFlow, PyTorch, Jupyter等)
- Git, Vim, htop等开发工具
- Node.js和npm

## GPU支持

容器已配置NVIDIA CUDA支持，可直接使用GPU进行深度学习训练。

EOF

    chown $DEV_UID:$DEV_GID /home/$DEV_USER/README.md 2>/dev/null
fi

# 切换到用户身份启动服务
echo "切换到用户 $DEV_USER 启动服务..."
if id -u $DEV_USER > /dev/null 2>&1 && [ -f /home/$DEV_USER/start_services.sh ]; then
    su - $DEV_USER -c "/home/$DEV_USER/start_services.sh" 2>/dev/null || echo "警告: 服务启动失败"
else
    echo "警告: 用户不存在或启动脚本缺失，直接启动服务..."
    # 直接启动基础服务
    nohup jupyter lab --ip=0.0.0.0 --port=8888 --allow-root --no-browser --PasswordIdentityProvider.hashed_password="$(python3 -c "from jupyter_server.auth import passwd; print(passwd('$DEV_PASSWORD'))")" > /tmp/jupyter.log 2>&1 &
    nohup code-server --bind-addr=0.0.0.0:8080 --auth=password --password="$DEV_PASSWORD" > /tmp/code-server.log 2>&1 &
fi

# 保持容器运行
echo "=== 容器启动完成 ==="
echo "SSH登录: ssh -p PORT $DEV_USER@HOST"
echo "密码: $DEV_PASSWORD"
tail -f /dev/null
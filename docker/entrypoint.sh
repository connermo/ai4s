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

# 确保PATH包含所有必要的路径
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/miniconda3/bin:/opt/miniconda3/condabin:$PATH"

# Custom aliases for development environment
# 只保留ll/ls等，不设置python/pip别名
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

# 密码修改工具
alias change-password='change-password.sh'
alias changepass='change-password.sh'
alias passwd-tool='change-password.sh'

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
export PATH="/opt/miniconda3/bin:/opt/miniconda3/condabin:/usr/local/bin:/home/$USER/.local/bin:$PATH"
export EDITOR=vim
export PYTHONPATH="/workspace:/shared:$PYTHONPATH"

# Python 3.11 as default
export PYTHON=/usr/bin/python3.11
# 不设置python/pip别名，让系统和conda各自管理

# Conda initialization (optional, base environment only)
# 注意：conda会自动在.bashrc末尾添加初始化代码，这里只设置基本配置
export PATH="/opt/miniconda3/bin:$PATH"

# CUDA and development tools
export CUDA_HOME=/usr/local/cuda
export PATH=$CUDA_HOME/bin:$PATH
# 修复：确保LD_LIBRARY_PATH包含nvidia驱动库
if [[ ":$LD_LIBRARY_PATH:" != *":/usr/lib/x86_64-linux-gnu:"* ]]; then
  export LD_LIBRARY_PATH="/usr/local/cuda/lib64:/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH"
fi

# Node.js and npm
export PATH=/usr/local/lib/nodejs/bin:$PATH

# Code-server and development services
export PATH=/usr/local/bin:/opt/code-server/bin:$PATH
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
alias shared='cd ~/shared'
alias workspace='cd ~/workspace'
alias logs='cd /tmp && ls -la *.log'

# 密码和安全工具
alias change-password='change-password.sh'
alias changepass='change-password.sh'
alias passwd='echo "💡 提示: 使用 change-password 命令来修改所有服务的密码"'

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

# TensorFlow环境管理
alias tf='conda activate tf'
alias tfexit='conda deactivate'
alias tfjupyter='conda activate tf && jupyter lab --ip=0.0.0.0 --port=8888 --allow-root --no-browser'
alias tftest='conda activate tf && python -c "import tensorflow as tf; print(f\"TensorFlow版本: {tf.__version__}\"); print(f\"GPU可用: {tf.config.list_physical_devices(\"GPU\")}\")"'
alias testenv='/usr/local/bin/test_environments.sh'

# Python包管理
alias piplist='pip list'
alias pipshow='pip show'
alias pipinstall='pip install'

# Jupyter相关
alias jlabstart='jupyter lab --ip=0.0.0.0 --port=8888 --allow-root --no-browser'
alias jnbstart='jupyter notebook --ip=0.0.0.0 --port=8888 --allow-root --no-browser'

# 确保基本命令可用
alias ls='ls --color=auto'
alias ll='ls -alF --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias python='python3'
alias pip='pip3'
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

# 确保PATH包含所有必要的路径
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/miniconda3/bin:/opt/miniconda3/condabin:$PATH"

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

# CUDA and development tools
export CUDA_HOME=/usr/local/cuda
export PATH=$CUDA_HOME/bin:$PATH
# 修复：确保LD_LIBRARY_PATH包含nvidia驱动库
if [[ ":$LD_LIBRARY_PATH:" != *":/usr/lib/x86_64-linux-gnu:"* ]]; then
  export LD_LIBRARY_PATH="/usr/local/cuda/lib64:/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH"
fi

# Development environment variables
export EDITOR=vim
export PYTHONPATH="/workspace:/shared:$PYTHONPATH"
export PYTHON=/usr/bin/python3.11
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
echo "[$(date '+%H:%M:%S')] 开始初始化用户conda环境..."
if [ -f "/opt/miniconda3/bin/conda" ]; then
    # 为用户初始化conda
    echo "[$(date '+%H:%M:%S')] 为用户初始化conda..."
    su - $DEV_USER -c "/opt/miniconda3/bin/conda init bash" 2>/dev/null || echo "Conda初始化失败，但程序继续"
    
    # 创建用户级conda配置目录
    echo "[$(date '+%H:%M:%S')] 创建conda配置目录..."
    mkdir -p /home/$DEV_USER/.conda
    chown -R $DEV_UID:$DEV_GID /home/$DEV_USER/.conda 2>/dev/null
    
    # 确保conda环境权限正确
    echo "[$(date '+%H:%M:%S')] 设置conda环境权限..."
    chown -R $DEV_UID:$DEV_GID /opt/miniconda3/envs 2>/dev/null || echo "警告: conda envs权限设置失败"
    mkdir -p /opt/miniconda3/pkgs 2>/dev/null
    chown -R $DEV_UID:$DEV_GID /opt/miniconda3/pkgs 2>/dev/null || echo "警告: conda pkgs权限设置失败"
    
    # 确保CUDA库符号链接存在（用于TensorFlow GPU支持）
    echo "[$(date '+%H:%M:%S')] 配置CUDA库链接..."
    ln -sf /usr/lib/x86_64-linux-gnu/libcuda.so.1 /usr/local/cuda/lib64/libcuda.so.1 2>/dev/null || true
    ln -sf /usr/lib/x86_64-linux-gnu/libcuda.so.1 /usr/local/cuda/lib64/libcuda.so 2>/dev/null || true
    ldconfig 2>/dev/null || true
    
    # 设置用户级conda配置
    echo "[$(date '+%H:%M:%S')] 配置conda渠道..."
    su - $DEV_USER -c "conda config --set auto_activate_base false" 2>/dev/null || true
    su - $DEV_USER -c "conda config --add channels conda-forge" 2>/dev/null || true
    su - $DEV_USER -c "conda config --add channels pytorch" 2>/dev/null || true
    su - $DEV_USER -c "conda config --add channels nvidia" 2>/dev/null || true
    
    echo "[$(date '+%H:%M:%S')] Conda环境初始化完成"
else
    echo "警告: Conda未找到，跳过conda初始化"
fi

# 配置pip源
echo "[$(date '+%H:%M:%S')] 配置pip源..."
if [ -n "$PIP_INDEX_URL" ]; then
    echo "[$(date '+%H:%M:%S')] 使用内部pip源: $PIP_INDEX_URL"
    
    # 创建pip配置目录
    mkdir -p /etc/pip /home/$DEV_USER/.pip
    
    # 生成系统级pip配置
    cat > /etc/pip/pip.conf << EOF
[global]
index-url = $PIP_INDEX_URL
trusted-host = $PIP_TRUSTED_HOST
timeout = ${PIP_TIMEOUT:-60}
EOF
    
    # 生成用户级pip配置
    cat > /home/$DEV_USER/.pip/pip.conf << EOF
[global]
index-url = $PIP_INDEX_URL
trusted-host = $PIP_TRUSTED_HOST
timeout = ${PIP_TIMEOUT:-60}
EOF
    
    chown $DEV_UID:$DEV_GID /home/$DEV_USER/.pip/pip.conf
    echo "[$(date '+%H:%M:%S')] pip源配置完成"
else
    echo "[$(date '+%H:%M:%S')] 使用默认pip源"
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

# 在用户主目录创建便捷访问的符号链接
echo "[$(date '+%H:%M:%S')] 创建目录快捷方式..."
if [ -d "/workspace" ]; then
    ln -sf /workspace /home/$DEV_USER/workspace
    echo "创建workspace快捷方式: ~/workspace -> /workspace"
fi

if [ -d "/shared" ]; then
    ln -sf /shared /home/$DEV_USER/shared
    echo "创建shared快捷方式: ~/shared -> /shared"
fi

# 设置符号链接的所有者
chown -h $DEV_UID:$DEV_GID /home/$DEV_USER/workspace /home/$DEV_USER/shared 2>/dev/null

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

# 配置SSH服务
echo "[$(date '+%H:%M:%S')] 开始配置SSH服务..."

# 确保SSH目录存在
echo "[$(date '+%H:%M:%S')] 创建SSH运行目录..."
mkdir -p /var/run/sshd

# 验证SSH密钥存在（应该在构建时已生成）
echo "[$(date '+%H:%M:%S')] 验证SSH主机密钥..."
if [ -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "[$(date '+%H:%M:%S')] SSH主机密钥已存在"
else
    echo "[$(date '+%H:%M:%S')] 警告: SSH主机密钥缺失，快速生成..."
    service haveged start 2>/dev/null
    ssh-keygen -A
    service haveged stop 2>/dev/null
    echo "[$(date '+%H:%M:%S')] SSH密钥生成完成"
fi

# 启动SSH服务
echo "[$(date '+%H:%M:%S')] 启动SSH服务..."
if service ssh start; then
    echo "[$(date '+%H:%M:%S')] SSH服务启动成功"
    # 验证SSH服务状态
    if pgrep sshd > /dev/null; then
        echo "[$(date '+%H:%M:%S')] SSH daemon正在运行"
    else
        echo "[$(date '+%H:%M:%S')] 警告: SSH daemon未运行"
    fi
else
    echo "[$(date '+%H:%M:%S')] 警告: SSH服务启动失败，尝试手动启动..."
    /usr/sbin/sshd -D &
    sleep 2
    if pgrep sshd > /dev/null; then
        echo "[$(date '+%H:%M:%S')] SSH手动启动成功"
    else
        echo "[$(date '+%H:%M:%S')] 错误: SSH手动启动失败"
    fi
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

- \`~/\` 或 \`/home/$DEV_USER\`: 个人主目录 (读写，私有)
- \`~/shared\` 或 \`/shared\`: 共享只读目录 (所有用户共享，只读)
- \`~/workspace\` 或 \`/workspace\`: 共享工作区 (所有用户共享，可读写)

## 启动服务

运行以下命令启动所有服务:
\`\`\`bash
./start_services.sh
\`\`\`

## 密码管理

修改SSH、VSCode和Jupyter的登录密码:
\`\`\`bash
change-password
\`\`\`

## 深度学习环境

### PyTorch环境 (主环境)
- 默认Python环境已安装PyTorch 2.6.0 + CUDA 12.4
- 可直接使用: \`python3 -c "import torch; print(torch.__version__)"\`
- 测试GPU: \`python3 -c "import torch; print(torch.cuda.is_available())"\`

### TensorFlow环境 (conda环境)
- 使用conda环境管理，避免版本冲突
- 激活环境: \`tf\` 或 \`conda activate tf\`
- 退出环境: \`tfexit\` 或 \`conda deactivate\`
- 测试环境: \`tftest\`
- TensorFlow专用Jupyter: \`tfjupyter\`

### 环境切换示例
\`\`\`bash
# 使用PyTorch (默认环境)
python3 -c "import torch; print('PyTorch:', torch.__version__)"

# 切换到TensorFlow环境
tf
python -c "import tensorflow as tf; print('TensorFlow:', tf.__version__)"

# 退出TensorFlow环境
tfexit
\`\`\`

## 预装软件

- Python 3.11 + PyTorch 2.6.0 (主环境)
- TensorFlow 2.15.0 (conda环境)
- Jupyter Lab, Git, Vim等开发工具
- Node.js和npm

## GPU支持

容器已配置NVIDIA CUDA 12.4支持，两个框架都可使用GPU加速。

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
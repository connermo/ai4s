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
echo "共享只读: /shared-ro $([ -d "/shared-ro" ] && echo "✓" || echo "✗")"
echo "共享读写: /shared-rw $([ -d "/shared-rw" ] && echo "✓" || echo "✗")"
echo "组共享目录: /groups $([ -d "/groups" ] && echo "✓" || echo "✗")"
echo ""

# 检查是否以root身份运行
if [ "$(id -u)" != "0" ]; then
    echo "错误: 容器需要以root身份启动才能创建用户"
    exit 1
fi

# 确保组目录存在
echo "=== 初始化组目录结构 ==="
if [ ! -d "/groups" ]; then
    mkdir -p /groups
    chmod 755 /groups
    echo "创建 /groups 目录"
else
    echo "/groups 目录已存在"
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
    mkdir -p /home/$DEV_USER
    if useradd -m -u $DEV_UID -g $DEV_GID -s /bin/bash -d /home/$DEV_USER $DEV_USER 2>/dev/null; then
        echo "创建用户: $DEV_USER ($DEV_UID:$DEV_GID)"
        echo "$DEV_USER:$DEV_PASSWORD" | chpasswd
            echo "密码设置成功"
        usermod -aG sudo $DEV_USER
            echo "添加到sudo组成功"
        echo "$DEV_USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
            echo "sudo免密设置成功"
    else
        echo "警告: 用户创建失败，可能已存在"
    fi
else
    # 用户已存在，静默处理
    # 确保密码是最新的
    echo "$DEV_USER:$DEV_PASSWORD" | chpasswd 2>/dev/null
fi

chown -R $DEV_UID:$DEV_GID /home/$DEV_USER
    echo "用户主目录权限设置成功"

echo ""
echo "=== 组权限设置 ==="

# 处理用户组信息
if [ -n "$USER_GROUPS" ] && [ -n "$USER_GROUP_GIDS" ]; then
    echo "配置用户组: $USER_GROUPS"
    echo "组GID: $USER_GROUP_GIDS"
    echo "用户角色: $USER_ROLES"
    # 将逗号分隔的字符串转换为数组
    IFS=',' read -ra GROUP_NAMES <<< "$USER_GROUPS"
    IFS=',' read -ra GROUP_GIDS <<< "$USER_GROUP_GIDS"
    IFS=',' read -ra ROLES <<< "$USER_ROLES"
    
    # 为每个组创建系统组并将用户添加到组中
    for i in "${!GROUP_NAMES[@]}"; do
        GROUP_NAME="${GROUP_NAMES[$i]}"
        GROUP_GID="${GROUP_GIDS[$i]}"
        
        echo "处理组: $GROUP_NAME (GID: $GROUP_GID)"
        
        # 创建系统组（如果不存在）
        if ! getent group "$GROUP_NAME" > /dev/null 2>&1; then
            if groupadd -g "$GROUP_GID" "$GROUP_NAME" 2>/dev/null; then
                echo "  创建系统组: $GROUP_NAME ($GROUP_GID)"
            else
                echo "  警告: 组 $GROUP_NAME 创建失败，可能已存在"
            fi
        fi
        
        # 将用户添加到组中（静默处理，避免重复信息）
        usermod -a -G "$GROUP_NAME" "$DEV_USER" 2>/dev/null
        
        # 设置组目录权限
        GROUP_DIR="/groups/$GROUP_NAME"
        if [ -d "$GROUP_DIR" ]; then
            echo "  设置组目录权限: $GROUP_DIR"
            
            # 确保目录所有者是root，组是对应的组
            chown -R "root:$GROUP_NAME" "$GROUP_DIR" 2>/dev/null || echo "    警告: 无法设置组目录所有者"
            
            # 设置目录权限为775 (rwxrwxr-x)，确保组成员有写权限
            chmod -R 775 "$GROUP_DIR" 2>/dev/null || echo "    警告: 无法设置组目录权限"
            
            # 设置组目录的粘滞位，新创建的文件和目录会继承组权限
            find "$GROUP_DIR" -type d -exec chmod g+s {} \; 2>/dev/null || echo "    警告: 无法设置组目录的粘滞位"
            
            # 验证权限设置
            echo "    目录权限: $(ls -ld "$GROUP_DIR" 2>/dev/null | cut -d' ' -f1)"
        else
            echo "  警告: 组目录 $GROUP_DIR 不存在，将创建目录"
            mkdir -p "$GROUP_DIR"
            chown "root:$GROUP_NAME" "$GROUP_DIR" 2>/dev/null
            chmod 775 "$GROUP_DIR" 2>/dev/null
            chmod g+s "$GROUP_DIR" 2>/dev/null
        fi
        
        # 创建标准子目录结构
        echo "  创建组子目录结构..."
        
        # shared-rw: 所有组成员可读写
        SHARED_RW_DIR="$GROUP_DIR/shared-rw"
        mkdir -p "$SHARED_RW_DIR" 2>/dev/null || true
        chown "root:$GROUP_NAME" "$SHARED_RW_DIR" 2>/dev/null || true
        chmod 775 "$SHARED_RW_DIR" 2>/dev/null || true
        chmod g+s "$SHARED_RW_DIR" 2>/dev/null || true
        echo "    ✓ 共享读写目录: shared-rw (775)"
        
        # shared-ro: 只有管理员可写，其他成员只读
        SHARED_RO_DIR="$GROUP_DIR/shared-ro"
        mkdir -p "$SHARED_RO_DIR" 2>/dev/null || true
        chown "root:$GROUP_NAME" "$SHARED_RO_DIR" 2>/dev/null || true
        chmod 755 "$SHARED_RO_DIR" 2>/dev/null || true
        chmod g+s "$SHARED_RO_DIR" 2>/dev/null || true
        
        # 检查当前用户是否为该组的管理员
        CURRENT_ROLE=""
        if [ ${#ROLES[@]} -gt $i ]; then
            CURRENT_ROLE="${ROLES[$i]}"
        fi
        
        if [ "$CURRENT_ROLE" = "admin" ]; then
            echo "    设置管理员权限: $DEV_USER 对 $GROUP_NAME/shared-ro"
            
            # 尝试使用ACL设置权限
            if command -v setfacl >/dev/null 2>&1; then
                setfacl -m "u:$DEV_USER:rwx" "$SHARED_RO_DIR" 2>/dev/null || {
                    echo "      ACL设置失败，使用传统方法..."
                    chown "$DEV_USER:$GROUP_NAME" "$SHARED_RO_DIR" 2>/dev/null || true
                }
                # 设置默认ACL，新文件也会有正确权限
                setfacl -d -m "u:$DEV_USER:rwx" "$SHARED_RO_DIR" 2>/dev/null || true
                setfacl -d -m "g:$GROUP_NAME:r-x" "$SHARED_RO_DIR" 2>/dev/null || true
                echo "    ✓ 管理员专用目录: shared-ro (755 + ACL)"
            else
                chown "$DEV_USER:$GROUP_NAME" "$SHARED_RO_DIR" 2>/dev/null || true
                echo "    ✓ 管理员专用目录: shared-ro (755, 所有者: $DEV_USER)"
            fi
            
            # 创建管理员标记文件
            if ! grep -q "^$DEV_USER$" "$GROUP_DIR/.group_admins" 2>/dev/null; then
                echo "$DEV_USER" >> "$GROUP_DIR/.group_admins"
            fi
            chmod 644 "$GROUP_DIR/.group_admins" 2>/dev/null || true
        else
            echo "    ✓ 成员只读目录: shared-ro (755)"
        fi
    done
    
    
    echo "组权限配置完成"
else
    echo "用户未分配到任何组"
fi

# 创建必要的目录
mkdir -p /home/$DEV_USER/.jupyter
mkdir -p /home/$DEV_USER/.vscode-server
mkdir -p /home/$DEV_USER/.config/code-server
mkdir -p /home/$DEV_USER/.local/share/code-server/extensions
mkdir -p /home/$DEV_USER/.local/share/code-server/User

# 设置目录权限
chown -R $DEV_UID:$DEV_GID /home/$DEV_USER/.jupyter 2>/dev/null
chown -R $DEV_UID:$DEV_GID /home/$DEV_USER/.vscode-server 2>/dev/null
chown -R $DEV_UID:$DEV_GID /home/$DEV_USER/.config 2>/dev/null
chown -R $DEV_UID:$DEV_GID /home/$DEV_USER/.local 2>/dev/null

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
alias shared-ro='cd ~/shared-ro'
alias shared-rw='cd ~/shared-rw'
alias groups='cd ~/groups'
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

# VSCode扩展管理
alias code-ext='code-server --list-extensions'
alias code-install='code-server --install-extension'
alias code-uninstall='code-server --uninstall-extension'
alias code-disable='code-server --disable-extension'

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
chown -R $DEV_UID:$DEV_GID /shared-rw 2>/dev/null || echo "警告: shared-rw权限设置失败"
echo "shared-rw目录权限设置完成"

# 创建用户目录下的符号链接
echo "创建用户目录下的符号链接..."
ln -sfnT /shared-ro /home/$DEV_USER/shared-ro
ln -sfnT /shared-rw /home/$DEV_USER/shared-rw
chown -h $DEV_UID:$DEV_GID /home/$DEV_USER/shared-ro /home/$DEV_USER/shared-rw

# 为用户组创建符号链接
if [ -n "$USER_GROUPS" ] && [ -d "/groups" ]; then
    echo "创建组目录符号链接..."
    # 只创建一个通用的groups目录链接，用户可通过 ~/groups/<组名> 访问各组目录
    ln -sfnT "/groups" "/home/$DEV_USER/groups"
    chown -h $DEV_UID:$DEV_GID "/home/$DEV_USER/groups"
    echo "  创建组目录符号链接: ~/groups (可访问所有组目录)"
    
    # 列出用户可访问的组目录
    IFS=',' read -ra GROUP_NAMES <<< "$USER_GROUPS"
    echo "  用户可访问的组目录:"
    for GROUP_NAME in "${GROUP_NAMES[@]}"; do
        if [ -d "/groups/$GROUP_NAME" ]; then
            echo "    ~/groups/$GROUP_NAME"
        fi
    done
fi

echo ""
echo "=== 启动服务 ==="

# 启动SSH服务
echo "启动SSH服务..."
    /usr/sbin/sshd -D &

# 切换到用户身份启动服务
echo "切换到用户 $DEV_USER 启动服务..."
if id -u $DEV_USER > /dev/null 2>&1; then
    # 设置VSCode Server密码
    export PASSWORD="$DEV_PASSWORD"

# 启动Jupyter Lab
echo "启动Jupyter Lab..."
    # 先生成Jupyter配置文件
    python3 -c "
import os
import json
from jupyter_server.auth import passwd

# 生成密码哈希
hashed_password = passwd('$DEV_PASSWORD')

# 创建配置目录
config_dir = '/home/$DEV_USER/.jupyter'
os.makedirs(config_dir, exist_ok=True)

# 写入JSON配置
config_file = os.path.join(config_dir, 'jupyter_server_config.json')
config = {
    'PasswordIdentityProvider': {
        'hashed_password': hashed_password
    },
    'ServerApp': {
        'ip': '0.0.0.0',
        'port': 8888,
        'allow_root': True,
        'open_browser': False,
        'token': '',
        'allow_origin': '*',
        'allow_remote_access': True,
        'disable_check_xsrf': True
    }
}

with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)
"
    chown $DEV_UID:$DEV_GID /home/$DEV_USER/.jupyter/jupyter_server_config.json
    su - $DEV_USER -c "nohup jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root > /tmp/jupyter.log 2>&1 &"

    # 启动VSCode Server
echo "启动VSCode Server..."
    # 创建VSCode配置文件
    mkdir -p /home/$DEV_USER/.config/code-server
    cat > /home/$DEV_USER/.config/code-server/config.yaml << EOF
bind-addr: 0.0.0.0:8080
auth: password
password: $DEV_PASSWORD
cert: false
EOF
    chown $DEV_UID:$DEV_GID /home/$DEV_USER/.config/code-server/config.yaml
    su - $DEV_USER -c "nohup code-server > /tmp/code-server.log 2>&1 &"
else
    echo "警告: 用户 $DEV_USER 不存在，无法启动用户服务。"
fi

# 创建欢迎信息
if mkdir -p /home/$DEV_USER; then
    cat > /home/$DEV_USER/README.md << EOF
# 开发环境使用指南

## 服务访问

- **SSH**: 使用用户名 \`$DEV_USER\` 登录
- **VSCode Server**: 浏览器访问分配的VSCode端口
- **Jupyter Lab**: 浏览器访问分配的Jupyter端口

## 目录结构

- \`~/\` 或 \`/home/$DEV_USER\`: 个人主目录 (读写，私有)
- \`~/shared-ro\` 或 \`/shared-ro\`: 全局共享只读目录 (所有用户共享，只读)
- \`~/shared-rw\` 或 \`/shared-rw\`: 全局共享工作区 (所有用户共享，可读写)
- \`~/groups\` 或 \`/groups\`: 用户组共享目录根目录 (所有组的统一入口)
- \`~/groups/<组名>/\`: 组共享目录 (仅组成员可访问)
  - \`~/groups/<组名>/shared-rw/\`: 组协作工作区 (所有组成员可读写)
  - \`~/groups/<组名>/shared-ro/\`: 组资源目录 (管理员可写，成员只读)

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

echo "=== 容器启动完成 ==="
echo "服务(SSH, VSCode, Jupyter)已启动。"
echo "请联系管理员获取主机、端口和登录凭证信息。"

# 保持容器运行
tail -f /dev/null
// API基础URL
const API_BASE = '/api';

// 当前显示的section
let currentSection = 'users';

// HTML转义函数，防止XSS攻击
function escapeHtml(text) {
    if (text == null) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// 格式化日期时间
function formatDateTime(dateTimeStr) {
    if (!dateTimeStr) return '';
    try {
        const date = new Date(dateTimeStr);
        return date.toLocaleString('zh-CN', {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit'
        });
    } catch (error) {
        return dateTimeStr;
    }
}

// 检查管理员认证
function checkAdminAuth() {
    const admin = sessionStorage.getItem('admin');
    const adminToken = sessionStorage.getItem('adminToken');
    
    if (!admin || !adminToken) {
        // 未登录，跳转到管理员登录页面
        window.location.href = '/admin-login';
        return;
    }
    
    try {
        const adminData = JSON.parse(admin);
        if (!adminData.is_admin) {
            // 不是管理员，跳转到管理员登录页面
            sessionStorage.removeItem('admin');
            sessionStorage.removeItem('adminToken');
            window.location.href = '/admin-login';
            return;
        }
    } catch (error) {
        console.error('解析管理员信息失败:', error);
        sessionStorage.removeItem('admin');
        sessionStorage.removeItem('adminToken');
        window.location.href = '/admin-login';
    }
}

// 获取管理员认证头
function getAdminHeaders() {
    const adminToken = sessionStorage.getItem('adminToken');
    return {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${adminToken}`
    };
}

// 防抖变量
let containerLoadTimeout = null;
let isContainerLoading = false;

// 页面加载完成后初始化
document.addEventListener('DOMContentLoaded', function() {
    // 检查管理员认证
    checkAdminAuth();
    
    loadUsers();
    loadContainers();
    loadUserOptions();
    
    // 设置密码类型切换事件
    setupPasswordTypeToggle();
    
    // 初始化模态框事件监听
    initializeModalEvents();
    
    // 监听创建容器模态框显示事件，实时刷新用户列表（增强健壮性）
    const createContainerModal = document.getElementById('createContainerModal');
    if (createContainerModal) {
        // 主要事件监听
        createContainerModal.addEventListener('shown.bs.modal', function() {
            console.log('创建容器模态框打开，刷新用户列表...');
            loadUserOptions(0); // 实时获取最新用户列表，重置重试计数
            generateSecurePassword(); // 自动生成密码
        });
        
        // 备用事件监听（防止Bootstrap事件失效）
        createContainerModal.addEventListener('show.bs.modal', function() {
            console.log('模态框准备显示，预加载用户列表...');
            // 预加载，但不重置已有的选项（除非失败）
            const select = document.getElementById('container-user-id');
            if (select && (select.innerHTML === '' || select.innerHTML.includes('加载失败'))) {
                loadUserOptions(0);
            }
        });
    }
    
    // 添加创建容器按钮点击事件作为最后的保障
    const createContainerButton = document.querySelector('[data-bs-target="#createContainerModal"]');
    if (createContainerButton) {
        createContainerButton.addEventListener('click', function() {
            console.log('创建容器按钮被点击，确保用户列表最新...');
            // 延迟一点确保模态框已经显示
            setTimeout(() => {
                const select = document.getElementById('container-user-id');
                if (select && select.children.length <= 1) {
                    console.log('检测到用户列表为空或仅有默认选项，强制刷新...');
                    loadUserOptions(0);
                }
            }, 200);
        });
    }
    
    // 优化的定时刷新机制（减少不必要的刷新）
    setInterval(() => {
        if (currentSection === 'users') {
            loadUsers();
        } else if (currentSection === 'containers' && !isContainerLoading) {
            // 容器页面使用强制刷新确保与Docker状态同步，但避免重复加载
            loadContainers(true);
        } else if (currentSection === 'groups') {
            loadGroups();
        } else if (currentSection === 'dashboard') {
            loadDashboard();
        }
    }, 30000);
    
    // 优化的页面可见性检测，添加防抖
    document.addEventListener('visibilitychange', function() {
        if (!document.hidden && currentSection === 'containers') {
            console.log('页面重新可见，延迟刷新容器状态...');
            // 清除之前的定时器
            if (containerLoadTimeout) {
                clearTimeout(containerLoadTimeout);
            }
            // 设置新的延迟刷新
            containerLoadTimeout = setTimeout(() => {
                if (!isContainerLoading) {
                    loadContainers(true);
                }
            }, 1000);
        }
    });

    // 初始化自定义tooltip
    const tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
    tooltipTriggerList.map(function (tooltipTriggerEl) {
        return new bootstrap.Tooltip(tooltipTriggerEl);
    });
});

// 设置密码类型切换（已简化，不再需要）
function setupPasswordTypeToggle() {
    // 功能已简化，不再需要密码类型切换
}

// 显示指定section
function showSection(sectionName) {
    // 隐藏所有section
    document.querySelectorAll('.section').forEach(section => {
        section.style.display = 'none';
    });
    
    // 移除所有nav-link的active类
    document.querySelectorAll('.nav-link').forEach(link => {
        link.classList.remove('active');
    });
    
    // 显示指定section
    document.getElementById(sectionName + '-section').style.display = 'block';
    
    // 添加active类到对应nav-link
    document.querySelector(`[href="#${sectionName}"]`).classList.add('active');
    
    currentSection = sectionName;
    
    // 根据section加载对应数据
    if (sectionName === 'users') {
        loadUsers();
    } else if (sectionName === 'containers') {
        // 切换到容器页面时强制刷新确保状态同步
        loadContainers(true);
    } else if (sectionName === 'groups') {
        loadGroups();
    } else if (sectionName === 'dashboard') {
        loadDashboard();
    }
}

// 加载用户列表
async function loadUsers() {
    try {
        const response = await fetch(`${API_BASE}/users`, {
            headers: getAdminHeaders()
        });
        const users = await response.json();
        
        const tbody = document.getElementById('users-table-body');
        tbody.innerHTML = '';
        
        // 处理null或空数组的情况
        if (users && Array.isArray(users) && users.length > 0) {
            users.forEach(user => {
                const row = createUserRow(user);
                tbody.appendChild(row);
            });
        } else {
            // 显示空状态
            const row = document.createElement('tr');
            row.innerHTML = '<td colspan="8" class="text-center text-muted">暂无用户</td>';
            tbody.appendChild(row);
        }
    } catch (error) {
        handleApiError(error, '加载用户失败');
    }
}

// 创建用户表格行
function createUserRow(user) {
    const row = document.createElement('tr');
    
    const statusClass = user.is_active ? 'status-active' : 'status-inactive';
    const statusText = user.is_active ? '活跃' : '禁用';
    const adminText = user.is_admin ? '是' : '否';
    const ports = `${user.base_port}-${user.base_port + 9}`;
    
    row.innerHTML = `
        <td>${user.id}</td>
        <td>${user.username}</td>
        <td>${user.email || '-'}</td>
        <td><span class="status-badge ${statusClass}">${statusText}</span></td>
        <td>${adminText}</td>
        <td>${ports}</td>
        <td>${new Date(user.created_at).toLocaleDateString()}</td>
        <td>
            <button class="btn btn-action btn-action-primary" onclick="editUser(${user.id})" title="编辑用户">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                    <path d="m18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
            </button>
            <button class="btn btn-action btn-action-warning" onclick="changePassword(${user.id})" title="修改密码">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <rect x="3" y="11" width="18" height="11" rx="2" ry="2" stroke="currentColor" stroke-width="2"/>
                    <circle cx="12" cy="16" r="1" fill="currentColor"/>
                    <path d="M7 11V7a5 5 0 0 1 10 0v4" stroke="currentColor" stroke-width="2"/>
                </svg>
            </button>
            ${user.username !== 'admin' ? 
                `<button class="btn btn-action btn-action-danger" onclick="deleteUser(${user.id}, '${user.username}')" title="删除用户">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <polyline points="3,6 5,6 21,6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                        <path d="m19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                        <line x1="10" y1="11" x2="10" y2="17" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                        <line x1="14" y1="11" x2="14" y2="17" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                    </svg>
                 </button>` : 
                '<span class="text-muted small">系统管理员</span>'
            }
        </td>
    `;
    
    return row;
}

// 创建用户
async function createUser() {
    const username = document.getElementById('username').value;
    const password = document.getElementById('password').value;
    const email = document.getElementById('email').value;
    
    if (!username || !password) {
        showAlert('用户名和密码不能为空', 'warning');
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE}/users`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                ...getAdminHeaders()
            },
            body: JSON.stringify({ username, password, email }),
        });
        
        if (response.ok) {
            showAlert('用户创建成功！', 'success');
            // 重置表单
            resetForm('addUserForm');
            // 关闭模态框
            closeModal('addUserModal');
            // 刷新数据
            loadUsers();
            loadUserOptions(); // 刷新用户选项列表
        } else {
            const error = await response.text();
            showAlert(`创建失败: ${error}`, 'danger');
        }
    } catch (error) {
        handleApiError(error, '创建用户失败');
    }
}

// 删除用户
async function deleteUser(id, username) {
    // 防止删除admin用户
    if (username === 'admin') {
        showAlert('不能删除系统管理员账户！', 'warning');
        return;
    }
    
    if (!confirm(`确定要删除用户 "${username}" 吗？`)) {
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE}/users/${id}`, {
            method: 'DELETE',
            headers: getAdminHeaders()
        });
        
        if (response.ok) {
            showAlert('用户删除成功', 'success');
            loadUsers();
        } else {
            showAlert('删除失败', 'danger');
        }
    } catch (error) {
        handleApiError(error, '删除用户失败');
    }
}

// 加载容器列表（优化防闪烁）
async function loadContainers(forceRefresh = false) {
    // 防止重复加载
    if (isContainerLoading) {
        console.log('容器列表正在加载中，跳过重复请求');
        return;
    }
    
    try {
        isContainerLoading = true;
        console.log('正在加载容器列表...', forceRefresh ? '(强制刷新)' : '');
        
        // 添加缓存控制头确保获取最新数据
        const headers = forceRefresh ? {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
            'Expires': '0'
        } : {};
        
        const response = await fetch(`${API_BASE}/containers`, { 
            headers: {
                ...headers,
                ...getAdminHeaders()
            }
        });
        const containers = await response.json();
        
        const tbody = document.getElementById('containers-table-body');
        if (!tbody) {
            console.warn('容器表格未找到');
            return;
        }
        
        // 检查当前表格是否已有内容，如果有则不显示加载状态
        const currentRows = tbody.querySelectorAll('tr');
        const hasContent = currentRows.length > 0 && !currentRows[0].textContent.includes('正在加载');
        
        // 只在首次加载或强制刷新时显示加载状态
        if (!hasContent || forceRefresh) {
            tbody.innerHTML = '<tr><td colspan="8" class="text-center text-muted">正在加载容器...</td></tr>';
        }
        
        // 处理null或空数组的情况
        if (containers && Array.isArray(containers) && containers.length > 0) {
            // 清空加载状态
            tbody.innerHTML = '';
            
            // 并行创建所有容器行以提高性能
            const rowPromises = containers.map(container => createContainerRow(container));
            const rows = await Promise.all(rowPromises);
            
            // 一次性添加所有行
            rows.forEach(row => {
                if (row) tbody.appendChild(row);
            });
            
            console.log(`成功加载 ${containers.length} 个容器`);
        } else {
            // 显示空状态
            tbody.innerHTML = '<tr><td colspan="8" class="text-center text-muted">暂无容器</td></tr>';
            console.log('当前没有容器');
        }
        
        // 更新容器计数（如果在仪表板页面）
        if (currentSection === 'dashboard') {
            updateContainerStats(containers);
        }
        
    } catch (error) {
        const tbody = document.getElementById('containers-table-body');
        if (tbody) {
            tbody.innerHTML = '<tr><td colspan="8" class="text-center text-danger">加载失败，请刷新页面重试</td></tr>';
        }
        handleApiError(error, '加载容器失败');
    } finally {
        isContainerLoading = false;
    }
}

// 更新容器统计信息
function updateContainerStats(containers) {
    if (containers && Array.isArray(containers)) {
        const runningCount = containers.filter(c => c.status === 'running').length;
        const runningElement = document.getElementById('running-containers');
        if (runningElement) {
            runningElement.textContent = runningCount;
        }
    }
}

// 创建容器表格行
async function createContainerRow(container) {
    const row = document.createElement('tr');
    
    // 获取用户信息
    let username = '未知';
    try {
        const userResponse = await fetch(`${API_BASE}/users/${container.user_id}`, {
            headers: getAdminHeaders()
        });
        if (userResponse.ok) {
            const user = await userResponse.json();
            username = user.username;
        }
    } catch (error) {
        console.error('获取用户信息失败:', error);
    }
    
    const statusClass = container.status === 'running' ? 'status-running' : 'status-stopped';
    const statusText = container.status === 'running' ? '运行中' : '已停止';
    // GPU设备默认显示"全部"，除非明确指定了特定设备
    const gpuDevices = container.gpu_devices && container.gpu_devices !== '' ? container.gpu_devices : '全部';
    
    // 获取端口信息
    let ports = '-';
    let portsTitle = '-';
    try {
        const portResponse = await fetch(`${API_BASE}/users/${container.user_id}/container`, {
            headers: getAdminHeaders()
        });
        if (portResponse.ok) {
            const data = await portResponse.json();
            const p = data.ports;
            const serverHost = window.location.hostname;
            
            // 纯文本版本用于title属性
            portsTitle = `SSH:${p.ssh} VSCode:${p.vscode} Jupyter:${p.jupyter}`;
            
            // 只有在容器运行时才显示可点击链接
            if (container.status === 'running') {
                ports = `SSH:${p.ssh} <a href="http://${serverHost}:${p.vscode}" target="_blank" class="text-primary" title="点击访问VSCode">VSCode:${p.vscode}</a> <a href="http://${serverHost}:${p.jupyter}" target="_blank" class="text-primary" title="点击访问Jupyter">Jupyter:${p.jupyter}</a>`;
            } else {
                ports = portsTitle;
            }
        }
    } catch (error) {
        console.error('获取端口信息失败:', error);
    }
    
    row.innerHTML = `
        <td>${username}</td>
        <td>${container.name}</td>
        <td><span class="status-badge ${statusClass}">${statusText}</span></td>
        <td>${gpuDevices}</td>
        <td class="text-truncate" title="${portsTitle}">${ports}</td>
        <td>
            ${container.status === 'running' 
                ? `<button class="btn btn-action btn-action-warning" onclick="stopContainer('${container.id}')" title="停止容器">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <rect x="6" y="4" width="4" height="16" fill="currentColor"/>
                        <rect x="14" y="4" width="4" height="16" fill="currentColor"/>
                    </svg>
                   </button>`
                : `<button class="btn btn-action btn-action-success" onclick="startContainer('${container.id}')" title="启动容器">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <polygon points="5,3 19,12 5,21" fill="currentColor"/>
                    </svg>
                   </button>`
            }
            <button class="btn btn-action btn-action-info" onclick="copyUsageInstructions('${container.id}', '${username}', '${container.name}')" title="复制使用说明">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <rect x="9" y="9" width="13" height="13" rx="2" ry="2" stroke="currentColor" stroke-width="2"/>
                    <path d="m5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" stroke="currentColor" stroke-width="2"/>
                </svg>
            </button>
            <button class="btn btn-action btn-action-secondary" onclick="resetContainerPasswordDialog('${container.id}', '${container.name}')" title="重置服务密码">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <rect x="3" y="11" width="18" height="11" rx="2" ry="2" stroke="currentColor" stroke-width="2"/>
                    <circle cx="12" cy="16" r="1" fill="currentColor"/>
                    <path d="M7 11V7a5 5 0 0 1 10 0v4" stroke="currentColor" stroke-width="2"/>
                </svg>
            </button>
            <button class="btn btn-action btn-action-danger" onclick="removeContainer('${container.id}', '${container.name}')" title="删除容器">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <polyline points="3,6 5,6 21,6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                    <path d="m19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                    <line x1="10" y1="11" x2="10" y2="17" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                    <line x1="14" y1="11" x2="14" y2="17" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
            </button>
        </td>
    `;
    
    return row;
}

// 启动容器（优化状态同步）
async function startContainer(id) {
    try {
        console.log(`正在启动容器 ${id}...`);
        
        const response = await fetch(`${API_BASE}/containers/${id}/start`, {
            method: 'POST',
            headers: getAdminHeaders()
        });
        
        if (response.ok) {
            showAlert('容器启动成功', 'success');
            // 延迟后刷新确保状态同步，但不强制刷新
            setTimeout(() => {
                if (!isContainerLoading) {
                    loadContainers(false); // 普通刷新，减少闪烁
                }
            }, 1500);
        } else {
            const error = await response.text();
            showAlert(`启动失败: ${error}`, 'danger');
            // 失败时强制刷新显示真实状态
            if (!isContainerLoading) {
                loadContainers(true);
            }
        }
    } catch (error) {
        handleApiError(error, '启动容器失败');
        // 失败时强制刷新显示真实状态
        if (!isContainerLoading) {
            loadContainers(true);
        }
    }
}

// 停止容器（优化状态同步）
async function stopContainer(id) {
    try {
        console.log(`正在停止容器 ${id}...`);
        
        const response = await fetch(`${API_BASE}/containers/${id}/stop`, {
            method: 'POST',
            headers: getAdminHeaders()
        });
        
        if (response.ok) {
            showAlert('容器停止成功', 'success');
            // 延迟后刷新确保状态同步，但不强制刷新
            setTimeout(() => {
                if (!isContainerLoading) {
                    loadContainers(false); // 普通刷新，减少闪烁
                }
            }, 1500);
        } else {
            const error = await response.text();
            showAlert(`停止失败: ${error}`, 'danger');
            // 失败时强制刷新显示真实状态
            if (!isContainerLoading) {
                loadContainers(true);
            }
        }
    } catch (error) {
        handleApiError(error, '停止容器失败');
        // 失败时强制刷新显示真实状态
        if (!isContainerLoading) {
            loadContainers(true);
        }
    }
}

// 删除容器（优化状态同步）
async function removeContainer(id, name) {
    if (!confirm(`确定要删除容器 "${name}" 吗？`)) {
        return;
    }
    
    try {
        console.log(`正在删除容器 ${id}...`);
        
        const response = await fetch(`${API_BASE}/containers/${id}`, {
            method: 'DELETE',
            headers: getAdminHeaders()
        });
        
        if (response.ok) {
            showAlert('容器删除成功', 'success');
            // 删除成功后立即刷新，但避免重复加载
            if (!isContainerLoading) {
                loadContainers(true); // 强制刷新
            }
            loadUserOptions(0); // 刷新用户列表（用户可能重新可用）
        } else {
            const error = await response.text();
            showAlert(`删除失败: ${error}`, 'danger');
            // 失败时强制刷新显示真实状态
            if (!isContainerLoading) {
                loadContainers(true);
            }
        }
    } catch (error) {
        handleApiError(error, '删除容器失败');
        // 失败时强制刷新显示真实状态
        if (!isContainerLoading) {
            loadContainers(true);
        }
    }
}

// 加载用户选项（增强健壮性）
async function loadUserOptions(retryCount = 0) {
    const maxRetries = 3;
    const retryDelay = 1000; // 1秒
    
    try {
        console.log(`正在加载用户选项... (尝试 ${retryCount + 1}/${maxRetries + 1})`);
        
        // 添加超时控制
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 10000); // 10秒超时
        
        const response = await fetch(`${API_BASE}/users`, {
            signal: controller.signal,
            headers: {
                'Cache-Control': 'no-cache, no-store, must-revalidate',
                'Pragma': 'no-cache',
                'Expires': '0',
                ...getAdminHeaders()
            }
        });
        
        clearTimeout(timeoutId);
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const users = await response.json();
        
        const select = document.getElementById('container-user-id');
        if (!select) {
            console.warn('用户选择框未找到');
            return;
        }
        
        // 显示加载状态
        select.innerHTML = '<option value="">正在加载用户...</option>';
        
        // 处理null或空数组的情况
        if (users && Array.isArray(users)) {
            const availableUsers = users.filter(user => user && !user.container_id);
            
            // 清空并重新填充选项
            select.innerHTML = '<option value="">选择用户</option>';
            
            if (availableUsers.length === 0) {
                const option = document.createElement('option');
                option.value = '';
                option.textContent = '暂无可用用户（所有用户都已有容器）';
                option.disabled = true;
                select.appendChild(option);
            } else {
                availableUsers.forEach(user => {
                    if (user && user.id && user.username) {
                        const option = document.createElement('option');
                        option.value = user.id;
                        option.textContent = user.username;
                        select.appendChild(option);
                    }
                });
                console.log(`成功加载 ${availableUsers.length} 个可用用户`);
            }
        } else {
            // 没有用户数据
            select.innerHTML = '<option value="">暂无用户，请先创建用户</option>';
        }
        
        // 重置重试计数
        return true;
        
    } catch (error) {
        console.error(`加载用户选项失败 (尝试 ${retryCount + 1}):`, error);
        
        const select = document.getElementById('container-user-id');
        if (select) {
            if (retryCount < maxRetries) {
                // 显示重试状态
                select.innerHTML = `<option value="" disabled>加载失败，正在重试... (${retryCount + 1}/${maxRetries})</option>`;
                
                // 延迟后重试
                setTimeout(() => {
                    loadUserOptions(retryCount + 1);
                }, retryDelay * (retryCount + 1)); // 递增延迟
                
            } else {
                // 最终失败处理
                select.innerHTML = `
                    <option value="" disabled>加载用户失败，请刷新页面重试</option>
                    <option value="refresh" style="color: red;">点击刷新用户列表</option>
                `;
                
                // 添加刷新选项的事件处理
                select.addEventListener('change', function(e) {
                    if (e.target.value === 'refresh') {
                        e.target.value = '';
                        loadUserOptions(0); // 重新开始重试
                    }
                });
                
                showAlert('用户列表加载失败，请检查网络连接或刷新页面', 'warning');
            }
        }
        
        return false;
    }
}

// 创建容器
async function createContainer() {
    const userId = document.getElementById('container-user-id').value;
    const gpuDevices = document.getElementById('gpu-devices').value;
    const password = document.getElementById('service-password').value;
    
    if (!userId) {
        showAlert('请选择用户', 'warning');
        return;
    }
    
    if (!password || password.trim() === '') {
        showAlert('请设置服务登录密码', 'warning');
        return;
    }
    
    if (password.length < 8) {
        showAlert('服务密码长度至少8位', 'warning');
        return;
    }
    
    const requestBody = {
        user_id: parseInt(userId),
        gpu_devices: gpuDevices,
        password: password
    };
    
    try {
        const response = await fetch(`${API_BASE}/containers`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                ...getAdminHeaders()
            },
            body: JSON.stringify(requestBody),
        });
        
        if (response.ok) {
            const responseData = await response.json();
            showAlert('容器创建成功！', 'success');
            // 重置表单
            resetForm('createContainerForm');
            // 关闭模态框
            closeModal('createContainerModal');
            
            // 显示用户通知信息
            setTimeout(() => {
                showUserNotificationModal(userId, password, responseData);
            }, 300);
            
            // 创建成功后延迟刷新，避免立即刷新导致的闪烁
            setTimeout(() => {
                if (!isContainerLoading) {
                    loadContainers(true); // 强制刷新显示新容器
                }
            }, 500);
            loadUserOptions(); // 刷新用户选项
        } else {
            const error = await response.text();
            showAlert(`创建失败: ${error}`, 'danger');
        }
    } catch (error) {
        handleApiError(error, '创建容器失败');
    }
}

// 加载仪表板数据
async function loadDashboard() {
    try {
        // 加载用户统计
        const usersResponse = await fetch(`${API_BASE}/users`, {
            headers: getAdminHeaders()
        });
        const users = await usersResponse.json();
        const activeUsers = (users && Array.isArray(users)) 
            ? users.filter(user => user.is_active).length 
            : 0;
        document.getElementById('active-users').textContent = activeUsers;
        
        // 加载容器统计
        const containersResponse = await fetch(`${API_BASE}/containers`, {
            headers: getAdminHeaders()
        });
        const containers = await containersResponse.json();
        const runningContainers = (containers && Array.isArray(containers)) 
            ? containers.filter(container => container.status === 'running').length 
            : 0;
        document.getElementById('running-containers').textContent = runningContainers;
        
        // 模拟系统资源数据（实际应该从系统API获取）
        document.getElementById('gpu-usage').textContent = '45%';
        document.getElementById('cpu-usage').textContent = '32%';
        document.getElementById('memory-usage').textContent = '67%';
        document.getElementById('disk-usage').textContent = '23%';
        
    } catch (error) {
        handleApiError(error, '加载仪表板数据失败');
    }
}

// 显示优雅的Toast通知
function showAlert(message, type = 'info') {
    // 类型映射
    const typeMap = {
        'success': { icon: 'bi-check-circle-fill', bg: 'success', title: '成功' },
        'danger': { icon: 'bi-exclamation-triangle-fill', bg: 'danger', title: '错误' },
        'warning': { icon: 'bi-exclamation-triangle-fill', bg: 'warning', title: '警告' },
        'info': { icon: 'bi-info-circle-fill', bg: 'info', title: '提示' }
    };
    
    const config = typeMap[type] || typeMap['info'];
    const toastId = 'toast-' + Date.now() + '-' + Math.random().toString(36).substr(2, 9);
    
    // 创建toast元素
    const toastHtml = `
        <div id="${toastId}" class="toast align-items-center text-bg-${config.bg} border-0" role="alert" aria-live="assertive" aria-atomic="true" data-bs-autohide="true" data-bs-delay="4000">
            <div class="d-flex">
                <div class="toast-body d-flex align-items-center">
                    <i class="bi ${config.icon} me-2"></i>
                    <span>${message}</span>
                </div>
                <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast" aria-label="Close"></button>
            </div>
        </div>
    `;
    
    // 获取toast容器
    const toastContainer = document.querySelector('.toast-container');
    if (!toastContainer) {
        console.error('Toast容器未找到');
        return;
    }
    
    // 插入toast
    toastContainer.insertAdjacentHTML('beforeend', toastHtml);
    
    // 获取刚创建的toast元素
    const toastElement = document.getElementById(toastId);
    if (!toastElement) {
        console.error('Toast元素创建失败');
        return;
    }
    
    // 初始化并显示toast
    const toast = new bootstrap.Toast(toastElement, {
        animation: true,
        autohide: true,
        delay: type === 'success' ? 3000 : 5000 // 成功消息3秒，其他5秒
    });
    
    // 显示toast
    toast.show();
    
    // 监听隐藏事件，自动清理DOM
    toastElement.addEventListener('hidden.bs.toast', function() {
        setTimeout(() => {
            if (toastElement.parentNode) {
                toastElement.remove();
            }
        }, 100);
    });
    
    // 添加动画效果
    toastElement.style.opacity = '0';
    toastElement.style.transform = 'translateX(100%)';
    
    // 延迟显示动画
    setTimeout(() => {
        toastElement.style.transition = 'all 0.3s ease-out';
        toastElement.style.opacity = '1';
        toastElement.style.transform = 'translateX(0)';
    }, 10);
}

// 退出登录
function logout() {
    if (confirm('确定要退出管理后台吗？')) {
        // 清除管理员认证信息
        sessionStorage.removeItem('admin');
        sessionStorage.removeItem('adminToken');
        // 跳转到管理员登录页面
        window.location.href = '/admin-login';
    }
}

// 编辑用户
async function editUser(id) {
    try {
        const response = await fetch(`${API_BASE}/users/${id}`, {
            headers: getAdminHeaders()
        });
        const user = await response.json();
        
        // 填充表单
        document.getElementById('edit-user-id').value = user.id;
        document.getElementById('edit-username').value = user.username;
        document.getElementById('edit-email').value = user.email || '';
        document.getElementById('edit-is-active').checked = user.is_active;
        document.getElementById('edit-is-admin').checked = user.is_admin;
        
        // 显示模态框
        new bootstrap.Modal(document.getElementById('editUserModal')).show();
    } catch (error) {
        handleApiError(error, '获取用户信息失败');
    }
}

// 更新用户
async function updateUser() {
    const id = document.getElementById('edit-user-id').value;
    const username = document.getElementById('edit-username').value;
    const email = document.getElementById('edit-email').value;
    const isActive = document.getElementById('edit-is-active').checked;
    const isAdmin = document.getElementById('edit-is-admin').checked;
    
    if (!username) {
        showAlert('用户名不能为空', 'warning');
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE}/users/${id}`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                ...getAdminHeaders()
            },
            body: JSON.stringify({ 
                username, 
                email, 
                is_active: isActive, 
                is_admin: isAdmin 
            }),
        });
        
        if (response.ok) {
            showAlert('用户更新成功', 'success');
            // 关闭模态框
            closeModal('editUserModal');
            // 刷新数据
            loadUsers();
            loadUserOptions(); // 刷新用户选项列表
        } else {
            const error = await response.text();
            showAlert(`更新失败: ${error}`, 'danger');
        }
    } catch (error) {
        handleApiError(error, '更新用户失败');
    }
}

// 修改密码
async function changePassword(id) {
    try {
        const response = await fetch(`${API_BASE}/users/${id}`, {
            headers: getAdminHeaders()
        });
        const user = await response.json();
        
        // 填充表单
        document.getElementById('password-user-id').value = user.id;
        document.getElementById('password-username').value = user.username;
        document.getElementById('new-password').value = '';
        document.getElementById('confirm-password').value = '';
        
        // 显示模态框
        new bootstrap.Modal(document.getElementById('changePasswordModal')).show();
    } catch (error) {
        handleApiError(error, '获取用户信息失败');
    }
}

// 通用模态框关闭函数
function closeModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) {
        const modalInstance = bootstrap.Modal.getInstance(modal);
        if (modalInstance) {
            modalInstance.hide();
        } else {
            // 如果获取不到实例，直接隐藏模态框
            modal.style.display = 'none';
            modal.classList.remove('show');
            document.body.classList.remove('modal-open');
            const backdrop = document.querySelector('.modal-backdrop');
            if (backdrop) {
                backdrop.remove();
            }
        }
    }
}

// 通用表单重置函数
function resetForm(formId) {
    const form = document.getElementById(formId);
    if (form) {
        form.reset();
        // 清除可能的验证状态
        const inputs = form.querySelectorAll('input, select, textarea');
        inputs.forEach(input => {
            input.classList.remove('is-valid', 'is-invalid');
        });
    }
}

// 改进的错误处理函数
function handleApiError(error, defaultMessage = '操作失败') {
    console.error('API错误:', error);
    
    let message = defaultMessage;
    
    if (error.response) {
        // 服务器响应了错误状态码
        try {
            const errorText = error.response.text();
            if (errorText) {
                message = errorText;
            }
        } catch (e) {
            message = `服务器错误 (${error.response.status})`;
        }
    } else if (error.request) {
        // 请求已发出但没有收到响应
        message = '网络连接失败，请检查网络连接';
    } else {
        // 其他错误
        message = error.message || defaultMessage;
    }
    
    showAlert(message, 'danger');
}

// 初始化模态框事件监听
function initializeModalEvents() {
    // 为所有模态框添加隐藏事件监听，自动重置表单
    const modals = [
        'addUserModal',
        'editUserModal', 
        'changePasswordModal',
        'createContainerModal',
        'resetContainerPasswordModal'
    ];
    
    modals.forEach(modalId => {
        const modal = document.getElementById(modalId);
        if (modal) {
            modal.addEventListener('hidden.bs.modal', function() {
                // 获取对应的表单ID
                const formId = modalId.replace('Modal', 'Form');
                resetForm(formId);
            });
        }
    });
}

// 更新密码
async function updatePassword() {
    const id = document.getElementById('password-user-id').value;
    const newPassword = document.getElementById('new-password').value;
    const confirmPassword = document.getElementById('confirm-password').value;
    
    if (!newPassword) {
        showAlert('密码不能为空', 'warning');
        return;
    }
    
    if (newPassword !== confirmPassword) {
        showAlert('两次输入的密码不一致', 'warning');
        return;
    }
    
    if (newPassword.length < 6) {
        showAlert('密码长度至少6位', 'warning');
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE}/users/${id}/password`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                ...getAdminHeaders()
            },
            body: JSON.stringify({ password: newPassword }),
        });
        
        if (response.ok) {
            showAlert('密码修改成功', 'success');
            // 关闭模态框
            closeModal('changePasswordModal');
            // 重置表单
            resetForm('changePasswordForm');
        } else {
            const error = await response.text();
            showAlert(`密码修改失败: ${error}`, 'danger');
        }
    } catch (error) {
        handleApiError(error, '修改密码失败');
    }
}

// 显示重置容器密码对话框
function resetContainerPasswordDialog(containerId, containerName) {
    // 填充表单
    document.getElementById('reset-container-id').value = containerId;
    document.getElementById('reset-container-name').value = containerName;
    document.getElementById('reset-new-password').value = '';
    document.getElementById('reset-confirm-password').value = '';
    
    // 显示模态框
    new bootstrap.Modal(document.getElementById('resetContainerPasswordModal')).show();
}

// 重置容器服务密码
async function resetContainerPassword() {
    const containerId = document.getElementById('reset-container-id').value;
    const newPassword = document.getElementById('reset-new-password').value;
    const confirmPassword = document.getElementById('reset-confirm-password').value;
    
    if (!newPassword) {
        showAlert('新密码不能为空', 'warning');
        return;
    }
    
    if (newPassword !== confirmPassword) {
        showAlert('两次输入的密码不一致', 'warning');
        return;
    }
    
    if (newPassword.length < 6) {
        showAlert('密码长度至少6位', 'warning');
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE}/containers/${containerId}/reset-password`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                ...getAdminHeaders()
            },
            body: JSON.stringify({ password: newPassword }),
        });
        
        if (response.ok) {
            showAlert('容器服务密码重置成功！新密码已应用到SSH、VSCode和Jupyter服务', 'success');
            // 关闭模态框
            closeModal('resetContainerPasswordModal');
            // 重置表单
            resetForm('resetContainerPasswordForm');
            // 刷新容器列表
            loadContainers();
        } else {
            const error = await response.text();
            showAlert(`密码重置失败: ${error}`, 'danger');
        }
    } catch (error) {
        handleApiError(error, '重置容器密码失败');
    }
}

// 生成安全密码
function generateSecurePassword() {
    const upperCase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lowerCase = 'abcdefghijklmnopqrstuvwxyz';
    const numbers = '0123456789';
    const specialChars = '!@#$%^&*';
    
    // 确保每种字符类型至少有一个
    let password = '';
    password += upperCase[Math.floor(Math.random() * upperCase.length)];
    password += lowerCase[Math.floor(Math.random() * lowerCase.length)];
    password += numbers[Math.floor(Math.random() * numbers.length)];
    password += specialChars[Math.floor(Math.random() * specialChars.length)];
    
    // 填充剩余位数
    const allChars = upperCase + lowerCase + numbers + specialChars;
    for (let i = 4; i < 8; i++) {
        password += allChars[Math.floor(Math.random() * allChars.length)];
    }
    
    // 打乱密码字符顺序
    password = password.split('').sort(() => Math.random() - 0.5).join('');
    
    document.getElementById('service-password').value = password;
    
    // 密码已生成，无需额外提示
}

// 复制密码到剪贴板
async function copyPassword() {
    const passwordField = document.getElementById('service-password');
    const password = passwordField.value;
    
    if (!password) {
        showAlert('请先生成密码', 'warning');
        return;
    }
    
    try {
        await navigator.clipboard.writeText(password);
        showAlert('密码已复制到剪贴板', 'success');
    } catch (error) {
        console.error('复制密码失败:', error);
        // 降级处理：选中文本
        passwordField.select();
        passwordField.setSelectionRange(0, 99999); // 对于移动设备
        showAlert('请手动复制密码', 'info');
    }
}

// 复制容器使用说明
async function copyUsageInstructions(containerId, username, containerName) {
    try {
        // 获取用户的端口信息
        const userResponse = await fetch(`${API_BASE}/users`, {
            headers: getAdminHeaders()
        });
        const users = await userResponse.json();
        const user = users.find(u => u.username === username);
        
        if (!user) {
            showAlert('用户信息获取失败', 'danger');
            return;
        }
        
        // 获取容器端口信息
        const portResponse = await fetch(`${API_BASE}/users/${user.id}/container`, {
            headers: getAdminHeaders()
        });
        let ports = {};
        if (portResponse.ok) {
            const data = await portResponse.json();
            ports = data.ports || {};
        }
        
        // 获取服务器主机名或IP（这里使用当前页面的host）
        const serverHost = window.location.hostname;
        
        // 构造使用说明
        const instructions = `🚀 GPU开发环境使用说明

📋 容器信息：
- 容器名称：${containerName}
- 用户名：${username}
- 服务器地址：${serverHost}

🔗 服务访问地址：
- SSH 登录：ssh ${username}@${serverHost} -p ${ports.ssh || 'N/A'}
- VSCode 服务器：http://${serverHost}:${ports.vscode || 'N/A'}
- Jupyter Lab：http://${serverHost}:${ports.jupyter || 'N/A'}

📁 目录说明：
- 个人目录：~/ 或 /home/${username} (私有目录)  
- 共享目录：~/shared 或 /shared (只读共享)
- 工作空间：~/workspace 或 /workspace (读写共享)

💡 使用提示：
- 所有服务使用相同的登录密码
- 支持GPU加速的PyTorch 2.6.0环境
- 预装常用AI/ML库和开发工具
- 可通过SSH上传下载文件`;

        // 尝试复制到剪贴板
        try {
            if (navigator.clipboard && window.isSecureContext) {
                await navigator.clipboard.writeText(instructions);
                showAlert('使用说明已复制到剪贴板！', 'success');
            } else {
                // 备用方案：显示弹窗让用户手动复制
                fallbackCopyToClipboard(instructions);
            }
        } catch (clipboardError) {
            console.warn('剪贴板API失败，使用备用方案:', clipboardError);
            fallbackCopyToClipboard(instructions);
        }
        
    } catch (error) {
        console.error('复制使用说明失败:', error);
        showAlert('获取使用说明失败: ' + error.message, 'danger');
    }
}

// 备用复制方案：显示模态框让用户手动复制
function fallbackCopyToClipboard(text) {
    // 创建模态框
    const modal = document.createElement('div');
    modal.className = 'modal fade';
    modal.style.zIndex = '9999';
    modal.innerHTML = `
        <div class="modal-dialog modal-instructions">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title">
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" style="margin-right: 8px;">
                            <path d="M4 4h4v4H4V4zm6 0h4v4h-4V4zm6 0h4v4h-4V4zM4 10h4v4H4v-4zm6 0h4v4h-4v-4zm6 0h4v4h-4v-4zM4 16h4v4H4v-4zm6 0h4v4h-4v-4zm6 0h4v4h-4v-4z" fill="currentColor"/>
                        </svg>
                        GPU开发环境使用说明
                    </h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body">
                    <p class="text-muted mb-3">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" style="margin-right: 6px;">
                            <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2"/>
                            <path d="m9 12 2 2 4-4" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                        </svg>
                        请手动复制以下内容：
                    </p>
                    <textarea class="form-control instructions-textarea" rows="30" readonly style="font-family: 'Courier New', monospace; font-size: 13px; line-height: 1.4;">${text}</textarea>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-primary" onclick="selectAndCopy(this)">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" style="margin-right: 6px;">
                            <rect x="9" y="9" width="13" height="13" rx="2" ry="2" stroke="currentColor" stroke-width="2"/>
                            <path d="m5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" stroke="currentColor" stroke-width="2"/>
                        </svg>
                        全选并复制
                    </button>
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">关闭</button>
                </div>
            </div>
        </div>
    `;
    
    document.body.appendChild(modal);
    const modalInstance = new bootstrap.Modal(modal);
    modalInstance.show();
    
    // 模态框关闭后移除元素
    modal.addEventListener('hidden.bs.modal', () => {
        document.body.removeChild(modal);
    });
}

// 全选并复制文本
function selectAndCopy(button) {
    const textarea = button.closest('.modal-content').querySelector('textarea');
    textarea.select();
    textarea.setSelectionRange(0, 99999); // 移动端支持
    
    try {
        document.execCommand('copy');
        showAlert('内容已复制到剪贴板！', 'success');
        // 关闭模态框
        const modal = button.closest('.modal');
        bootstrap.Modal.getInstance(modal).hide();
    } catch (err) {
        showAlert('复制失败，请手动选择并复制文本', 'warning');
    }
}

// 显示用户通知信息Modal
async function showUserNotificationModal(userId, password, containerData) {
    try {
        // 获取用户信息
        const userResponse = await fetch(`${API_BASE}/users/${userId}`, {
            headers: getAdminHeaders()
        });
        const user = await userResponse.json();
        
        // 获取容器端口信息
        const portResponse = await fetch(`${API_BASE}/users/${userId}/container`, {
            headers: getAdminHeaders()
        });
        let ports = {};
        if (portResponse.ok) {
            const data = await portResponse.json();
            ports = data.ports || {};
        }
        
        // 获取服务器主机名或IP
        const serverHost = window.location.hostname;
        
        // 构造完整的用户通知信息
        const userNotification = `🎉 恭喜！您的GPU开发环境已就绪！

📋 账户信息：
👤 用户名：${user.username}
🔐 登录密码：${password}
🖥️  服务器地址：${serverHost}

🔗 服务访问地址：
🔹 SSH 登录：ssh ${user.username}@${serverHost} -p ${ports.ssh || 'N/A'}
🔹 VSCode 服务器：http://${serverHost}:${ports.vscode || 'N/A'}
🔹 Jupyter Lab：http://${serverHost}:${ports.jupyter || 'N/A'}

📁 目录说明：
🔹 个人目录：~/ 或 /home/${user.username} (私有目录)
🔹 共享目录：~/shared 或 /shared (只读共享)
🔹 工作空间：~/workspace 或 /workspace (读写共享)

💡 重要提示：
🔹 所有服务使用相同的登录密码
🔹 支持GPU加速的PyTorch 2.6.0环境
🔹 预装常用AI/ML库和开发工具
🔹 可通过SSH上传下载文件
🔹 请妥善保管您的登录密码，系统不会再次显示

如有问题，请联系系统管理员。祝您使用愉快！🚀`;

        // 创建并显示模态框
        const modal = document.createElement('div');
        modal.className = 'modal fade';
        modal.style.zIndex = '9999';
        modal.innerHTML = `
            <div class="modal-dialog modal-user-notification">
                <div class="modal-content">
                    <div class="modal-header bg-success text-white">
                        <h5 class="modal-title">
                            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" style="margin-right: 8px;">
                                <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2"/>
                                <path d="m9 12 2 2 4-4" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                            </svg>
                            用户通知信息（请发送给用户）
                        </h5>
                        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <div class="alert alert-warning">
                            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" style="margin-right: 8px;">
                                <path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z" stroke="currentColor" stroke-width="2"/>
                                <line x1="12" y1="9" x2="12" y2="13" stroke="currentColor" stroke-width="2"/>
                                <line x1="12" y1="17" x2="12.01" y2="17" stroke="currentColor" stroke-width="2"/>
                            </svg>
                            <strong>重要提醒：</strong>此页面仅展示一次！请立即复制用户信息并通过安全渠道发送给用户 <strong>${user.username}</strong>
                        </div>
                        <textarea class="form-control notification-textarea" rows="28" readonly style="font-family: 'Courier New', monospace; font-size: 13px; line-height: 1.4;">${userNotification}</textarea>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-primary" onclick="selectAndCopy(this)">
                            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" style="margin-right: 6px;">
                                <rect x="9" y="9" width="13" height="13" rx="2" ry="2" stroke="currentColor" stroke-width="2"/>
                                <path d="m5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" stroke="currentColor" stroke-width="2"/>
                            </svg>
                            复制全部内容
                        </button>
                        <button type="button" class="btn btn-success" onclick="copyPasswordOnly('${password}')">
                            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" style="margin-right: 6px;">
                                <rect x="3" y="11" width="18" height="11" rx="2" ry="2" stroke="currentColor" stroke-width="2"/>
                                <circle cx="12" cy="16" r="1" fill="currentColor"/>
                                <path d="M7 11V7a5 5 0 0 1 10 0v4" stroke="currentColor" stroke-width="2"/>
                            </svg>
                            仅复制密码
                        </button>
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">关闭</button>
                    </div>
                </div>
            </div>
        `;
        
        document.body.appendChild(modal);
        const modalInstance = new bootstrap.Modal(modal);
        modalInstance.show();
        
        // 模态框关闭后移除元素
        modal.addEventListener('hidden.bs.modal', () => {
            document.body.removeChild(modal);
        });
        
    } catch (error) {
        console.error('生成用户通知信息失败:', error);
        showAlert('生成用户通知信息失败: ' + error.message, 'danger');
    }
}

// 仅复制密码
async function copyPasswordOnly(password) {
    try {
        if (navigator.clipboard && window.isSecureContext) {
            await navigator.clipboard.writeText(password);
            showAlert('密码已复制到剪贴板！', 'success');
        } else {
            // 降级处理
            const textArea = document.createElement('textarea');
            textArea.value = password;
            document.body.appendChild(textArea);
            textArea.select();
            document.execCommand('copy');
            document.body.removeChild(textArea);
            showAlert('密码已复制到剪贴板！', 'success');
        }
    } catch (error) {
        console.error('复制密码失败:', error);
        showAlert('复制失败，密码为：' + password, 'warning');
    }
}

// ===================== 组管理功能 =====================

// 加载组列表
async function loadGroups() {
    try {
        const response = await fetch(`${API_BASE}/groups`, {
            headers: getAdminHeaders()
        });
        const data = await response.json();
        
        if (!data.success) {
            throw new Error(data.message || '加载组列表失败');
        }
        
        const tbody = document.getElementById('groups-table-body');
        tbody.innerHTML = '';
        
        if (data.data && Array.isArray(data.data) && data.data.length > 0) {
            data.data.forEach(group => {
                const row = createGroupRow(group);
                tbody.appendChild(row);
            });
        } else {
            const row = document.createElement('tr');
            row.innerHTML = '<td colspan="8" class="text-center text-muted">暂无组</td>';
            tbody.appendChild(row);
        }
    } catch (error) {
        handleApiError(error, '加载组列表失败');
    }
}

// 创建组表格行
function createGroupRow(group) {
    const row = document.createElement('tr');
    
    row.innerHTML = `
        <td>${group.id}</td>
        <td>
            <strong>${escapeHtml(group.name)}</strong>
            ${group.user_role === 'admin' ? '<span class="badge bg-warning text-dark ms-1">管理员</span>' : ''}
            ${group.user_role === 'member' ? '<span class="badge bg-info ms-1">成员</span>' : ''}
        </td>
        <td>${escapeHtml(group.description || '')}</td>
        <td>${escapeHtml(group.created_by_username || '')}</td>
        <td>
            <span class="badge bg-secondary">${group.member_count || 0} 人</span>
        </td>
        <td><code>${group.gid}</code></td>
        <td>${formatDateTime(group.created_at)}</td>
        <td>
            <div class="btn-group btn-group-sm">
                <button class="btn btn-outline-primary" onclick="showGroupMembers(${group.id}, '${escapeHtml(group.name)}')" title="管理成员">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                        <circle cx="9" cy="7" r="4" stroke="currentColor" stroke-width="2"/>
                        <path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                    </svg>
                </button>
                ${group.can_manage ? `
                    <button class="btn btn-outline-secondary" onclick="editGroup(${group.id})" title="编辑组">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                            <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                            <path d="m18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                        </svg>
                    </button>
                    <button class="btn btn-outline-danger" onclick="deleteGroup(${group.id}, '${escapeHtml(group.name)}')" title="删除组">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                            <polyline points="3,6 5,6 21,6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                            <path d="m19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                        </svg>
                    </button>
                ` : ''}
            </div>
        </td>
    `;
    
    return row;
}

// 创建组
async function createGroup() {
    const name = document.getElementById('group-name').value.trim();
    const description = document.getElementById('group-description').value.trim();
    
    if (!name) {
        showAlert('请输入组名', 'warning');
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE}/groups`, {
            method: 'POST',
            headers: getAdminHeaders(),
            body: JSON.stringify({
                name: name,
                description: description
            })
        });
        
        const data = await response.json();
        
        if (data.success) {
            showAlert(data.message || '组创建成功', 'success');
            bootstrap.Modal.getInstance(document.getElementById('addGroupModal')).hide();
            document.getElementById('addGroupForm').reset();
            loadGroups();
        } else {
            throw new Error(data.message || '创建组失败');
        }
    } catch (error) {
        handleApiError(error, '创建组失败');
    }
}

// 编辑组
async function editGroup(groupId) {
    try {
        const response = await fetch(`${API_BASE}/groups/${groupId}`, {
            headers: getAdminHeaders()
        });
        const data = await response.json();
        
        if (data.success) {
            const group = data.data;
            document.getElementById('edit-group-id').value = group.id;
            document.getElementById('edit-group-name').value = group.name;
            document.getElementById('edit-group-description').value = group.description || '';
            
            new bootstrap.Modal(document.getElementById('editGroupModal')).show();
        } else {
            throw new Error(data.message || '获取组信息失败');
        }
    } catch (error) {
        handleApiError(error, '获取组信息失败');
    }
}

// 更新组
async function updateGroup() {
    const groupId = document.getElementById('edit-group-id').value;
    const name = document.getElementById('edit-group-name').value.trim();
    const description = document.getElementById('edit-group-description').value.trim();
    
    if (!name) {
        showAlert('请输入组名', 'warning');
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE}/groups/${groupId}`, {
            method: 'PUT',
            headers: getAdminHeaders(),
            body: JSON.stringify({
                name: name,
                description: description
            })
        });
        
        const data = await response.json();
        
        if (data.success) {
            showAlert(data.message || '组更新成功', 'success');
            bootstrap.Modal.getInstance(document.getElementById('editGroupModal')).hide();
            loadGroups();
        } else {
            throw new Error(data.message || '更新组失败');
        }
    } catch (error) {
        handleApiError(error, '更新组失败');
    }
}

// 删除组
function deleteGroup(groupId, groupName) {
    document.getElementById('delete-group-id').value = groupId;
    document.getElementById('delete-group-name').textContent = groupName;
    new bootstrap.Modal(document.getElementById('deleteGroupModal')).show();
}

// 确认删除组
async function confirmDeleteGroup() {
    const groupId = document.getElementById('delete-group-id').value;
    
    try {
        const response = await fetch(`${API_BASE}/groups/${groupId}`, {
            method: 'DELETE',
            headers: getAdminHeaders()
        });
        
        const data = await response.json();
        
        if (data.success) {
            showAlert(data.message || '组删除成功', 'success');
            bootstrap.Modal.getInstance(document.getElementById('deleteGroupModal')).hide();
            loadGroups();
        } else {
            throw new Error(data.message || '删除组失败');
        }
    } catch (error) {
        handleApiError(error, '删除组失败');
    }
}

// 显示组成员管理
async function showGroupMembers(groupId, groupName) {
    document.getElementById('members-group-id').value = groupId;
    document.getElementById('group-members-title').textContent = `组成员管理 - ${groupName}`;
    document.getElementById('group-members-subtitle').textContent = `组ID: ${groupId}`;
    
    // 加载可添加的用户列表
    await loadAvailableUsers(groupId);
    
    // 加载当前成员列表
    await loadGroupMembers(groupId);
    
    new bootstrap.Modal(document.getElementById('groupMembersModal')).show();
}

// 加载可添加的用户列表
async function loadAvailableUsers(groupId) {
    try {
        const response = await fetch(`${API_BASE}/groups/${groupId}/available-users`, {
            headers: getAdminHeaders()
        });
        const data = await response.json();
        
        const select = document.getElementById('available-users-select');
        select.innerHTML = '<option value="">选择用户...</option>';
        
        if (data.success && data.data && Array.isArray(data.data)) {
            data.data.forEach(user => {
                const option = document.createElement('option');
                option.value = user.id;
                option.textContent = `${user.username} (${user.email || 'N/A'})`;
                select.appendChild(option);
            });
        }
    } catch (error) {
        console.error('加载可用用户失败:', error);
    }
}

// 加载组成员列表
async function loadGroupMembers(groupId) {
    try {
        const response = await fetch(`${API_BASE}/groups/${groupId}/members`, {
            headers: getAdminHeaders()
        });
        const data = await response.json();
        
        const tbody = document.getElementById('group-members-table-body');
        tbody.innerHTML = '';
        
        if (data.success && data.data && Array.isArray(data.data)) {
            data.data.forEach(member => {
                const row = createMemberRow(member, groupId);
                tbody.appendChild(row);
            });
        } else {
            const row = document.createElement('tr');
            row.innerHTML = '<td colspan="5" class="text-center text-muted">暂无成员</td>';
            tbody.appendChild(row);
        }
    } catch (error) {
        console.error('加载组成员失败:', error);
    }
}

// 创建成员表格行
function createMemberRow(member, groupId) {
    const row = document.createElement('tr');
    
    row.innerHTML = `
        <td>
            <strong>${escapeHtml(member.username)}</strong>
            ${member.role === 'admin' ? '<span class="badge bg-warning text-dark ms-1">管理员</span>' : '<span class="badge bg-info ms-1">成员</span>'}
        </td>
        <td>${escapeHtml(member.user_email || 'N/A')}</td>
        <td>
            <select class="form-select form-select-sm" onchange="updateMemberRole(${groupId}, ${member.user_id}, this.value)">
                <option value="member" ${member.role === 'member' ? 'selected' : ''}>成员</option>
                <option value="admin" ${member.role === 'admin' ? 'selected' : ''}>管理员</option>
            </select>
        </td>
        <td><small class="text-muted">${formatDateTime(member.joined_at)}</small></td>
        <td>
            <button class="btn btn-outline-danger btn-sm" onclick="removeGroupMember(${groupId}, ${member.user_id}, '${escapeHtml(member.username)}')" title="移除成员">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <line x1="18" y1="6" x2="6" y2="18" stroke="currentColor" stroke-width="2"/>
                    <line x1="6" y1="6" x2="18" y2="18" stroke="currentColor" stroke-width="2"/>
                </svg>
            </button>
        </td>
    `;
    
    return row;
}

// 添加组成员
async function addGroupMember() {
    const groupId = document.getElementById('members-group-id').value;
    const userId = document.getElementById('available-users-select').value;
    const role = document.getElementById('member-role-select').value;
    
    if (!userId) {
        showAlert('请选择用户', 'warning');
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE}/groups/${groupId}/members`, {
            method: 'POST',
            headers: getAdminHeaders(),
            body: JSON.stringify({
                user_id: parseInt(userId),
                role: role
            })
        });
        
        const data = await response.json();
        
        if (data.success) {
            showAlert(data.message || '成员添加成功', 'success');
            // 重新加载成员列表和可用用户列表
            await loadGroupMembers(groupId);
            await loadAvailableUsers(groupId);
            // 重置选择
            document.getElementById('available-users-select').value = '';
            document.getElementById('member-role-select').value = 'member';
            // 刷新组列表以更新成员数量
            loadGroups();
        } else {
            throw new Error(data.message || '添加成员失败');
        }
    } catch (error) {
        handleApiError(error, '添加成员失败');
    }
}

// 移除组成员
async function removeGroupMember(groupId, userId, username) {
    if (!confirm(`确定要将用户 "${username}" 从组中移除吗？`)) {
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE}/groups/${groupId}/members/${userId}`, {
            method: 'DELETE',
            headers: getAdminHeaders()
        });
        
        const data = await response.json();
        
        if (data.success) {
            showAlert(data.message || '成员移除成功', 'success');
            // 重新加载成员列表和可用用户列表
            await loadGroupMembers(groupId);
            await loadAvailableUsers(groupId);
            // 刷新组列表以更新成员数量
            loadGroups();
        } else {
            throw new Error(data.message || '移除成员失败');
        }
    } catch (error) {
        handleApiError(error, '移除成员失败');
    }
}

// 更新成员角色
async function updateMemberRole(groupId, userId, newRole) {
    try {
        const response = await fetch(`${API_BASE}/groups/${groupId}/members/${userId}`, {
            method: 'PUT',
            headers: getAdminHeaders(),
            body: JSON.stringify({
                role: newRole
            })
        });
        
        const data = await response.json();
        
        if (data.success) {
            showAlert(data.message || '角色更新成功', 'success');
            // 重新加载成员列表
            await loadGroupMembers(groupId);
        } else {
            throw new Error(data.message || '更新角色失败');
        }
    } catch (error) {
        handleApiError(error, '更新角色失败');
        // 刷新页面以恢复原始状态
        loadGroupMembers(groupId);
    }
}
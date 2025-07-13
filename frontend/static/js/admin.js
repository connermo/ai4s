// API基础URL
const API_BASE = '/api';

// 当前显示的section
let currentSection = 'users';

// 页面加载完成后初始化
document.addEventListener('DOMContentLoaded', function() {
    loadUsers();
    loadContainers();
    loadUserOptions();
    
    // 设置密码类型切换事件
    setupPasswordTypeToggle();
    
    // 监听创建容器模态框显示事件，实时刷新用户列表（增强健壮性）
    const createContainerModal = document.getElementById('createContainerModal');
    if (createContainerModal) {
        // 主要事件监听
        createContainerModal.addEventListener('shown.bs.modal', function() {
            console.log('创建容器模态框打开，刷新用户列表...');
            loadUserOptions(0); // 实时获取最新用户列表，重置重试计数
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
    
    // 增强的定时刷新机制
    setInterval(() => {
        if (currentSection === 'users') {
            loadUsers();
        } else if (currentSection === 'containers') {
            // 容器页面使用强制刷新确保与Docker状态同步
            loadContainers(true);
        } else if (currentSection === 'dashboard') {
            loadDashboard();
        }
    }, 30000);
    
    // 添加页面可见性检测，页面重新可见时强制刷新
    document.addEventListener('visibilitychange', function() {
        if (!document.hidden && currentSection === 'containers') {
            console.log('页面重新可见，强制刷新容器状态...');
            setTimeout(() => {
                loadContainers(true);
            }, 500);
        }
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
    } else if (sectionName === 'dashboard') {
        loadDashboard();
    }
}

// 加载用户列表
async function loadUsers() {
    try {
        const response = await fetch(`${API_BASE}/users`);
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
        console.error('加载用户失败:', error);
        showAlert('加载用户失败', 'danger');
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
            <button class="btn btn-sm btn-outline-primary" onclick="editUser(${user.id})">
                <i class="bi bi-pencil"></i>
            </button>
            <button class="btn btn-sm btn-outline-warning" onclick="changePassword(${user.id})">
                <i class="bi bi-key"></i>
            </button>
            <button class="btn btn-sm btn-outline-danger" onclick="deleteUser(${user.id}, '${user.username}')">
                <i class="bi bi-trash"></i>
            </button>
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
            },
            body: JSON.stringify({ username, password, email }),
        });
        
        if (response.ok) {
            showAlert('用户创建成功！', 'success');
            document.getElementById('addUserForm').reset();
            bootstrap.Modal.getInstance(document.getElementById('addUserModal')).hide();
            loadUsers();
            loadUserOptions(); // 刷新用户选项列表
        } else {
            const error = await response.text();
            showAlert(`创建失败: ${error}`, 'danger');
        }
    } catch (error) {
        console.error('创建用户失败:', error);
        showAlert('创建用户失败', 'danger');
    }
}

// 删除用户
async function deleteUser(id, username) {
    if (!confirm(`确定要删除用户 "${username}" 吗？`)) {
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE}/users/${id}`, {
            method: 'DELETE',
        });
        
        if (response.ok) {
            showAlert('用户删除成功', 'success');
            loadUsers();
        } else {
            showAlert('删除失败', 'danger');
        }
    } catch (error) {
        console.error('删除用户失败:', error);
        showAlert('删除用户失败', 'danger');
    }
}

// 加载容器列表（增强实时同步）
async function loadContainers(forceRefresh = false) {
    try {
        console.log('正在加载容器列表...', forceRefresh ? '(强制刷新)' : '');
        
        // 添加缓存控制头确保获取最新数据
        const headers = forceRefresh ? {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
            'Expires': '0'
        } : {};
        
        const response = await fetch(`${API_BASE}/containers`, { headers });
        const containers = await response.json();
        
        const tbody = document.getElementById('containers-table-body');
        if (!tbody) {
            console.warn('容器表格未找到');
            return;
        }
        
        // 显示加载状态
        tbody.innerHTML = '<tr><td colspan="8" class="text-center text-muted">正在加载容器...</td></tr>';
        
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
        console.error('加载容器失败:', error);
        const tbody = document.getElementById('containers-table-body');
        if (tbody) {
            tbody.innerHTML = '<tr><td colspan="8" class="text-center text-danger">加载失败，请刷新页面重试</td></tr>';
        }
        showAlert('加载容器失败: ' + error.message, 'danger');
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
        const userResponse = await fetch(`${API_BASE}/users/${container.user_id}`);
        if (userResponse.ok) {
            const user = await userResponse.json();
            username = user.username;
        }
    } catch (error) {
        console.error('获取用户信息失败:', error);
    }
    
    const statusClass = container.status === 'running' ? 'status-running' : 'status-stopped';
    const statusText = container.status === 'running' ? '运行中' : '已停止';
    const gpuDevices = container.gpu_devices || '无';
    const resources = container.cpu_limit === 'unlimited' ? 'CPU: 无限制, 内存: 无限制' : `CPU: ${container.cpu_limit}, 内存: ${container.memory_limit}`;
    
    // 获取端口信息
    let ports = '-';
    try {
        const portResponse = await fetch(`${API_BASE}/users/${container.user_id}/container`);
        if (portResponse.ok) {
            const data = await portResponse.json();
            const p = data.ports;
            ports = `SSH:${p.ssh} VSCode:${p.vscode} Jupyter:${p.jupyter} TB:${p.tensorboard}`;
        }
    } catch (error) {
        console.error('获取端口信息失败:', error);
    }
    
    row.innerHTML = `
        <td class="text-truncate" title="${container.id}">${container.id.substring(0, 12)}</td>
        <td>${username}</td>
        <td>${container.name}</td>
        <td><span class="status-badge ${statusClass}">${statusText}</span></td>
        <td>${gpuDevices}</td>
        <td>${resources}</td>
        <td class="text-truncate" title="${ports}">${ports}</td>
        <td>
            ${container.status === 'running' 
                ? `<button class="btn btn-sm btn-outline-warning" onclick="stopContainer('${container.id}')"><i class="bi bi-stop"></i></button>`
                : `<button class="btn btn-sm btn-outline-success" onclick="startContainer('${container.id}')"><i class="bi bi-play"></i></button>`
            }
            <button class="btn btn-sm btn-outline-info" onclick="resetContainerPasswordDialog('${container.id}', '${container.name}')" title="重置服务密码">
                <i class="bi bi-key"></i>
            </button>
            <button class="btn btn-sm btn-outline-danger" onclick="removeContainer('${container.id}', '${container.name}')">
                <i class="bi bi-trash"></i>
            </button>
        </td>
    `;
    
    return row;
}

// 启动容器（增强状态同步）
async function startContainer(id) {
    try {
        console.log(`正在启动容器 ${id}...`);
        
        const response = await fetch(`${API_BASE}/containers/${id}/start`, {
            method: 'POST',
        });
        
        if (response.ok) {
            showAlert('容器启动成功', 'success');
            // 延迟后强制刷新确保状态同步
            setTimeout(() => {
                loadContainers(true); // 强制刷新
            }, 1000);
        } else {
            const error = await response.text();
            showAlert(`启动失败: ${error}`, 'danger');
            loadContainers(true); // 刷新显示真实状态
        }
    } catch (error) {
        console.error('启动容器失败:', error);
        showAlert('启动容器失败: ' + error.message, 'danger');
        loadContainers(true); // 刷新显示真实状态
    }
}

// 停止容器（增强状态同步）
async function stopContainer(id) {
    try {
        console.log(`正在停止容器 ${id}...`);
        
        const response = await fetch(`${API_BASE}/containers/${id}/stop`, {
            method: 'POST',
        });
        
        if (response.ok) {
            showAlert('容器停止成功', 'success');
            // 延迟后强制刷新确保状态同步
            setTimeout(() => {
                loadContainers(true); // 强制刷新
            }, 1000);
        } else {
            const error = await response.text();
            showAlert(`停止失败: ${error}`, 'danger');
            loadContainers(true); // 刷新显示真实状态
        }
    } catch (error) {
        console.error('停止容器失败:', error);
        showAlert('停止容器失败: ' + error.message, 'danger');
        loadContainers(true); // 刷新显示真实状态
    }
}

// 删除容器（增强状态同步）
async function removeContainer(id, name) {
    if (!confirm(`确定要删除容器 "${name}" 吗？`)) {
        return;
    }
    
    try {
        console.log(`正在删除容器 ${id}...`);
        
        const response = await fetch(`${API_BASE}/containers/${id}`, {
            method: 'DELETE',
        });
        
        if (response.ok) {
            showAlert('容器删除成功', 'success');
            loadContainers(true); // 立即强制刷新
            loadUserOptions(0); // 刷新用户列表（用户可能重新可用）
        } else {
            const error = await response.text();
            showAlert(`删除失败: ${error}`, 'danger');
            loadContainers(true); // 刷新显示真实状态
        }
    } catch (error) {
        console.error('删除容器失败:', error);
        showAlert('删除容器失败: ' + error.message, 'danger');
        loadContainers(true); // 刷新显示真实状态
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
                'Expires': '0'
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
    
    if (password.length < 6) {
        showAlert('服务密码长度至少6位', 'warning');
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
            },
            body: JSON.stringify(requestBody),
        });
        
        if (response.ok) {
            showAlert('容器创建成功！已设置所有服务的登录密码', 'success');
            document.getElementById('createContainerForm').reset();
            
            bootstrap.Modal.getInstance(document.getElementById('createContainerModal')).hide();
            loadContainers();
            loadUserOptions(); // 刷新用户选项
        } else {
            const error = await response.text();
            showAlert(`创建失败: ${error}`, 'danger');
        }
    } catch (error) {
        console.error('创建容器失败:', error);
        showAlert('创建容器失败', 'danger');
    }
}

// 加载仪表板数据
async function loadDashboard() {
    try {
        // 加载用户统计
        const usersResponse = await fetch(`${API_BASE}/users`);
        const users = await usersResponse.json();
        const activeUsers = (users && Array.isArray(users)) 
            ? users.filter(user => user.is_active).length 
            : 0;
        document.getElementById('active-users').textContent = activeUsers;
        
        // 加载容器统计
        const containersResponse = await fetch(`${API_BASE}/containers`);
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
        console.error('加载仪表板数据失败:', error);
        showAlert('加载仪表板数据失败', 'danger');
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
    if (confirm('确定要退出吗？')) {
        // 这里可以添加实际的退出逻辑
        window.location.reload();
    }
}

// 编辑用户
async function editUser(id) {
    try {
        const response = await fetch(`${API_BASE}/users/${id}`);
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
        console.error('获取用户信息失败:', error);
        showAlert('获取用户信息失败', 'danger');
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
            bootstrap.Modal.getInstance(document.getElementById('editUserModal')).hide();
            loadUsers();
            loadUserOptions(); // 刷新用户选项列表
        } else {
            const error = await response.text();
            showAlert(`更新失败: ${error}`, 'danger');
        }
    } catch (error) {
        console.error('更新用户失败:', error);
        showAlert('更新用户失败', 'danger');
    }
}

// 修改密码
async function changePassword(id) {
    try {
        const response = await fetch(`${API_BASE}/users/${id}`);
        const user = await response.json();
        
        // 填充表单
        document.getElementById('password-user-id').value = user.id;
        document.getElementById('password-username').value = user.username;
        document.getElementById('new-password').value = '';
        document.getElementById('confirm-password').value = '';
        
        // 显示模态框
        new bootstrap.Modal(document.getElementById('changePasswordModal')).show();
    } catch (error) {
        console.error('获取用户信息失败:', error);
        showAlert('获取用户信息失败', 'danger');
    }
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
            },
            body: JSON.stringify({ password: newPassword }),
        });
        
        if (response.ok) {
            showAlert('密码修改成功', 'success');
            bootstrap.Modal.getInstance(document.getElementById('changePasswordModal')).hide();
        } else {
            const error = await response.text();
            showAlert(`密码修改失败: ${error}`, 'danger');
        }
    } catch (error) {
        console.error('修改密码失败:', error);
        showAlert('修改密码失败', 'danger');
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
            },
            body: JSON.stringify({ password: newPassword }),
        });
        
        if (response.ok) {
            showAlert('容器服务密码重置成功！新密码已应用到SSH、VSCode和Jupyter服务', 'success');
            bootstrap.Modal.getInstance(document.getElementById('resetContainerPasswordModal')).hide();
            loadContainers(); // 刷新容器列表
        } else {
            const error = await response.text();
            showAlert(`密码重置失败: ${error}`, 'danger');
        }
    } catch (error) {
        console.error('重置容器密码失败:', error);
        showAlert('重置容器密码失败', 'danger');
    }
}
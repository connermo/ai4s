// API基础URL
const API_BASE = '/api';

// 当前显示的section
let currentSection = 'users';

// 页面加载完成后初始化
document.addEventListener('DOMContentLoaded', function() {
    loadUsers();
    loadContainers();
    loadUserOptions();
    
    // 每30秒刷新一次数据
    setInterval(() => {
        if (currentSection === 'users') {
            loadUsers();
        } else if (currentSection === 'containers') {
            loadContainers();
        }
    }, 30000);
});

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
        loadContainers();
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
        
        users.forEach(user => {
            const row = createUserRow(user);
            tbody.appendChild(row);
        });
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
    const ports = `${user.base_port}-${user.base_port + 300}`;
    
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
            showAlert('用户创建成功', 'success');
            document.getElementById('addUserForm').reset();
            bootstrap.Modal.getInstance(document.getElementById('addUserModal')).hide();
            loadUsers();
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

// 加载容器列表
async function loadContainers() {
    try {
        const response = await fetch(`${API_BASE}/containers`);
        const containers = await response.json();
        
        const tbody = document.getElementById('containers-table-body');
        tbody.innerHTML = '';
        
        for (const container of containers) {
            const row = await createContainerRow(container);
            tbody.appendChild(row);
        }
    } catch (error) {
        console.error('加载容器失败:', error);
        showAlert('加载容器失败', 'danger');
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
    const resources = `CPU: ${container.cpu_limit}, 内存: ${container.memory_limit}`;
    
    // 获取端口信息
    let ports = '-';
    try {
        const portResponse = await fetch(`${API_BASE}/users/${container.user_id}/container`);
        if (portResponse.ok) {
            const data = await portResponse.json();
            const p = data.ports;
            ports = `SSH:${p.ssh}, VSCode:${p.vscode}, Jupyter:${p.jupyter}, TB:${p.tensorboard}`;
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
            <button class="btn btn-sm btn-outline-danger" onclick="removeContainer('${container.id}', '${container.name}')">
                <i class="bi bi-trash"></i>
            </button>
        </td>
    `;
    
    return row;
}

// 启动容器
async function startContainer(id) {
    try {
        const response = await fetch(`${API_BASE}/containers/${id}/start`, {
            method: 'POST',
        });
        
        if (response.ok) {
            showAlert('容器启动成功', 'success');
            loadContainers();
        } else {
            showAlert('启动失败', 'danger');
        }
    } catch (error) {
        console.error('启动容器失败:', error);
        showAlert('启动容器失败', 'danger');
    }
}

// 停止容器
async function stopContainer(id) {
    try {
        const response = await fetch(`${API_BASE}/containers/${id}/stop`, {
            method: 'POST',
        });
        
        if (response.ok) {
            showAlert('容器停止成功', 'success');
            loadContainers();
        } else {
            showAlert('停止失败', 'danger');
        }
    } catch (error) {
        console.error('停止容器失败:', error);
        showAlert('停止容器失败', 'danger');
    }
}

// 删除容器
async function removeContainer(id, name) {
    if (!confirm(`确定要删除容器 "${name}" 吗？`)) {
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE}/containers/${id}`, {
            method: 'DELETE',
        });
        
        if (response.ok) {
            showAlert('容器删除成功', 'success');
            loadContainers();
        } else {
            showAlert('删除失败', 'danger');
        }
    } catch (error) {
        console.error('删除容器失败:', error);
        showAlert('删除容器失败', 'danger');
    }
}

// 加载用户选项
async function loadUserOptions() {
    try {
        const response = await fetch(`${API_BASE}/users`);
        const users = await response.json();
        
        const select = document.getElementById('container-user-id');
        select.innerHTML = '<option value="">选择用户</option>';
        
        users.forEach(user => {
            if (!user.container_id) { // 只显示没有容器的用户
                const option = document.createElement('option');
                option.value = user.id;
                option.textContent = user.username;
                select.appendChild(option);
            }
        });
    } catch (error) {
        console.error('加载用户选项失败:', error);
    }
}

// 创建容器
async function createContainer() {
    const userId = document.getElementById('container-user-id').value;
    const gpuDevices = document.getElementById('gpu-devices').value;
    
    if (!userId) {
        showAlert('请选择用户', 'warning');
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE}/containers`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ 
                user_id: parseInt(userId), 
                gpu_devices: gpuDevices 
            }),
        });
        
        if (response.ok) {
            showAlert('容器创建成功', 'success');
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
        const activeUsers = users.filter(user => user.is_active).length;
        document.getElementById('active-users').textContent = activeUsers;
        
        // 加载容器统计
        const containersResponse = await fetch(`${API_BASE}/containers`);
        const containers = await containersResponse.json();
        const runningContainers = containers.filter(container => container.status === 'running').length;
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

// 显示提示信息
function showAlert(message, type = 'info') {
    const alertDiv = document.createElement('div');
    alertDiv.className = `alert alert-${type} alert-dismissible fade show`;
    alertDiv.role = 'alert';
    alertDiv.innerHTML = `
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    
    // 在main标签开头插入alert
    const main = document.querySelector('main');
    main.insertBefore(alertDiv, main.firstChild);
    
    // 3秒后自动消失
    setTimeout(() => {
        if (alertDiv.parentNode) {
            alertDiv.remove();
        }
    }, 3000);
}

// 退出登录
function logout() {
    if (confirm('确定要退出吗？')) {
        // 这里可以添加实际的退出逻辑
        window.location.reload();
    }
}

// 占位函数，将来实现
function editUser(id) {
    showAlert('编辑用户功能待实现', 'info');
}

function changePassword(id) {
    showAlert('修改密码功能待实现', 'info');
}
// 检测操作系统和架构
function detectOS() {
  const userAgent = navigator.userAgent.toLowerCase();
  const platform = navigator.platform.toLowerCase();
  
  if (userAgent.includes('mac')) {
    // 检测 Apple Silicon (arm64) 还是 Intel (amd64)
    if (platform.includes('arm') || platform.includes('aarch64')) {
      return 'mac';
    }
    return 'macIntel';
  }
  if (userAgent.includes('win')) return 'windows';
  if (userAgent.includes('linux')) return 'linux';
  return 'unknown';
}

// 获取下载链接
function getDownloadLinks() {
  const baseUrl = 'https://github.com/mynameisny/biscuit-box/releases/latest/download';
  return {
    mac: `${baseUrl}/biscuit-box-macos-arm64.tar.gz`,
    macIntel: `${baseUrl}/biscuit-box-macos-amd64.tar.gz`,
    windows: `${baseUrl}/biscuit-box-windows-amd64.zip`,
    linux: `${baseUrl}/biscuit-box-linux-amd64.tar.gz`
  };
}

// 检测 Native Host 状态
async function checkNativeHost() {
  return new Promise((resolve) => {
    chrome.runtime.sendMessage({ action: 'checkNativeHost' }, (response) => {
      resolve(response);
    });
  });
}

// 更新状态显示
function updateStatus(connected, message) {
  const statusBox = document.getElementById('statusBox');
  const statusIcon = document.getElementById('statusIcon');
  const statusText = document.getElementById('statusText');
  const statusDesc = document.getElementById('statusDesc');
  const installGuide = document.getElementById('installGuide');

  if (connected) {
    statusBox.className = 'status-box connected';
    statusIcon.textContent = '✅';
    statusText.textContent = 'Native Host 已连接';
    statusDesc.textContent = message || '可以正常使用 Cookie Saver';
    installGuide.classList.add('hidden');
  } else {
    statusBox.className = 'status-box disconnected';
    statusIcon.textContent = '⚠️';
    statusText.textContent = 'Native Host 未安装';
    statusDesc.textContent = '需要安装 Native Host 才能保存 Cookie 到本地';
    installGuide.classList.remove('hidden');
  }
}

// 初始化下载按钮
function initDownloadButtons() {
  const os = detectOS();
  const links = getDownloadLinks();
  const osInfo = document.getElementById('osInfo');
  
  const osNames = {
    mac: 'macOS (Apple Silicon)',
    macIntel: 'macOS (Intel)',
    windows: 'Windows',
    linux: 'Linux'
  };
  
  osInfo.textContent = `检测到您的操作系统: ${osNames[os] || '未知'}`;
  
  // 设置下载链接
  document.getElementById('downloadMac').href = links.mac;
  document.getElementById('downloadLinux').href = links.linux;
  document.getElementById('downloadWindows').href = links.windows;
  
  // 高亮当前操作系统的下载按钮
  const buttons = {
    mac: document.getElementById('downloadMac'),
    macIntel: document.getElementById('downloadMac'),
    windows: document.getElementById('downloadWindows'),
    linux: document.getElementById('downloadLinux')
  };
  
  if (buttons[os]) {
    buttons[os].classList.remove('secondary');
    buttons[os].style.transform = 'scale(1.05)';
    buttons[os].style.boxShadow = '0 4px 12px rgba(26, 115, 232, 0.3)';
  }
}

// 页面加载完成后初始化
document.addEventListener('DOMContentLoaded', async () => {
  initDownloadButtons();
  
  // 初始检测
  const result = await checkNativeHost();
  updateStatus(result.connected, result.message);
  
  // 重新检测按钮
  document.getElementById('recheckBtn').addEventListener('click', async () => {
    const btn = document.getElementById('recheckBtn');
    btn.disabled = true;
    btn.textContent = '检测中...';
    
    const result = await checkNativeHost();
    updateStatus(result.connected, result.message);
    
    btn.disabled = false;
    btn.textContent = '重新检测';
  });
  
  // 关闭按钮
  document.getElementById('closeBtn').addEventListener('click', () => {
    window.close();
  });
});

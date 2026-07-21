function setStatus(message, type) {
  const status = document.getElementById('status');
  status.textContent = message;
  status.className = 'status ' + type;
}

function openOptions() {
  chrome.tabs.create({ url: chrome.runtime.getURL('options.html') });
}

function openInstallPage() {
  chrome.tabs.create({ url: chrome.runtime.getURL('install.html') });
}

function renderConfig(config) {
  const el = document.getElementById('configSummary');
  let pathDisplay = config.savePath || `~/.caches/biscuit/${config.cookieName}`;
  el.innerHTML = `
    <div><span class="label">域名: </span><span class="value">${config.domain}</span></div>
    <div><span class="label">Cookie 键名: </span><span class="value">${config.cookieName}</span></div>
    <div><span class="label">保存路径: </span><span class="value">${pathDisplay}</span></div>
  `;
}

function handleSave() {
  const btn = document.getElementById('saveBtn');
  btn.disabled = true;
  setStatus('正在读取并保存 Cookie...', 'info');

  chrome.runtime.sendMessage({ action: 'saveCookie' }, (response) => {
    btn.disabled = false;
    if (response && response.success) {
      setStatus(`✅ ${response.message}`, 'success');
    } else {
      setStatus(`❌ ${response?.error || '保存失败'}`, 'error');
    }
  });
}

function handleCopy() {
  const btn = document.getElementById('copyBtn');
  btn.disabled = true;
  setStatus('正在读取 Cookie...', 'info');

  chrome.runtime.sendMessage({ action: 'readCookie' }, (response) => {
    btn.disabled = false;
    if (response && response.success) {
      navigator.clipboard.writeText(response.value).then(() => {
        setStatus('✅ Cookie 已复制到剪贴板', 'success');
      }).catch(() => {
        setStatus('❌ 复制到剪贴板失败', 'error');
      });
    } else {
      setStatus(`❌ ${response?.error || '读取失败'}`, 'error');
    }
  });
}

// 打开 popup 时加载配置，停留在就绪状态
document.addEventListener('DOMContentLoaded', async () => {
  document.getElementById('saveBtn').addEventListener('click', handleSave);
  document.getElementById('copyBtn').addEventListener('click', handleCopy);
  document.getElementById('settingsBtn').addEventListener('click', openOptions);

  // 加载配置
  chrome.runtime.sendMessage({ action: 'getConfig' }, (config) => {
    if (config) {
      renderConfig(config);
    }
  });

  // 检测 Native Host 状态
  const hostStatus = await new Promise((resolve) => {
    chrome.runtime.sendMessage({ action: 'checkNativeHost' }, resolve);
  });

  if (!hostStatus.connected) {
    // Native Host 未安装：显示警告，提示可复制到剪贴板
    document.getElementById('hostWarning').classList.remove('hidden');
    document.getElementById('installBtn').addEventListener('click', openInstallPage);
    setStatus('就绪，可「复制 Cookie」到剪贴板或安装 Native Host 保存到本地', 'info');
  } else {
    setStatus('就绪，点击「保存 Cookie」保存到本地或「复制 Cookie」到剪贴板', 'info');
  }
});

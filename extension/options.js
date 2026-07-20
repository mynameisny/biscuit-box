const DEFAULT_CONFIG = {
  domain: "example.com",
  cookieName: "session_token",
  savePath: "",
};

function showMessage(text, type) {
  const el = document.getElementById('message');
  el.textContent = text;
  el.className = 'message ' + type;
  setTimeout(() => { el.style.display = 'none'; }, 3000);
}

function loadConfig() {
  chrome.storage.sync.get("cookieConfig", (result) => {
    const config = Object.assign({}, DEFAULT_CONFIG, result.cookieConfig);
    document.getElementById('domain').value = config.domain;
    document.getElementById('cookieName').value = config.cookieName;
    document.getElementById('savePath').value = config.savePath;
  });
}

function saveConfig() {
  const domain = document.getElementById('domain').value.trim();
  const cookieName = document.getElementById('cookieName').value.trim();
  const savePath = document.getElementById('savePath').value.trim();

  if (!domain) {
    showMessage('请输入域名', 'error');
    return;
  }
  if (!cookieName) {
    showMessage('请输入 Cookie 键名', 'error');
    return;
  }

  // 去掉用户可能输入的协议前缀
  const cleanDomain = domain.replace(/^https?:\/\//, '').replace(/\/.*$/, '');

  chrome.storage.sync.set({
    cookieConfig: { domain: cleanDomain, cookieName, savePath }
  }, () => {
    if (chrome.runtime.lastError) {
      showMessage(`保存失败: ${chrome.runtime.lastError.message}`, 'error');
    } else {
      showMessage(`✅ 已保存`, 'success');
    }
  });
}

function resetConfig() {
  chrome.storage.sync.set({ cookieConfig: DEFAULT_CONFIG }, () => {
    loadConfig();
    showMessage('✅ 已恢复默认配置', 'success');
  });
}

document.addEventListener('DOMContentLoaded', () => {
  document.getElementById('saveBtn').addEventListener('click', saveConfig);
  document.getElementById('resetBtn').addEventListener('click', resetConfig);
  loadConfig();
});

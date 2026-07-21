// 默认配置
const DEFAULT_CONFIG = {
  domain: "example.com",
  cookieName: "session_token",
  savePath: "",
};

// 获取配置
async function getConfig() {
  return new Promise((resolve) => {
    chrome.storage.sync.get("cookieConfig", (result) => {
      resolve(Object.assign({}, DEFAULT_CONFIG, result.cookieConfig));
    });
  });
}

// 创建右键菜单，显示在目标网页上
chrome.runtime.onInstalled.addListener(() => {
  createContextMenu();
});

async function createContextMenu() {
  const config = await getConfig();
  chrome.contextMenus.create({
    id: "cookieSaver",
    title: "Cookie Saver",
    contexts: ["page"],
  });
  chrome.contextMenus.create({
    id: "saveCookie",
    parentId: "cookieSaver",
    title: `保存 Cookie(${config.cookieName}) 到本地`,
    contexts: ["page"],
  });
  chrome.contextMenus.create({
    id: "copyCookie",
    parentId: "cookieSaver",
    title: `复制 Cookie(${config.cookieName}) 到剪贴板`,
    contexts: ["page"],
  });
}

// 配置变化时更新菜单标题
chrome.storage.onChanged.addListener((changes) => {
  if (changes.cookieConfig) {
    chrome.contextMenus.removeAll();
    createContextMenu();
  }
});

// 监听右键菜单点击
chrome.contextMenus.onClicked.addListener((info) => {
  if (info.menuItemId === "saveCookie") {
    handleContextMenuSave();
  }
  if (info.menuItemId === "copyCookie") {
    handleContextMenuCopy();
  }
});

// Native Host 状态
let nativeHostConnected = false;

// 检测 Native Host 是否可用
async function checkNativeHost() {
  return new Promise((resolve) => {
    chrome.runtime.sendNativeMessage(
      "com.biscuitbox.host",
      { value: "__ping__" },
      (response) => {
        if (chrome.runtime.lastError) {
          nativeHostConnected = false;
          resolve({ connected: false, error: chrome.runtime.lastError.message });
        } else {
          nativeHostConnected = true;
          resolve({ connected: true, message: response?.message });
        }
      }
    );
  });
}

// 安装后自动检测
chrome.runtime.onInstalled.addListener(async () => {
  const result = await checkNativeHost();
  if (!result.connected) {
    // 打开安装引导页
    chrome.tabs.create({ url: chrome.runtime.getURL("install.html") });
  }
});

// 监听来自 popup 的消息
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === "saveCookie") {
    saveCookie().then(sendResponse);
    return true;
  }
  if (request.action === "readCookie") {
    readCookie().then(sendResponse);
    return true;
  }
  if (request.action === "getConfig") {
    getConfig().then(sendResponse);
    return true;
  }
  if (request.action === "checkNativeHost") {
    checkNativeHost().then(sendResponse);
    return true;
  }
});

async function readCookie() {
  const config = await getConfig();
  return new Promise((resolve) => {
    // 尝试 http 和 https 两种协议
    const urls = [
      `https://${config.domain}`,
      `http://${config.domain}`,
    ];
    tryUrl(0);

    function tryUrl(index) {
      if (index >= urls.length) {
        resolve({
          success: false,
          error: `Cookie "${config.cookieName}" 在 ${config.domain} 上不存在，请先登录`,
        });
        return;
      }
      chrome.cookies.get(
        { url: urls[index], name: config.cookieName },
        (cookie) => {
          if (chrome.runtime.lastError) {
            tryUrl(index + 1);
            return;
          }
          if (cookie) {
            resolve({ success: true, value: cookie.value });
          } else {
            tryUrl(index + 1);
          }
        }
      );
    }
  });
}

async function saveCookie() {
  const result = await readCookie();
  if (!result.success) {
    return result;
  }

  const config = await getConfig();

  // 默认路径：~/.caches/biscuit/{cookieName}
  const savePath = config.savePath || `~/.caches/biscuit/${config.cookieName}`;

  return new Promise((resolve) => {
    chrome.runtime.sendNativeMessage(
      "com.biscuitbox.host",
      {
        value: result.value,
        domain: config.domain,
        cookieName: config.cookieName,
        savePath: savePath,
      },
      (response) => {
        if (chrome.runtime.lastError) {
          resolve({
            success: false,
            error: `Native Messaging 错误: ${chrome.runtime.lastError.message}`,
          });
          return;
        }
        resolve({
          success: true,
          message: response?.message || "Cookie 已保存",
        });
      }
    );
  });
}

function showNotification(title, message) {
  // 扩展图标徽章（最可靠，用户一定能看到）
  chrome.action.setBadgeText({ text: "OK" });
  chrome.action.setBadgeBackgroundColor({ color: "#4caf50" });
  setTimeout(() => chrome.action.setBadgeText({ text: "" }), 3000);

  // 系统通知（需要 macOS 通知权限）
  try {
    chrome.notifications.create({
      type: "basic",
      iconUrl: "icon128.png",
      title: title,
      message: message,
      priority: 2,
    });
  } catch (e) {
    // 静默失败
  }
}

function showErrorNotification(errorMessage) {
  chrome.action.setBadgeText({ text: "ERR" });
  chrome.action.setBadgeBackgroundColor({ color: "#f44336" });
  setTimeout(() => chrome.action.setBadgeText({ text: "" }), 3000);

  try {
    chrome.notifications.create({
      type: "basic",
      iconUrl: "icon128.png",
      title: "Cookie Saver",
      message: `❌ ${errorMessage}`,
      priority: 2,
    });
  } catch (e) {
    // 静默失败
  }
}

async function showToast(tab, icon, text, color) {
  if (!tab || !tab.id) return;
  try {
    await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      func: (icon, text, color) => {
        const existing = document.getElementById("cookie-saver-toast");
        if (existing) existing.remove();

        const toast = document.createElement("div");
        toast.id = "cookie-saver-toast";
        toast.style.cssText = `
          position: fixed;
          top: 50%;
          left: 50%;
          transform: translate(-50%, -50%);
          z-index: 2147483647;
          background: ${color};
          color: #fff;
          padding: 24px 36px;
          border-radius: 12px;
          font-family: -apple-system, BlinkMacSystemFont, sans-serif;
          font-size: 16px;
          line-height: 1.5;
          box-shadow: 0 8px 32px rgba(0,0,0,0.3);
          max-width: 400px;
          word-break: break-all;
          opacity: 1;
          transition: opacity 0.3s ease;
          pointer-events: none;
          text-align: center;
        `;
        toast.textContent = `${icon} ${text}`;
        document.body.appendChild(toast);

        setTimeout(() => {
          toast.style.opacity = "0";
          setTimeout(() => toast.remove(), 300);
        }, 3000);
      },
      args: [icon, text, color],
    });
  } catch (e) {
    // 注入失败则回退到徽章和通知
  }
}

async function handleContextMenuCopy() {
  const result = await readCookie();
  const [tab] = await chrome.tabs.query({ active: true, lastFocusedWindow: true });

  if (result.success) {
    // 通过注入脚本复制到剪贴板
    if (tab && tab.id) {
      try {
        await chrome.scripting.executeScript({
          target: { tabId: tab.id },
          func: (value) => {
            navigator.clipboard.writeText(value);
          },
          args: [result.value],
        });
      } catch (e) {
        // 静默失败
      }
    }
    showToast(tab, "✅", "Cookie 已复制到剪贴板", "#4caf50");
    showNotification("Cookie Saver", "Cookie 已复制到剪贴板");
  } else {
    showToast(tab, "❌", result.error, "#f44336");
    showErrorNotification(result.error);
  }
}

async function handleContextMenuSave() {
  const result = await saveCookie();
  const [tab] = await chrome.tabs.query({ active: true, lastFocusedWindow: true });

  if (result.success) {
    showToast(tab, "✅", "Cookie 已保存到本地", "#4caf50");
    showNotification("Cookie Saver", result.message.replace("Cookie 已保存到: ", ""));
  } else {
    showToast(tab, "❌", result.error, "#f44336");
    showErrorNotification(result.error);
  }
}

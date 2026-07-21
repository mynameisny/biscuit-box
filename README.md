# Biscuit Box

Chrome 扩展 + Native Messaging Host（Go 实现），读取指定域名的 Cookie 并保存到本地文件，供 AI 自动化脚本使用。

## 特性

- 可配置域名和 Cookie 键名
- 可自定义保存路径（默认 `~/.caches/biscuit/{Cookie键名}`）
- 右键菜单一键保存
- 页面内 Toast 提示
- **自动检测 Native Host 是否安装，未安装时引导用户下载安装**

## 项目结构

```
├── extension/                  # Chrome 扩展（Manifest V3）
│   ├── manifest.json           # 扩展清单
│   ├── background.js           # Service Worker
│   ├── popup.html / popup.js   # 弹出窗口 UI
│   ├── options.html / options.js # 配置页面
│   └── install.html / install.js # Native Host 安装引导页
├── native-host/                # Native Messaging Host（Go）
│   ├── main.go                 # 主程序
│   ├── go.mod                  # Go 模块定义
│   ├── com.biscuitbox.host.json # Chrome 原生消息主机清单
│   ├── setup.sh                # macOS/Linux 安装脚本
│   ├── setup.bat               # Windows 安装脚本
│   └── build.sh                # 跨平台构建脚本
```

## 保存的文件

| 文件 | 内容 | 用途 |
|------|------|------|
| `cookie_token` | Cookie 原始值（纯文本） | AI 直接读取 token |
| `cookie_meta.json` | `{value, domain, cookieName}` 元数据 | AI 识别 token 来源 |

## Cookie 保存路径

默认路径：`~/.caches/biscuit/{Cookie键名}`（可通过设置页自定义）

## 安装

### 方式一：从 Release 下载（推荐）

1. 从 [GitHub Releases](https://github.com/mynameisny/biscuit-box/releases) 下载对应平台的安装包
2. 解压后运行安装脚本：
   - macOS/Linux: `chmod +x setup.sh && ./setup.sh`
   - Windows: 双击 `setup.bat`
3. 在 Chrome 中安装扩展（开发者模式 → 加载已解压的扩展程序，使用 `archives/extension.pem` 打包）

> **注意：** 扩展 ID 由 `archives/extension.pem` 公钥决定，安装时必须使用该 PEM 文件打包，ID 才能与 Native Host manifest 匹配。

### 方式二：从源码构建

```bash
# 编译 Native Host
cd native-host
go build -ldflags="-s -w" -o biscuit-host .
./setup.sh

# 加载扩展
# chrome://extensions → 开发者模式 → 加载 extension/ 目录（使用 archives/extension.pem 打包）
```

### 方式三：仅安装扩展（自动引导安装 Native Host）

1. 在 Chrome 中安装扩展（使用 `archives/extension.pem` 打包）
2. 首次使用时，扩展会自动检测 Native Host 是否安装
3. 如果未安装，会自动打开安装引导页面
4. 按页面提示下载并安装 Native Host

## 使用

- **右键网页** →「保存 Cookie(xxx) 到本地」
- **点击扩展图标** → 弹出窗口操作
- **右键扩展图标** →「选项」→ 配置域名、Cookie 键名和保存路径

## AI 自动化读取

```bash
cat ~/.caches/biscuit/BAIDUID             # Cookie 原始值
cat ~/.caches/biscuit/cookie_meta.json    # 元数据
```

## 构建发布包

```bash
cd native-host
chmod +x build.sh
./build.sh 1.0.0
```

将生成 macOS (amd64/arm64)、Linux、Windows 四个平台的安装包。

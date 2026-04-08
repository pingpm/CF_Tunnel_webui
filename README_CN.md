# 🚀 CF_Tunnel

一个轻量化、全自动的 Cloudflare Tunnel 管理面板。无需公网 IP，无需配置防火墙端口转发，即可轻松将本地服务（Web、SSH、API 等）发布到公网。

![Web UI 预览](./website/preview.png)

![平台支持](https://img.shields.io/badge/平台-Windows%20|%20Linux%20|%20macOS-success?style=for-the-badge)
![开源协议](https://img.shields.io/badge/协议-MIT-orange?style=for-the-badge)

## ✨ 功能亮点

- **一键安装**：为 Windows 和 Linux 提供全自动的一键部署脚本。
- **智能依赖管理**：自动检测并安装 Node.js、npm 以及适配您系统的最新版 `cloudflared`。
- **无限端口映射**：不对映射数量做任何软件限制，随心扩展。
- **现代化面板**：高颜值的专业极简设计，支持深色/浅色模式自适应。
- **零配置安全**：利用 Cloudflare Quick Tunnels 技术，由 Edge 提供 SSL 加密保障。
- **双语支持**：完整的中英文界面切换支持。

---

## 🚀 一键安装

### 🪟 Windows (PowerShell)
打开 PowerShell 并运行：
```powershell
iwr -useb https://cft.imdaxia.com/install.ps1 | iex
```

### 🍎 Linux / macOS
打开终端并运行：
```bash
curl -sSL https://cft.imdaxia.com/install.sh | bash
```

---

## 📖 如何使用

1.  **启动**：运行上方的一键安装命令。
2.  **获取访问面板**：查看终端输出，点击 **Access Link** 链接。
3.  **创建穿透**：在浏览器打开面板，输入本地端口并点击 **Create Tunnel**。

---

## 🛠️ 手动安装 (备选方案)
如果一键脚本失败，请按照以下步骤手动部署：

1. **安装 Node.js**：前往 [nodejs.org](https://nodejs.org/) 安装 LTS 版本。
2. **下载项目**：
   ```bash
   git clone https://github.com/pingpm/CF_Tunnel_webui.git
   cd CF_Tunnel_webui
   ```
3. **安装依赖**：
   ```bash
   npm install
   ```
4. **启动服务**：
   ```bash
   node server/index.js
   ```
5. **访问面板**：浏览器打开 `http://localhost:11122`。

---

## ⚠️ 重要提示
*   **会话保持**：本工具基于当前进程运行。关闭窗口或终止进程，所有穿透网址将立即失效。
*   **持久化运行**：如需 7x24 小时运行，建议使用 [PM2](https://pm2.keymetrics.io/)：
    ```bash
    npm install -g pm2
    pm2 start server/index.js --name cf-tunnel
    ```

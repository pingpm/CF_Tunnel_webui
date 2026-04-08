# 🚀 CF_Tunnel

[中文文档](./README_CN.md)

A lightweight, automated management dashboard for Cloudflare Tunnels. Easily expose your local services (Web, SSH, API, etc.) to the internet without a public IP or port forwarding.

![Web UI Preview](./website/preview.png)

![Platform Support](https://img.shields.io/badge/Platform-Windows%20|%20Linux%20|%20macOS-success?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-orange?style=for-the-badge)

## ✨ Features

- **One-Click Setup**: Fully automated installation script for Windows and Linux.
- **Smart Dependency Management**: Automatically detects and installs Node.js, npm, and the latest `cloudflared` binary for your OS.
- **Modern Dashboard**: High-end minimalist user interface with dark/light mode support.
- **Dynamic Port Mapping**: Add, monitor, and remove port mappings directly from your browser.
- **Bilingual Support**: Full Chinese and English user interface.
- **Zero Configuration**: Uses Cloudflare "Quick Tunnels" (TryCloudflare) to provide public URLs instantly.

---

## 🛠️ Installation

### Windows (PowerShell)
Open PowerShell and run:
```powershell
iwr -useb https://cft.imdaxia.com/install.ps1 | iex
```

## 🛠️ Manual Installation (Fallback)
If the one-line command fails, please follow these steps:

1. **Install Node.js**: Download and install from [nodejs.org](https://nodejs.org/) (LTS version is recommended).
2. **Download Project**:
   ```bash
   git clone https://github.com/pingpm/CF_Tunnel_webui.git
   cd CF_Tunnel_webui
   ```
   *(Or download and extract the project [ZIP](https://github.com/pingpm/CF_Tunnel_webui/archive/refs/heads/main.zip))*
3. **Install Dependencies**:
   ```bash
   npm install
   ```
4. **Start Server**:
   ```bash
   node server/index.js
   ```
5. **Open Dashboard**: Go to `http://localhost:11122` in your browser.

---

## 📖 How to Use

1.  **Launch**: Run the installation script.
2.  **Access Control Panel**: Look at your terminal output for the **Access Link**.
3.  **Create Tunnels**: Open the link, enter your local port, and click **Create Tunnel**.

### Curl-to-Install (One-Liner)
```bash
curl -sSL https://cft.imdaxia.com/install.sh | bash
```

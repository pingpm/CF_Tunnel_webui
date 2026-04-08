# Cloudflare Tunnel Control Panel Installer for Windows (PowerShell)

$Host.UI.RawUI.WindowTitle = "Cloudflare Tunnel Control Panel Installer"

Write-Host "`n🚀 Starting Cloudflare Tunnel Control Panel Installation...`n" -ForegroundColor Cyan

# 1. Check for Node.js
if (!(Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Node.js is not installed." -ForegroundColor Red
    Write-Host "Please install Node.js from https://nodejs.org/" -ForegroundColor Yellow
    Write-Host "After installation, please restart your terminal and run this script again." -ForegroundColor Gray
    exit
}

Write-Host "✅ Node.js detected: $(node -v)" -ForegroundColor Green

# 2. Navigate to project directory (assuming script is in the project root)
# Set-Location -Path $PSScriptRoot

# 3. Install dependencies
Write-Host "`n📦 Installing npm dependencies (this may take a minute)..." -ForegroundColor Yellow
npm install

# 4. Start the application
Write-Host "`n🌟 Starting the control panel..." -ForegroundColor Green
Write-Host "-------------------------------------------------"
Write-Host "Please wait for the Cloudflare Tunnel to initialize..." -ForegroundColor Cyan
Write-Host "-------------------------------------------------`n"

node server/index.js


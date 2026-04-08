$Host.UI.RawUI.WindowTitle = "CF_Tunnel Installer"

Write-Host "`n🚀 Starting CF_Tunnel Installation...`n" -ForegroundColor Cyan

# 0. Remote execution handler
# If package.json is missing, we need to clone the repo first
if (!(Test-Path "package.json")) {
    Write-Host "📥 Project files not found. Preparing to clone from GitHub..." -ForegroundColor Yellow
    
    # Check if git is installed
    if (!(Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "❌ Git is not installed. Continuous installation failed." -ForegroundColor Red
        Write-Host "Please install Git or download the repository manually." -ForegroundColor Yellow
        Read-Host "Press Enter to exit..."
        exit
    }

    $REPO_URL = "https://github.com/pingpm/CF_Tunnel_webui.git"
    Write-Host "📥 Cloning repository from $REPO_URL..." -ForegroundColor Cyan
    
    git clone $REPO_URL CF_Tunnel-temp
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to clone repository." -ForegroundColor Red
        Read-Host "Press Enter to exit..."
        exit
    }
    
    Set-Location -Path "CF_Tunnel-temp"
}

# 1. Check for Node.js
if (!(Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Node.js is not installed." -ForegroundColor Red
    Write-Host "Please install Node.js from https://nodejs.org/" -ForegroundColor Yellow
    Write-Host "After installation, please restart your terminal and run this script again." -ForegroundColor Gray
    Read-Host "Press Enter to exit..."
    exit
}

Write-Host "✅ Node.js detected: $(node -v)" -ForegroundColor Green

# 2. Install dependencies
Write-Host "`n📦 Installing npm dependencies (this may take a minute)..." -ForegroundColor Yellow
npm install
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ npm install failed." -ForegroundColor Red
    Read-Host "Press Enter to exit..."
    exit
}

# 3. Start the application
Write-Host "`n🌟 Starting the control panel..." -ForegroundColor Green
Write-Host "-------------------------------------------------"
Write-Host "Please wait for the Cloudflare Tunnel to initialize..." -ForegroundColor Cyan
Write-Host "-------------------------------------------------`n"

node server/index.js

# If node exits, keep the window open so user can see why
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n❌ Process exited with error code $LASTEXITCODE" -ForegroundColor Red
}
Read-Host "`nInstallation finished. Press Enter to close this window..."


# Set encoding to UTF-8 to support emojis and international characters
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "CF_Tunnel Installer"

Write-Host "`n🚀 Starting CF_Tunnel Installation...`n" -ForegroundColor Cyan

# 0. Remote execution handler
# If package.json is missing, we need to get the code first
if (!(Test-Path "package.json")) {
    Write-Host "📥 Project files not found. Preparing to fetch code..." -ForegroundColor Yellow
    
    $REPO_URL = "https://github.com/pingpm/CF_Tunnel_webui"
    $DIR_NAME = "CF_Tunnel-main"

    if (Get-Command git -ErrorAction SilentlyContinue) {
        # Method 1: Git Clone
        Write-Host "📥 Cloning repository via Git..." -ForegroundColor Cyan
        git clone "$REPO_URL.git" "CF_Tunnel-temp"
        if ($LASTEXITCODE -eq 0) {
            Set-Location -Path "CF_Tunnel-temp"
        }
    } else {
        # Method 2: Direct ZIP Download (Fallback for systems without Git)
        Write-Host "⚠️  Git not detected. Downloading ZIP archive instead..." -ForegroundColor Yellow
        $zipFile = "$env:TEMP\cft_latest.zip"
        $destFolder = "$PWD\CF_Tunnel-main"
        
        try {
            Invoke-WebRequest -Uri "$REPO_URL/archive/refs/heads/main.zip" -OutFile $zipFile
            Write-Host "📦 Extracting files..." -ForegroundColor Cyan
            Expand-Archive -Path $zipFile -DestinationPath "$PWD" -Force
            Remove-Item $zipFile
            Set-Location -Path $destFolder
        } catch {
            Write-Host "❌ Failed to download or extract the project." -ForegroundColor Red
            Read-Host "Press Enter to exit..."
            exit
        }
    }
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


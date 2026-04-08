# Set encoding and security protocol for modern web connections
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Host.UI.RawUI.WindowTitle = "CF_Tunnel Installer"

Write-Host "`n🚀 Starting CF_Tunnel Installation...`n" -ForegroundColor Cyan

# 0. Remote execution handler
if (!(Test-Path "package.json") -and !(Test-Path "server\index.js")) {
    Write-Host "📥 Project files not found. Preparing to fetch code..." -ForegroundColor Yellow
    
    $REPO_URL = "https://github.com/pingpm/CF_Tunnel_webui"

    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Host "📥 Cloning repository via Git..." -ForegroundColor Cyan
        git clone "$REPO_URL.git" "CF_Tunnel-temp"
        if (Test-Path "CF_Tunnel-temp") { Set-Location -Path "CF_Tunnel-temp" }
    } else {
        Write-Host "⚠️  Git not detected. Downloading ZIP archive instead..." -ForegroundColor Yellow
        $zipFile = "$env:TEMP\cft_latest.zip"
        
        try {
            Invoke-WebRequest -Uri "$REPO_URL/archive/refs/heads/main.zip" -OutFile $zipFile
            Write-Host "📦 Extracting files..." -ForegroundColor Cyan
            Expand-Archive -Path $zipFile -DestinationPath "$PWD" -Force
            Remove-Item $zipFile
            
            # Dynamically find the extracted folder (GitHub ZIPs are usually RepoName-BranchName)
            $extractedFolder = Get-ChildItem -Directory | Where-Object { $_.Name -like "*CF_Tunnel_webui-main*" } | Select-Object -First 1
            if ($extractedFolder) {
                Set-Location -Path $extractedFolder.FullName
            } else {
                Write-Host "❌ Could not find the extracted folder." -ForegroundColor Red
                exit
            }
        } catch {
            Write-Host "❌ Failed to download or extract the project." -ForegroundColor Red
            Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Gray
            Read-Host "Press Enter to exit..."
            exit
        }
    }
}

# 1. Check for Node.js and handle installation
$nodeCheckLimit = "$env:TEMP\cft_node_install_attempt.txt"

function Refresh-Environment {
    $env:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

if (!(Get-Command node -ErrorAction SilentlyContinue)) {
    # Check common install path directly if command not found
    $commonPath = "C:\Program Files\nodejs\node.exe"
    if (Test-Path $commonPath) {
        $env:PATH += ";C:\Program Files\nodejs"
    }
}

if (!(Get-Command node -ErrorAction SilentlyContinue)) {
    # Check if we are caught in a loop
    if (Test-Path $nodeCheckLimit) {
        $attempts = Get-Content $nodeCheckLimit
        if ([int]$attempts -ge 2) {
            Write-Host "❌ Still cannot detect Node.js after multiple attempts." -ForegroundColor Red
            Write-Host "Please RESTART YOUR COMPUTER manually to finish Node.js setup, then run this command again." -ForegroundColor Yellow
            Remove-Item $nodeCheckLimit
            Read-Host "Press Enter to exit..."
            exit
        }
        $attempts = [int]$attempts + 1
        $attempts | Out-File $nodeCheckLimit
    } else {
        "1" | Out-File $nodeCheckLimit
    }

    Write-Host "❌ Node.js is not installed." -ForegroundColor Red
    
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "💡 Attempting to install Node.js via winget..." -ForegroundColor Yellow
        winget install --id OpenJS.NodeJS.LTS --silent --accept-package-agreements --accept-source-agreements
    } else {
        Write-Host "⚠️  winget not found. Attempting direct MSI installation..." -ForegroundColor Yellow
        $msiPath = "$env:TEMP\node-v20.msi"
        $msiUrl = "https://nodejs.org/dist/v20.11.1/node-v20.11.1-x64.msi"
        
        try {
            Write-Host "📥 Downloading Node.js MSI..." -ForegroundColor Cyan
            (New-Object Net.WebClient).DownloadFile($msiUrl, $msiPath)
            Write-Host "📦 Installing Node.js (Silent)..." -ForegroundColor Yellow
            $process = Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /quiet /qn /norestart" -Wait -PassThru
            Remove-Item $msiPath
        } catch {
            Write-Host "❌ Failed to download or install Node.js." -ForegroundColor Red
            Read-Host "Press Enter to exit..."
            exit
        }
    }
    
    Write-Host "✅ Node.js installation completed. Refreshing environment..." -ForegroundColor Green
    Refresh-Environment
    
    if (!(Get-Command node -ErrorAction SilentlyContinue)) {
        Write-Host "🔄 Restarting PowerShell to apply environment changes..." -ForegroundColor Yellow
        $currentCommand = "iwr -useb https://cft.imdaxia.com/install.ps1 | iex"
        Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", "& { $currentCommand }"
        exit
    }
}

# Clear the loop tracker if we reach here
if (Test-Path $nodeCheckLimit) { Remove-Item $nodeCheckLimit }
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


const express = require('express');
const { bin, install } = require('cloudflared');
const cors = require('cors');
const bodyParser = require('body-parser');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const app = express();
const PORT = process.env.PORT || 11122;
const DATA_FILE = path.join(__dirname, 'data.json');

app.use(cors());
app.use(bodyParser.json());
app.use(express.static(path.join(__dirname, '../client')));

// Store for active tunnels
const activeTunnels = new Map();
let adminTunnelUrl = '';
let db = { mappings: [] };

// Load DB
if (fs.existsSync(DATA_FILE)) {
    try {
        db = JSON.parse(fs.readFileSync(DATA_FILE));
    } catch (e) {
        console.error('Failed to load DB:', e);
    }
}

function saveDb() {
    fs.writeFileSync(DATA_FILE, JSON.stringify(db, null, 2));
}

/**
 * Start a Cloudflare Quick Tunnel
 */
function startTunnel(localPort, id = null) {
    return new Promise((resolve, reject) => {
        const absoluteBin = path.resolve(bin);
        console.log(`🚀 Starting tunnel for port ${localPort} using binary: ${absoluteBin}`);
        
        if (!fs.existsSync(absoluteBin)) {
            return reject(new Error(`Binary not found at ${absoluteBin}`));
        }

        const stats = fs.statSync(absoluteBin);
        console.log(`📊 Binary size: ${stats.size} bytes`);
        if (stats.size === 0) {
            return reject(new Error(`Binary at ${absoluteBin} is empty (0 bytes).`));
        }

        // cloudflared tunnel --url http://localhost:PORT
        // Use shell: true on Windows to prevent 'spawn UNKNOWN' errors
        const tunnelProcess = spawn(absoluteBin, ['tunnel', '--url', `http://localhost:${localPort}`], {
            shell: process.platform === 'win32'
        });
        
        let urlDetected = false;
        let url = '';

        tunnelProcess.stderr.on('data', (data) => {
            const output = data.toString();
            // Trycloudflare URLs usually look like: https://something.trycloudflare.com
            const match = output.match(/https:\/\/[a-z0-9-]+\.trycloudflare\.com/);
            if (match && !urlDetected) {
                url = match[0];
                urlDetected = true;
                console.log(`✅ Tunnel URL for port ${localPort}: ${url}`);
                resolve({ process: tunnelProcess, url });
            }
            
            if (process.env.DEBUG) {
                console.log(`[cloudflared ${localPort}] ${output}`);
            }
        });

        tunnelProcess.on('exit', (code) => {
            console.log(`ℹ️ Tunnel for port ${localPort} exited with code ${code}`);
            if (id) {
                const mapping = db.mappings.find(m => m.id === id);
                if (mapping) mapping.status = 'stopped';
                activeTunnels.delete(id);
                saveDb();
            }
        });

        tunnelProcess.on('error', (err) => {
            console.error(`❌ Tunnel error for port ${localPort}:`, err);
            if (!urlDetected) reject(err);
        });

        // Timeout if no URL in 30s
        setTimeout(() => {
            if (!urlDetected) {
                try { tunnelProcess.kill(); } catch(e) {}
                reject(new Error('Tunnel startup timeout - Could not detect URL in output'));
            }
        }, 30000);
    });
}

// API Routes
app.get('/api/status', (req, res) => {
    res.json({
        adminUrl: adminTunnelUrl,
        port: PORT,
        activeCount: activeTunnels.size
    });
});

app.get('/api/tunnels', (req, res) => {
    const list = db.mappings.map(m => ({
        ...m,
        status: activeTunnels.has(m.id) ? 'running' : 'stopped',
        url: activeTunnels.get(m.id)?.url || null
    }));
    res.json(list);
});

app.post('/api/tunnels', async (req, res) => {
    const { name, localPort } = req.body;
    if (!localPort) return res.status(400).json({ error: 'Port is required' });

    // Prevent duplicate mapping
    const existing = db.mappings.find(m => m.localPort == localPort);
    if (existing) {
        return res.status(400).json({ error: `Port ${localPort} is already mapped.` });
    }
    const newMapping = { id, name: name || `Port ${localPort}`, localPort, status: 'starting', createdAt: new Date() };
    db.mappings.push(newMapping);
    saveDb();

    try {
        const { process, url } = await startTunnel(localPort, id);
        activeTunnels.set(id, { process, url });
        
        const mapping = db.mappings.find(m => m.id === id);
        if (mapping) {
            mapping.status = 'running';
            saveDb();
        }
        
        res.json({ id, url });
    } catch (err) {
        console.error(err);
        const mapping = db.mappings.find(m => m.id === id);
        if (mapping) {
            mapping.status = 'failed';
            saveDb();
        }
        res.status(500).json({ error: `Failed to start tunnel: ${err.message}` });
    }
});

app.delete('/api/tunnels/:id', (req, res) => {
    const { id } = req.params;
    const tunnelInfo = activeTunnels.get(id);
    
    if (tunnelInfo) {
        try { tunnelInfo.process.kill(); } catch(e) {}
        activeTunnels.delete(id);
    }
    
    db.mappings = db.mappings.filter(m => m.id !== id);
    saveDb();
    res.json({ success: true });
});

// Handle binary installation with Mirror support
async function installBinary() {
    if (fs.existsSync(bin)) {
        const stats = fs.statSync(bin);
        if (stats.size > 0) return;
        console.warn('⚠️  Binary exists but is empty, re-downloading...');
        fs.unlinkSync(bin);
    }

    console.log('📦 Cloudflare binary not found. Preparing install...');

    // If a mirror URL is provided via env, use it directly (skip slow official source)
    if (process.env.CLOUDFLARED_BIN_URL) {
        console.log(`📥 Downloading from mirror: ${process.env.CLOUDFLARED_BIN_URL}`);
        await downloadBinary(process.env.CLOUDFLARED_BIN_URL, bin);
        return;
    }

    // Attempt 1: Default installer from npm package
    try {
        console.log('Attempting official download...');
        const installWithTimeout = Promise.race([
            install(bin),
            new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 15000))
        ]);
        await installWithTimeout;
        console.log('✅ Cloudflare binary installed via official source.');
        return;
    } catch (err) {
        console.warn('⚠️  Official download failed or timed out, trying mirror...');
    }

    // Attempt 2: Mirror fallback (China friendly)
    const platform = process.platform;
    const arch = process.arch;

    // Fallback version with known-good mirror URLs (update periodically)
    const FALLBACK_VERSION = '2026.3.0';
    const MIRROR_BASE = `https://githubproxy.cc/https://github.com/cloudflare/cloudflared/releases/download/${FALLBACK_VERSION}`;

    const FALLBACK_URLS = {
        'darwin-arm64':  `${MIRROR_BASE}/cloudflared-darwin-arm64.tgz`,
        'darwin-x64':    `${MIRROR_BASE}/cloudflared-darwin-amd64.tgz`,
        'linux-x64':     `${MIRROR_BASE}/cloudflared-linux-amd64`,
        'linux-arm64':   `${MIRROR_BASE}/cloudflared-linux-arm64`,
        'linux-arm':     `${MIRROR_BASE}/cloudflared-linux-armhf`,
        'linux-ia32':    `${MIRROR_BASE}/cloudflared-linux-386`,
        'win32-x64':     `${MIRROR_BASE}/cloudflared-windows-amd64.exe`,
    };

    const key = `${platform}-${arch}`;
    const mirrorUrl = FALLBACK_URLS[key];

    if (!mirrorUrl) {
        console.error(`❌ No fallback URL available for platform: ${key}`);
        process.exit(1);
    }

    console.log(`📥 Downloading fallback binary (${FALLBACK_VERSION}) from mirror: ${mirrorUrl}`);
    await downloadBinary(mirrorUrl, bin);
}

async function downloadBinary(url, dest) {
    const axios = require('axios');
    const os = require('os');
    const tmpFile = dest + '.tmp';

    // Ensure the destination directory exists
    fs.mkdirSync(path.dirname(dest), { recursive: true });

    const response = await axios({ method: 'get', url, responseType: 'stream', timeout: 60000 });
    const writer = fs.createWriteStream(tmpFile);
    response.data.pipe(writer);
    await new Promise((resolve, reject) => {
        writer.on('finish', resolve);
        writer.on('error', reject);
    });

    // Handle .tgz (macOS)
    if (url.endsWith('.tgz')) {
        const { execSync } = require('child_process');
        const extractDir = path.join(os.tmpdir(), 'cloudflared-extract');
        fs.mkdirSync(extractDir, { recursive: true });
        execSync(`tar -xzf "${tmpFile}" -C "${extractDir}"`);
        const extracted = fs.readdirSync(extractDir).find(f => f.startsWith('cloudflared'));
        if (!extracted) throw new Error('cloudflared binary not found in tgz');
        fs.renameSync(path.join(extractDir, extracted), dest);
        fs.rmSync(extractDir, { recursive: true, force: true });
    } else {
        fs.renameSync(tmpFile, dest);
    }

    if (fs.existsSync(tmpFile)) fs.unlinkSync(tmpFile);
    if (process.platform !== 'win32') fs.chmodSync(dest, '755');
    console.log('✅ Cloudflare binary installed successfully.');
}

// Start Admin Tunnel and Server
async function init() {
    // 1. Ensure binary exists
    await installBinary();

    app.listen(PORT, async () => {
        console.log(`Control Panel Server running on http://localhost:${PORT}`);
        
        try {
            const { url } = await startTunnel(PORT);
            adminTunnelUrl = url;
            console.log('\n=================================================');
            console.log('🚀 Cloudflare Tunnel Control Panel is ONLINE!');
            console.log(`🔗 Access Link: ${url}`);
            console.log('=================================================\n');
        } catch (err) {
            console.error('❌ Failed to start Admin Tunnel:', err.message);
            console.log('\n⚠️  Control panel is only available locally at http://localhost:' + PORT);
        }
    });
}

init();



let currentPort = 6969;
let socket = null;
let isConnected = false;
const api = chrome || browser;
const action = api.action || api.browserAction;

// Session Heartbeat Config
const SUPPORTED_DOMAINS = [
    'youtube.com', 'youtu.be',
    'instagram.com',
    'twitter.com', 'x.com',
    'tiktok.com',
    'twitch.tv',
    'facebook.com', 'pornhub.com'
];
let cookieDebounce = null;

function getConfiguredPort() {
    return new Promise((resolve) => {
        api.storage.local.get(['serverPort'], (result) => {
            resolve(result.serverPort || 6969);
        });
    });
}

// ==========================================
// 1. WebSocket Connection & Logic
// ==========================================
async function connect() {
    currentPort = await getConfiguredPort();
    console.log(`Connecting to Modern Downloader app on localhost:${currentPort}...`);
    try {
        socket = new WebSocket(`ws://localhost:${currentPort}`);

        socket.onopen = () => {
            console.log("✅ Connected to Modern Downloader App");
            isConnected = true;
            action.setBadgeText({ text: "ON" });
            action.setBadgeBackgroundColor({ color: "#6C5DD3" }); // Premium Purple
            socket.send(JSON.stringify({ type: 'HELLO', version: '2.0.0' }));

            // Send initial heartbeat for current tab if supported (Debounced/Checked)
            api.storage.local.get(['autoSendCookies'], (res) => {
                if (res.autoSendCookies !== false) {
                    setTimeout(sendCurrentTabCookies, 2000);
                }
            });
        };

        socket.onclose = () => {
            console.log("❌ Disconnected from App. Retrying in 5s...");
            isConnected = false;
            action.setBadgeText({ text: "OFF" });
            action.setBadgeBackgroundColor({ color: "#FF4757" }); // Red
            socket = null;
            setTimeout(connect, 5000);
        };

        socket.onmessage = (event) => {
            try {
                const message = JSON.parse(event.data);
                handleAppMessage(message);
            } catch (e) {
                console.error("Failed to parse app message", e);
            }
        };

        socket.onerror = (e) => {
            console.error("⚠️ WebSocket Error", e);
        };
    } catch (e) {
        console.error("💥 Critical WebSocket Error", e);
        setTimeout(connect, 5000);
    }
}

api.storage.onChanged.addListener((changes, area) => {
    if (area !== 'local' || !changes.serverPort) {
        return;
    }

    const nextPort = changes.serverPort.newValue || 6969;
    if (nextPort === currentPort) {
        return;
    }

    currentPort = nextPort;
    if (socket) {
        socket.close();
    } else {
        connect();
    }
});

function handleAppMessage(message) {
    if (message.type === 'PROGRESS') {
        const item = message.data;
        updateBadgeFromProgress(item);
        // Store for dashboard
        api.storage.local.get(['recentDownloads'], (result) => {
            let recents = result.recentDownloads || [];
            // Upsert
            const idx = recents.findIndex(r => r.id === item.id);
            if (idx >= 0) {
                recents[idx] = item;
            } else {
                recents.unshift(item);
            }
            // Keep last 10
            recents = recents.slice(0, 10);
            api.storage.local.set({ recentDownloads: recents });
        });
    }
}

function updateBadgeFromProgress(item) {
    if (item.status === 1 || item.status === 2 || item.status === 3) { // 1=Queued, 2=Extracting, 3=Downloading
        action.setBadgeText({ text: "⬇" });
        action.setBadgeBackgroundColor({ color: "#4CAF50" });
    } else if (item.status === 4) { // Completed
        action.setBadgeText({ text: "✓" });
        setTimeout(() => {
            if (isConnected) action.setBadgeText({ text: "ON" });
            action.setBadgeBackgroundColor({ color: "#6C5DD3" });
        }, 3000);
    }
}


// ==========================================
// 2. Context Menu
// ==========================================
// Check if contextMenus exists (Firefox MV2 might behave differently if not in manifest)
if (api.contextMenus) {
    api.runtime.onInstalled.addListener(() => {
        api.contextMenus.create({
            id: "download-with-md",
            title: "Download with Modern Downloader",
            contexts: ["link", "video", "audio", "page"]
        });
    });

    api.contextMenus.onClicked.addListener((info, tab) => {
        if (info.menuItemId === "download-with-md") {
            const url = info.linkUrl || info.srcUrl || info.pageUrl;
            handleDownloadRequest(url, tab.url);
        }
    });
}

// ==========================================
// 3. Communications Hook (Content Script -> Background)
// ==========================================
api.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.type === 'DOWNLOAD_BTN_CLICK') {
        handleDownloadRequest(message.url, message.pageUrl, message.options);
    }
});

function formatCookiesToNetscape(cookies) {
    let sb = "# Netscape HTTP Cookie File\n";
    sb += "# This file was generated by Modern Downloader Extension\n\n";

    for (const cookie of cookies) {
        const domain = cookie.domain;
        const flag = domain.startsWith('.') ? 'TRUE' : 'FALSE';
        const path = cookie.path;
        const secure = cookie.secure ? 'TRUE' : 'FALSE';
        const expiration = Math.floor(cookie.expirationDate || (Date.now() / 1000 + 31536000)); // Default 1 year if session
        const name = cookie.name;
        const value = cookie.value;

        sb += `${domain}\t${flag}\t${path}\t${secure}\t${expiration}\t${name}\t${value}\n`;
    }
    return sb;
}


async function detectBrowser() {
    return 'firefox';
}

async function handleDownloadRequest(mediaUrl, pageUrl, options = {}) {
    if (!isConnected || !socket) {
        console.warn("App not connected");
        return;
    }

    // Debug log to App
    socket.send(JSON.stringify({ type: 'DEBUG', message: `Processing click for ${mediaUrl}` }));

    try {
        const urlObj = new URL(pageUrl);
        const cookies = await api.cookies.getAll({ domain: urlObj.hostname });
        // CHANGED: Use Netscape format
        const cookieString = formatCookiesToNetscape(cookies);

        // Detect browser for yt-dlp --cookies-from-browser
        const detectedBrowser = await detectBrowser();

        const payload = {
            type: 'DOWNLOAD',
            url: mediaUrl,
            cookies: cookieString,
            userAgent: navigator.userAgent,
            referrer: pageUrl,
            cookieBrowser: detectedBrowser, // PASS DETECTED BROWSER
            ...options // Quality, audioOnly, etc.
        };

        socket.send(JSON.stringify(payload));
        console.log("Sent download request", payload);
        socket.send(JSON.stringify({ type: 'DEBUG', message: `Payload SENT for ${mediaUrl}` }));
    } catch (e) {
        console.error("Error processing download request", e);
        if (isConnected && socket) {
            socket.send(JSON.stringify({ type: 'DEBUG', message: `ERROR in BG: ${e.message || e.toString()}` }));
        }
    }
}


// ==========================================
// 4. Session Heartbeat (Cookies)
// ==========================================
// We watch for changes in cookies for supported domains
if (api.cookies && api.cookies.onChanged) {
    api.cookies.onChanged.addListener((changeInfo) => {
        const domain = changeInfo.cookie.domain.replace(/^\./, ''); // Strip leading dot

        // Check if supported
        const isSupported = SUPPORTED_DOMAINS.some(d => domain.includes(d));
        if (!isSupported) return;

        // Debounce to batch multiple cookie changes (login sets many cookies)
        if (cookieDebounce) clearTimeout(cookieDebounce);

        cookieDebounce = setTimeout(async () => {
            if (!isConnected || !socket) return;

            // Check setting
            const res = await api.storage.local.get(['autoSendCookies']);
            if (res.autoSendCookies === false) return;

            try {
                // Fetch all cookies for this domain to rebuild the file
                const cookies = await api.cookies.getAll({ domain: domain });
                // CHANGED: Use Netscape format
                const cookieString = formatCookiesToNetscape(cookies);

                const payload = {
                    type: 'HEARTBEAT_COOKIES',
                    domain: domain,
                    cookies: cookieString
                };

                socket.send(JSON.stringify(payload));
                console.log(`❤️ Sent Session Heartbeat for ${domain}`);
            } catch (e) {
                console.error("Heartbeat error", e);
            }
        }, 2000); // 2 seconds debounce
    });
}

// Helper to send initial cookies
async function sendCurrentTabCookies() {
    try {
        const [tab] = await api.tabs.query({ active: true, currentWindow: true });
        if (tab && tab.url) {
            const url = new URL(tab.url);
            const domain = url.hostname;
            if (SUPPORTED_DOMAINS.some(d => domain.includes(d))) {
                const cookies = await api.cookies.getAll({ domain: domain });
                // CHANGED: Use Netscape format
                const cookieString = formatCookiesToNetscape(cookies);

                socket.send(JSON.stringify({
                    type: 'HEARTBEAT_COOKIES',
                    domain: domain,
                    cookies: cookieString
                }));
            }
        }
    } catch (e) { }
}

// Start
connect();

export type Language = 'zh-CN' | 'en';
export type Theme = 'system' | 'light' | 'dark';

const messages = {
    'zh-CN': {
        appTitle: 'Pageway RDP',
        language: '语言',
        theme: '外观',
        system: '跟随系统',
        light: '浅色',
        dark: '深色',
        windowsSignIn: 'Windows 登录',
        windowsAccountHint: '使用这台电脑的 Windows 账户',
        username: '用户名',
        password: '密码',
        usernamePlaceholder: 'Windows 用户名',
        passwordPlaceholder: 'Windows 密码',
        advanced: '高级',
        dynamicResolution: '窗口大小变化时调整远程分辨率',
        scaleMode: '本地缩放',
        scaleReal: '原始大小（清晰）',
        scaleFit: '适应窗口',
        scaleFull: '填满窗口',
        graphicsMode: '画面与流量',
        graphicsLossless: '32 位无损（画质优先）',
        graphicsCompressed: '16 位压缩（节省流量）',
        connect: '连接',
        connecting: '连接中…',
        connected: '已连接',
        componentInitTimeout: '远程组件初始化超时，请刷新页面后重试。',
        sessionEnded: '会话已结束',
        securityNotice: '当前为受限模式。点此重新选择信任方式。',
        pinBar: '钉住连接栏',
        unpinBar: '取消钉住',
        secureConnection: '安全连接',
        limitedMode: '受限模式：剪贴板需手动收发，全屏组合键不可用',
        ctrlAltDel: 'Ctrl+Alt+Del',
        windowsKey: 'Win 键',
        fullscreen: '全屏',
        exitFullscreen: '退出全屏',
        disconnect: '断开',
        textClipboard: '剪贴板',
        clipboardTitle: 'HTTP 文本剪贴板',
        clipboardHelp: '在此粘贴本地文本并发送到远程，或复制远程最近发送的文本。',
        clipboardPlaceholder: '在此粘贴或输入文本',
        sendToRemote: '发送到远程',
        copyRemote: '复制远程文本',
        close: '关闭',
        clipboardSent: '文本已发送到远程。',
        clipboardEmpty: '请先粘贴或输入文本。',
        clipboardCopied: '远程文本已复制。',
        clipboardCopyManual: '已选中远程文本，请按 Ctrl+C 复制。',
        clipboardNoRemote: '尚未收到远程文本。',
        clipboardRemoteReady: '收到新的远程文本，点击“复制远程文本”获取。',
        clipboardFailed: '剪贴板操作失败',
    },
    en: {
        appTitle: 'Pageway RDP',
        language: 'Language',
        theme: 'Appearance',
        system: 'System',
        light: 'Light',
        dark: 'Dark',
        windowsSignIn: 'Windows sign-in',
        windowsAccountHint: 'Use the Windows account on this PC',
        username: 'Username',
        password: 'Password',
        usernamePlaceholder: 'Windows username',
        passwordPlaceholder: 'Windows password',
        advanced: 'Advanced',
        dynamicResolution: 'Resize the remote desktop with the window',
        scaleMode: 'Local scaling',
        scaleReal: 'Actual size (sharpest)',
        scaleFit: 'Fit to window',
        scaleFull: 'Fill window',
        graphicsMode: 'Image quality and bandwidth',
        graphicsLossless: '32-bit lossless (quality)',
        graphicsCompressed: '16-bit compressed (bandwidth)',
        connect: 'Connect',
        connecting: 'Connecting…',
        connected: 'Connected',
        componentInitTimeout: 'The remote component timed out during initialization. Refresh the page and try again.',
        sessionEnded: 'Session ended',
        securityNotice: 'Limited mode. Select here to choose a trust method again.',
        pinBar: 'Pin connection bar',
        unpinBar: 'Unpin connection bar',
        secureConnection: 'Secure connection',
        limitedMode: 'Limited mode: clipboard transfer is manual and fullscreen shortcuts are unavailable',
        ctrlAltDel: 'Ctrl+Alt+Del',
        windowsKey: 'Windows key',
        fullscreen: 'Fullscreen',
        exitFullscreen: 'Exit fullscreen',
        disconnect: 'Disconnect',
        textClipboard: 'Clipboard',
        clipboardTitle: 'HTTP text clipboard',
        clipboardHelp: 'Paste local text to send it remotely, or copy the latest text received from the remote PC.',
        clipboardPlaceholder: 'Paste or enter text here',
        sendToRemote: 'Send to remote',
        copyRemote: 'Copy remote text',
        close: 'Close',
        clipboardSent: 'Text sent to the remote PC.',
        clipboardEmpty: 'Paste or enter some text first.',
        clipboardCopied: 'Remote text copied.',
        clipboardCopyManual: 'Remote text selected. Press Ctrl+C to copy it.',
        clipboardNoRemote: 'No remote text has been received yet.',
        clipboardRemoteReady: 'New remote text received. Select “Copy remote text” to retrieve it.',
        clipboardFailed: 'Clipboard operation failed',
    },
};

export type MessageKey = keyof (typeof messages)['zh-CN'];

let language: Language = localStorage.getItem('pageway.language') === 'en' ? 'en' : 'zh-CN';
let theme: Theme = ['system', 'light', 'dark'].includes(localStorage.getItem('pageway.theme') || '')
    ? (localStorage.getItem('pageway.theme') as Theme)
    : 'system';

const systemTheme = window.matchMedia('(prefers-color-scheme: dark)');

export function t(key: MessageKey): string {
    return messages[language][key];
}

function applyTheme() {
    const resolved = theme === 'system' ? (systemTheme.matches ? 'dark' : 'light') : theme;
    document.documentElement.dataset.theme = resolved;
}

function applyTranslations() {
    document.documentElement.lang = language;
    document.querySelectorAll<HTMLElement>('[data-i18n]').forEach((element) => {
        element.textContent = t(element.dataset.i18n as MessageKey);
    });
    document.querySelectorAll<HTMLInputElement>('[data-i18n-placeholder]').forEach((element) => {
        element.placeholder = t(element.dataset.i18nPlaceholder as MessageKey);
    });
    document.querySelectorAll<HTMLElement>('[data-i18n-aria]').forEach((element) => {
        element.setAttribute('aria-label', t(element.dataset.i18nAria as MessageKey));
    });
    document.querySelectorAll<HTMLElement>('[data-i18n-title]').forEach((element) => {
        element.title = t(element.dataset.i18nTitle as MessageKey);
    });
    document.dispatchEvent(new Event('pageway:translated'));
}

export function initAppearance() {
    const languageSelect = document.getElementById('language-select') as HTMLSelectElement | null;
    const themeSelect = document.getElementById('theme-select') as HTMLSelectElement | null;

    if (languageSelect) {
        languageSelect.value = language;
        languageSelect.addEventListener('change', () => {
            language = languageSelect.value as Language;
            localStorage.setItem('pageway.language', language);
            applyTranslations();
        });
    }
    if (themeSelect) {
        themeSelect.value = theme;
        themeSelect.addEventListener('change', () => {
            theme = themeSelect.value as Theme;
            localStorage.setItem('pageway.theme', theme);
            applyTheme();
        });
    }

    systemTheme.addEventListener('change', () => {
        if (theme === 'system') {
            applyTheme();
        }
    });
    applyTheme();
    applyTranslations();
}

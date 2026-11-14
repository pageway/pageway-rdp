import '@ird/component/iron-remote-desktop.svelte';
import {
    Backend,
    init,
    displayControl,
    legacyGraphics,
    desktopScaleFactor,
    deviceScaleFactor,
} from '@ird/rdp';
import { initAppearance, t } from './settings';

initAppearance();

const form = document.getElementById('login-form') as HTMLFormElement;
const loginView = document.getElementById('login')!;
const screenView = document.getElementById('screen')!;
const usernameInput = document.getElementById('username') as HTMLInputElement;
const passwordInput = document.getElementById('password') as HTMLInputElement;
const dynamicResolutionInput = document.getElementById('dynamic-resolution') as HTMLInputElement;
const scaleModeInput = document.getElementById('scale-mode') as HTMLSelectElement;
const graphicsModeInput = document.getElementById('graphics-mode') as HTMLSelectElement;
const connectBtn = document.getElementById('connect-btn') as HTMLButtonElement;
const statusEl = document.getElementById('status') as HTMLParagraphElement;
const securityNotice = document.getElementById('security-notice')!;
const sessionTools = document.getElementById('session-tools')!;
const pinToggle = document.getElementById('pin-toggle') as HTMLButtonElement;
const connectionName = document.getElementById('connection-name')!;
const secureIcon = document.getElementById('secure-icon')!;
const limitedIcon = document.getElementById('limited-icon')!;
const fullscreenToggle = document.getElementById('fullscreen-toggle') as HTMLButtonElement;
const fullscreenLabel = document.getElementById('fullscreen-label')!;
const fullscreenEnterIcon = document.getElementById('fullscreen-enter-icon')!;
const fullscreenExitIcon = document.getElementById('fullscreen-exit-icon')!;
const clipboardOpen = document.getElementById('clipboard-open') as HTMLButtonElement;
const clipboardDialog = document.getElementById('clipboard-dialog') as HTMLDialogElement;
const clipboardText = document.getElementById('clipboard-text') as HTMLTextAreaElement;
const clipboardStatus = document.getElementById('clipboard-status') as HTMLParagraphElement;
const clipboardSend = document.getElementById('clipboard-send') as HTMLButtonElement;
const clipboardReceive = document.getElementById('clipboard-receive') as HTMLButtonElement;
const clipboardClose = document.getElementById('clipboard-close') as HTMLButtonElement;

let userInteraction: any = null;
let wasmReady: Promise<void> | null = null;
let resizeTimer: number | undefined;
let toolbarTimer: number | undefined;
let sessionActive = false;
let remoteClipboardReady = false;
let toolbarPinned = localStorage.getItem('pageway.pinBar') !== 'false';
let toolbarHovered = false;

usernameInput.value = localStorage.getItem('pageway.username') || '';
dynamicResolutionInput.checked = localStorage.getItem('pageway.dynamicResolution') !== 'false';
const storedScale = localStorage.getItem('pageway.scale');
scaleModeInput.value = storedScale === 'fit' || storedScale === 'full' ? storedScale : 'real';
graphicsModeInput.value = localStorage.getItem('pageway.graphics') === 'compressed' ? 'compressed' : 'lossless';
securityNotice.hidden = window.isSecureContext;
document.getElementById('connection-host')!.textContent = window.location.hostname;

function updatePinButton() {
    const label = t(toolbarPinned ? 'unpinBar' : 'pinBar');
    pinToggle.setAttribute('aria-pressed', `${toolbarPinned}`);
    pinToggle.setAttribute('aria-label', label);
    pinToggle.title = label;
}

function updateFullscreenButton() {
    const label = t(document.fullscreenElement ? 'exitFullscreen' : 'fullscreen');
    fullscreenLabel.textContent = label;
    fullscreenToggle.setAttribute('aria-label', label);
    fullscreenToggle.title = label;
    fullscreenEnterIcon.toggleAttribute('hidden', Boolean(document.fullscreenElement));
    fullscreenExitIcon.toggleAttribute('hidden', !document.fullscreenElement);
}

function updateConnectionSecurity() {
    secureIcon.toggleAttribute('hidden', !window.isSecureContext);
    limitedIcon.toggleAttribute('hidden', window.isSecureContext);
    connectionName.title = t(window.isSecureContext ? 'secureConnection' : 'limitedMode');
}

updatePinButton();
updateFullscreenButton();
updateConnectionSecurity();
document.addEventListener('pageway:translated', () => {
    updatePinButton();
    updateFullscreenButton();
    updateConnectionSecurity();
});

function ensureWasm(): Promise<void> {
    if (!wasmReady) {
        wasmReady = init('DEBUG');
    }
    return wasmReady;
}

function mountComponent(): HTMLElement {
    const el = document.createElement('iron-remote-desktop');
    el.setAttribute('scale', scaleModeInput.value);
    el.setAttribute('flexcenter', 'true');
    (el as any).module = Backend;
    el.addEventListener('ready', (e: Event) => {
        userInteraction = (e as CustomEvent).detail.irgUserInteraction;
        userInteraction.onClipboardRemoteUpdateCallback(() => {
            remoteClipboardReady = true;
            clipboardOpen.classList.add('has-update');
            if (clipboardDialog.open) {
                setClipboardStatus(t('clipboardRemoteReady'));
            }
        });
    });
    screenView.appendChild(el);
    return el;
}

function setStatus(message: string) {
    statusEl.hidden = false;
    statusEl.textContent = message;
}

function setClipboardStatus(message: string) {
    clipboardStatus.textContent = message;
}

function gatewayAddress(): string {
    const scheme = window.location.protocol === 'https:' ? 'wss' : 'ws';
    return `${scheme}://${window.location.host}/rdp`;
}

function displayScale() {
    const ratio = window.devicePixelRatio || 1;
    return {
        desktop: Math.min(500, Math.max(100, Math.round(ratio * 100))),
        device: ratio >= 1.8 ? 180 : ratio >= 1.4 ? 140 : 100,
    };
}

function desktopSize() {
    const ratio = window.devicePixelRatio || 1;
    const width = Math.floor(window.innerWidth * ratio);
    return {
        width: Math.min(8192, Math.max(200, width - (width % 2))),
        height: Math.min(8192, Math.max(200, Math.floor(window.innerHeight * ratio))),
    };
}

const isIronError = (error: unknown): error is { backtrace(): string } =>
    typeof error === 'object' && error !== null && typeof (error as any).backtrace === 'function';

function resizeSession() {
    if (!sessionActive || !dynamicResolutionInput.checked) {
        return;
    }
    window.clearTimeout(resizeTimer);
    resizeTimer = window.setTimeout(() => {
        const size = desktopSize();
        userInteraction?.resize(size.width, size.height, displayScale().desktop);
    }, 200);
}

window.addEventListener('resize', resizeSession);

function scheduleToolbarHide() {
    window.clearTimeout(toolbarTimer);
    if (!sessionActive || toolbarPinned || toolbarHovered || clipboardDialog.open) {
        return;
    }
    toolbarTimer = window.setTimeout(() => {
        if (!toolbarPinned && !toolbarHovered && !clipboardDialog.open) {
            sessionTools.classList.add('auto-hidden');
        }
    }, 3000);
}

function showToolbar() {
    sessionTools.classList.remove('auto-hidden');
    scheduleToolbarHide();
}

pinToggle.addEventListener('click', () => {
    toolbarPinned = !toolbarPinned;
    localStorage.setItem('pageway.pinBar', `${toolbarPinned}`);
    updatePinButton();
    showToolbar();
});

sessionTools.addEventListener('mouseenter', () => {
    toolbarHovered = true;
    window.clearTimeout(toolbarTimer);
});
sessionTools.addEventListener('mouseleave', () => {
    toolbarHovered = false;
    scheduleToolbarHide();
});

window.addEventListener('mousemove', (event) => {
    if (sessionActive && event.clientY <= 6) {
        showToolbar();
    }
});

async function updateKeyboardLock() {
    const keyboard = (navigator as any).keyboard;
    if (!keyboard || !window.isSecureContext) {
        return;
    }
    try {
        if (document.fullscreenElement) {
            await keyboard.lock(['MetaLeft', 'MetaRight', 'AltLeft', 'AltRight', 'Tab', 'Escape']);
        } else {
            keyboard.unlock();
        }
    } catch (error) {
        console.warn('Keyboard lock unavailable', error);
    }
}

document.addEventListener('fullscreenchange', () => {
    updateFullscreenButton();
    showToolbar();
    updateKeyboardLock();
    resizeSession();
});

fullscreenToggle.addEventListener('click', async () => {
    if (document.fullscreenElement) {
        await document.exitFullscreen();
    } else {
        await document.documentElement.requestFullscreen();
    }
});

document.getElementById('ctrl-alt-del')!.addEventListener('click', () => userInteraction?.ctrlAltDel());
document.getElementById('windows-key')!.addEventListener('click', () => userInteraction?.metaKey());
document.getElementById('disconnect')!.addEventListener('click', () => userInteraction?.shutdown());

clipboardOpen.addEventListener('click', () => {
    showToolbar();
    setClipboardStatus(remoteClipboardReady ? t('clipboardRemoteReady') : '');
    clipboardDialog.showModal();
    clipboardText.focus();
});

clipboardClose.addEventListener('click', () => clipboardDialog.close());
clipboardDialog.addEventListener('close', scheduleToolbarHide);
clipboardDialog.addEventListener('keydown', (event) => event.stopPropagation());
clipboardDialog.addEventListener('keyup', (event) => event.stopPropagation());

clipboardSend.addEventListener('click', async () => {
    if (!clipboardText.value) {
        setClipboardStatus(t('clipboardEmpty'));
        return;
    }
    try {
        await userInteraction.sendClipboardText(clipboardText.value);
        setClipboardStatus(t('clipboardSent'));
    } catch (error) {
        setClipboardStatus(`${t('clipboardFailed')}: ${error}`);
    }
});

clipboardReceive.addEventListener('click', () => {
    const text = userInteraction.remoteClipboardText();
    if (!text) {
        setClipboardStatus(t('clipboardNoRemote'));
        return;
    }
    remoteClipboardReady = false;
    clipboardOpen.classList.remove('has-update');
    clipboardText.value = text;
    clipboardText.focus();
    clipboardText.select();
    setClipboardStatus(t(document.execCommand('copy') ? 'clipboardCopied' : 'clipboardCopyManual'));
});

function finishSession() {
    sessionActive = false;
    window.clearTimeout(toolbarTimer);
    sessionTools.classList.remove('auto-hidden');
    sessionTools.hidden = true;
    remoteClipboardReady = false;
    clipboardOpen.classList.remove('has-update');
    clipboardDialog.close();
    if (document.fullscreenElement) {
        document.exitFullscreen().catch(() => {});
    }
    screenView.replaceChildren();
    screenView.hidden = true;
    userInteraction = null;
    loginView.hidden = false;
}

form.addEventListener('submit', async (event) => {
    event.preventDefault();

    connectBtn.disabled = true;
    setStatus(t('connecting'));
    localStorage.setItem('pageway.username', usernameInput.value);
    localStorage.setItem('pageway.dynamicResolution', `${dynamicResolutionInput.checked}`);
    localStorage.setItem('pageway.scale', scaleModeInput.value);
    localStorage.setItem('pageway.graphics', graphicsModeInput.value);

    try {
        await ensureWasm();

        if (!userInteraction) {
            mountComponent();
            await new Promise<void>((resolve, reject) => {
                const timeout = window.setTimeout(() => {
                    window.clearInterval(timer);
                    reject(new Error(t('componentInitTimeout')));
                }, 15000);
                const timer = window.setInterval(() => {
                    if (userInteraction) {
                        window.clearTimeout(timeout);
                        window.clearInterval(timer);
                        resolve();
                    }
                }, 50);
            });
        }

        const scale = displayScale();
        const config = userInteraction
            .configBuilder()
            .withUsername(usernameInput.value)
            .withPassword(passwordInput.value)
            .withDestination('pageway')
            .withProxyAddress(gatewayAddress())
            .withServerDomain('')
            // RDCleanPath requires a non-empty proxy_auth value, but Pageway does not authenticate it.
            .withAuthToken('pageway')
            .withDesktopSize(desktopSize())
            .withExtension(displayControl(true))
            .withExtension(legacyGraphics(graphicsModeInput.value === 'lossless'))
            .withExtension(desktopScaleFactor(scale.desktop))
            .withExtension(deviceScaleFactor(scale.device))
            .build();

        const sessionInfo = await userInteraction.connect(config);

        loginView.hidden = true;
        screenView.hidden = false;
        sessionTools.hidden = false;
        clipboardOpen.hidden = window.isSecureContext && userInteraction.supportsAutomaticClipboard();
        sessionActive = true;
        setStatus(t('connected'));
        userInteraction.setVisibility(true);
        showToolbar();

        const termination = await sessionInfo.run();
        finishSession();
        setStatus(`${t('sessionEnded')}: ${termination.reason()}`);
    } catch (error) {
        finishSession();
        if (isIronError(error)) {
            setStatus(error.backtrace());
        } else {
            setStatus(`${error}`);
        }
    } finally {
        connectBtn.disabled = false;
    }
});

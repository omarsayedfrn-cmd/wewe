'use client';

import { useEffect } from 'react';

/**
 * Initialises native-only features when the dashboard runs inside the
 * Capacitor Android shell (status bar, splash, hardware back button) and
 * registers the device for background push notifications. On the web this
 * component is a no-op.
 */
export function NativeInit() {
  useEffect(() => {
    let disposers: Array<() => void> = [];
    let cancelled = false;

    (async () => {
      try {
        const { Capacitor } = await import('@capacitor/core');
        if (!Capacitor.isNativePlatform()) return;

        // ── Status bar ──────────────────────────────────────────────
        try {
          const { StatusBar, Style } = await import('@capacitor/status-bar');
          await StatusBar.setStyle({ style: Style.Dark });
          await StatusBar.setBackgroundColor({ color: '#121212' });
        } catch {
          /* plugin unavailable */
        }

        // ── Splash screen ───────────────────────────────────────────
        try {
          const { SplashScreen } = await import('@capacitor/splash-screen');
          await SplashScreen.hide();
        } catch {
          /* plugin unavailable */
        }

        // ── Hardware back button ────────────────────────────────────
        try {
          const { App } = await import('@capacitor/app');
          const handle = await App.addListener('backButton', ({ canGoBack }) => {
            if (canGoBack || window.location.pathname !== '/') {
              window.history.back();
            } else {
              App.exitApp();
            }
          });
          disposers.push(() => handle.remove());
        } catch {
          /* plugin unavailable */
        }

        // ── Push notifications ──────────────────────────────────────
        try {
          const { PushNotifications } = await import(
            '@capacitor/push-notifications'
          );

          await PushNotifications.createChannel({
            id: 'admin-alerts',
            name: 'تنبيهات الإدارة',
            description: 'حسابات جديدة، رسائل الدعم، وتغييرات النظام',
            importance: 5,
            visibility: 1,
            vibration: true,
            lights: true,
            lightColor: '#800020',
          });

          let perm = await PushNotifications.checkPermissions();
          if (
            perm.receive === 'prompt' ||
            perm.receive === 'prompt-with-rationale'
          ) {
            perm = await PushNotifications.requestPermissions();
          }
          if (perm.receive !== 'granted') return;

          const regHandle = await PushNotifications.addListener(
            'registration',
            (token) => {
              fetch('/api/admin/devices', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                  token: token.value,
                  platform: Capacitor.getPlatform(),
                }),
              }).catch(() => {});
            }
          );
          const errHandle = await PushNotifications.addListener(
            'registrationError',
            () => {}
          );
          const tapHandle = await PushNotifications.addListener(
            'pushNotificationActionPerformed',
            (action) => {
              const href = action.notification.data?.href;
              if (href) window.location.assign(href);
            }
          );

          await PushNotifications.register();

          disposers.push(() => {
            regHandle.remove();
            errHandle.remove();
            tapHandle.remove();
          });
        } catch {
          /* push unavailable */
        }
      } catch {
        /* not running in Capacitor */
      }
    })();

    return () => {
      cancelled = true;
      if (cancelled) disposers.forEach((d) => d());
      disposers = [];
    };
  }, []);

  return null;
}

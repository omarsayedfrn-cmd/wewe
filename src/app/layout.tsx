import type { Metadata, Viewport } from 'next';
import localFont from 'next/font/local';
import './globals.css';
import { AppShell } from '@/components/app-shell';

const sans = localFont({
  src: [
    { path: './fonts/Tajawal-Regular.ttf', weight: '400', style: 'normal' },
    { path: './fonts/Tajawal-Medium.ttf', weight: '500', style: 'normal' },
    { path: './fonts/Tajawal-Bold.ttf', weight: '700', style: 'normal' },
    { path: './fonts/Tajawal-ExtraBold.ttf', weight: '800', style: 'normal' },
  ],
  variable: '--font-sans',
  display: 'swap',
  fallback: ['system-ui', 'Segoe UI', 'sans-serif'],
});

export const metadata: Metadata = {
  title: 'Solver Admin',
  description: 'لوحة إدارة منصة Solver',
  applicationName: 'Solver Admin',
  appleWebApp: {
    capable: true,
    statusBarStyle: 'black-translucent',
    title: 'Solver Admin',
  },
  formatDetection: { telephone: false, email: false, address: false },
};

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1,
  viewportFit: 'cover',
  themeColor: '#121212',
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ar" dir="rtl" className={`dark ${sans.variable}`}>
      <body className="bg-[#121212] text-[#E0E0E0] antialiased">
        <AppShell>{children}</AppShell>
      </body>
    </html>
  );
}
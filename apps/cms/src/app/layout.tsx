import type { Metadata } from 'next';
import { Geist, Geist_Mono } from 'next/font/google';
import { ThemedToaster } from '@/components/theme';
import './globals.css';

const geistSans = Geist({ variable: '--font-geist-sans', subsets: ['latin'] });
const geistMono = Geist_Mono({ variable: '--font-geist-mono', subsets: ['latin'] });

export const metadata: Metadata = {
  title: { default: 'CocEnglish — Soạn bài cho app', template: '%s · CocEnglish' },
  description: 'Soạn nội dung và vận hành cho ứng dụng học',
};

// Runs before the first paint: reading the stored theme on the server would
// make the whole app dynamic and still be wrong for a cached HTML response.
const themeBootstrap = `(function(){try{if(localStorage.getItem('cms-theme')==='dark'){var r=document.documentElement;r.classList.add('dark');r.style.colorScheme='dark';}}catch(e){}})();`;

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="vi" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeBootstrap }} />
      </head>
      <body className={`${geistSans.variable} ${geistMono.variable} font-sans antialiased`}>
        {children}
        <ThemedToaster />
      </body>
    </html>
  );
}

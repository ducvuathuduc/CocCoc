'use client';

import { useSyncExternalStore } from 'react';
import { Toaster } from 'sonner';

type Theme = 'light' | 'dark';

const KEY = 'cms-theme';
const listeners = new Set<() => void>();

function read(): Theme {
  return document.documentElement.classList.contains('dark') ? 'dark' : 'light';
}

function subscribe(onChange: () => void) {
  listeners.add(onChange);
  // A second tab that flips the theme writes the same storage key.
  window.addEventListener('storage', onChange);
  return () => {
    listeners.delete(onChange);
    window.removeEventListener('storage', onChange);
  };
}

function write(theme: Theme) {
  const root = document.documentElement;
  // The class swap alone repaints every surface at once; one beat of
  // `.theme-anim` turns that into a crossfade instead of a hard cut.
  root.classList.add('theme-anim');
  root.classList.toggle('dark', theme === 'dark');
  root.style.colorScheme = theme;
  window.setTimeout(() => root.classList.remove('theme-anim'), 360);
  try {
    localStorage.setItem(KEY, theme);
  } catch {
    // Private mode / disabled storage: the theme still applies for this page.
  }
  for (const notify of listeners) notify();
}

function useTheme(): Theme {
  return useSyncExternalStore(subscribe, read, () => 'light');
}

export function ThemeToggle({ className }: { className?: string }) {
  const theme = useTheme();

  // The label names the current state, so the server render cannot disagree with the pre-paint
  // script in the document head that already flipped <html> before React hydrated.
  return (
    <button
      type="button"
      onClick={() => write(theme === 'dark' ? 'light' : 'dark')}
      aria-label={theme === 'dark' ? 'Chuyển sang nền sáng' : 'Chuyển sang nền tối'}
      className={
        className ??
        'flex h-8 w-full items-center justify-center rounded-lg border border-line bg-elevated text-xs text-fg-3 hover:border-primary/40 hover:bg-primary-soft hover:text-primary-text active:scale-[0.98]'
      }
    >
      {theme === 'dark' ? 'Nền tối' : 'Nền sáng'}
    </button>
  );
}

export function ThemedToaster() {
  const theme = useTheme();
  // Bottom-right: a top-right toast sat on top of the sticky "Lưu" button and ate the next click.
  return <Toaster position="bottom-right" richColors closeButton theme={theme} />;
}

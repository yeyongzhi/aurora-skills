import { shallowRef, watch } from 'vue'

export type ThemeMode = 'light' | 'dark'

const storageKey = 'aurora-skills:theme'

function initialTheme(): ThemeMode {
  if (typeof window === 'undefined') return 'light'
  const saved = window.localStorage.getItem(storageKey)
  if (saved === 'light' || saved === 'dark') return saved
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
}

export function useTheme() {
  const theme = shallowRef<ThemeMode>(initialTheme())

  watch(theme, (value) => {
    if (typeof document !== 'undefined') document.documentElement.classList.toggle('dark', value === 'dark')
    if (typeof window !== 'undefined') window.localStorage.setItem(storageKey, value)
  }, { immediate: true })

  function toggleTheme() {
    theme.value = theme.value === 'dark' ? 'light' : 'dark'
  }

  return { theme, toggleTheme }
}

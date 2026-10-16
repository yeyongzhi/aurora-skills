import { shallowRef, watch } from 'vue'

const storageKey = 'aurora-skills:favorites'

function loadFavorites(): string[] {
  if (typeof window === 'undefined') return []
  try {
    const stored = JSON.parse(window.localStorage.getItem(storageKey) ?? '[]') as unknown
    return Array.isArray(stored) ? stored.filter((item): item is string => typeof item === 'string') : []
  } catch {
    return []
  }
}

export function useFavorites() {
  const favorites = shallowRef(loadFavorites())

  watch(favorites, (value) => {
    if (typeof window !== 'undefined') window.localStorage.setItem(storageKey, JSON.stringify(value))
  }, { deep: false })

  function toggleFavorite(path: string) {
    favorites.value = favorites.value.includes(path)
      ? favorites.value.filter((favorite) => favorite !== path)
      : [...favorites.value, path]
  }

  return { favorites, toggleFavorite }
}

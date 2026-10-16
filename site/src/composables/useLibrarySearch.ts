import { computed, shallowRef, type Ref } from 'vue'
import type { SkillCategory, VisibleCategory } from '@/types/skills'

export function useLibrarySearch(categories: SkillCategory[], favorites: Ref<string[]>) {
  const query = shallowRef('')
  const favoritesOnly = shallowRef(false)

  const visibleCategories = computed<VisibleCategory[]>(() => {
    const term = query.value.trim().toLocaleLowerCase()
    const favoritePaths = new Set(favorites.value)

    return categories.flatMap((category) => {
      const skills = category.skills.flatMap((skill) => {
        const skillMatches = !term || [
          category.name, category.title, skill.name, skill.title, skill.description, ...skill.tags,
        ].join(' ').toLocaleLowerCase().includes(term)
        const files = skill.files.filter((file) => {
          if (favoritesOnly.value && !favoritePaths.has(file.path)) return false
          if (skillMatches) return true
          return !term || [file.name, file.path, file.content].join(' ').toLocaleLowerCase().includes(term)
        })
        return files.length ? [{ skill, files }] : []
      })
      return skills.length ? [{ category, skills }] : []
    })
  })

  return { query, favoritesOnly, visibleCategories }
}

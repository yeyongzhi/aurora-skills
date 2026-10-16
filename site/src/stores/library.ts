import { computed, shallowRef } from 'vue'
import { defineStore } from 'pinia'
import { skillsPayload } from '@/data/skills'
import type { Skill } from '@/types/skills'

const allFiles = skillsPayload.categories.flatMap((category) =>
  category.skills.flatMap((skill) => skill.files.map((file) => ({ category, skill, file }))),
)
const fileByPath = new Map(allFiles.map((entry) => [entry.file.path, entry]))

function pathFromHash(): string | null {
  if (typeof window === 'undefined' || !window.location.hash) return null
  try {
    const candidate = decodeURIComponent(window.location.hash.slice(1))
    return fileByPath.has(candidate) ? candidate : null
  } catch {
    return null
  }
}

function defaultPath(): string | null {
  for (const category of skillsPayload.categories) {
    for (const skill of category.skills) {
      const file = skill.files.find((item) => item.name === 'SKILL.md') ?? skill.files[0]
      if (file) return file.path
    }
  }
  return null
}

export const useLibraryStore = defineStore('library', () => {
  const selectedPath = shallowRef(pathFromHash() ?? defaultPath())
  const mode = shallowRef<'render' | 'raw'>('render')
  const currentEntry = computed(() => selectedPath.value ? fileByPath.get(selectedPath.value) ?? null : null)
  const currentFile = computed(() => currentEntry.value?.file ?? null)
  const currentSkill = computed<Skill | null>(() => currentEntry.value?.skill ?? null)
  const currentIndex = computed(() => allFiles.findIndex((entry) => entry.file.path === selectedPath.value))
  const previousFile = computed(() => currentIndex.value > 0 ? allFiles[currentIndex.value - 1]?.file ?? null : null)
  const nextFile = computed(() => currentIndex.value >= 0 ? allFiles[currentIndex.value + 1]?.file ?? null : null)

  function selectFile(path: string, updateHash = true) {
    if (!fileByPath.has(path)) return
    selectedPath.value = path
    const entry = fileByPath.get(path)
    if (entry?.file.binary || !entry?.file.name.endsWith('.md')) mode.value = 'raw'
    else mode.value = 'render'
    if (updateHash && typeof window !== 'undefined') {
      const hash = `#${encodeURIComponent(path)}`
      window.history.replaceState(null, '', `${window.location.pathname}${window.location.search}${hash}`)
    }
  }

  function setMode(value: 'render' | 'raw') {
    if (value === 'render' && (!currentFile.value?.name.endsWith('.md') || currentFile.value.binary)) return
    mode.value = value
  }

  function selectAdjacent(direction: -1 | 1) {
    const target = direction < 0 ? previousFile.value : nextFile.value
    if (target) selectFile(target.path)
  }

  return {
    categories: skillsPayload.categories,
    stats: skillsPayload.stats,
    allFiles: allFiles.map((entry) => entry.file),
    selectedPath,
    mode,
    currentFile,
    currentSkill,
    previousFile,
    nextFile,
    selectFile,
    setMode,
    selectAdjacent,
  }
})

<script setup lang="ts">
import { computed, onMounted, onUnmounted, shallowRef, watch } from 'vue'
import { toast } from 'vue-sonner'
import CategoryTree from '@/components/library/CategoryTree.vue'
import LibraryHeader from '@/components/library/LibraryHeader.vue'
import ReaderPanel from '@/components/library/ReaderPanel.vue'
import { Toaster } from '@/components/ui/sonner'
import { TooltipProvider } from '@/components/ui/tooltip'
import { useFavorites } from '@/composables/useFavorites'
import { useLibrarySearch } from '@/composables/useLibrarySearch'
import { useTheme } from '@/composables/useTheme'
import { useLibraryStore } from '@/stores/library'

const library = useLibraryStore()
const { favorites, toggleFavorite } = useFavorites()
const { query, favoritesOnly, visibleCategories } = useLibrarySearch(library.categories, favorites)
const { theme, toggleTheme } = useTheme()
const currentIsFavorite = computed(() => Boolean(library.selectedPath && favorites.value.includes(library.selectedPath)))
const position = computed(() => {
  const index = library.allFiles.findIndex((file) => file.path === library.selectedPath)
  return index < 0 ? 0 : index + 1
})

function onHashChange() {
  if (!window.location.hash) return
  try {
    const path = decodeURIComponent(window.location.hash.slice(1))
    library.selectFile(path, false)
  } catch {
    // Ignore malformed hash fragments.
  }
}

function onKeyDown(event: KeyboardEvent) {
  const target = event.target
  const isTyping = target instanceof HTMLElement && (
    target.matches('input, textarea, [contenteditable="true"]')
  )

  if (event.key === '/' && !isTyping && !event.metaKey && !event.ctrlKey && !event.altKey) {
    event.preventDefault()
    document.getElementById('library-search')?.focus()
  } else if (event.key === 'Escape' && document.activeElement?.id === 'library-search') {
    query.value = ''
    document.getElementById('library-search')?.blur()
  } else if (event.altKey && event.key === 'ArrowLeft') {
    event.preventDefault()
    library.selectAdjacent(-1)
  } else if (event.altKey && event.key === 'ArrowRight') {
    event.preventDefault()
    library.selectAdjacent(1)
  }
}

function changeTheme() {
  toggleTheme()
  toast.info(`已切换到${theme.value === 'dark' ? '深色' : '浅色'}模式`)
}

function toggleFavoritesFilter() {
  favoritesOnly.value = !favoritesOnly.value
  toast.info(favoritesOnly.value ? `已筛选收藏 · ${favorites.value.length} 项` : '已显示全部文件')
}

function toggleCurrentFavorite() {
  if (!library.selectedPath) return
  const wasFavorite = currentIsFavorite.value
  toggleFavorite(library.selectedPath)
  toast[wasFavorite ? 'info' : 'success'](wasFavorite ? '已取消收藏' : '已加入收藏')
}

let copyTimer: ReturnType<typeof setTimeout> | undefined
let nameCopyTimer: ReturnType<typeof setTimeout> | undefined
const isCopied = shallowRef(false)
const isNameCopied = shallowRef(false)

function fallbackCopy(text: string): boolean {
  const textarea = document.createElement('textarea')
  textarea.value = text
  textarea.setAttribute('readonly', '')
  textarea.style.position = 'fixed'
  textarea.style.opacity = '0'
  textarea.style.pointerEvents = 'none'
  document.body.append(textarea)
  textarea.select()
  try {
    return document.execCommand('copy')
  } catch {
    return false
  } finally {
    textarea.remove()
  }
}

async function copyText(content: string): Promise<boolean> {
  try {
    if (navigator.clipboard?.writeText) {
      try {
        await navigator.clipboard.writeText(content)
      } catch {
        if (!fallbackCopy(content)) throw new Error('clipboard unavailable')
      }
    } else if (!fallbackCopy(content)) {
      throw new Error('clipboard unavailable')
    }
    return true
  } catch {
    toast.error('复制失败', { description: '浏览器没有授予剪贴板访问权限。' })
    return false
  }
}

async function copyCurrentFile() {
  if (!library.currentFile || !await copyText(library.currentFile.content)) return
  isCopied.value = true
  if (copyTimer) clearTimeout(copyTimer)
  copyTimer = setTimeout(() => { isCopied.value = false }, 1500)
  toast.success('复制成功', { description: '文件内容已复制到剪贴板。' })
}

async function copyCurrentSkillName() {
  const name = library.currentSkill?.dir.split('/').filter(Boolean).pop()?.toLowerCase()
  if (!name || !await copyText(name)) return
  isNameCopied.value = true
  if (nameCopyTimer) clearTimeout(nameCopyTimer)
  nameCopyTimer = setTimeout(() => { isNameCopied.value = false }, 1500)
  toast.success('名称已复制', { description: name })
}

onMounted(() => {
  window.addEventListener('hashchange', onHashChange)
  document.addEventListener('keydown', onKeyDown)
})

onUnmounted(() => {
  window.removeEventListener('hashchange', onHashChange)
  document.removeEventListener('keydown', onKeyDown)
  if (copyTimer) clearTimeout(copyTimer)
  if (nameCopyTimer) clearTimeout(nameCopyTimer)
})

watch(() => library.currentFile?.path, (path) => {
  isCopied.value = false
  isNameCopied.value = false
  if (path) document.title = `${library.currentSkill?.name ?? 'Skill'} · aurora-skills`
}, { immediate: true })
</script>

<template>
  <TooltipProvider>
  <div class="library-shell">
    <LibraryHeader v-model:query="query" :stats="library.stats" :theme="theme" :current-skill="library.currentSkill" @toggle-theme="changeTheme" />
    <div class="workspace">
      <CategoryTree
        :categories="visibleCategories"
        :selected-path="library.selectedPath"
        :favorites="favorites"
        :favorites-only="favoritesOnly"
        :filtering="Boolean(query.trim() || favoritesOnly)"
        @select-file="library.selectFile"
        @toggle-favorites="toggleFavoritesFilter"
      />
      <main class="workspace-main">
        <ReaderPanel
          :file="library.currentFile"
          :skill="library.currentSkill"
          :mode="library.mode"
          :is-favorite="currentIsFavorite"
          :copied="isCopied"
          :name-copied="isNameCopied"
          :previous-file="library.previousFile"
          :next-file="library.nextFile"
          :position="position"
          :total="library.allFiles.length"
          @change-mode="library.setMode"
          @toggle-favorite="toggleCurrentFavorite"
          @copy="copyCurrentFile"
          @copy-name="copyCurrentSkillName"
          @navigate="library.selectFile"
        />
      </main>
    </div>
    <Toaster :theme="theme" position="top-center" rich-colors />
  </div>
  </TooltipProvider>
</template>

<script setup lang="ts">
import { computed, shallowRef, watch } from 'vue'
import { BookOpen, ChevronDown, ChevronRight, ChevronUp, FileCode2, FileText, Folder, Star } from '@lucide/vue'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip'
import type { VisibleCategory } from '@/types/skills'

const props = defineProps<{
  categories: VisibleCategory[]
  selectedPath: string | null
  favorites: string[]
  favoritesOnly: boolean
  filtering: boolean
}>()

const emit = defineEmits<{
  selectFile: [path: string]
  toggleFavorites: []
}>()

const expandedCategories = shallowRef(new Set<string>())
const expandedSkills = shallowRef(new Set<string>())
const allExpanded = computed(() => props.categories.length > 0 && props.categories.every((item) =>
  expandedCategories.value.has(item.category.name)
  && item.skills.every(({ skill }) => expandedSkills.value.has(skill.dir)),
))

watch(() => props.selectedPath, (path) => {
  if (!path) return
  const match = props.categories.flatMap((category) => category.skills.map((item) => ({ category, ...item })))
    .find((item) => item.files.some((file) => file.path === path))
  if (!match) return
  expandedCategories.value = new Set(expandedCategories.value).add(match.category.category.name)
  expandedSkills.value = new Set(expandedSkills.value).add(match.skill.dir)
}, { immediate: true })

watch(() => [props.categories, props.filtering] as const, ([categories, filtering]) => {
  if (!filtering) return
  expandedCategories.value = new Set([
    ...expandedCategories.value,
    ...categories.map(({ category }) => category.name),
  ])
  expandedSkills.value = new Set([
    ...expandedSkills.value,
    ...categories.flatMap(({ skills }) => skills.map(({ skill }) => skill.dir)),
  ])
}, { immediate: true })

function toggleCategory(name: string) {
  const next = new Set(expandedCategories.value)
  if (next.has(name)) next.delete(name)
  else next.add(name)
  expandedCategories.value = next
}

function toggleSkill(dir: string) {
  const next = new Set(expandedSkills.value)
  if (next.has(dir)) next.delete(dir)
  else next.add(dir)
  expandedSkills.value = next
}

function toggleAll() {
  expandedCategories.value = allExpanded.value
    ? new Set()
    : new Set(props.categories.map((item) => item.category.name))
  expandedSkills.value = allExpanded.value
    ? new Set()
    : new Set(props.categories.flatMap((item) => item.skills.map(({ skill }) => skill.dir)))
}
</script>

<template>
  <aside class="sidebar" aria-label="Skill 目录">
    <div class="sidebar-head">
      <div class="eyebrow">Your toolkit</div>
      <h1 class="sidebar-title">资源目录</h1>
      <div class="sidebar-subtitle">按场景探索可复用的能力与参考资料。</div>
      <div class="sidebar-actions">
        <Tooltip>
          <TooltipTrigger as-child>
            <Button
              size="icon"
              :variant="favoritesOnly ? 'default' : 'outline'"
              class="icon-control favorite-filter"
              :aria-label="favoritesOnly ? '显示全部文件' : '只显示收藏文件'"
              :aria-pressed="favoritesOnly"
              @click="emit('toggleFavorites')"
            >
              <Star :size="15" :fill="favoritesOnly ? 'currentColor' : 'none'" />
            </Button>
          </TooltipTrigger>
          <TooltipContent side="right">{{ favoritesOnly ? '显示全部文件' : `查看收藏（${favorites.length}）` }}</TooltipContent>
        </Tooltip>
        <span class="favorite-count">{{ favorites.length }} 项收藏</span>
        <Button size="sm" variant="ghost" class="ml-auto" @click="toggleAll">
          <ChevronDown v-if="!allExpanded" :size="14" />
          <ChevronUp v-else :size="14" />
          {{ allExpanded ? '全部折叠' : '全部展开' }}
        </Button>
      </div>
    </div>

    <ScrollArea class="tree-scroll">
      <div v-if="categories.length" class="tree-list">
        <section v-for="{ category, skills } in categories" :key="category.name" class="tree-category">
          <Button
            variant="ghost"
            class="tree-row tree-category-button"
            :aria-expanded="expandedCategories.has(category.name)"
            @click="toggleCategory(category.name)"
          >
            <ChevronDown v-if="expandedCategories.has(category.name)" :size="14" />
            <ChevronRight v-else :size="14" />
            <Folder :size="14" class="category-icon" aria-hidden="true" />
            <span class="tree-label">{{ category.title || category.name }}</span>
            <span class="tree-count">{{ skills.length }}</span>
          </Button>

          <div v-if="expandedCategories.has(category.name)" class="tree-category-content">
            <div v-for="{ skill, files } in skills" :key="skill.dir" class="tree-skill">
              <Tooltip>
                <TooltipTrigger as-child>
                  <Button
                    variant="ghost"
                    class="tree-row tree-skill-button"
                    :aria-expanded="expandedSkills.has(skill.dir)"
                    @click="() => { toggleSkill(skill.dir); const main = skill.files.find((file) => file.name === 'SKILL.md') ?? skill.files[0]; if (main) emit('selectFile', main.path) }"
                  >
                    <ChevronDown v-if="expandedSkills.has(skill.dir)" :size="13" />
                    <ChevronRight v-else :size="13" />
                    <BookOpen :size="14" class="skill-icon" />
                    <span class="tree-label">{{ skill.name }}</span>
                    <Badge v-if="skill.platform && skill.platform !== 'all'" variant="outline" class="tree-platform-badge">{{ skill.platform === 'windows' ? 'win' : skill.platform }}</Badge>
                    <span class="tree-count">{{ files.length }}</span>
                  </Button>
                </TooltipTrigger>
                <TooltipContent side="right"><span class="break-all">{{ skill.name }}</span></TooltipContent>
              </Tooltip>

              <div v-if="expandedSkills.has(skill.dir)" class="tree-files">
                <Button
                  v-for="file in files"
                  :key="file.path"
                  variant="ghost"
                  class="tree-row tree-file-button"
                  :class="{ 'tree-file-active': selectedPath === file.path }"
                  :aria-current="selectedPath === file.path ? 'page' : undefined"
                  :title="file.path"
                  @click="emit('selectFile', file.path)"
                >
                  <FileText v-if="file.lang === 'markdown'" :size="13" />
                  <FileCode2 v-else :size="13" />
                  <span class="tree-label">{{ file.name }}</span>
                  <Star v-if="favorites.includes(file.path)" :size="12" class="tree-favorite" fill="currentColor" />
                </Button>
              </div>
            </div>
          </div>
        </section>
      </div>
      <div v-else class="empty-tree">
        <Folder :size="20" class="mx-auto mb-2 opacity-50" />
        {{ favoritesOnly && !favorites.length ? '还没有收藏内容' : '没有找到匹配内容' }}
      </div>
    </ScrollArea>
  </aside>
</template>

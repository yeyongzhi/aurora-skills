<script setup lang="ts">
import { computed, shallowRef } from 'vue'
import { History, Moon, Sun } from '@lucide/vue'
import {
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogOverlay,
  DialogPortal,
  DialogRoot,
  DialogTitle,
} from 'reka-ui'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { ScrollArea } from '@/components/ui/scroll-area'
import { ScrollBar } from '@/components/ui/scroll-area'
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip'
import { skillsPayload } from '@/data/skills'
import type { ThemeMode } from '@/composables/useTheme'
import type { Skill, SkillStats } from '@/types/skills'

const baseUrl = import.meta.env.BASE_URL

defineProps<{
  stats: SkillStats
  theme: ThemeMode
  currentSkill: Skill | null
}>()

const query = defineModel<string>('query', { required: true })
const emit = defineEmits<{ toggleTheme: [] }>()
const isChangelogOpen = shallowRef(false)

const skillEntries = computed(() => skillsPayload.categories
  .filter((category) => !category.meta)
  .flatMap((category) => category.skills.map((skill) => ({
    ...skill,
    categoryTitle: category.title,
  }))))
</script>

<template>
  <DialogRoot v-model:open="isChangelogOpen">
  <header class="topbar">
    <a class="brand" :href="baseUrl" aria-label="aurora-skills 首页">
      <span class="brand-mark" aria-hidden="true">A</span>
      <span>
        <span class="brand-name">aurora-skills</span>
        <span class="brand-caption">Curated skill library</span>
      </span>
    </a>

    <div class="topbar-search">
      <Input id="library-search" v-model="query" placeholder="搜索名称、标签或内容…" aria-label="搜索技能库" />
      <kbd class="shortcut-key">/</kbd>
    </div>

    <div class="topbar-stats" aria-live="polite">
      {{ stats.categories }} 个分类 <span aria-hidden="true">·</span>
      {{ stats.skills }} 个 skill <span aria-hidden="true">·</span>
      {{ stats.files }} 个文件<span v-if="stats.templates"> <span aria-hidden="true">·</span> {{ stats.templates }} 个模板</span>
    </div>

    <Button variant="ghost" size="sm" class="changelog-trigger" @click="isChangelogOpen = true">
      <History :size="15" />
      <span>更新日志</span>
    </Button>

    <Tooltip>
      <TooltipTrigger as-child>
        <Button variant="outline" size="icon" class="icon-control" :aria-label="theme === 'dark' ? '切换到浅色模式' : '切换到深色模式'" @click="emit('toggleTheme')">
          <Sun v-if="theme === 'dark'" :size="16" />
          <Moon v-else :size="16" />
        </Button>
      </TooltipTrigger>
      <TooltipContent>{{ theme === 'dark' ? '切换到浅色模式' : '切换到深色模式' }}</TooltipContent>
    </Tooltip>
  </header>
  <DialogPortal>
    <DialogOverlay class="changelog-overlay" />
    <DialogContent class="changelog-dialog">
      <div class="changelog-dialog-header">
        <div>
          <DialogTitle class="changelog-title">更新日志</DialogTitle>
          <DialogDescription class="changelog-description">全部 {{ skillEntries.length }} 个 Skill 的创建、更新与用途</DialogDescription>
        </div>
        <DialogClose as-child>
          <Button variant="ghost" size="icon" aria-label="关闭更新日志">×</Button>
        </DialogClose>
      </div>
      <ScrollArea class="changelog-scroll">
        <table class="changelog-table">
          <thead>
            <tr>
              <th scope="col">序号</th>
              <th scope="col">标题</th>
              <th scope="col">作用</th>
              <th scope="col">创建日期</th>
              <th scope="col">更新日期</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(skill, index) in skillEntries" :key="skill.dir" :class="{ 'is-current-skill': skill.dir === currentSkill?.dir }">
              <td>{{ index + 1 }}</td>
              <td>
                <strong>{{ skill.title }}</strong>
                <span class="changelog-skill-category">{{ skill.categoryTitle }} · {{ skill.name }}</span>
              </td>
              <td>{{ skill.description }}</td>
              <td>{{ skill.createdAt || '—' }}</td>
              <td>{{ skill.updatedAt || '—' }}</td>
            </tr>
          </tbody>
        </table>
        <ScrollBar orientation="horizontal" />
      </ScrollArea>
    </DialogContent>
  </DialogPortal>
  </DialogRoot>
</template>

<script setup lang="ts">
import { computed, onMounted, onUpdated, useTemplateRef } from 'vue'
import DOMPurify from 'dompurify'
import { marked } from 'marked'
import hljs from 'highlight.js/lib/core'
import bash from 'highlight.js/lib/languages/bash'
import css from 'highlight.js/lib/languages/css'
import go from 'highlight.js/lib/languages/go'
import html from 'highlight.js/lib/languages/xml'
import java from 'highlight.js/lib/languages/java'
import javascript from 'highlight.js/lib/languages/javascript'
import json from 'highlight.js/lib/languages/json'
import markdown from 'highlight.js/lib/languages/markdown'
import powershell from 'highlight.js/lib/languages/powershell'
import python from 'highlight.js/lib/languages/python'
import ruby from 'highlight.js/lib/languages/ruby'
import sql from 'highlight.js/lib/languages/sql'
import scss from 'highlight.js/lib/languages/scss'
import typescript from 'highlight.js/lib/languages/typescript'
import ini from 'highlight.js/lib/languages/ini'
import xml from 'highlight.js/lib/languages/xml'
import yaml from 'highlight.js/lib/languages/yaml'
import 'highlight.js/styles/github.css'
import {
  ArrowLeft, ArrowRight, BookOpen, Check, Clock, Copy, ExternalLink, FileText, Star,
} from '@lucide/vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Separator } from '@/components/ui/separator'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip'
import { skillsPayload } from '@/data/skills'
import type { Skill, SkillFile } from '@/types/skills'

const props = defineProps<{
  file: SkillFile | null
  skill: Skill | null
  mode: 'render' | 'raw'
  isFavorite: boolean
  copied: boolean
  nameCopied: boolean
  previousFile: SkillFile | null
  nextFile: SkillFile | null
  position: number
  total: number
}>()

const emit = defineEmits<{
  changeMode: [mode: 'render' | 'raw']
  toggleFavorite: []
  copy: []
  copyName: []
  navigate: [path: string]
}>()

const markdownRef = useTemplateRef<HTMLElement>('markdown-content')

for (const [name, language] of Object.entries({ bash, css, go, html, ini, java, javascript, json, markdown, powershell, python, ruby, scss, sql, toml: ini, typescript, xml, yaml })) {
  hljs.registerLanguage(name, language)
}

function stripFrontmatter(content: string): string {
  if (!content.startsWith('---')) return content
  const end = content.indexOf('\n---', 3)
  return end < 0 ? content : content.slice(end + 4).replace(/^\r?\n/, '')
}

const isMarkdown = computed(() => props.file?.lang === 'markdown')
const categoryTitle = computed(() => {
  const category = skillsPayload.categories.find((item) => item.skills.some((skill) => skill.dir === props.skill?.dir))
  return category?.title || category?.name || '资源'
})
const title = computed(() => {
  if (!props.file) return '从目录中选择一项'
  const heading = isMarkdown.value
    ? stripFrontmatter(props.file.content).match(/^#\s+(.+)$/m)?.[1]?.trim()
    : null
  return heading || props.file.name
})
const markdownHtml = computed(() => {
  if (!props.file || !isMarkdown.value) return ''
  const html = marked.parse(stripFrontmatter(props.file.content), { async: false })
  return DOMPurify.sanitize(html, {
    USE_PROFILES: { html: true },
    FORBID_TAGS: ['style', 'iframe', 'object', 'embed'],
    FORBID_ATTR: ['style'],
  })
})
const rawHtml = computed(() => {
  if (!props.file || props.file.binary) return ''
  const language = hljs.getLanguage(props.file.lang) ? props.file.lang : 'plaintext'
  try {
    return DOMPurify.sanitize(hljs.highlight(props.file.content, { language }).value)
  } catch {
    return DOMPurify.sanitize(props.file.content)
  }
})

function highlightMarkdown() {
  markdownRef.value?.querySelectorAll('pre code:not([data-highlighted])').forEach((block) => {
    try { hljs.highlightElement(block as HTMLElement) } catch { /* Unsupported language falls back to plain text. */ }
  })
}

function humanSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`
}

function githubFileUrl(path: string): string {
  return `https://github.com/yeyongzhi/aurora-skills/blob/master/${path.split('/').map(encodeURIComponent).join('/')}`
}

function handleMode(value: string | number) {
  if (value === 'render' || value === 'raw') emit('changeMode', value)
}

onMounted(highlightMarkdown)
onUpdated(highlightMarkdown)
</script>

<template>
  <section class="reader-frame" aria-label="文件内容">
    <template v-if="file && skill">
      <header class="reader-toolbar">
        <div class="reader-identity" :title="file.path">
          <div class="reader-breadcrumb"><BookOpen :size="12" />{{ categoryTitle }} / {{ skill.name }}</div>
          <span class="reader-identity-separator" aria-hidden="true">/</span>
          <div class="reader-toolbar-title">{{ title }}</div>
        </div>
        <div class="reader-actions">
          <Tabs :model-value="mode" @update:model-value="handleMode">
            <TabsList class="h-8 rounded-lg">
              <TabsTrigger value="render" class="px-3 text-xs" :disabled="!isMarkdown || file.binary">阅读</TabsTrigger>
              <TabsTrigger value="raw" class="px-3 text-xs">源码</TabsTrigger>
            </TabsList>
          </Tabs>
          <div class="flex items-center gap-1" role="group" aria-label="文件信息与收藏">
            <Tooltip>
              <TooltipTrigger as-child>
                <Button variant="ghost" size="icon" class="icon-control" :aria-label="`文件大小：${humanSize(file.size)}`">
                  <FileText />
                </Button>
              </TooltipTrigger>
              <TooltipContent>文件大小：{{ humanSize(file.size) }}</TooltipContent>
            </Tooltip>
            <Tooltip>
              <TooltipTrigger as-child>
                <Button variant="ghost" size="icon" class="icon-control" aria-label="查看 Skill 创建和更新时间">
                  <Clock />
                </Button>
              </TooltipTrigger>
              <TooltipContent>
                <div class="flex flex-col gap-1">
                  <span>创建日期：{{ skill.createdAt || '—' }}</span>
                  <span>更新日期：{{ skill.updatedAt || '—' }}</span>
                </div>
              </TooltipContent>
            </Tooltip>
            <Tooltip>
              <TooltipTrigger as-child>
                <Button variant="outline" size="icon" class="icon-control" :aria-label="isFavorite ? '取消收藏' : '收藏此文件'" @click="emit('toggleFavorite')">
                  <Star :size="15" :fill="isFavorite ? 'currentColor' : 'none'" :class="isFavorite ? 'text-primary' : ''" />
                </Button>
              </TooltipTrigger>
              <TooltipContent>{{ isFavorite ? '取消收藏' : '加入收藏' }}</TooltipContent>
            </Tooltip>
          </div>
          <Tooltip>
            <TooltipTrigger as-child>
              <Button variant="outline" size="sm" class="action-button" aria-label="复制 Skill 名称" @click="emit('copyName')">
                <Check v-if="nameCopied" data-icon="inline-start" />
                <Copy v-else data-icon="inline-start" />
                <span class="desktop-label">{{ nameCopied ? '已复制名称' : '复制名称' }}</span>
              </Button>
            </TooltipTrigger>
            <TooltipContent>{{ nameCopied ? 'Skill 名称已复制' : '复制 Skill 名称（文件夹名）' }}</TooltipContent>
          </Tooltip>
          <Tooltip>
            <TooltipTrigger as-child>
              <Button size="sm" class="action-button" aria-label="复制文件内容" @click="emit('copy')">
                <Check v-if="copied" :size="14" />
                <Copy v-else :size="14" />
                <span class="desktop-label">{{ copied ? '已复制' : '复制内容' }}</span>
              </Button>
            </TooltipTrigger>
            <TooltipContent>{{ copied ? '已复制到剪贴板' : '复制文件内容' }}</TooltipContent>
          </Tooltip>
        </div>
      </header>

      <ScrollArea class="document-scroll">
        <div class="document-content">
          <div class="reader-intro" :class="{ 'reader-intro-markdown': isMarkdown }">
            <div v-if="!isMarkdown" class="eyebrow"><BookOpen :size="12" class="mr-1 inline" />{{ categoryTitle }} / {{ skill.name }}</div>
            <h2 class="reader-heading">{{ title }}</h2>
            <p class="reader-description">{{ skill.description }}</p>
            <div v-if="skill.tags.length" class="reader-meta">
              <Badge v-for="tag in skill.tags" :key="tag" variant="outline">{{ tag }}</Badge>
            </div>
          </div>

          <Separator class="reader-divider" />

          <div v-if="file.binary" class="notice">这是一个二进制文件，无法在页面内显示。请从 GitHub 下载。</div>
          <div v-else-if="file.truncated" class="notice">文件超过 512 KB，此处只显示前 512 KB；复制内容也会被截断。</div>

          <article v-if="mode === 'render' && isMarkdown && !file.binary" ref="markdown-content" class="markdown-body" v-html="markdownHtml" />
          <pre v-else-if="!file.binary" class="raw-code"><code v-html="rawHtml" /></pre>
        </div>
      </ScrollArea>

      <footer class="reader-footer">
        <div>{{ position }} / {{ total }} 个资源</div>
        <div class="flex items-center gap-2">
          <Button variant="ghost" size="sm" :disabled="!previousFile" @click="previousFile && emit('navigate', previousFile.path)">
            <ArrowLeft :size="14" /> 上一个
          </Button>
          <Button variant="ghost" size="sm" :disabled="!nextFile" @click="nextFile && emit('navigate', nextFile.path)">
            下一个 <ArrowRight :size="14" />
          </Button>
          <a :href="githubFileUrl(file.path)" target="_blank" rel="noopener noreferrer">
            在 GitHub 查看 <ExternalLink :size="13" />
          </a>
        </div>
      </footer>
    </template>

    <div v-else class="welcome-card">
      <div class="welcome-inner">
        <div class="eyebrow">A curated skill library</div>
        <h2>把常用能力，整理成随时可复用的 Skill。</h2>
        <p>从左侧目录选择一个 skill，阅读说明、辅助脚本与参考资料，并可一键复制到你的工作流中。</p>
      </div>
    </div>
  </section>
</template>

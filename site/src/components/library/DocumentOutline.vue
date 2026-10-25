<script setup lang="ts">
import { computed, ref } from 'vue'
import { ChevronDown, ChevronRight, ListTree } from '@lucide/vue'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { ScrollArea } from '@/components/ui/scroll-area'

export interface OutlineHeading {
  id: string
  text: string
  level: number
  ancestors: string[]
}

const props = defineProps<{ headings: OutlineHeading[]; activeId: string }>()
const emit = defineEmits<{ select: [id: string] }>()
const open = ref(true)
const collapsed = ref(new Set<string>())
const parents = computed(() => new Set(props.headings.flatMap((heading) => heading.ancestors)))
const visible = computed(() => props.headings.filter((heading) => !heading.ancestors.some((id) => collapsed.value.has(id))))
function toggle(id: string) {
  const next = new Set(collapsed.value)
  if (next.has(id)) next.delete(id)
  else next.add(id)
  collapsed.value = next
}
</script>

<template>
  <Card size="sm" class="document-outline" role="complementary" aria-label="文档目录">
    <CardHeader class="shrink-0">
    <CardTitle class="outline-header">
      <Button variant="ghost" size="sm" :aria-expanded="open" aria-controls="document-outline-items" @click="open = !open">
        <ListTree data-icon="inline-start" /> 文档目录
        <ChevronDown v-if="open" data-icon="inline-end" />
        <ChevronRight v-else data-icon="inline-end" />
      </Button>
      <Button v-if="open && parents.size" variant="ghost" size="sm" @click="collapsed = collapsed.size ? new Set() : new Set(parents)">
        {{ collapsed.size ? '全部展开' : '全部收起' }}
      </Button>
    </CardTitle>
    </CardHeader>
    <CardContent v-show="open" class="flex min-h-0 flex-col">
    <ScrollArea v-show="open" class="outline-items">
    <nav id="document-outline-items" aria-label="章节导航">
      <div v-for="heading in visible" :key="heading.id" class="outline-row" :style="{ paddingLeft: `${heading.ancestors.length * 12}px` }">
        <Button v-if="parents.has(heading.id)" variant="ghost" size="icon" class="outline-toggle" :aria-label="`${collapsed.has(heading.id) ? '展开' : '收起'}${heading.text}`" :aria-expanded="!collapsed.has(heading.id)" @click="toggle(heading.id)">
          <ChevronRight v-if="collapsed.has(heading.id)" />
          <ChevronDown v-else />
        </Button>
        <span v-else class="outline-spacer" />
        <Button :variant="activeId === heading.id ? 'secondary' : 'ghost'" size="sm" class="outline-link justify-start" :aria-current="activeId === heading.id ? 'location' : undefined" :title="heading.text" @click="emit('select', heading.id)">
          <span class="truncate">{{ heading.text }}</span>
        </Button>
      </div>
    </nav>
    </ScrollArea>
    </CardContent>
  </Card>
</template>

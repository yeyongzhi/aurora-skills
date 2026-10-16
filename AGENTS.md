# aurora-skills repository instructions

## Vue and shadcn-vue UI

- Build Vue components with Vue 3 Composition API, `<script setup lang="ts">`, and typed props/emits.
- Use the shadcn-vue components from `site/src/components/ui/` for controls whenever a matching component exists.
- Do not use native `button`, `input`, `textarea`, `select`, `option`, or `dialog` controls in business views/components; do not replace available shadcn-vue controls with custom CSS controls.
- Use `Button`, `Input`, `Tabs`, `Tooltip`, and other matching components from `@/components/ui/`. This restriction does not apply inside the generated `src/components/ui/` implementations.
- Keep components focused and use props down/events up. Keep derived state in `computed` and move reusable stateful behavior into composables.
- Sanitize rendered Markdown before using `v-html`; never render raw repository content directly as HTML.

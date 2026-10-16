import bundleSource from '../../data/skills.js?raw'
import type { SkillsPayload } from '@/types/skills'

const bundlePrefix = 'window.__SKILLS__ = '
const bundleContent = bundleSource.trim()

if (!bundleContent.startsWith(bundlePrefix) || !bundleContent.endsWith(';')) {
  throw new Error('站点技能数据格式无效，请运行 python scripts/build-site.py。')
}

export const skillsPayload = JSON.parse(
  bundleContent.slice(bundlePrefix.length, -1),
) as SkillsPayload

if (skillsPayload.schemaVersion !== 1 || !Array.isArray(skillsPayload.categories)) {
  throw new Error('站点技能数据版本不受支持，请运行 python scripts/build-site.py。')
}

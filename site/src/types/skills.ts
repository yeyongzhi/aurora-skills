export interface SkillFile {
  path: string
  name: string
  lang: string
  size: number
  content: string
  binary: boolean
  truncated?: boolean
}

export interface Skill {
  name: string
  dir: string
  title: string
  createdAt: string
  updatedAt: string
  description: string
  platform: string
  tags: string[]
  files: SkillFile[]
}

export interface SkillCategory {
  name: string
  title: string
  meta: boolean
  readme: string
  skills: Skill[]
}

export interface SkillStats {
  categories: number
  skills: number
  files: number
  templates: number
}

export interface SkillsPayload {
  schemaVersion: number
  categories: SkillCategory[]
  stats: SkillStats
}

export interface VisibleCategory {
  category: SkillCategory
  skills: Array<{ skill: Skill; files: SkillFile[] }>
}

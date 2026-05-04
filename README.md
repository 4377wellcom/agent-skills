# Agent Skills Collection

本仓库收集了一系列适用于 **Cherry Studio / Claude Code** 的 AI Agent Skill 定义文件，方便快速扩展 Agent 能力。

## 包含的 Skill

| Skill | 功能 | 状态 |
|-------|------|------|
| **conversation-extractor** | 对话关键信息结构化提取（核心主题、决策、行动项等） | ✅ |
| **memory-capsule-skill** | 记忆胶囊制作与管理（/ai-memory 系列命令） | ✅ |
| ...更多 skill 陆续添加中 | | 🚧 |

## 安装方法

将对应 Skill 的文件夹复制到 Cherry Studio 或 Claude Code 的 skill 目录下即可：

```
{Data}/Skills/
├── conversation-extractor/
│   ├── SKILL.md
│   └── evals/
├── memory-capsule-skill/
│   ├── SKILL.md
│   └── evals/
```

Claude Code 会自动发现并注册这些 skill。
Cherry Studio 用户刷新或重启后即可使用。

## Skill 文件结构

```
skill-name/
├── SKILL.md        # Skill 定义（YAML frontmatter + 行为指令）
└── evals/
    └── evals.json  # 评测数据
```

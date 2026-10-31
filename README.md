# 校园闲置物资循环 AI 平台

面向本校学生的公益向闲置流转 Web 应用：毕业季教材、被褥、文具、小家电在校内循环，支持**低价转售**与**公益捐赠给困难新生**双通道。AI 负责发布提效（识图 + 文案 + 估价）、供需语义匹配、违规审核与感谢信生成，后台提供环保数据看板。

技术栈：Next.js 15 (App Router) + TypeScript + Tailwind CSS + SQLite (better-sqlite3) + 阿里百炼 DashScope（qwen-vl-max / qwen-plus / text-embedding-v3）+ ECharts。

## 文档索引

| 文件 | 内容 |
|---|---|
| [docs/01-PRD.md](docs/01-PRD.md) | 需求、痛点、功能清单、非功能要求、验收标准、里程碑 |
| [docs/02-页面流程.md](docs/02-页面流程.md) | 站点地图、三条用户旅程、页面结构与视觉规范 |
| [docs/03-数据库设计.md](docs/03-数据库设计.md) | ER 关系、9 张表字段、状态机、环保折算系数 |
| [docs/04-AI接口契约.md](docs/04-AI接口契约.md) | 5 个 AI 接口的输入输出、降级策略、Prompt 设计要点 |
| [prompts/](prompts/) | 分轮次开发提示词脚本 R1–R22 + 修 bug 引导话术 |

## 快速开始（骨架完成后生效）

```bash
npm install
cp .env.example .env.local     # 填入 DASHSCOPE_API_KEY
npm run migrate && npm run seed
npm run dev                    # http://localhost:3000
```

## 开发约定

- 一个功能一次提交，提交信息前缀 `feat:` / `fix:` / `chore:` / `docs:`，并标注对应的提示词轮次（如 `R10`）。
- 每次 AI 调用的 prompt 原文与模型响应写入 `ai_call_logs` 表，通过 `node scripts/export-prompts.mjs` 导出为 Prompt 历史快照。
- API Key 只在服务端读取，`.env.local` 与 `data/*.db` 不入库。

## 当前进度

- [x] 阶段 1：需求文档包、数据库设计、AI 接口契约、分轮提示词脚本
- [ ] 阶段 2：基础业务（R1–R8）
- [ ] 阶段 3：AI 能力（R9–R15）
- [ ] 阶段 4：数据看板（R16–R18）
- [ ] 阶段 5：联调与打磨（R19–R22）

报名与省赛作品提交截止：**2026-11-18**。

---
name: campus-cycle-dev-spec
description: 校园闲置物资循环 AI 平台的项目级开发规范与 AI 协作契约。每次让 AI 写代码前投喂本文件，作为唯一事实来源；与 AI 的建议冲突时以本文件为准。
metadata:
  project: 校园闲置物资循环 AI 平台
  competition: 传智杯 AI 创新应用挑战赛
  version: 1.0
  updated: 2026-10-31
---

# 怎么用这份文件

> 本文件是**完整版规范**。WorkBuddy / CodeBuddy 每轮自动注入的是根目录的 `CODEBUDDY.md`（精简硬约束版，受 8000 字符上限约束）。两份内容冲突时以本文件为准，并同步回 `CODEBUDDY.md`。

| 场景 | 做法 |
|---|---|
| Trae / 通义灵码 / Cursor / Claude Code | 把本文件放到项目根目录，多数工具会自动读取；不自动读就在会话开头贴一次 |
| 网页版对话（豆包 / 通义 / DeepSeek） | 每轮对话开头贴「§1 项目定位」+「§2 技术栈」+ 本轮任务；涉及数据库或 AI 时追加对应章节 |
| 我让 AI 改一处小 bug | 只贴「§6 安全红线」+「§9 禁止事项」+ 报错原文，省 token |

---

## §1 项目定位

**校园闲置物资循环 AI 平台**：面向本校学生的公益向闲置流转 Web 应用。毕业季教材、被褥、文具、小家电在校内循环，双通道流转 —— **低价转售** 与 **公益捐赠给通过审核的困难生**。

**范围边界（超出即拒绝实现）**
- 不做在线支付、担保交易、物流对接：线上达成意向，线下自提交割。
- 不做实名认证、信用分、评价体系。
- 不做自研模型、微调、算法研究：只做商用大模型 API 的应用层编排。
- 不做微服务、消息队列、Redis、K8s：单人学生项目，复杂度必须与规模匹配。

**核心 AI 能力（4 个）**：识图发布辅助（类别/成色/文案/估价）、供需语义检索（RAG）、违规内容审核、捐赠感谢信与环保报告生成。

## §2 技术栈（锁定，不得替换）

| 层 | 选型 | 备注 |
|---|---|---|
| 框架 | Next.js 16.4 App Router + React 19 + TypeScript | 严格模式，不用 Pages Router |
| 样式 | Tailwind CSS v4 | 无 `tailwind.config.js`，主题令牌写在 `src/app/globals.css` 的 `@theme`；**不引 shadcn / antd / MUI / Chakra** |
| 后端 | Next.js Route Handler `src/app/api/**` | **不单独起 Node/Python 服务** |
| 数据库 | SQLite + `better-sqlite3`（同步 API） | **不用 ORM、不用 Prisma** |
| AI | 阿里百炼 DashScope OpenAI 兼容端点 | `qwen-vl-max` / `qwen-plus` / `text-embedding-v3` |
| 图表 | ECharts | 仅管理端看板 |
| 鉴权 | `node:crypto` scrypt + HMAC 签名 cookie | **不用 NextAuth / Clerk / Passport** |
| 测试 | `node:test` | 状态机、向量计算、统计口径 |

## §3 目录结构约定

```
src/
  app/
    (public)/          首页、登录、注册、公益专区
    items/[id]/        详情页
    publish/           发布页
    me/                个人中心（发布/收藏/申领/台账/帮扶申请）
    admin/             管理端（帮扶审核、违规复核、看板、AI 留痕）
    api/               auth/ items/ ai/ upload/ stats/ admin/
  components/          ui/ 卡片与基础件 · charts/ 图表 · layout/
  server/              db.ts schema.sql migrate.ts auth.ts
                       item-state.ts retrieval.ts stats.ts seed.ts donate-boost.ts
  lib/                 ai/(client.ts prompts.ts json.ts embed.ts vector.ts)
                       green-factors.ts ref-price.ts banned-terms.ts
public/uploads/        上传图片
data/campus.db         SQLite（不入库）
docs/ prompts/         文档与分轮提示词
```

## §4 编码规范

1. **服务端组件优先**：页面默认 Server Component 直接查库渲染，只有需要交互（表单、轮询、图表、动画）的叶子节点才加 `'use client'`。页面初始化不绕 HTTP 调自己的 API。
2. 数据访问只写在 `src/server/**` 与 `src/app/api/**`，组件里不出现 `db.` 调用。
3. 类型：接口出入参定义在 `src/lib/types.ts`，禁用 `any`；AI 返回先按 `unknown` 解析再收窄。
4. 命名：文件 kebab-case，组件 PascalCase，函数 camelCase，DB 字段 snake_case。
5. 错误处理：API 统一返回 `{ ok: false, code, message }`，`message` 面向用户、不含堆栈与 SQL。
6. 注释：默认不写。只在写"为什么"（口径、兜底策略、非直觉的取舍）时写一行。
7. 不写用不到的抽象、不留 TODO 让人补、不写空壳函数。
8. **Next 16 与你的训练数据不同**：写 Next 代码前先读 `node_modules/next/dist/docs/` 下的对应指南，别按 Next 13/14 的写法猜。独立 Node 脚本用 `.mts` 后缀（`node src/server/migrate.mts`），不引 tsx / ts-node。

## §5 数据层规范

- 表结构以 `docs/03-数据库设计.md` 与 `src/server/schema.sql` 为**唯一事实来源**：9 张表 `users / items / favorites / applications / donations / letters / messages / aid_applications / ai_call_logs`。
- **不得擅自增删字段**。确需新增：先说明「加什么、为什么现有字段不够」，等我确认。
- 建表用 `CREATE TABLE IF NOT EXISTS`，迁移幂等，`npm run migrate` 可重复执行。
- 时间字段统一 `TEXT`，默认 `datetime('now','localtime')`。
- 枚举用 `TEXT` + 服务端白名单校验，不用 CHECK 之外的隐式约定。
- 向量存 `items.embedding BLOB`（Float32Array → Buffer），改标题或描述时置空 `embedded_at` 触发重算。
- 打开连接时开启 `foreign_keys` 与 WAL。

## §6 安全红线（每条都必须满足）

1. `DASHSCOPE_API_KEY` 只在服务端从 `process.env` 读取，**绝不出现在客户端组件、返回值、日志或录屏里**。
2. 密码 `scrypt` + 每用户 16 字节随机盐，校验用 `timingSafeEqual`。
3. 会话：`httpOnly` + `sameSite=lax`（生产加 `secure`）+ HMAC 签名；`SESSION_SECRET` 缺失时启动即抛错，不用默认值。
4. **所有写接口先做服务端登录校验**，并校验资源归属（`owner_id` / `donor_id` / `applicant_id`），不信任前端传来的 id 与角色。
5. SQL 一律参数化占位 `?`；动态筛选条件用**字段名白名单**拼接，值永远走占位；`LIKE` 转义 `%` 与 `_`。
6. 上传：扩展名 + MIME 双白名单（jpg/jpeg/png/webp）、5MB 上限、`crypto.randomUUID()` 重命名、拒绝路径穿越（读取 `image_path` 时校验前缀）。
7. AI 生成内容入库前做枚举白名单与长度校验，非法值降级为默认值而不是直接写入。
8. AI 接口按 `userId` 内存限流（每分钟 N 次），超限 429。

## §7 AI 调用规范

- 统一走 `src/lib/ai/client.ts` 的 `chat()` / `embed()`，`AbortController` 15s 超时，错误带 `kind: api_error | timeout | parse_error`。
- **Prompt 全部集中在 `src/lib/ai/prompts.ts` 导出常量**，不散落在路由文件里 —— 这是比赛要审查的意图控制证据。
- 强制 JSON 输出：prompt 里写死字段与枚举值，给 2 条少样本；解析走 `safeParseJson()`，能处理 ```json 包裹、前后夹带解释文字、字段缺失。
- **每次调用写 `ai_call_logs`**：feature / model / prompt 原文 / 模型原始返回 / 解析结果 / 耗时 / 状态。
- 降级优先于失败：识图失败→纯文本生成；AI 全挂→保留手动表单可提交；审核故障→放行但 `violation_flag=2` 待人工复核。**任何情况都不能阻断用户正常发布。**
- 数字不交给模型：估价来自同 `category` 已成交记录 SQL 聚合；环保报告的数字全部来自服务端统计，prompt 明令禁止推算新增，返回后做一次数字比对校验。
- 语义检索：查询向量化 → 载入 `listed` 物品向量 → 余弦相似度 → 业务加权（`donate` +0.15；通过审核的帮扶生对 `donate` 再 +0.30）→ Top-K → 生成导购语。物品量 < 5000 时**内存计算，不引入向量数据库**。

## §8 视觉与交互规范

- 色板：背景 `#FDF6F0`；公益捐赠 `#F7B2BD`（暖粉）；低价转售 `#A8D8EA`（浅青）；AI 能力强调 `#C7CEEA`（淡紫）；正文 `#4A4A55`。
- **三层圆角卡片**：页面底 → 区块卡 → 内容卡；圆角 12 / 16 / 20px 三级；轻阴影 `0 2px 12px rgba(0,0,0,.06)`。
- hover：上浮 2px + 阴影加深，`transition 180ms ease`。
- AI 等待态：按钮禁用 + 骨架屏 + 「AI 正在识别…」三点跳动动画；导购语用逐字打字机效果（纯 CSS/JS，不引动画库）。
- AI 采纳标记：AI 回填的字段右上角显示「AI」小徽章，用户改动后变「已修改」，并置 `items.ai_edited=2`。
- 布局：移动端单列 + 底部标签栏（首页/发布/公益/我的），桌面最多 4 列瀑布流。
- 无障碍：图片 `alt`、按钮 `aria-label`、表单 `label` 关联、focus 可见。

## §9 禁止事项（AI 高频犯错处，出现即要求回退）

1. 换技术栈或加依赖（"我建议用 Prisma 更方便" → 回退，理由见 §2）。
2. 一次改多个不相关模块；重写我没让你动的文件。
3. 把 Supabase / Firebase / Vercel KV / pgvector / Chroma / LangChain 塞进来。
4. 用 `useEffect` + `fetch` 做页面首屏数据加载。
5. 前端做权限判断当作安全手段；把用户角色存在 localStorage。
6. 字符串拼接 SQL；把用户输入直接当文件名或路径。
7. 编造数据源：虚构"接入校内历史成交大数据"、虚构实测环保数据。
8. 输出省略号代替代码（`// ...其余不变`）——我要能直接落盘的完整文件。
9. 加没用的 README 章节、注释、日志。
10. 静默引入 shadcn/ui、Tailwind 插件、图标库。

## §10 协作与提交纪律

- **一轮提示词 = 一个功能 = 一次 commit**，禁止攒到最后一次性提交（比赛明令禁止，占分 25%）。
- commit 前缀：`feat:` 新功能 / `fix:` 修复 / `chore:` 骨架与配置 / `docs:` 文档，末尾标注轮次，例：
  `feat: qwen-vl-max 识图生成类别成色与文案 (R10)`
- 修 bug 单独一次 commit，message 里写清是谁定位的。
- 提交前 `git status` 复查，确认 `.env.local`、`data/*.db`、`public/uploads/*` 未被跟踪。
- 每 3–4 轮要求 AI 输出一次「当前文件清单 + 依赖变更」，核对后继续。

## §11 回答格式要求

只输出三部分，不要散文：
1. 新增/修改的文件清单（路径 + 一句话说明）
2. 每个文件的**完整内容**
3. 我需要在终端执行的命令（整行可复制，Windows PowerShell 版）

涉及取舍时，用一行说明「为什么这样做」，不超过 3 行。

## §12 每轮验收清单（我自查，你也自检）

- [ ] `npm run dev` 无报错，页面能打开
- [ ] 本轮功能肉眼可见，不是只写了代码没接线
- [ ] 未登录访问写接口返回 401；越权访问他人资源返回 403
- [ ] AI 调用在 `ai_call_logs` 有记录（含 prompt 原文）
- [ ] 断掉 API Key 时功能降级而不是白屏
- [ ] 没有新增未在 §2 白名单里的依赖
- [ ] `npm run migrate && npm run seed` 仍可重复执行

## §13 冲突处理

当 AI 的意见与本文件不一致：**默认本文件优先**。若 AI 认为本文件会导致功能无法实现，要求它先说明「哪一条、为什么在 Next.js + SQLite 约束下做不到、有什么不违反 §2 的替代方案」，再等我决定。不要让它"先按更好的实践做了"。

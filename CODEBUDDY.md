# 项目硬约束（WorkBuddy 每轮自动注入）

**项目**：校园闲置物资循环 AI 平台 —— 本校学生公益向闲置流转 Web 应用，双通道「低价转售 / 公益捐赠给通过审核的困难生」，参加传智杯 AI 创新应用挑战赛。

**详细规范在 `skilled.md`（必读）；分轮开发任务在 `prompts/`；数据表定义在 `docs/03-数据库设计.md`；AI 接口契约在 `docs/04-AI接口契约.md`。动代码前先读 `skilled.md`。**

## 范围边界（超出即拒绝实现）
不做支付/担保交易/物流对接（线上达成意向，线下自提）；不做实名认证、信用分、评价体系；不做自研模型与算法研究，只做商用大模型 API 的应用层编排；不做微服务、消息队列、Redis、K8s。

## 技术栈（锁定，不得替换、不得加白名单外依赖）
Next.js 15 App Router + TypeScript（严格模式）｜Tailwind CSS，**不用 shadcn/antd/MUI/Chakra**｜后端用 Route Handler `src/app/api/**`，**不单独起 Node/Python 服务**｜SQLite + `better-sqlite3` 同步 API，**不用 ORM/Prisma**｜AI 用阿里百炼 DashScope OpenAI 兼容端点：`qwen-vl-max` / `qwen-plus` / `text-embedding-v3`｜ECharts 仅管理端看板｜鉴权用 `node:crypto` scrypt + HMAC 签名 cookie，**不用 NextAuth/Clerk/Passport**｜测试用 `node:test`。

## 安全红线
1. `DASHSCOPE_API_KEY` 只在服务端 `process.env` 读取，绝不出现在客户端组件、返回值、日志里。
2. 密码 scrypt + 每用户 16 字节随机盐，比对用 `timingSafeEqual`。
3. cookie `httpOnly` + `sameSite=lax`（生产加 `secure`）；`SESSION_SECRET` 缺失时启动即抛错，不用默认值。
4. 所有写接口先做服务端登录校验，并校验资源归属（`owner_id`/`donor_id`/`applicant_id`），不信任前端传来的 id 与角色。
5. SQL 全参数化 `?`；动态筛选用字段名白名单，值走占位；`LIKE` 转义 `%` 与 `_`。
6. 上传：扩展名 + MIME 双白名单（jpg/jpeg/png/webp）、5MB 上限、`crypto.randomUUID()` 重命名、防路径穿越。
7. AI 返回入库前做枚举白名单与长度校验，非法值降级为默认值。
8. AI 接口按 `userId` 内存限流，超限 429。

## AI 调用规范
统一走 `src/lib/ai/client.ts`，15s `AbortController` 超时，错误带 `kind: api_error|timeout|parse_error`；**prompt 集中在 `src/lib/ai/prompts.ts` 导出常量**（这是比赛要审查的意图控制证据）；强制 JSON 输出 + 2 条少样本，解析走 `safeParseJson()`；**每次调用写 `ai_call_logs`**（prompt 原文 + 模型原始返回 + 耗时 + 状态）；**降级优先于失败，任何情况都不能阻断用户发布**；数字不交给模型（估价来自同 `category` 已成交记录 SQL 聚合，环保报告数字全部来自服务端统计并做比对校验）。

## 禁止事项（出现即要求回退）
1. 换技术栈或加依赖（"我建议用 Prisma 更方便" → 回退）。
2. 一次改多个不相关模块；重写我没让你动的文件。
3. 引入 Supabase/Firebase/pgvector/Chroma/LangChain。
4. 用 `useEffect` + `fetch` 做页面首屏数据加载（服务端组件直接查库）。
5. 把前端权限判断当安全手段；把角色存 localStorage。
6. 字符串拼接 SQL；用户输入直接当文件名或路径。
7. 编造数据源或实测数据（"接入校内大数据"、虚构环保实测值）。
8. 用 `// ...其余不变` 省略代码——要能直接落盘的完整文件。
9. 加没用的 README 章节、注释、日志。
10. 静默引入组件库、图标库、Tailwind 插件。

## 提交纪律（比赛评分项，占 25%）
**一轮提示词 = 一个功能 = 一次 commit**，禁止攒到最后一次性提交。前缀 `feat:`/`fix:`/`chore:`/`docs:`，末尾标轮次，例：`feat: qwen-vl-max 识图生成类别成色与文案 (R10)`。修 bug 单独一次 commit。提交前 `git status` 确认 `.env.local`、`data/*.db`、`public/uploads/*` 未被跟踪。

## 回答格式
只输出：①新增/修改文件清单（路径 + 一句话）②每个文件的完整内容 ③我需要在终端执行的整行命令（Windows PowerShell 版）。取舍理由不超过 3 行，不要散文。

## 冲突处理
本文件与你的判断冲突时**以本文件为准**。若你认为某条在 Next.js + SQLite 约束下会导致功能无法实现，先说明「哪一条、为什么做不到、不违反技术栈的替代方案」，等我决定，**不要"先按更好的实践做了"**。

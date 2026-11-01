# WorkBuddy 逐轮投喂卡（R2 → R22 + 插播卡）

## 使用协议（先看这页，别跳）

1. **一次只贴一张卡**。贴完等它写完、你验收、`git commit`，再贴下一张。一次贴两张以上 = commit 粒度废掉 = 可复现性那 25 分没了。
2. **每张卡开头都有 `S` 卡要求的那句话**，如果你是新开会话，先贴 `S`，再贴轮次卡；同一会话里连续贴轮次卡即可。
3. **建议每 3–4 轮新开会话**（阶段 2 一轮话、阶段 3 分两轮话），因为长会话里它开始记混自己写过的东西。新会话会自动重新注入 `CODEBUDDY.md`，成本为零。
4. 它写完先别 commit：**按卡里的「验收」逐条点一遍**，点不动就进「插播卡 B1」。
5. commit 命令整行复制，末尾轮次号别丢——评委翻 `git log` 就靠这个对上 Prompt。
6. **R1 已经由 Qoder 做完并提交**（骨架 + SQLite + 建表脚本，`3155656`），你从 R2 开始。

---

## S｜会话开场卡（新开会话时先贴这一条）

```text
先读 skilled.md 和 docs/03-数据库设计.md，再读 src/server/schema.sql 与 src/app/globals.css，确认你已经知道：9 张表的字段、Tailwind v4 的主题令牌（bg-cream/bg-panel/bg-blush/bg-sky/bg-lilac/text-ink/text-ink-soft/rounded-card/shadow-soft/shadow-lift）、已装的依赖只有 next/react/better-sqlite3/openai。
读完只回一句「已就绪，等下一轮指令」，不要写任何代码，不要提改进建议。
```

---

## R2｜注册与登录

```text
本轮只做注册登录，服务端校验，不引任何鉴权库。
1. src/server/auth.ts：hashPassword(pw) 用 node:crypto 的 scrypt + 16 字节随机盐，返回 "salt:hash" 的 hex 串；verifyPassword 用 timingSafeEqual；signSession(userId) 生成 HMAC 签名 token；requireUser(req) 从 httpOnly cookie 解析当前用户，失败返回 401；requireAdmin(req) 再校验 role。SESSION_SECRET 缺失时启动即抛错。
2. POST /api/auth/register：username 4-20 位、password ≥6 位、nickname 非空；重名返回 409；成功后直接签发登录 cookie。
3. POST /api/auth/login：错误统一返回「用户名或密码错误」，不区分是哪个字段错。POST /api/auth/logout 清 cookie。
4. 页面 /login 与 /signup：居中粉彩卡片表单，错误红字提示，成功后跳回来源页或首页。
5. 顶部导航 src/components/layout/Navbar.tsx：服务端读 cookie 后作为 props 传入，未登录显示「登录 / 注册」，已登录显示昵称与「我的」「退出」。不要在客户端组件里调 /api 拿用户信息。
6. 注册第一个账号时若环境变量 FIRST_USER_IS_ADMIN=1，role 置为 admin。
验收标准：注册后刷新仍是登录态；退出后 POST /api/items 返回 401。
```
**验收**：注册→刷新保持登录→退出→直接访问 `/api/auth/logout` 之外的写接口返回 401；数据库 `users` 表里 `password_hash` 看不到明文。
```bash
git add -A && git commit -m "feat: scrypt 注册登录与 httpOnly 会话 (R2)"
```

---

## R3｜发布表单与图片上传（AI 位先留空）

```text
本轮只做发布，不接任何 AI。
1. POST /api/upload：校验扩展名与 MIME 双白名单（jpg/jpeg/png/webp）、5MB 上限，用 crypto.randomUUID() 重命名存 public/uploads，返回可访问路径；其他类型 415。要求登录。
2. POST /api/items：要求登录；校验 category 属于 textbook/bedding/stationery/appliance/daily/clothing/other 七枚举、mode 属于 sale|donate、sale 必须 price>0、donate 强制 price=0；写入 items，raw_desc 存用户原话，ai_edited=0。
3. 页面 /publish 三步：① 图片上传 + 一句话口语描述 ② 类别/成色/价格 ③ 转售或捐赠单选。左侧表单，右侧实时预览物品卡片。
4. 第二步顶部放一个「AI 帮我完善」按钮，本轮 disabled 置灰并加 tooltip「下一轮接入」，同时预留一个骨架屏容器 div。
5. 提交成功跳 /items/[id]，失败把服务端 message 显示在表单顶部。
6. 未登录访问 /publish 跳 /login。
验收标准：能发布并落库；未登录被拦；上传 .txt 被拒。
```
**验收**：发布 2 件（一件转售一件捐赠）后 `sqlite3 data/campus.db "select id,title,mode,price,category from items"` 看到记录；上传 `.txt` 报错；未登录访问 `/publish` 跳登录。
```bash
git add -A && git commit -m "feat: 物品发布表单与图片上传，AI 按钮位预留 (R3)"
```

---

## R4｜首页列表、筛选与详情页

```text
1. GET /api/items：支持 category、mode、condition、minPrice、maxPrice、page、pageSize，返回 { total, items }，只返回 status='listed' 且 violation_flag=0，按 created_at desc。字段名走白名单，值全部参数化。
2. 首页 src/app/page.tsx 改成服务端组件直接查库渲染（不要 fetch 自己的 API）：顶部搜索框跳 /search?q=，筛选栏（类别 chip、模式 chip、成色下拉、价格区间），物品卡片桌面最多 4 列、移动单列，「加载更多」分页。保留现在那张三卡片介绍区块，移到列表下方或做成次级区块。
3. 物品卡片组件 src/components/ItemCard.tsx：图片 4:3、标题、模式徽章（公益捐赠 bg-blush / 低价转售 bg-sky）、价格或「免费」、成色与类别小标签、右上收藏心形，hover 上浮 2px（复用 shadow-lift）。
4. /items/[id] 详情页服务端渲染：view_count 自增；大图、ai_desc 为空时回退 raw_desc、标签、发起人昵称与学院、「申请领取 / 我想要」按钮（本轮只渲染按钮不接逻辑）、收藏按钮。
5. 空列表用统一空态卡片：「还没有闲置，去发布第一件」。
验收标准：seed 前你手工发的 2 件能刷出来，筛选与分页结果正确，详情页刷新一次计数 +1。
```
**验收**：筛选「公益捐赠」只剩 donate；详情页 F5 刷新两次，`view_count` 从 1 变 3。
```bash
git add -A && git commit -m "feat: 首页筛选列表与物品详情页（服务端渲染） (R4)"
```

---

## R5｜收藏、申领单与状态机（含单测）

```text
1. 状态机集中写在 src/server/item-state.ts：导出纯函数 transition(item, application, action) 返回新的 { itemStatus, applicationStatus }，action ∈ approve|reject|complete|cancel。规则：approve→item=reserved；reject→item 回 listed；complete→application=completed 且 item=completed；cancel→application=cancelled 且该物品无其他进行中申领时 item 回 listed。非法流转抛错。
2. POST /api/items/[id]/favorite 切换收藏；GET 时服务端算出是否已收藏再传进组件。
3. POST /api/items/[id]/applications：校验不能申领自己的物品、物品必须 listed、同一用户对该物品只能有一条非 cancelled 记录；donate 物品 reason 必填。
4. PATCH /api/applications/[id]：只有物品主人能 approve/reject；只有申领人或主人能 cancel；complete 只有主人能做，且此时若 mode=donate 则向 donations 插一条，green_weight_kg 按 src/lib/green-factors.ts 的类别系数计算（系数表按 docs/03 第 4 节，注明为参考估算值）。
5. 越权一律 403，不是 401。
6. 用 node:test 给 item-state.ts 写测试（tests/item-state.test.ts），package.json 加 "test": "node --test tests/"。覆盖正常链路与非法流转。
验收标准：npm test 全绿；两个账号跑通申领→同意→完成，donate 物品完成后 donations 多一条。
```
**验收**：`npm test` 通过；用 A 账号申领 B 的物品、B 同意、B 标记完成，`donations` 表有数据且 `items.status='completed'`；A 去改别人物品返回 403。
```bash
git add -A && git commit -m "feat: 收藏、申领状态机与捐赠台账落库 (R5)"
```

---

## R6｜个人中心与捐赠台账

```text
1. /me 服务端渲染，四个 tab：我的发布 / 我的收藏 / 我收到的申领 / 我的申领。每项是卡片列表，带状态徽章与操作按钮（同意、拒绝、标记完成、取消），按钮走 R5 的接口。
2. /me/donations 捐赠台账表格：日期、物品、类别、受赠人昵称（receiver_anonymous 或对方要求匿名时显示「一位受益于你的同学」）、折算重量 kg、操作列「查看感谢信」按钮先占位禁用。
3. /me 顶部三张统计小卡：我发布的、我捐出的、我收到的，SQL 服务端算。
4. 抽一个 src/components/EmptyState.tsx，所有空态复用它。
5. tab 切换用 query 参数（/me?tab=fav），不要纯客户端 state，保证刷新后还在原 tab。
验收标准：四个 tab 数据与库一致，操作后状态即时更新，刷新不丢 tab。
```
**验收**：R5 跑完的那笔捐赠出现在台账里；未登录访问 `/me` 跳登录。
```bash
git add -A && git commit -m "feat: 个人中心四视图与捐赠台账 (R6)"
```

---

## R7｜物品维度站内私信

```text
1. GET /api/items/[id]/messages：返回当前用户与对方（物品主人 或 已 approved 的申领人）在该物品下的消息，时间升序。POST 发送：校验请求者确实是这两个角色之一，内容非空且 ≤500 字，写入 messages。
2. 详情页右下「联系 TA」打开右侧抽屉对话面板，30 秒 setInterval 轮询刷新，组件卸载清定时器。本轮不做 WebSocket。
3. 气泡样式：自己 bg-blush、对方 bg-panel 带边框，时间戳小字居中，圆角用 rounded-card-sm，面板有阴影 shadow-lift。
4. 抽屉里输入框回车即发，发送中禁用按钮。
验收标准：两个账号互相收发，刷新不丢消息，非相关人调接口 403。
```
**验收**：A/B 互发各一条，`select * from messages` 两条；用第三个账号调该接口返回 403。
```bash
git add -A && git commit -m "feat: 物品维度站内私信抽屉 (R7)"
```

---

## R8｜帮扶审核、捐赠优先曝光与种子数据

```text
1. /me/aid 帮扶资格申请表单：reason 必填 ≥20 字，proof_note 选填；提交写 aid_applications(status=pending) 并把 users.is_aid_approved 置 2；页面显示当前状态。
2. /admin/aid 管理员列表：pending 排前，通过/驳回按钮；通过后 users.is_aid_approved=1 并回写 reviewed_by/reviewed_at。所有 /api/admin/** 走 requireAdmin。
3. src/server/donate-boost.ts：输入 viewerId，输出 donate 物品的排序权重（通过审核的帮扶生权重更高），/donate 公益专区页与 R12 的检索都复用它，不要两处各写一遍。
4. /donate 页：只列 mode=donate 且 status=listed，帮扶生视角 donate 置顶且顶部显示「你已通过帮扶资格审核，这些物资优先向你开放」。
5. src/server/seed.ts（.mts 入口或加 npm run seed 脚本，注意 Node 直跑用 .mts）：灌 1 个管理员 + 3 个毕业生 + 3 个新生（其中 1 个 is_aid_approved=1）、24 件物品覆盖 7 个类别与 sale/donate 混合、若干 completed 记录并配套 donations、若干收藏与消息。密码统一 123456。图片用 public/uploads 下的渐变 SVG 占位图（自己生成 8 张）。幂等：先清空业务表再插。
6. README 补一节「演示账号」表格。
验收标准：npm run seed 后首页有 24 件；帮扶生账号与普通账号在 /donate 看到的顺序不同。
```
**验收**：`npm run seed` 可重复执行两次不报错；用帮扶生账号和普通账号分别打开 `/donate` 对比顺序。
```bash
git add -A && git commit -m "feat: 帮扶资格审核、捐赠优先曝光与演示种子数据 (R8)"
```

---

## R9｜百炼调用底座与 AI 留痕

```text
1. src/lib/ai/client.ts：用已装的 openai SDK，baseURL 与 apiKey 从 process.env 读（DASHSCOPE_BASE_URL / DASHSCOPE_API_KEY），导出 chat({model,messages,maxTokens}) 与 embed({model,texts})。AbortController 15s 超时；失败抛出带 kind 字段的错误对象：api_error | timeout | parse_error。
2. src/lib/ai/log.ts：logAiCall({feature,model,userId,refItemId,prompt,raw,parsed,latencyMs,status}) 写 ai_call_logs；feature 枚举含 analyze/search/moderate/letter/report/embed。另导出 getRecentCalls(feature,limit)。
3. src/lib/ai/prompts.ts：本轮只放 SYSTEM_BASE 常量（角色：校园闲置物品信息整理助手；必须只输出 JSON；禁止编造图片中不存在的品牌、版本、型号；中文），以及 buildAnalyzePrompt 的空占位导出。
4. src/lib/ai/json.ts：safeParseJson(raw) 处理三种脏情况——被 ```json 代码块包裹、前后夹带解释文字、字段缺失；解析失败返回 null 不抛异常。
5. src/lib/ai/withAiLog.ts：高阶函数，统一负责计时、落库、错误转成降级响应，业务路由里不写重复 try/catch。
6. GET /api/ai/health：要求登录，让 qwen-plus 回 "ok"，返回 { ok, model, latencyMs }。
7. 加一个 src/app/api/ai/_demo 路由跑通 withAiLog，验证留痕写入。
验收标准：配好 key 后 /api/ai/health 返回 ok，ai_call_logs 有记录；把 key 改错，接口返回结构化的 api_error 而不是 500 堆栈。
```
**验收**：`.env.local` 填 key 后浏览器打开 `http://localhost:3000/api/ai/health` 返回 ok；`select feature,model,status,latency_ms from ai_call_logs order by id desc limit 5` 有数据。**这一轮必须录屏**（终端里贴 prompt 让它写 + 跑通的样子）。
```bash
git add -A && git commit -m "feat: 百炼调用底座、超时降级与 ai_call_logs 留痕 (R9)"
```

---

## R10｜VLM 识图 + 文案 + 成色

```text
实现 POST /api/ai/analyze 的图像理解部分，不含估价。
1. buildAnalyzePrompt(rawDesc, mode) 返回 messages：system 用 SYSTEM_BASE；user 为多模态数组 [image_url(dataURL), text(指令)]。
2. 指令要求严格输出 JSON：{"category":"textbook|bedding|stationery|appliance|daily|clothing|other","conditionLevel":"95新|9成新|8成新|可用","title":"不超过22字","aiDesc":"60-110字","tags":["3-6个"]}，并在 prompt 里给两条少样本示例（教材、台灯），明确「只描述图片与描述中确实存在的信息，看不清就不要编品牌」。
3. 调 VLM_MODEL（qwen-vl-max），safeParseJson 解析，枚举值白名单校验，非法值降级为 other / 可用；解析失败 status=parse_error 且返回 502 degraded=true。
4. 前端上传前用 canvas 把图压到最长边 1024px、jpeg 质量 0.8 再转 dataURL，减少 token 和耗时。
5. 接上 /publish 第二步的「AI 帮我完善」：点击后按钮禁用 + 文案「AI 正在识别…」+ 骨架屏，回填各字段；每个被 AI 填过的字段右上角显示「AI」小徽章，用户手动改动后徽章变「已修改」并把 ai_edited 置 2。
6. 失败时提示「AI 暂不可用，已保留手动填写」，表单仍可提交。
验收标准：真拍一张课本照片能出合理类别成色；断 key 时仍能手动发布。
```
**验收**：拍一张实物图试 3 次，`category` 与成色不离谱；把 `DASHSCOPE_API_KEY` 改成乱码，发布流程仍然走得通。**录屏这段 + 保留失败那次的终端输出，后面修 bug 卡 B3 要用。**
```bash
git add -A && git commit -m "feat: qwen-vl-max 识图生成类别成色与文案 (R10)"
```

---

## R11｜参考定价与公益标签

```text
给 analyze 补估价，禁止调用任何外部行情接口。
1. src/server/price-stats.ts：getCategoryPriceStats(category) 用 SQL 聚合同类目 status='completed' 且 mode='sale' 的 price，返回 { count, avg, min, max }；count<3 时 insufficient=true。
2. src/lib/ref-price.ts：内置参考折扣表（教材按原价 3 折、小家电 5 折、被褥 2 折等），文件顶部注释写明「经验参考值，非实测数据」。
3. buildAnalyzePrompt 增加上下文段：样本充足时注入「本校同类目历史成交：N 件，均价 X 元，区间 [min,max]」；不足时注入参考折扣表并说明样本不足。
4. 输出 JSON 增加 "priceRange":{"low","high","suggested"} 与 "priceReason"（≤40 字，说明依据）。
5. mode=donate 时不估价，改生成 "donateTag"（8-16 字，积极不煽情，如「教材援助 · 让知识继续流转」）。
6. 前端：价格输入框下方画参考区间条（low→high 渐变，suggested 打点，点击填入价格）；捐赠模式隐藏价格、显示 AI 公益标签。
验收标准：seed 数据下 textbook 有成交记录时返回区间合理且 priceReason 引用了这些数字。
```
**验收**：故意把某类物品在库里改成有 5 条 completed sale 记录，再发布同类物品，看 `priceReason` 是否引用了均价区间（这证明估价走的是你的数据、不是模型瞎猜）。
```bash
git add -A && git commit -m "feat: 基于校内成交聚合与参考折扣的 AI 估价 (R11)"
```

---

## R12｜向量化与语义检索

```text
1. src/lib/ai/embed.ts：embedItem(itemId) 把 title + ai_desc + raw_desc + category + condition_level + ai_tags 拼成一段文本，调 EMBEDDING_MODEL（text-embedding-v3，1024 维），Float32Array→Buffer 存 items.embedding 与 embedded_at。feature 用 'embed' 落 ai_call_logs。
2. src/lib/ai/vector.ts：serializeVector / deserializeVector / cosineSimilarity 三个纯函数；tests/vector.test.ts 用 node:test 覆盖同向=1、正交=0、零向量不崩。
3. src/server/retrieval.ts：searchItems(queryVec, { topK, viewerId }) —— 载入所有 status='listed' 且 embedding 非空的物品，算余弦相似度，业务加权：donate +0.15；viewer 为 is_aid_approved=1 时对 donate 再 +0.30（复用 src/server/donate-boost.ts，不要重写规则）；返回带 similarity 与 matchLabel（≥0.75 高度匹配 / ≥0.6 较匹配 / 其他 相关）。
4. POST /api/ai/search：query 向量化 → searchItems → Top-8 交给 qwen-plus 生成 60-100 字导购语（prompt 里写死「只能依据给到的物品事实，不得承诺库存与价格，不得编造」）→ 返回 { guide, items }。
5. /search 页：顶部 AI 导购卡片（打字机逐字效果，纯 CSS/JS），下方复用 ItemCard 并在右上角显示匹配度百分比；无结果时显示放宽建议 + /donate 入口。
6. 发布成功后服务端自动 embedItem；用户改了 title 或描述时置空 embedded_at，列表渲染时对缺向量的记录串行补算且不阻塞响应。
验收标准：搜「有没有便宜点的高数课本」能召回教材；同一句 query 用帮扶生账号搜，donate 结果排前。
```
**验收**：跑两个账号对比排序；`select count(*) from items where embedding is not null` 应等于已发布数。**这是答辩演示的关键一段，录屏。**
```bash
git add -A && git commit -m "feat: 物品向量化与语义检索召回（含帮扶加权） (R12)"
```

---

## R13｜违规内容审核

```text
1. POST /api/ai/moderate：入参 title/desc/image(可选)。有图用 qwen-vl-max，无图用 qwen-plus，严格输出 {"pass":true|false,"category":"ok|prohibited|dangerous|medical|animal|indecent|offcampus","reason":"不超过50字","confidence":0-1}。
2. prompt 里列明平台规则：仅限校内自用闲置；禁止药品与医疗器械、管制刀具与易燃易爆、活体动物、涉黄涉政；疑似校外批量倒卖（一次挂大量全新同款）需人工复核。要求 reason 指出命中了哪条规则。
3. src/lib/banned-terms.ts 本地关键词表兜底：命中直接拦截，不依赖模型可用性；模型结果与本地结果冲突时以严格的一方为准，并在 ai_call_logs 的 parsed_result 里记下冲突。
4. 接入发布：提交前先 moderate，pass=false 时阻断发布、展示类别与原因、允许修改后重试；模型 api_error/timeout 时放行但 items.violation_flag=2 标记待人工复核。
5. /admin/violations 列表：violation_flag>0 的物品 + AI 理由 + 命中的本地关键词，提供「人工下架 / 恢复上架」按钮（改 status 与 violation_flag），走 requireAdmin。
验收标准：描述写「转让一盒处方消炎药」被拦截；把 key 改错后正常物品仍能发布且 violation_flag=2。
```
**验收**：三种情况各测一次——正常放行 / 药品拦截 / 断 key 后放行且标记为 2。
```bash
git add -A && git commit -m "feat: AI 违规审核 + 本地关键词兜底与人工复核 (R13)"
```

---

## R14｜捐赠电子感谢信

```text
1. POST /api/ai/letter：入参只有 { donationId }，物品名、捐赠人昵称、受赠人信息由服务端自查 donations/items/users 组装，不接受前端传隐私字段。requireLogin 且只有 donor 或 receiver 或 admin 能触发。
2. prompt 约束：200-300 字，收信人是捐赠人，落款「校园闲置物资循环平台 + 日期」；语气平视真诚不煽情；禁止出现「贫困/困难/资助」等标签化词；禁止透露受赠人姓名、学院等可识别信息；receiver_anonymous=1 时以「一位受益于你的同学」自称。
3. 结果写 letters 表，donation_id 唯一，重复请求返回已存在的那封（幂等，不重复消耗 API）。
4. /letters/[id] 信纸展示页：米白底、衬线字体、轻阴影、顶部平台徽章，右上「下载为图片」用 canvas 导出 PNG。
5. 捐赠完成时自动触发一次生成；/me/donations 台账的「查看感谢信」按钮解禁并跳转该页。
验收标准：完成一笔捐赠后能打开信并导出 PNG；再点一次不重复生成（letters 表仍只有一条）。
```
**验收**：`select count(*) from letters where donation_id=X` 触发两次后仍是 1。
```bash
git add -A && git commit -m "feat: 电子感谢信生成与信纸展示导出 (R14)"
```

---

## R15｜Prompt 历史快照导出（比赛材料）

```text
1. /admin/ai-logs 页：按 feature 筛选 ai_call_logs，表格显示时间、功能、模型、耗时、状态；点开一行用 pre 保留换行显示 prompt_text 与 response_text 原文。
2. GET /api/admin/ai-logs/export?format=json|csv：导出全部留痕，列含 feature/model/prompt_text/response_text/parsed_result/latency_ms/status/created_at，CSV 加 UTF-8 BOM。
3. scripts/export-prompts.mjs：把 ai_call_logs 按 feature 分组，生成 docs/ai-prompt-history.md，每个功能一节，按时间顺序列出 prompt 与响应，并在每节顶部统计调用次数、成功率、平均耗时。
4. README 增加「如何导出 AI 协同过程证据」一节，写清这条命令。
验收标准：跑一遍发布+搜索+审核+感谢信后执行脚本，md 里能看到 5 类功能的完整 prompt 链。
```
**验收**：`node scripts/export-prompts.mjs` 生成的 [docs/ai-prompt-history.md](file:///C:/Users/嘿嘿/Documents/Qoder/2026-10-31/f14fcb0a/campus-cycle/docs/ai-prompt-history.md) 里 prompt 原文完整、不是摘要。**这个文件就是比赛要交的 Prompt 历史快照，别丢。**
```bash
git add -A && git commit -m "feat: AI 留痕导出与 Prompt 历史快照生成脚本 (R15)"
```

---

## R16｜统计聚合接口

```text
1. src/server/stats.ts：getOverview() 返回 { totalItems, completedItems, saleCount, donateCount, activeUsers, aidedStudents, greenWeightKg, co2SavedKg }，全部 SQL 服务端算。
2. getMonthlyTrend(months=6) 按 strftime('%Y-%m', created_at) 分组统计完成流转件数；getCategoryDistribution()；getModeSplit()。
3. 环保折算复用 src/lib/green-factors.ts，返回值附 formula 字符串字段写明口径与「参考估算值」，前端 tooltip 与技术文档都引用它。
4. GET /api/stats/overview 走 requireAdmin。
5. tests/stats.test.ts：断言 donateCount 与 donations 行数一致、co2SavedKg 与手算一致（用固定 seed 数据）。
验收标准：npm test 全绿；数字与手工 SQL 查询一致。
```
**验收**：`select count(*) from donations` 与接口返回的 donateCount 对得上。
```bash
git add -A && git commit -m "feat: 平台统计聚合接口与环保折算口径 (R16)"
```

---

## R17｜管理端环保数据看板

```text
1. /admin 页：顶部 4 张指标卡（累计流转件数 / 捐赠件数 / 节约纸张 kg / 减碳 kg），粉彩渐变底 + 数字滚动动画（requestAnimationFrame 自己写，不引动画库）。
2. npm i echarts，客户端组件 src/components/charts/ 下四个图：月度趋势折线（渐变面积）、类别分布环形、转售 vs 捐赠横向柱、学院受益人数条。配色只用 bg-blush/bg-sky/bg-lilac 同色系，网格线极淡，tooltip 圆角卡片。
3. 桌面 2×2 栅格，移动端单列。
4. 数据由服务端组件查好后作为 props 传进图表组件，不要在浏览器里再 fetch 一次。
5. 页底放「一键生成环保报告」按钮，本轮先禁用。
验收标准：看板数字与 /api/stats/overview 一致，缩窗口图表重排不错位。
```
**验收**：把浏览器缩到手机宽度看图表是否重排；控制台无 ECharts 警告。
```bash
git add -A && git commit -m "feat: 管理端环保数据看板（ECharts 四图） (R17)"
```

---

## R18｜AI 环保报告与台账导出

```text
1. POST /api/ai/report：无入参，服务端取 R16 的统计结果，把数字以 JSON 塞进 prompt，要求 qwen-plus 输出 600-900 字 Markdown 报告，结构为 概述 / 数据事实 / 公益成效 / 改进方向。
2. prompt 硬约束：所有数字必须原样引用给到的 JSON，禁止新增或推算任何未提供的数据，不得虚构学校名称与个人姓名。
3. 服务端拿到结果后做一次数字比对：报告里出现的每个数字都要能在源数据里找到，找不到就 status=parse_error 并返回错误，不展示可疑内容。
4. /admin/report 页渲染 Markdown（粉彩信纸卡片），提供「导出 PDF」= 浏览器打印样式，@media print 隐藏导航与按钮。
5. GET /api/admin/donations/export.csv：UTF-8 BOM，列含日期、物品、类别、捐赠人、受赠人（匿名处理）、折算重量。
6. 解禁 R17 的「一键生成环保报告」按钮。
验收标准：生成的报告里数字与看板一致，改一个源数字后报告跟着变。
```
**验收**：故意在 prompt 外塞一个假数字测试比对逻辑是否拦得住（拦不住就进 B3）。
```bash
git add -A && git commit -m "feat: AI 环保报告生成与台账 CSV 导出 (R18)"
```

---

## R19｜全局体验、加载态与移动端

```text
1. 抽 src/components/ui/ 基础件：Button（主/次/危险三态，hover 上浮）、Card（三层圆角）、Badge、Input、Select、Modal、Toast、Skeleton、EmptyState（已有则合并）。全部用 globals.css 的主题令牌，不写死十六进制。
2. 路由切换顶部细进度条；所有 AI 请求期间按钮禁用 + 「AI 正在思考…」三点跳动。
3. app/error.tsx 与 app/global-error.tsx：粉彩插画 + 重试按钮；not-found.tsx 定制。
4. 移动端：导航折叠为底部标签栏（首页 / 发布 / 公益 / 我的），列表单列，私信抽屉全屏。
5. 无障碍：图片 alt、按钮 aria-label、表单 label 关联、focus 可见样式。
验收标准：手机尺寸（375px）能走完发布→搜索→申领全流程。
```
**验收**：Chrome 设备模拟器 375×667 走一遍主流程；Tab 键能顺序聚焦。
```bash
git add -A && git commit -m "feat: 统一 UI 组件、异常态与移动端适配 (R19)"
```

---

## R20｜安全与健壮性复查（要求它先列问题再改）

```text
本轮先只输出「发现的问题清单 + 每条的改法」，我确认后你再改代码。逐条检查：
1. 所有写接口是否 requireUser/requireAdmin；有无越权（改别人的物品、读别人的私信、用别人的 donationId 生成感谢信）。
2. SQL 是否全参数化；LIKE 是否转义 % 与 _；动态字段名是否走白名单。
3. 上传是否类型 + 大小双校验、随机文件名、读取 image_path 时是否防路径穿越。
4. cookie 是否 httpOnly + sameSite；SESSION_SECRET 缺失是否启动即失败。
5. AI 接口是否有按 userId 的内存限流（每分钟 N 次，超限 429）；没有就加。
6. 对外错误响应是否泄漏堆栈、SQL 片段、绝对路径。
7. 是否存在把 API Key 或 prompt 里含隐私内容返回给前端的地方。
```
**验收**：它给的清单里如果一条问题都没有，说明没真查——追问「items 详情接口能不能通过改 id 读到别人的私有数据？给出证据」。
```bash
git add -A && git commit -m "fix: 越权校验、上传与 SQL 加固、AI 接口限流 (R20)"
```

---

## R21｜README 十分钟复现指南

```text
重写 README.md，评委要在 10 分钟内跑起来，严格按此结构：
1. 一句话简介 + 3 张界面截图（我稍后放到 public/screenshots，你留占位与命名规范）。
2. 环境要求：Node ≥ 20，只需 npm。说明 better-sqlite3 自带各平台预编译二进制，npm install 时若出现 install-scripts 警告可忽略，不需要 Visual Studio 编译工具链。
3. 五步跑通：git clone → npm install → cp .env.example .env.local 并填 DASHSCOPE_API_KEY → npm run migrate && npm run seed → npm run dev。每步给 PowerShell 与 macOS/Linux 两版整行命令。
4. 演示账号表格（管理员/毕业生/新生/帮扶生，密码 123456）。
5. 功能地图：哪个页面对应哪个 AI 能力；建议演示顺序（3 分钟速览版 + 8 分钟完整版）。
6. 无 API Key 的降级说明：哪些功能仍可用。
7. 架构说明：为什么用 SQLite + 内存余弦检索而不是 Chroma/pgvector（物品量级、复现成本、评委环境），以及 ai_call_logs 作为可复现证据链的设计。
8. 目录结构树。
9. 已知限制：无支付、无物流、审核有兜底、环保系数为参考估算值。
10. 如何导出 AI 协同过程证据（R15 脚本）。
```
**验收**：你自己照 README 从 `git clone` 开始跑一遍，卡在任何一步就是它写错了。
```bash
git add -A && git commit -m "docs: 十分钟复现指南与演示动线 (R21)"
```

---

## R22｜演示脚本与答辩素材

```text
1. docs/demo-script.md：8 分钟演示逐段脚本（每段说什么、点哪里、预期 AI 输出、失败时的备用路径）。
2. docs/技术文档大纲.md：按比赛三章要求写 —— ①意图控制策略（prompt 如何设计、如何强制 JSON、如何迭代修 bug，从 docs/ai-prompt-history.md 引 3 个真实前后对比）②架构设计（分层、数据流、为什么这样解耦、如何约束 AI 生成的代码）③可复现性论证（git 提交链、ai_call_logs、seed 数据、环境变量清单）。
3. docs/申报书素材.md：创新点 3 条、社会价值 3 条（可量化）、落地可行性 2 条、与商业二手平台差异 4 条。
4. docs/ppt-outline.md：12 页大纲，每页标题 + 3 个要点 + 建议配图。
5. 所有材料里对齐官方赛题话术：本作品属方向 6「校园/垂直社区全栈 MVP 平台」，兼方向 2「场景化轻量 RAG 知识库」与方向 3「多模态创意与微工具工坊」。
```
**验收**：技术文档大纲里的数字与截图必须能在系统里复现，不能有一句编的。
```bash
git add -A && git commit -m "docs: 演示脚本、技术文档大纲与答辩素材 (R22)"
```

---

# 插播卡（随时用，用完回到主线）

## B1｜通用修 bug 卡

```text
页面出问题了。先不要改代码。
现象：______（我做了什么、看到什么、期望什么）
终端/控制台原文：
______（整段粘贴，不要转述）
请回答：①你判断的根因是什么，定位到具体文件与行号；②需要我补充什么信息才能确认；③给我最小改动方案，不要重写整个文件。
```
确认根因后接着贴：

```text
按你的方案改，只改这一处。改完为这个 bug 补一个测试用例或断言，防止回归。
然后检查代码里是否还有同类写法，只列出来，先不要动。
```
最后一定要贴这段（这段是给你写技术文档用的，也是评委要看的"人的判断"）：

```text
用 3 句话总结：这个 bug 属于哪类问题（类型 / 边界 / 时序 / 环境配置），我作为开发者做对了哪一步判断，你的哪一次修正是无效的。我要写进比赛技术文档的「意图控制策略」章节。
```
```bash
git add -A && git commit -m "fix: ______（一句话说清症状，不要写 fix bug）(B1)"
```

## B2｜越权 / 安全类

```text
怀疑存在越权：______（例：未登录能调 /api/items；A 能改 B 的物品；改 URL 里的 id 就能看到别人的私信）。
1. 先写出复现步骤（含 curl 命令），确认问题真实存在，不要直接改。
2. 再全仓扫一遍所有 /api/** 路由，列出每个路由的鉴权与归属校验现状，做成表格。
3. 按表格逐条修，每条修完说明改法。
4. 给 requireUser / requireAdmin 的用法补一条注释规范，并说明哪些接口是刻意公开的。
```

## B3｜AI 输出不稳定类

```text
模型返回不稳定：______（例：JSON 解析失败、成色乱填、导购语编造了不存在的物品、报告里出现没给过它的数字）。
1. 把 ai_call_logs 里最近 5 次该 feature 的 response_text 原文查出来给我看（写个临时脚本或 SQL 都行），先判断是格式问题还是内容问题。
2. 格式问题：改 safeParseJson 或改 prompt 的 schema 约束，二选一并说明为什么。
3. 内容问题：收紧 prompt（加禁止项 + 少样本 + 明确「不确定就返回默认值」），并在服务端加校验兜底，不要指望模型自觉。
4. 说明这次改动会不会影响已有的降级路径。
```

---

# 收尾清单（11-17 之前全部打勾）

- [ ] `git log --oneline` 有 20+ 条按轮次的细粒度提交
- [ ] 仓库设为 Public（GitHub 或 Gitee），或准备好评审访问权限
- [ ] `docs/ai-prompt-history.md` 含 ≥3 个核心功能的完整 Prompt 链
- [ ] README 五步复现，自己从零 clone 跑过一遍
- [ ] 5–8 分钟 1080p MP4，含 ≥2 分钟 AI 协同过程（B1 那几段）
- [ ] 技术文档 PDF ≤30 页（意图控制 / 架构设计 / 可复现性论证）
- [ ] 仓库里**没有** `.env.local`、没有真实 API Key、没有 `data/campus.db`
- [ ] 组别报错没报错（报错 = 取消资格）
- [ ] 11-18 前在官网个人中心提交（需先完成缴费）

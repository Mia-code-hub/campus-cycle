import { getDb } from "@/server/db";

function readDbState() {
  try {
    const db = getDb();
    const tables = (
      db
        .prepare(
          "SELECT count(*) AS c FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
        )
        .get() as { c: number }
    ).c;
    if (tables === 0) {
      return { ok: false, text: "数据库文件已创建，但还没有表 —— 执行 npm run migrate" };
    }
    const items = (db.prepare("SELECT count(*) AS c FROM items").get() as { c: number }).c;
    return { ok: true, text: `SQLite 已连接 · ${tables} 张表 · items 现有 ${items} 件物品` };
  } catch {
    return { ok: false, text: "SQLite 未连接" };
  }
}

const MODULES = [
  {
    title: "公益捐赠通道",
    desc: "闲置定向流转给通过审核的困难生，AI 生成捐赠标签与电子感谢信，全程留台账。",
    tone: "bg-blush/25 text-blush-deep",
  },
  {
    title: "AI 发布与语义找物",
    desc: "拍张照一句话，自动出类别、成色、文案与参考价；搜索按语义匹配而非关键词。",
    tone: "bg-lilac/30 text-lilac-deep",
  },
  {
    title: "环保数据看板",
    desc: "流转件数、捐赠占比、折算减碳量自动统计，一键生成校园循环环保报告。",
    tone: "bg-sky/30 text-sky-deep",
  },
];

export default function Home() {
  const db = readDbState();

  return (
    <main className="mx-auto flex w-full max-w-5xl flex-1 flex-col gap-10 px-6 py-14">
      <header className="flex flex-col gap-3">
        <span className="w-fit rounded-full bg-panel px-4 py-1 text-xs text-ink-soft shadow-soft">
          校内自用 · 线下自提 · 不涉及资金
        </span>
        <h1 className="text-4xl font-semibold tracking-tight">校园闲置物资循环 AI 平台</h1>
        <p className="max-w-2xl text-base leading-7 text-ink-soft">
          毕业季带不走的教材、被褥、台灯和小家电，不必直接丢弃。低价转售给需要的同学，或者捐给通过审核的困难新生。
        </p>
      </header>

      <section className="rounded-card-lg bg-panel p-6 shadow-soft">
        <div className="grid gap-4 sm:grid-cols-3">
          {MODULES.map((m) => (
            <article
              key={m.title}
              className="group rounded-card bg-cream/70 p-5 shadow-soft transition duration-200 hover:-translate-y-0.5 hover:shadow-lift"
            >
              <span
                className={`inline-block rounded-full px-3 py-1 text-xs font-medium ${m.tone}`}
              >
                模块
              </span>
              <h2 className="mt-3 text-lg font-semibold">{m.title}</h2>
              <p className="mt-2 text-sm leading-6 text-ink-soft">{m.desc}</p>
            </article>
          ))}
        </div>
      </section>

      <footer
        className={`w-fit rounded-card-sm px-4 py-2 text-sm shadow-soft ${
          db.ok ? "bg-sky/25 text-ink" : "bg-blush/30 text-ink"
        }`}
      >
        {db.text}
      </footer>
    </main>
  );
}

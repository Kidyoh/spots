/**
 * `spots analytics` — headline product metrics from the `events` table, read over
 * the RLS-bypassing CLI connection. For ad-hoc digging see packages/db/analytics.sql.
 *
 * Two accuracy fixes over naive coalesce(user_id, anon_id) counting (which
 * inflated MAU ~8x — most "actors" were one-hit anonymous ids):
 *  - identity stitching: an anon_id that ever co-occurred with a user_id is that
 *    user, so pre-sign-in / signed-out events don't mint a second actor.
 *  - bot filtering: events whose user_agent matches known crawlers/preview
 *    fetchers are dropped (rows with null UA — all pre-0021 history — are kept).
 *
 * Platform: the Flutter app (apps/mobile) writes the same events with a
 * user_agent starting "spots-app/", so web vs app is read off that prefix —
 * no schema change. `--platform app|web` narrows every number to one of them.
 */
import { defineCommand } from "citty";
import { consola } from "consola";
import { sql } from "drizzle-orm";
import { db } from "../db.ts";

const BOT_UA = "bot|crawl|spider|slurp|headless|facebookexternalhit|whatsapp|telegram|preview|python-requests|curl/";
/** Must match the prefix in apps/mobile/lib/data/analytics.dart. */
const APP_UA_PREFIX = "spots-app/%";
const PLATFORMS = ["all", "web", "app"] as const;

export const analyticsCommand = defineCommand({
  meta: { name: "analytics", description: "DAU/MAU and most-used features from the events table" },
  args: {
    days: { type: "string", description: "Look-back window in days (default 30)", default: "30" },
    platform: {
      type: "string",
      description: "all | web | app (the Flutter app) — default all",
      default: "all",
    },
  },
  run: async ({ args }) => {
    const days = Number(args.days) || 30;
    const since = sql.raw(`now() - interval '${days} days'`);
    const platform = String(args.platform) as (typeof PLATFORMS)[number];
    if (!PLATFORMS.includes(platform)) {
      consola.error(`--platform must be one of: ${PLATFORMS.join(", ")}`);
      process.exitCode = 1;
      return;
    }
    const platformFilter =
      platform === "all" ? sql`` : sql`and ${platform === "app" ? sql`` : sql`not `}(coalesce(e.user_agent, '') like ${APP_UA_PREFIX})`;

    // Shared CTE: `ev` is the window's events with a stitched actor id and bots
    // removed. Every query below reads from it so the numbers always agree.
    const ev = sql`
      with linked as (
        select anon_id, min(user_id) as user_id
        from events
        where anon_id is not null and user_id is not null
        group by 1
      ),
      ev as (
        select coalesce(e.user_id, l.user_id, e.anon_id) as actor,
               (e.user_id is not null or l.user_id is not null) as signed_in,
               case when e.user_agent like ${APP_UA_PREFIX} then 'app' else 'web' end as platform,
               e.name, e.created_at
        from events e
        left join linked l on l.anon_id = e.anon_id
        where e.created_at > ${since}
          and (e.user_agent is null or e.user_agent !~* ${BOT_UA})
          ${platformFilter}
      )
    `;

    // One distinct-actor count per active day, reused for the average and the
    // most-active-days list below. Averaging over active days (not all calendar
    // days) avoids understating a freshly-launched app whose window has empty days.
    const daily = (await db.execute(sql`
      ${ev}
      select date_trunc('day', created_at) as day,
             count(distinct actor)          as actors
      from ev
      group by 1
      order by day
    `)) as unknown as { day: string; actors: number }[];

    const avgDau = daily.length
      ? Math.round(daily.reduce((s, d) => s + Number(d.actors), 0) / daily.length)
      : 0;

    const rows = (await db.execute(sql`
      ${ev}
      select count(distinct actor)                            as mau,
             count(distinct actor) filter (where signed_in)   as signed_in_mau,
             count(*)                                         as events
      from ev
    `)) as unknown as { mau: number; signed_in_mau: number; events: number }[];
    const totals = rows[0] ?? { mau: 0, signed_in_mau: 0, events: 0 };

    const stickiness = totals.mau ? ((avgDau / totals.mau) * 100).toFixed(1) : "0";
    consola.box(
      [
        `Window:        last ${days} days${platform === "all" ? "" : `, ${platform} only`}`,
        `Avg DAU:       ${avgDau}  (mean over ${daily.length} active day${daily.length === 1 ? "" : "s"})`,
        `MAU:           ${totals.mau}  (${totals.signed_in_mau} signed in)`,
        `Stickiness:    ${stickiness}%  (avg DAU/MAU)`,
        `Events:        ${totals.events}`,
      ].join("\n"),
    );

    const topDays = [...daily].sort((a, b) => Number(b.actors) - Number(a.actors)).slice(0, 5);
    if (topDays.length) {
      consola.info("Most active days");
      for (const d of topDays) {
        const label = new Date(d.day).toISOString().slice(0, 10);
        consola.log(`  ${label}   ${d.actors} active user${Number(d.actors) === 1 ? "" : "s"}`);
      }
    }

    const features = (await db.execute(sql`
      ${ev}
      select name,
             count(*)              as events,
             count(distinct actor) as actors
      from ev
      group by name
      order by events desc
      limit 20
    `)) as unknown as { name: string; events: number; actors: number }[];

    if (features.length) {
      consola.info("Most-used features");
      for (const f of features) {
        consola.log(`  ${f.name.padEnd(20)} ${String(f.events).padStart(7)} events   ${f.actors} actors`);
      }
    } else {
      consola.info("No events recorded yet in this window.");
    }

    // Stitched: a person is "signed-in" if ANY of their events link to a user_id,
    // so nobody appears in both buckets.
    const audience = (await db.execute(sql`
      ${ev}
      select case when signed_in then 'signed-in' else 'anonymous' end as audience,
             count(*) as actors
      from (select actor, bool_or(signed_in) as signed_in from ev group by actor) a
      group by 1
      order by 2 desc
    `)) as unknown as { audience: string; actors: number }[];

    if (audience.length) {
      consola.info("Audience");
      for (const a of audience) consola.log(`  ${a.audience.padEnd(12)} ${a.actors} actors`);
    }

    // Web vs app. Someone who uses both counts once on each line, so the two
    // rows can add up to more than MAU.
    const platforms = (await db.execute(sql`
      ${ev}
      , per_day as (
        select platform, date_trunc('day', created_at) as day, count(distinct actor) as actors
        from ev group by 1, 2
      )
      select p.platform,
             count(distinct p.actor) as actors,
             count(*)                as events,
             (select round(avg(actors)) from per_day d where d.platform = p.platform) as avg_dau
      from (select platform, actor from ev) p
      group by p.platform
      order by actors desc
    `)) as unknown as { platform: string; actors: number; events: number; avg_dau: number | null }[];

    if (platforms.length) {
      consola.info("Platform (web site vs the app)");
      for (const p of platforms) {
        consola.log(
          `  ${p.platform.padEnd(5)} ${String(p.actors).padStart(6)} actors   ${String(p.events).padStart(7)} events   avg DAU ${p.avg_dau ?? 0}`,
        );
      }
    }
  },
});

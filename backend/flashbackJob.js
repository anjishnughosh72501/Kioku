// flashbackJob.js
// Runs once a day. For every group, picks a random handful of photos from
// "on this day" in past weeks/months/years and caches the selection so it
// stays stable for the whole day instead of re-randomizing on every open.

const cron = require('node-cron');
const { nanoid } = require('nanoid');
const db = require('./db');

const PERIODS = {
  weekly: 7,
  monthly: 30,
  yearly: 365,
};

function pickRandom(arr, n) {
  const copy = [...arr];
  const picked = [];
  while (copy.length && picked.length < n) {
    const idx = Math.floor(Math.random() * copy.length);
    picked.push(copy.splice(idx, 1)[0]);
  }
  return picked;
}

function generateForGroup(group, today) {
  Object.entries(PERIODS).forEach(([period, daysAgo]) => {
    const targetDate = new Date(today);
    targetDate.setDate(targetDate.getDate() - daysAgo);
    const windowStart = new Date(targetDate);
    windowStart.setDate(windowStart.getDate() - 2);
    const windowEnd = new Date(targetDate);
    windowEnd.setDate(windowEnd.getDate() + 2);

    const candidates = db
      .prepare(
        `SELECT id FROM media WHERE group_id = ? AND taken_at BETWEEN ? AND ?`
      )
      .all(group.id, windowStart.toISOString(), windowEnd.toISOString());

    if (candidates.length === 0) return;

    const chosen = pickRandom(candidates, 6).map((c) => c.id);
    const todayStr = today.toISOString().slice(0, 10);

    db.prepare(
      `INSERT OR REPLACE INTO flashbacks (id, group_id, period, generated_for, media_ids)
       VALUES (?, ?, ?, ?, ?)`
    ).run(nanoid(), group.id, period, todayStr, JSON.stringify(chosen));
  });
}

function runFlashbackGeneration() {
  const groups = db.prepare(`SELECT * FROM groups`).all();
  const today = new Date();
  let successCount = 0;
  for (const group of groups) {
    try {
      generateForGroup(group, today);
      successCount++;
    } catch (err) {
      console.error(`[flashbacks] Failed for group ${group.id} (${group.name}):`, err);
    }
  }
  console.log(`[flashbacks] generated for ${successCount}/${groups.length} group(s) at ${today.toISOString()}`);
}

function startFlashbackScheduler() {
  // Runs every day at 6am server time
  cron.schedule('0 6 * * *', runFlashbackGeneration);
  // Also run once on boot so there's always something to show
  runFlashbackGeneration();
}

module.exports = { startFlashbackScheduler, generateForGroup, runFlashbackGeneration };

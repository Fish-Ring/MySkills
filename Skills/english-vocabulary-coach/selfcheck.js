#!/usr/bin/env node
'use strict';

const path = require('path');

let db;
try {
    db = require(path.join(__dirname, 'db.js'));
} catch (e) {
    console.error('[FAIL] db.js 加载失败：' + e.message);
    console.error('排查：1) 确认本文件在技能目录内；2) 已安装 sqlite3 CLI（apt install sqlite3）；3) 必要时用 SQLITE3_BIN 指定 sqlite3 路径');
    process.exit(1);
}

function safe(label, fn) {
    try {
        return { [label]: fn() };
    } catch (e) {
        return { [label]: { error: e.message } };
    }
}

console.log(JSON.stringify({
    node: process.version,
    skill_dir: __dirname,
    ...safe('profile', () => db.getProfile()),
    ...safe('due_reviews', () => db.getDueReviews()),
    ...safe('today', () => db.getTodayStats())
}, null, 2));

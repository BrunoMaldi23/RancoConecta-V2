import assert from 'node:assert/strict';
import { execSync } from 'node:child_process';

const status = JSON.parse(execSync('npx -y supabase status -o json', {
  encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'],
}));
assert.match(status.API_URL, /^http:\/\/(127\.0\.0\.1|localhost):54321$/);

const response = await fetch(
  `${status.API_URL}/rest/v1/businesses?select=id,is_featured,accepts_requests,rating_avg,review_count&limit=1`,
  { headers: { apikey: status.ANON_KEY, Authorization: `Bearer ${status.ANON_KEY}` } },
);
assert.equal(response.status, 200, `Home query failed with HTTP ${response.status}`);
const rows = await response.json();
assert.ok(Array.isArray(rows), 'Home query did not return rows');
console.log(`Home schema contract: HTTP 200; ${rows.length} visible row(s)`);

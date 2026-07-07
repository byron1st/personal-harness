---
name: loki-log-search
description: Search and scan Grafana Loki logs for errors, panics, or anomalies over a time range via gcx api passthrough. Use whenever investigating recent logs or hunting what went wrong in a service on a Grafana + Loki stack, even if Loki/gcx/logs is not named explicitly.
---

# Loki log search (via gcx api passthrough)

Query Grafana-backed Loki without a browser. Discover the datasource, scan a time range for where errors cluster, then drill into the narrow window.

## Prerequisites

- `gcx` installed, with a context configured and current (check with `gcx config current-context`). Server URL and token come from the context — do NOT export `GRAFANA_SERVER`/`GRAFANA_TOKEN` or shell out to `curl`.
- `jq` on PATH (used for URL-encoding the query and for parsing responses).

## Critical rules (read before running anything)

1. **Use the classic REST API + Loki proxy via `gcx api`. Do NOT use the typed commands `gcx datasources list`, `gcx datasources query`, or `gcx logs query`.** On self-hosted Grafana the typed commands go through the newer app-platform API (`datasource.grafana.app`), which is frequently disabled by feature flag — they return *empty* results even when the data exists. The classic `/api/datasources` + `/api/datasources/proxy/...` path is what the Grafana MCP server uses and always works with the context's token.

2. **Never slurp days of raw logs into context.** Always do SCAN → DRILL: first aggregate with `count_over_time` to find *when* errors spike, then fetch raw lines only for that narrow window. Slurping breaks on Loki entry limits, is slow, and blows up the context window.

3. **Encode the LogQL value exactly once and embed it in the path.** `gcx api` has no `--data-urlencode`; it forwards the query string verbatim without re-encoding. So percent-encode only the query value with `jq -rn --arg q "$LOGQL" '$q|@uri'`, put it after `?query=`, and leave the structural `?`/`&`/`=` alone. Never encode the whole URL, and never encode twice.

## Step 1 — Resolve the Loki datasource UID

```bash
# List all datasources (classic API returns a JSON array).
gcx api /api/datasources -o json | jq -r '.[] | "\(.name)\t\(.type)\t\(.uid)"'

# Grab the UID for a known name (exact match):
LOKI_UID=$(gcx api /api/datasources -o json \
  | jq -r '.[] | select(.name=="Loki") | .uid')

# Or by type, if the name is unknown:
LOKI_UID=$(gcx api /api/datasources -o json \
  | jq -r 'map(select(.type=="loki")) | .[0].uid')

BASE="/api/datasources/proxy/uid/$LOKI_UID/loki/api/v1"
echo "$LOKI_UID"
```

If this array is empty or missing the datasource, it is an org/permission issue, not an encoding issue: confirm the token's org with `gcx api /api/org -o json` and that the service account has `datasources:read` plus per-datasource read permission.

## Step 2 — Verify the proxy works

```bash
gcx api "$BASE/labels"                       # should list stream labels
gcx api "$BASE/label/service/values"         # values for a label, to pick a selector
```

## Step 3 — SCAN: where do errors cluster?

`count_over_time` is a metric query, so use `query_range` with a `step` and read `.data.result[].values` (points are `[unixSeconds, "count"]`).

```bash
SEL='{service="foo"}'
LOGQL="count_over_time(${SEL} |~ \`(?i)\\b(error|panic|fatal|exception)\\b\` [1h])"

# Time window (GNU date shown; macOS/BSD alt in comment).
END=$(date -u +%Y-%m-%dT%H:%M:%SZ)
START=$(date -u -d '3 days ago' +%Y-%m-%dT%H:%M:%SZ)   # macOS: date -u -v-3d +%Y-%m-%dT%H:%M:%SZ
Q=$(jq -rn --arg q "$LOGQL" '$q|@uri')

gcx api "$BASE/query_range?query=$Q&start=$START&end=$END&step=1h" -o json \
| jq -r '.data.result[] | .metric as $m | .values[] | "\(.[0])\t\($m)\t\(.[1])"'
```

Identify the timestamp(s) with elevated counts. Those bound the drill window.

## Step 4 — DRILL: raw lines for the spike window

Plain stream selector → log query. `query_range` returns `resultType: "streams"`; each result has `.stream` (labels) and `.values` = `[[tsNanos, "line"], ...]`. Use `direction=backward` so newest lines come first.

```bash
LOGQL='{service="foo"} |~ `(?i)error`'
END=$(date -u -d '2026-07-02T03:15:00Z' +%Y-%m-%dT%H:%M:%SZ)   # spike end
START=$(date -u -d '2026-07-02T02:45:00Z' +%Y-%m-%dT%H:%M:%SZ) # spike start
Q=$(jq -rn --arg q "$LOGQL" '$q|@uri')

gcx api "$BASE/query_range?query=$Q&start=$START&end=$END&limit=200&direction=backward" -o json \
| jq -r '.data.result[].values[] | .[1]'
```

Then cluster similar messages and summarize (top error signatures, first/last occurrence, affected labels). Do not paste the full raw dump back to the user.

## Response-shape cheat sheet

- Log query  → `resultType: "streams"`, results carry `.stream`, values `[tsNanos, line]`.
- Metric query → `resultType: "matrix"`, results carry `.metric`, values `[tsSec, "val"]`.
- Instant "right now" query → `gcx api "$BASE/query?query=$Q"` (single `time` param, no start/end).

## Fallbacks / gotchas

- **Empty results everywhere** → org mismatch or missing RBAC. A service-account token is bound to the org it was created in; setting `org-id` in gcx config does not switch a SA token to another org. Confirm with `gcx api /api/org -o json`.
- **Verify encoding when a query misbehaves** → run `gcx -v api "$BASE/query_range?query=$Q&..."`; in the outgoing URL a `{` must appear as `%7B`. If you see `%257B`, it was double-encoded — drop a redundant `@uri` step (the query value should be encoded exactly once).
- **`--jq` shorthand** → `gcx api` accepts `--jq '<expr>'` to filter inline, so `... --jq '.data.result[].values[] | .[1]'` can replace the trailing `| jq` pipe. External `jq` is still needed for the `@uri` encoding step.
- Keep `limit` small (100–500). If truncated, narrow the time window rather than raising the limit.

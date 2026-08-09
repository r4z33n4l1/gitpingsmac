# Representative GraphQL cost projection (S1 worksheet)

Host: fixture math only — not measured against live GitHub.

Assumptions:

- Point limit: 5,000 points / hour (authenticated user-to-server typical).
- Search page size: 25 nodes.
- Nested fields: repository + head commit statusCheckRollup only.
- Rough document cost model used here: `1 + (nodes × field_weight)`.
  - Search page field_weight ≈ 3 (PR scalars + repo + rollup).
  - Viewer login ≈ 1.
  - Targeted `node(id:)` lookup ≈ 1–2.

## Scenario A — small personal install

| Dimension | Value |
| --- | --- |
| Selected repos | 3 |
| Enabled filters | authored + assigned + review-requested (3) |
| Matching PRs | ~15 total after merge |
| Search pages / filter | 1 |
| Polls / hour | 60 |

Estimated points / poll:

- viewer: 1
- 3 search pages × (1 + 25×3) ≈ 3 × 76 = 228 (upper bound if each page full)
- More realistic sparse pages (~5 nodes): 3 × (1 + 5×3) ≈ 48

Hourly (realistic): 60 × ~50 ≈ **3,000** → within limit with headroom.  
Hourly (pessimistic full pages): 60 × ~230 ≈ **13,800** → would require page-size tuning / backoff.

## Scenario B — org power user

| Dimension | Value |
| --- | --- |
| Selected repos | 40 (may need repo sharding) |
| Enabled filters | all four OR filters |
| Matching PRs | ~120 |
| Search pages / filter | 2 |
| Repo shards / filter | 2 (query length) |

Estimated points / poll (mid):

- 4 filters × 2 shards × 2 pages × (1 + 25×3) ≈ 16 × 76 ≈ **1,216**
- Hourly at 60s: far over budget → **must** lower cadence under rate-limit, reduce page size, or coalesce filters when `includeAllOpen` alone is sufficient.

## Controls required in production client

1. Prefer `includeAllOpen` alone when enabled (skip redundant actor queries).
2. Page size 25 default; raise only when cost allows.
3. Shard `repo:` qualifiers before hitting search query length limits.
4. Persist `RateLimitSnapshot`; exponential backoff on low remaining / Retry-After.
5. Coalesce refresh triggers (REFRESH-3) so popover/dashboard open does not multiply cost.

## Live measurement still required

Replace this worksheet with captured `rateLimit.cost` from a private org repo before Gate 0 closes GitHub feasibility.

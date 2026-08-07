# Online leaderboard plan

## Recommended approach

Use Godot's `HTTPRequest` node with a small Supabase backend. The game keeps the
current local leaderboard as an offline fallback and synchronizes scores when a
connection is available.

Official references:

- Godot HTTPRequest: https://docs.godotengine.org/en/latest/classes/class_httprequest.html
- Supabase anonymous users: https://supabase.com/docs/guides/auth/auth-anonymous
- Supabase Row Level Security: https://supabase.com/docs/guides/database/postgres/row-level-security
- Supabase Edge Functions: https://supabase.com/docs/guides/functions

## Why not write directly from the game

Anything stored inside a Windows executable can be inspected. The Supabase
publishable key may be included in the client, but a service-role key must never
be included. Clients should be allowed to read the ranking, while score writes
must pass through a server-side Edge Function.

No client-only leaderboard can be completely cheat-proof. The objective for
this project is to reject obvious forged scores and make automated abuse harder.

## Data model

```sql
create table public.leaderboard (
    id bigint generated always as identity primary key,
    player_id uuid not null references auth.users(id),
    initials text not null check (initials ~ '^[A-Z0-9-]{3}$'),
    score integer not null check (score >= 0),
    survival_time_ms integer not null check (survival_time_ms >= 0),
    wave integer not null check (wave >= 1),
    run_id uuid not null unique,
    game_version text not null,
    created_at timestamptz not null default now()
);

alter table public.leaderboard enable row level security;

create policy "Leaderboard is publicly readable"
on public.leaderboard for select
to anon, authenticated
using (true);
```

Do not create a direct INSERT policy for clients. The Edge Function writes the
validated result using its server-side credentials.

## Game flow

1. On first launch, create an anonymous Supabase account and save its refresh
   token in `user://`.
2. At the title screen, request the global top scores over HTTPS.
3. During a run, record a compact event summary: elapsed time, waves completed,
   enemies defeated, upgrades and score sources.
4. On Game Over, send the summary, initials, a random `run_id` and game version
   to the Edge Function.
5. The function validates ranges, rate limits the player, rejects duplicate
   `run_id` values and inserts the score.
6. If the request fails, keep the result locally and offer to retry later.

## Minimum server checks

- Initials must contain exactly three allowed characters.
- Score, survival time and wave must be non-negative and internally plausible.
- Reject scores above the maximum theoretically possible for the supplied run
  summary, with a small tolerance.
- Accept each `run_id` only once.
- Rate limit submissions per authenticated player and IP.
- Keep the server/service key only in the Edge Function.
- Store `game_version` so incompatible balance versions can use separate boards.

## Information needed before implementation

- Supabase project URL.
- Supabase publishable key (safe for a client when RLS is correctly configured).
- Confirmation that anonymous player accounts are enabled.
- Whether rankings are global forever or separated by game version/season.

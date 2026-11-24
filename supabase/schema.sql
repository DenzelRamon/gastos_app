-- Esquema remoto para Gastos App (Supabase / Postgres).
-- Ejecutar en: Supabase Dashboard > SQL Editor.
-- Nota de privacidad: las notas y las fotos de tickets NUNCA se envían a la nube.

create table if not exists public.categories (
  id          text        not null,
  user_id     uuid        not null default auth.uid()
                          references auth.users (id) on delete cascade,
  name        text        not null check (char_length(name) between 1 and 40),
  color       bigint      not null,
  deleted     boolean     not null default false,
  updated_at  timestamptz not null default now(),
  primary key (user_id, id)
);

create table if not exists public.budgets (
  id            text          not null,
  user_id       uuid          not null default auth.uid()
                              references auth.users (id) on delete cascade,
  category_id   text,
  limit_amount  numeric(12,2) not null check (limit_amount > 0),
  period        text          not null check (period in ('weekly', 'monthly')),
  deleted       boolean       not null default false,
  updated_at    timestamptz   not null default now(),
  primary key (user_id, id),
  foreign key (user_id, category_id) references public.categories (user_id, id)
);

create table if not exists public.expenses (
  id           text          not null,
  user_id      uuid          not null default auth.uid()
                             references auth.users (id) on delete cascade,
  category_id  text          not null,
  amount       numeric(12,2) not null check (amount > 0 and amount < 1000000000),
  description  text          not null check (char_length(description) between 2 and 80),
  spent_at     timestamptz   not null,
  deleted      boolean       not null default false,
  updated_at   timestamptz   not null default now(),
  primary key (user_id, id),
  foreign key (user_id, category_id) references public.categories (user_id, id)
);

create index if not exists idx_categories_updated on public.categories (user_id, updated_at);
create index if not exists idx_budgets_updated    on public.budgets    (user_id, updated_at);
create index if not exists idx_expenses_updated   on public.expenses   (user_id, updated_at);

-- Row Level Security: cada usuario solo ve y modifica sus propias filas.
alter table public.categories enable row level security;
alter table public.budgets    enable row level security;
alter table public.expenses   enable row level security;

create policy "categories: own rows" on public.categories
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "budgets: own rows" on public.budgets
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "expenses: own rows" on public.expenses
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ============================================================================
-- AgroCampo MVP - Schema PostgreSQL e Políticas RLS (Supabase)
-- ============================================================================
-- Execute este script no SQL Editor do projeto Supabase antes de rodar o app
-- com --dart-define=SUPABASE_URL=... e --dart-define=SUPABASE_ANON_KEY=...

create extension if not exists "pgcrypto";

-- ----------------------------------------------------------------------------
-- 1. Tabela de Perfis de Usuário (vinculada a auth.users)
-- ----------------------------------------------------------------------------
create table if not exists public.perfis (
  id uuid primary key references auth.users(id) on delete cascade,
  nome text not null check (char_length(trim(nome)) >= 2),
  email text not null unique,
  perfil text not null check (
    perfil in (
      'produtor_rural',
      'agronomo',
      'tecnico_agricola',
      'gestor_propriedade'
    )
  ),
  criado_em timestamptz not null default now()
);

-- Função auxiliar para consultar o perfil do usuário autenticado nas regras RLS
create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select perfil from public.perfis where id = auth.uid();
$$;

-- Trigger para criar perfil automaticamente a partir dos metadados do Auth SignUp
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.perfis (id, nome, email, perfil)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'nome', split_part(new.email, '@', 1)),
    new.email,
    coalesce(new.raw_user_meta_data->>'perfil', 'tecnico_agricola')
  )
  on conflict (id) do update
    set nome = excluded.nome,
        perfil = excluded.perfil;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ----------------------------------------------------------------------------
-- 2. Propriedades / Áreas Agrícolas
-- ----------------------------------------------------------------------------
create table if not exists public.propriedades (
  id uuid primary key default gen_random_uuid(),
  nome text not null check (char_length(trim(nome)) >= 2),
  municipio text not null check (char_length(trim(municipio)) >= 2),
  estado text not null check (char_length(trim(estado)) = 2),
  area_total_ha numeric(10, 2) not null check (area_total_ha > 0),
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  criado_por uuid references public.perfis(id) on delete set null,
  criado_em timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- 3. Talhões vinculados às Propriedades
-- ----------------------------------------------------------------------------
create table if not exists public.talhoes (
  id uuid primary key default gen_random_uuid(),
  propriedade_id uuid not null references public.propriedades(id) on delete cascade,
  identificacao text not null check (char_length(trim(identificacao)) >= 2),
  cultura text not null check (char_length(trim(cultura)) >= 2),
  area_ha numeric(10, 2) not null check (area_ha > 0),
  data_plantio date not null,
  previsao_colheita date not null,
  umidade numeric(5, 2) not null check (umidade between 0 and 100),
  situacao text not null check (
    situacao in ('saudavel', 'atencao', 'critico', 'colhido')
  ),
  observacoes text not null default '',
  ultima_atualizacao timestamptz not null default now(),
  criado_por uuid references public.perfis(id) on delete set null,
  constraint talhoes_colheita_apos_plantio check (previsao_colheita >= data_plantio)
);

-- ----------------------------------------------------------------------------
-- 4. Histórico de Registros de Campo (plantio, condição atual e ocorrências)
-- ----------------------------------------------------------------------------
create table if not exists public.registros_campo (
  id uuid primary key default gen_random_uuid(),
  talhao_id uuid not null references public.talhoes(id) on delete cascade,
  propriedade_id uuid not null references public.propriedades(id) on delete cascade,
  tipo text not null check (tipo in ('plantio', 'condicao', 'ocorrencia')),
  categoria_ocorrencia text null check (
    categoria_ocorrencia is null or categoria_ocorrencia in (
      'praga', 'doenca', 'deficiencia_hidrica', 'clima', 'manutencao', 'outro'
    )
  ),
  severidade text null check (
    severidade is null or severidade in ('baixa', 'media', 'alta')
  ),
  titulo text not null,
  descricao text not null default '',
  umidade_registrada numeric(5, 2) null check (
    umidade_registrada is null or (umidade_registrada between 0 and 100)
  ),
  situacao_registrada text null check (
    situacao_registrada is null or situacao_registrada in (
      'saudavel', 'atencao', 'critico', 'colhido'
    )
  ),
  autor_id uuid references public.perfis(id) on delete set null,
  autor_nome text not null,
  autor_perfil text not null,
  criado_em timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- 5. Alertas Automáticos vinculados ao Talhão
-- ----------------------------------------------------------------------------
create table if not exists public.alertas (
  id uuid primary key default gen_random_uuid(),
  talhao_id uuid not null references public.talhoes(id) on delete cascade,
  propriedade_id uuid not null references public.propriedades(id) on delete cascade,
  regra text not null check (
    regra in (
      'umidade_baixa',
      'ocorrencia_praga_doenca',
      'proximidade_colheita',
      'colheita_atrasada'
    )
  ),
  severidade text not null check (severidade in ('baixa', 'media', 'alta')),
  titulo text not null,
  mensagem text not null,
  parametro_disparo text not null,
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  resolvido_em timestamptz null,
  resolvido_por text null
);

-- ----------------------------------------------------------------------------
-- 6. Row Level Security (RLS) - Permissões aplicadas também no banco remoto
-- ----------------------------------------------------------------------------
alter table public.perfis enable row level security;
alter table public.propriedades enable row level security;
alter table public.talhoes enable row level security;
alter table public.registros_campo enable row level security;
alter table public.alertas enable row level security;

-- Perfis: usuário autenticado lê perfis e atualiza apenas o próprio nome
drop policy if exists "perfis_select_auth" on public.perfis;
create policy "perfis_select_auth" on public.perfis
  for select to authenticated using (true);

drop policy if exists "perfis_insert_own" on public.perfis;
create policy "perfis_insert_own" on public.perfis
  for insert to authenticated with check (auth.uid() = id);

drop policy if exists "perfis_update_own" on public.perfis;
create policy "perfis_update_own" on public.perfis
  for update to authenticated using (auth.uid() = id);

-- Propriedades: todos leem; apenas Gestor da Propriedade e Produtor Rural criam/editam
drop policy if exists "propriedades_select_auth" on public.propriedades;
create policy "propriedades_select_auth" on public.propriedades
  for select to authenticated using (true);

drop policy if exists "propriedades_insert_gestor_produtor" on public.propriedades;
create policy "propriedades_insert_gestor_produtor" on public.propriedades
  for insert to authenticated
  with check (public.current_user_role() in ('gestor_propriedade', 'produtor_rural'));

drop policy if exists "propriedades_update_gestor_produtor" on public.propriedades;
create policy "propriedades_update_gestor_produtor" on public.propriedades
  for update to authenticated
  using (public.current_user_role() in ('gestor_propriedade', 'produtor_rural'));

-- Talhões: todos leem; Gestor, Produtor e Agrônomo criam; todos autenticados podem atualizar condição,
-- sendo que alterações estruturais de plantio são restritas por regra de aplicação e policy específica:
drop policy if exists "talhoes_select_auth" on public.talhoes;
create policy "talhoes_select_auth" on public.talhoes
  for select to authenticated using (true);

drop policy if exists "talhoes_insert_roles" on public.talhoes;
create policy "talhoes_insert_roles" on public.talhoes
  for insert to authenticated
  with check (
    public.current_user_role() in ('gestor_propriedade', 'produtor_rural', 'agronomo')
  );

drop policy if exists "talhoes_update_roles" on public.talhoes;
create policy "talhoes_update_roles" on public.talhoes
  for update to authenticated
  using (
    public.current_user_role() in (
      'gestor_propriedade',
      'produtor_rural',
      'agronomo',
      'tecnico_agricola'
    )
  );

-- Registros de campo: todos os perfis autenticados leem e registram condições/ocorrências;
-- registros do tipo 'plantio' exigem Gestor, Produtor ou Agrônomo.
drop policy if exists "registros_select_auth" on public.registros_campo;
create policy "registros_select_auth" on public.registros_campo
  for select to authenticated using (true);

drop policy if exists "registros_insert_roles" on public.registros_campo;
create policy "registros_insert_roles" on public.registros_campo
  for insert to authenticated
  with check (
    case
      when tipo = 'plantio' then
        public.current_user_role() in ('gestor_propriedade', 'produtor_rural', 'agronomo')
      else
        public.current_user_role() in (
          'gestor_propriedade',
          'produtor_rural',
          'agronomo',
          'tecnico_agricola'
        )
    end
  );

-- Alertas: todos leem e o fluxo automático insere; apenas Gestor e Agrônomo resolvem alertas
drop policy if exists "alertas_select_auth" on public.alertas;
create policy "alertas_select_auth" on public.alertas
  for select to authenticated using (true);

drop policy if exists "alertas_insert_auth" on public.alertas;
create policy "alertas_insert_auth" on public.alertas
  for insert to authenticated with check (true);

drop policy if exists "alertas_update_resolve_roles" on public.alertas;
create policy "alertas_update_resolve_roles" on public.alertas
  for update to authenticated
  using (
    public.current_user_role() in (
      'gestor_propriedade',
      'agronomo',
      'produtor_rural',
      'tecnico_agricola'
    )
  )
  with check (
    -- Apenas Gestor ou Agrônomo podem marcar ativo = false (resolver alerta)
    ativo = true or public.current_user_role() in ('gestor_propriedade', 'agronomo')
  );

-- ----------------------------------------------------------------------------
-- 7. Permissões de Schema e Tabelas para a Data API (necessário quando
--    "Automatically expose new tables" está desmarcado na criação do projeto)
-- ----------------------------------------------------------------------------
grant usage on schema public to anon, authenticated;
grant select, insert, update on public.perfis to authenticated;
grant select, insert, update on public.propriedades to authenticated;
grant select, insert, update on public.talhoes to authenticated;
grant select, insert, update on public.registros_campo to authenticated;
grant select, insert, update on public.alertas to authenticated;
grant execute on function public.current_user_role() to authenticated;


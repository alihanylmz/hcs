alter table public.tickets
add column if not exists job_type text not null default 'service';

alter table public.tickets
add column if not exists project_type text;

alter table public.tickets
add column if not exists project_status text not null default 'planned';

alter table public.tickets
add column if not exists project_location text;

alter table public.tickets
add column if not exists responsible_user_id uuid references public.profiles(id) on delete set null;

alter table public.tickets
add column if not exists assigned_user_ids uuid[] not null default '{}'::uuid[];

alter table public.tickets
add column if not exists project_start_date timestamptz;

alter table public.tickets
add column if not exists project_due_date timestamptz;

alter table public.tickets
add column if not exists internal_notes text;

alter table public.tickets
drop constraint if exists tickets_job_type_check;

alter table public.tickets
add constraint tickets_job_type_check
check (job_type in ('service', 'project'))
not valid;

alter table public.tickets
drop constraint if exists tickets_project_status_check;

alter table public.tickets
add constraint tickets_project_status_check
check (
  project_status in (
    'planned',
    'in_progress',
    'waiting',
    'testing',
    'missing',
    'done',
    'cancelled'
  )
)
not valid;

create index if not exists tickets_job_type_idx
on public.tickets (job_type, created_at desc);

create index if not exists tickets_responsible_user_idx
on public.tickets (responsible_user_id);

update public.tickets
set job_type = 'service'
where job_type is null or job_type = '';

alter table public.activity_logs
add column if not exists job_id uuid references public.tickets(id) on delete set null;

alter table public.activity_logs
add column if not exists activity_type text not null default '';

alter table public.activity_logs
add column if not exists is_manual_note boolean not null default false;

update public.activity_logs
set activity_type = coalesce(nullif(action_key, ''), source, 'activity')
where activity_type = '';

update public.activity_logs
set is_manual_note = source = 'manual'
where is_manual_note is false;

create index if not exists activity_logs_job_idx
on public.activity_logs (job_id, created_at desc);

alter table public.activity_logs
add column if not exists user_id uuid references public.profiles(id) on delete set null;

alter table public.activity_logs
add column if not exists message text not null default '';

update public.activity_logs
set user_id = actor_id
where user_id is null and actor_id is not null;

update public.activity_logs
set message = coalesce(nullif(note, ''), nullif(action, ''), '')
where message = '';

create or replace function public.hcs_sync_activity_log_compat()
returns trigger
language plpgsql
as $$
begin
  if new.user_id is null then
    new.user_id := new.actor_id;
  end if;

  if new.actor_id is null then
    new.actor_id := new.user_id;
  end if;

  if coalesce(new.activity_type, '') = '' then
    new.activity_type := coalesce(nullif(new.action_key, ''), nullif(new.source, ''), 'activity');
  end if;

  if coalesce(new.message, '') = '' then
    new.message := coalesce(nullif(new.note, ''), nullif(new.action, ''), '');
  end if;

  if new.job_id is null and new.metadata ? 'ticket_id' then
    begin
      new.job_id := (new.metadata ->> 'ticket_id')::uuid;
    exception when others then
      new.job_id := null;
    end;
  end if;

  if new.is_manual_note is null then
    new.is_manual_note := false;
  end if;

  if new.source = 'manual' or new.action_key = 'manual_note' or new.activity_type = 'manual_note' then
    new.is_manual_note := true;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_hcs_sync_activity_log_compat on public.activity_logs;

create trigger trg_hcs_sync_activity_log_compat
before insert or update on public.activity_logs
for each row execute function public.hcs_sync_activity_log_compat();

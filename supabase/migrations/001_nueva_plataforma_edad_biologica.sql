-- NUMED | Edad Biológica V7 -- arquitectura clínica y QR único.
-- REVISA antes de ejecutar. Solo tablas nuevas con prefijo eb_ en un proyecto dedicado.
-- Nunca utilizar esta migración sin respaldo si ya existen tablas eb_.
-- No incluye fórmula de edad biológica; la clínica debe aprobar y versionar el modelo.

create table public.eb_staff (
 user_id uuid primary key references auth.users(id) on delete cascade,
 nombre text not null,
 rol text not null check(rol in ('administrador','doctor')),
 activo boolean not null default true,
 creado_en timestamptz not null default now()
);
create table public.eb_pacientes (
 id uuid primary key default gen_random_uuid(),
 codigo text not null unique default ('NM-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,10))),
 nombres text not null check(length(trim(nombres)) between 2 and 80),
 apellidos text not null check(length(trim(apellidos)) between 2 and 80),
 fecha_nacimiento date not null check (fecha_nacimiento > date '1900-01-01'),
 cedula text not null unique check(cedula ~ '^[0-9]{3}-[0-9]{7}-[0-9]$'),
 whatsapp text not null check(length(whatsapp) between 10 and 22),
 correo text not null,
 user_id uuid references auth.users(id) on delete set null,
 portal_habilitado boolean not null default false,
 creado_en timestamptz not null default now()
);
create index eb_pacientes_correo_index on public.eb_pacientes(lower(correo));
create index eb_pacientes_usuario_index on public.eb_pacientes(user_id);
create table public.eb_evaluaciones (
 id uuid primary key default gen_random_uuid(),
 paciente_id uuid not null references public.eb_pacientes(id) on delete restrict,
 estado text not null default 'registrado' check(estado in ('registrado','cuestionario','mediciones','listo','publicado')),
 creado_en timestamptz not null default now(),
 actualizado_en timestamptz not null default now(),
 consentimiento_version text not null,
 consentimiento_en timestamptz not null default now(),
 solicitud_id uuid unique,
 fuente text not null default 'qr' check(fuente in ('qr','medico'))
);
create index eb_eval_paciente_fecha_idx on public.eb_evaluaciones(paciente_id,creado_en desc);
create table public.eb_cuestionarios (
 evaluacion_id uuid primary key references public.eb_evaluaciones(id) on delete cascade,
 version_preguntas text not null default 'v6-12',
 respuestas jsonb not null check(jsonb_typeof(respuestas)='object'),
 completado_en timestamptz not null default now()
);
create table public.eb_mediciones (
 evaluacion_id uuid primary key references public.eb_evaluaciones(id) on delete cascade,
 peso_kg numeric(6,2) not null check(peso_kg between 25 and 350),
 talla_cm numeric(6,2) not null check(talla_cm between 100 and 250),
 fuerza_kg numeric(6,2) not null check(fuerza_kg between 0 and 150),
 perimetro_abdominal_cm numeric(6,2) not null check(perimetro_abdominal_cm between 30 and 250),
 imc numeric(5,2) generated always as (round(peso_kg/power(talla_cm/100,2),2)) stored,
 registrado_por uuid not null references auth.users(id),
 registrado_en timestamptz not null default now()
);
create table public.eb_resultados (
 evaluacion_id uuid primary key references public.eb_evaluaciones(id) on delete cascade,
 edad_biologica numeric(5,1),
 metodo_version text,
 publicado_en timestamptz,
 revisado_por uuid references auth.users(id),
 detalle jsonb not null default '{}'::jsonb,
 check(edad_biologica is null or (edad_biologica between 0 and 130 and metodo_version is not null)),
 check(publicado_en is null or (edad_biologica is not null and metodo_version is not null and revisado_por is not null))
);

-- Solo personal clínico activo puede operar sobre expedientes.
create or replace function public.eb_is_staff() returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.eb_staff s where s.user_id=(select auth.uid()) and s.activo);
$$;
create or replace function public.eb_is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.eb_staff s where s.user_id=(select auth.uid()) and s.activo and s.rol='administrador');
$$;
revoke all on function public.eb_is_staff(), public.eb_is_admin() from public,anon;
grant execute on function public.eb_is_staff(), public.eb_is_admin() to authenticated;

-- Reglas del cuestionario también aplicadas del lado del servidor.
create or replace function public.eb_respuestas_validas(a jsonb) returns boolean
language plpgsql immutable set search_path = '' as $$
declare k text; keys text[] := array['actividad','sentado','sueno','descanso','frutas','procesados','agua','tabaco','alcohol','estres']; q text; v jsonb; e jsonb; n integer; choices integer[]; excl integer[]; other_index integer; total integer;
begin
 if a is null or jsonb_typeof(a) <> 'object' then return false; end if;
 if (select count(*) from jsonb_object_keys(a)) <> 12 then return false; end if;
 foreach k in array keys loop
  if jsonb_typeof(a->k) <> 'number' or a->>k !~ '^[0-3]$' then return false; end if;
 end loop;
 foreach q in array array['cronicas','familiares'] loop
  v:=a->q;
  if v is null or jsonb_typeof(v) is distinct from 'object' or jsonb_typeof(v->'selected') is distinct from 'array' or jsonb_typeof(v->'other') is distinct from 'string' then return false; end if;
  if (select count(*) from jsonb_object_keys(v)) <> 2 then return false; end if;
  total:=jsonb_array_length(v->'selected');
  if total=0 or total>11 then return false; end if;
  choices:=array[]::integer[];
  for e in select value from jsonb_array_elements(v->'selected') loop
    if jsonb_typeof(e) <> 'number' or trim(both '"' from e::text) !~ '^([0-9]|10)$' then return false; end if;
    n:=(e::text)::integer;
    if (q='cronicas' and n>9) or (q='familiares' and n>10) or n=any(choices) then return false; end if;
    choices:=array_append(choices,n);
  end loop;
  if q='cronicas' then excl:=array[0]; other_index:=9; else excl:=array[0,1]; other_index:=10; end if;
  if choices && excl and total>1 then return false; end if;
  if other_index=any(choices) then
    if length(trim(v->>'other'))<2 or length(v->>'other')>120 then return false; end if;
  else
    if v->>'other' <> '' then return false; end if;
  end if;
 end loop;
 return true;
exception when others then return false;
end $$;

-- Registro público desde una Edge Function con service_role (no desde el navegador).
-- La transacción genera/recupera el paciente y crea una nueva evaluación con respuestas.
create or replace function public.eb_registrar_y_responder(
 p_nombres text,p_apellidos text,p_fecha_nacimiento date,p_cedula text,
 p_whatsapp text,p_correo text,p_respuestas jsonb,p_consentimiento boolean,
 p_consentimiento_version text,p_solicitud_id uuid
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare p public.eb_pacientes%rowtype; eid uuid; v_edad integer;
begin
 if p_consentimiento is distinct from true or p_consentimiento_version is null or length(trim(p_consentimiento_version))<5 or p_solicitud_id is null then raise exception 'Consentimiento requerido'; end if;
 -- Los reintentos de una misma solicitud no crean evaluaciones duplicadas.
 select e.id into eid from public.eb_evaluaciones e where e.solicitud_id=p_solicitud_id;
 if eid is not null then
   select * into p from public.eb_pacientes where id=(select paciente_id from public.eb_evaluaciones where id=eid);
   return jsonb_build_object('codigo',p.codigo);
 end if;
 v_edad:=date_part('year',age(current_date,p_fecha_nacimiento));
 if length(trim(p_nombres)) not between 2 and 80 or length(trim(p_apellidos)) not between 2 and 80
 or p_fecha_nacimiento is null or v_edad not between 18 and 115
 or p_cedula !~ '^[0-9]{3}-[0-9]{7}-[0-9]$'
 or length(regexp_replace(p_whatsapp,'[^0-9]','','g')) not between 10 and 15
 or p_correo !~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
 or not public.eb_respuestas_validas(p_respuestas)
 then raise exception 'Registro no valido'; end if;
 select * into p from public.eb_pacientes where cedula=p_cedula for update;
 if p.id is null then
   insert into public.eb_pacientes(nombres,apellidos,fecha_nacimiento,cedula,whatsapp,correo)
   values(trim(p_nombres),trim(p_apellidos),p_fecha_nacimiento,p_cedula,trim(p_whatsapp),lower(trim(p_correo))) returning * into p;
 else
   -- NO vincular automáticamente una nueva evaluación a una cédula existente.
   -- Identidad y nueva visita deben verificarse por recepción de NUMED.
   raise exception 'Registro requiere verificacion presencial';
 end if;
 insert into public.eb_evaluaciones(paciente_id,estado,consentimiento_version,solicitud_id)
 values(p.id,'cuestionario',p_consentimiento_version,p_solicitud_id) returning id into eid;
 insert into public.eb_cuestionarios(evaluacion_id,respuestas,version_preguntas)
 values(eid,p_respuestas,'v7-12');
 return jsonb_build_object('codigo',p.codigo,'evaluacion_id',eid);
end $$;
revoke all on function public.eb_registrar_y_responder(text,text,date,text,text,text,jsonb,boolean,text,uuid) from public,anon,authenticated;
grant execute on function public.eb_registrar_y_responder(text,text,date,text,text,text,jsonb,boolean,text,uuid) to service_role;

-- Cambiar automáticamente el estado una vez registradas las mediciones.
create or replace function public.eb_actualizar_estado() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
 update public.eb_evaluaciones e set estado=case
 when exists(select 1 from public.eb_mediciones m where m.evaluacion_id=new.evaluacion_id)
 and exists(select 1 from public.eb_cuestionarios q where q.evaluacion_id=new.evaluacion_id) then 'listo'
 when exists(select 1 from public.eb_mediciones m where m.evaluacion_id=new.evaluacion_id) then 'mediciones'
 else 'cuestionario' end,
 actualizado_en=now()
 where e.id=new.evaluacion_id and e.estado <> 'publicado';
 return new;
end $$;
create trigger eb_metrics_status after insert or update on public.eb_mediciones for each row execute function public.eb_actualizar_estado();

-- Portal: permitir vincular por correo confirmado solo cuando haya 1 paciente habilitado.
-- Si hay varios pacientes con un mismo correo, un administrador debe vincular manualmente las cuentas.
create or replace function public.eb_reclamar_portal() returns integer
language plpgsql security definer set search_path = '' as $$
declare mail text; n integer;
begin
 select email into mail from auth.users where id=auth.uid() and email_confirmed_at is not null;
 if mail is null then return 0; end if;
 select count(*) into n from public.eb_pacientes where lower(correo)=lower(mail) and portal_habilitado;
 if n<>1 then return 0; end if;
 update public.eb_pacientes set user_id=auth.uid()
 where lower(correo)=lower(mail) and portal_habilitado and (user_id is null or user_id=auth.uid());
 get diagnostics n=row_count;
 return n;
end $$;
revoke all on function public.eb_reclamar_portal() from public,anon;
grant execute on function public.eb_reclamar_portal() to authenticated;

alter table public.eb_staff enable row level security;
alter table public.eb_pacientes enable row level security;
alter table public.eb_evaluaciones enable row level security;
alter table public.eb_cuestionarios enable row level security;
alter table public.eb_mediciones enable row level security;
alter table public.eb_resultados enable row level security;
revoke all on public.eb_staff,public.eb_pacientes,public.eb_evaluaciones,public.eb_cuestionarios,public.eb_mediciones,public.eb_resultados from anon,authenticated;
grant select on public.eb_staff to authenticated;
grant select on public.eb_pacientes to authenticated;
grant update (portal_habilitado) on public.eb_pacientes to authenticated;
grant select on public.eb_evaluaciones to authenticated;
grant select on public.eb_cuestionarios to authenticated;
grant select,insert,update on public.eb_mediciones to authenticated;
grant select on public.eb_resultados to authenticated;

create policy eb_staff_read on public.eb_staff for select to authenticated
 using(user_id=(select auth.uid()) or (select public.eb_is_admin()));
create policy eb_pacientes_read on public.eb_pacientes for select to authenticated
 using((select public.eb_is_staff()) or (portal_habilitado and user_id=(select auth.uid())));
create policy eb_pacientes_edit on public.eb_pacientes for update to authenticated
 using((select public.eb_is_staff())) with check((select public.eb_is_staff()));
create policy eb_eval_read on public.eb_evaluaciones for select to authenticated
 using((select public.eb_is_staff()) or exists(select 1 from public.eb_pacientes p where p.id=paciente_id and p.portal_habilitado and p.user_id=(select auth.uid())));
create policy eb_answers_read on public.eb_cuestionarios for select to authenticated
 using((select public.eb_is_staff()));
create policy eb_metrics_read on public.eb_mediciones for select to authenticated
 using((select public.eb_is_staff()));
create policy eb_metrics_insert on public.eb_mediciones for insert to authenticated
 with check((select public.eb_is_staff()) and registrado_por=(select auth.uid()));
create policy eb_metrics_edit on public.eb_mediciones for update to authenticated
 using((select public.eb_is_staff())) with check((select public.eb_is_staff()) and registrado_por=(select auth.uid()));
create policy eb_results_read on public.eb_resultados for select to authenticated
 using((select public.eb_is_staff()) or (publicado_en is not null and exists(select 1 from public.eb_evaluaciones e join public.eb_pacientes p on p.id=e.paciente_id where e.id=evaluacion_id and p.portal_habilitado and p.user_id=(select auth.uid()))));

-- No se habilitan inserts directos anónimos ni lectura del expediente por código.
-- Publicar edades biológicas requerirá un procedimiento clínico independiente y validado.

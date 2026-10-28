"""Comprobaciones estáticas; NO sustituyen E2E contra Supabase."""
from pathlib import Path
p=Path(__file__).resolve().parent.parent
js=(p/'app.js').read_text()
html=(p/'index.html').read_text()
sql=(p/'supabase/migrations/001_nueva_plataforma_edad_biologica.sql').read_text()
edge=(p/'supabase/functions/submit-intake/index.ts').read_text()
config=(p/'config.js').read_text()
checks={
 '12 preguntas incluyendo 2 listas medicas': js.split("const QUESTIONS = [",1)[1].split("];",1)[0].count("{id:")==12 and "id:'cronicas'" in js and "id:'familiares'" in js,
 'QR es primera pantalla': "?'portal':'qr'" in js and "target.hash='/registro'" in js,
 'No hay datos demo/localstorage': not any(x in js for x in ['sessionStorage','localStorage','demoSamples','seed-demo','DEMO_KEY']),
 'Supabase habilitado': "mode: 'supabase'" in config and 'functions.invoke' in js,
 'Control Turnstile obligatorio': 'verifyTurnstile' in edge and 'TURNSTILE_SECRET' in edge and 'captcha_token' in edge,
 'Consentimiento requiere aprobacion': 'consentApproved: false' in config and 'CONSENT_VERSION' in edge,
 'RLS en seis tablas': sql.count('enable row level security')==6,
 'Anon sin lectura clinica': 'grant select on public.eb_pacientes to authenticated' in sql and 'grant select on public.eb_pacientes to anon' not in sql,
 'Bajo privilegio del frontend': 'SUPABASE_SERVICE_ROLE_KEY' not in config and 'SUPABASE_SERVICE_ROLE_KEY' not in js,
 'HTML publico y logo de NUMED': '<main id="app"' in html and (p/'assets/logo-numed.png').exists(),
 'Sin edad biologica inventada': 'edad_biologica numeric(5,1)' in sql and 'no se ha calculado una edad biológica' in js.lower(),
}
for name,okay in checks.items():print(('OK' if okay else 'FAIL'),name)
if not all(checks.values()):raise SystemExit(1)

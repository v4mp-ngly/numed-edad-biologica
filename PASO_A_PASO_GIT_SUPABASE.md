# Publicación paso a paso en Mac: GitHub + Supabase + QR

## A. Subir la página mediante Git (Terminal de VS Code)

1. Descarga `NUMED_Edad_Biologica_V7_PRODUCCION.zip`, descomprime y **abre esa carpeta** en Visual Studio Code: **File → Open Folder**. Debes ver `index.html` directamente dentro de ella.
2. Abre **Terminal → New Terminal** y ejecuta `git --version`.
3. En https://github.com/new crea un repositorio vacío `numed-edad-biologica`, sin README inicial, sin .gitignore inicial y sin licencia automática. **No subas datos reales de pacientes**.
4. En la terminal del proyecto ejecuta (reemplaza TU_USUARIO):

```bash
git init
git branch -M main
git add .
git commit -m "NUMED edad biologica V7 - QR y Supabase"
git remote add origin https://github.com/TU_USUARIO/numed-edad-biologica.git
git push -u origin main
```

Si Git pide identificación, usa `git config --global user.name "Tu nombre"` y `git config --global user.email "tu-correo-github"`. Si pide autenticación, usa el inicio de sesión de GitHub mediante VS Code / Git Credential Manager. GitHub no admite contraseña de cuenta tradicional para `git push` HTTPS; utiliza credenciales compatibles / token cuando corresponda.

5. En el repositorio abre **Settings → Pages → Build and deployment → Source: Deploy from a branch → Branch: main → /(root) → Save**. Espera a que GitHub muestre la URL publicada. Ejemplo: `https://TU_USUARIO.github.io/numed-edad-biologica/`.
6. Comprueba que el enlace HTTPS muestre directamente la pantalla **QR de recepción**. **Todavía no lo imprimas para pacientes**, el backend y consentimiento no están habilitados.

## B. Preparar la base de datos Supabase

1. Ve a https://supabase.com/dashboard y selecciona **exactamente** el proyecto con ref `gcdputopqujkxxyhqezs` (revisa la URL y el nombre antes de ejecutar).
2. En **SQL Editor**, comprueba que no haya tablas `public.eb_%` previamente creadas. Si ya existen, NO ejecutes la migración inicial: se requiere una migración de actualización compatible. Haz respaldo.
3. Abre `supabase/migrations/001_nueva_plataforma_edad_biologica.sql`, copia todo y ejecuta desde SQL Editor. Revisa errores. **Esto crea tablas nuevas**; no lo ejecutes en una base de datos con datos reales sin revisión de DBA.
4. En **Authentication → Users**, crea o invita a una cuenta médica mediante Supabase Auth. Copia su `User UID` y con SQL Editor ejecuta, sustituyendo el UUID por el real:

```sql
insert into public.eb_staff(user_id,nombre,rol,activo)
values('UUID-DE-AUTH-USERS','Responsable médico NUMED','administrador',true);
```

No inventes el UUID ni uses un UID de otra cuenta. La interfaz no permite crear personal médico sin autorización.

## C. Activar el endpoint público (Edge Function)

1. En Mac con Homebrew puedes instalar CLI con:

```bash
brew install supabase/tap/supabase
supabase login
supabase link --project-ref gcdputopqujkxxyhqezs
```

2. Crea una cuenta gratuita de **Cloudflare Turnstile**, añade **el dominio exacto** de tu GitHub Pages (por ejemplo `TU_USUARIO.github.io`) y copia su **Site Key** (pública) y **Secret Key** (privada).
3. Abre `config.js` en VS Code. Reemplaza `CONFIGURAR_SITE_KEY` por la **Site Key pública**. **Nunca agregues Secret Key al HTML o GitHub**.
4. Pídele al responsable de NUMED que complete y apruebe `privacidad.html` con todos los datos legales obligatorios. Hasta ese momento, **deja `consentApproved:false`** y no operes con pacientes reales.
5. Una vez aprobado, cambia `consentApproved: true` en `config.js`. Elige una versión real, por ejemplo `NUMED-EVAL-2026-10-v1`, registra internamente el documento correspondiente y configura los secretos desde la terminal (sustituye valores por los reales):

```bash
supabase secrets set ALLOWED_ORIGINS="https://TU_USUARIO.github.io"
supabase secrets set TURNSTILE_SECRET="SECRET_KEY_DE_CLOUDFLARE"
supabase secrets set CONSENT_VERSION="VERSION_APROBADA_NUMED"
supabase functions deploy submit-intake --no-verify-jwt
```

**Importante**: `--no-verify-jwt` permite llamadas sin sesión porque el paciente no tiene cuenta; la función valida CAPTCHA en el servidor y jamás expone la `service_role`. Configura solo los orígenes HTTPS correctos. No habilites `ALLOW_LOCAL_DEV` en producción.

6. En Supabase → **Authentication → URL Configuration**, usa como **Site URL** la dirección HTTPS de GitHub Pages y agrega `https://TU_USUARIO.github.io/numed-edad-biologica/*` a Redirect URLs si utilizarás enlaces por correo en el portal.
7. Después de cambiar `config.js`, vuelve a subir los cambios:

```bash
git add .
git commit -m "Configurar dominio y verificacion NUMED"
git push
```

**El QR funciona a partir de la URL pública:** al abrir la raíz `https://TU_USUARIO.github.io/numed-edad-biologica/` muestra un QR que debe apuntar a `https://TU_USUARIO.github.io/numed-edad-biologica/#/registro`.

## D. Prueba de extremo a extremo obligatoria

- [ ] Abrir la web pública desde la computadora; debe aparecer el QR NUMED.
- [ ] Escanear QR con el iPhone; debe abrir **directamente registro**.
- [ ] Completar con datos **ficticios**, aceptar consentimiento ya aprobado y responder 12 preguntas.
- [ ] Validar Cloudflare Turnstile y confirmar que se vea un código de recepción.
- [ ] Abrir `#/medico` en computadora; iniciar sesión con Auth y comprobar que el registro esté en el panel.
- [ ] Guardar mediciones; comprobar IMC y estado de la evaluación.
- [ ] Cerrar sesión; verificar que un visitante NO pueda listar `eb_pacientes`, `eb_evaluaciones` ni `eb_cuestionarios` mediante la clave pública.
- [ ] Verificar que un médico sin perfil `eb_staff` NO pueda ver los pacientes.
- [ ] Revisar funcionalidad y formato en Safari/iPhone, navegadores de escritorio y tablas.
- [ ] Configurar monitoreo, retención, seguridad, copias de seguridad y política de acceso antes de atención real.

## E. Errores frecuentes

**No se carga la página:** GitHub Pages debe usar la carpeta `/ (root)` con `index.html` y el repositorio contener `.nojekyll`.

**El QR apunta a 127.0.0.1:** estás abriendo Live Server. Abre primero la URL HTTPS de GitHub Pages y solo entonces imprime el QR.

**Error 403 origen no autorizado:** la variable `ALLOWED_ORIGINS` debe coincidir exactamente con el origen `https://TU_USUARIO.github.io`, SIN el nombre de repositorio, SIN barra final.

**No se pudo validar la verificación:** revisa el dominio permitido en Turnstile y las Site/Secret Keys correspondientes.

**El médico no ve pacientes:** revisa sesión Auth, `eb_staff`, tabla/función y RLS. No desactives RLS para resolverlo.

**Ya está registrado:** por seguridad, pacientes que regresan deben verificarse en recepción y seguir un flujo de nueva visita aprobado; no mezcles pacientes por cédula o correo sin verificación.

**GitHub pide contraseña:** usa autenticación de GitHub para HTTPS; no pegues tu contraseña ni un token en este chat.

**Cuenta con datos clínicos:** no reemplaces ni sobrescribas migraciones ni operes en producción antes de auditoría/backup.

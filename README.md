# NUMED · Edad Biológica V7 · Preparación para operación real

**Repositorio de implementación**, no demo. Preserva logo y paleta oficial azul `#114C76` / verde `#AACA41`.

## Experiencia

1. **Recepción abre la URL principal** (`https://USUARIO.github.io/numed-edad-biologica/`) y muestra/imprime el QR oficial NUMED.
2. **Paciente escanea con el celular** el QR, que abre `.../#/registro` de inmediato, sin pantalla de selección ni login médico.
3. Registra nombre, apellido, nacimiento, cédula, WhatsApp y correo; lee y acepta consentimiento.
4. Responde 12 preguntas consecutivas. Las preguntas 11–12 admiten múltiples enfermedades y el campo «Otra». Ninguna opción llega preseleccionada.
5. Tras Turnstile, la función `submit-intake` registra paciente + evaluación + respuestas en una transacción dentro de Supabase. Aparece un código de recepción, NO una contraseña.
6. Médico inicia sesión en `#/medico`, revisa la evaluación y registra peso, talla, fuerza y perímetro abdominal. IMC calculado automáticamente por Postgres.
7. Portal mediante correo verificado, habilitado expresamente por personal clínico. No se calcula ni publica edad biológica hasta validar método y proceso de revisión.

**Importante**: Por privacidad, si la cédula ya figura en el sistema, el registro público **no se vincula automáticamente** a ese expediente; la persona solicita verificación presencial a recepción. La gestión segura de visitas sucesivas será una mejora administrativa.

## Archivos relevantes

- `index.html` – portada QR de recepción y navegación.
- `app.js` – registro, cuestionario, roles, dashboard y Photo Booth.
- `styles.css` y `assets/` – identidad NUMED.
- `config.js` – URL + clave ANON pública, identificador PUBLICO de Turnstile y bandera de consentimiento.
- `privacidad.html` – **borrador, no apto todavía para pacientes**.
- `supabase/migrations/001_nueva_plataforma_edad_biologica.sql` – tablas nuevas, restricciones, políticas RLS, función transaccional.
- `supabase/functions/submit-intake/index.ts` – endpoint público con Turnstile obligatorio y secreto solo en Edge Function.
- `PASO_A_PASO_GIT_SUPABASE.md` – instrucciones de puesta en línea y comprobaciones.

## Estado de puesta en marcha

- Código frontal **conectado únicamente a Supabase**; no contiene modo demo ni almacenamiento local de expedientes.
- **No se ha aplicado el SQL ni publicado** en tu proyecto. No podemos comprobar desde aquí su estado actual ni usar cuentas reales.
- Función protegida: exige `TURNSTILE_SECRET`, `ALLOWED_ORIGINS` y `CONSENT_VERSION` antes de registrar.
- Frontend: bloquea el envío mientras `consentApproved=false` o falta Turnstile.
- La fórmula clínica de edad biológica **no está desarrollada ni publicada**. El formulario recopila datos para revisión.
- GitHub Pages aloja HTML/JS/estilos públicos; **no aloja expedientes**. Expedientes solo en Supabase con RLS. Nunca hacer `git add` de claves `service_role`, datos de pacientes, capturas clínicas o `.env`.

## Falta antes de utilizar con pacientes reales

1. Revisar SQL en proyecto correcto y crear respaldo si existe información previa.
2. Ejecutar migración, crear usuario médico y concederle perfil activo.
3. Instalar/desplegar función y configurar orígenes exactos.
4. Crear Cloudflare Turnstile para dominio final y configurar site/secret key.
5. Aprobar texto legal y publicación de privacidad, poner `consentApproved=true` **solo después** y configurar versión de consentimiento en secreto.
6. Configurar Auth Redirect URLs, verificar RLS con una sesión no autorizada, probar con pacientes ficticios en **proyecto de pruebas** y verificar en dos dispositivos.
7. Definir protección adicional contra abuso, copias de seguridad, auditoría clínica, seguridad operacional y responsabilidad de protección de datos antes de producción.

No confundas **web publicada** con **sistema clínico habilitado**: el primero puede existir mientras el segundo sigue bloqueado intencionalmente.

# NUMED Edad Biológica V7 — Proyecto completo hasta Fase 2

Incluye web completa, estilos, imágenes NUMED, app.js Fase 2, función Edge original, SQL y guías.

## Para actualizar un proyecto que YA está funcionando
1. Conserva tu `config.js` actual de producción: el incluido aquí es una plantilla de la versión inicial y puede tener `turnstileSiteKey` sin configurar y `consentApproved: false`. NO lo reemplaces sin revisar.
2. Sustituye `app.js` por el incluido. Conserva tus cambios locales posteriores si los hubiera.
3. Los SQL `002_*` y `003_*` corresponden a fases anteriores; si ya los ejecutaste correctamente, NO necesitas volver a hacerlo.
4. No redepliegues la Edge Function `submit-intake` del ZIP sin compararla con tu versión desplegada: el archivo es la versión original del paquete V7 y puede ser anterior a las correcciones que hiciste en Supabase.
5. Publica tus cambios en GitHub Pages y verifica QR, formulario, panel médico, portal y acceso por correo.

## Estado real
- Contiene funcionalidades de Fase 2: indicadores del paciente y campos clínicos.
- NO contiene todavía el cálculo integral PSS-14/TAB-NUMED ni publicación de edad biológica; no se deben presentar resultados de edad biológica no validados.
- No contiene contraseñas ni secretos SMTP / service-role.

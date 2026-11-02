-- NUMED V7 Fase 2: permitir al paciente ver SOLO sus propias mediciones.
-- Ejecutar después de la migración de Fase 1. No actualiza datos clínicos,
-- no publica la edad biológica ni modifica permisos de escritura.
BEGIN;
DROP POLICY IF EXISTS eb_metrics_patient_own_read ON public.eb_mediciones;
CREATE POLICY eb_metrics_patient_own_read
 ON public.eb_mediciones FOR SELECT TO authenticated
 USING (EXISTS (
   SELECT 1 FROM public.eb_evaluaciones e
   JOIN public.eb_pacientes p ON p.id=e.paciente_id
   WHERE e.id=eb_mediciones.evaluacion_id
     AND p.portal_habilitado IS TRUE
     AND p.user_id=(SELECT auth.uid())
 ));
COMMIT;
-- La política de personal médico 'eb_metrics_read' permanece vigente.
-- Los resultados eb_resultados solo son visibles al paciente si publicado_en no es NULL.

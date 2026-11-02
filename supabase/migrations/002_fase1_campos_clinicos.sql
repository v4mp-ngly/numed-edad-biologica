-- NUMED Edad Biologica V7 / Fase 1 - Campos clinicos adicionales
-- Ejecutar UNA VEZ en Supabase SQL Editor. No elimina ni reescribe registros.
-- Los valores de evaluaciones antiguas permanecen NULL hasta nueva medicion.
BEGIN;
ALTER TABLE public.eb_mediciones
  ADD COLUMN IF NOT EXISTS sexo_referencia text,
  ADD COLUMN IF NOT EXISTS presion_sistolica integer,
  ADD COLUMN IF NOT EXISTS presion_diastolica integer,
  ADD COLUMN IF NOT EXISTS entrenamiento_fuerza boolean;

-- Reglas de plausibilidad operativa, no diagnostico.
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='eb_mediciones_sexo_ref_check') THEN
    ALTER TABLE public.eb_mediciones ADD CONSTRAINT eb_mediciones_sexo_ref_check
    CHECK (sexo_referencia IS NULL OR sexo_referencia IN ('F','M'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='eb_mediciones_pa_check') THEN
    ALTER TABLE public.eb_mediciones ADD CONSTRAINT eb_mediciones_pa_check
    CHECK ((presion_sistolica IS NULL OR presion_sistolica BETWEEN 70 AND 260)
      AND (presion_diastolica IS NULL OR presion_diastolica BETWEEN 40 AND 160)
      AND (presion_sistolica IS NULL OR presion_diastolica IS NULL OR presion_sistolica > presion_diastolica));
  END IF;
END $$;
COMMIT;
-- No se modifican RLS ni eb_resultados: ninguna edad se publica automaticamente.

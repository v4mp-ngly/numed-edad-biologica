// NUMED V7 | Configuración pública. NUNCA colocar service_role ni secretos aquí.
// Modo conectado exclusivamente. Las claves públicas son visibles; NO colocar secretos aquí.
// Para usarlo con pacientes hay que completar configuración, medidas antiabuso y consentimiento.
window.NUMED_CONFIG = {
  mode: 'supabase',
  supabaseUrl: 'https://gcdputopqujkxxyhqezs.supabase.co',
  supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdjZHB1dG9wcXVqa3h4eWhxZXpzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMxOTcyODksImV4cCI6MjEwODc3MzI4OX0.ZGfwvo-RjriZyJ68OjDgtKST-CTt6BfN6CRfrnWDlps',
  clinicLabel: 'NUMED CARE',
   turnstileSiteKey: '0x4AAAAAAFqAvSbWiKroX5cl', // Clave PUBLICA de Cloudflare Turnstile
  consentApproved: false, // Cambia a true SOLO tras aprobar privacidad y consentimiento

};

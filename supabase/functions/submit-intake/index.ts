// NUMED V7 | Edge Function pública para recibir un formulario COMPLETO con un solo QR.
// El navegador NUNCA recibe la service_role key. El SQL valida nuevamente las respuestas.
// Turnstile obligatorio. CORS estricto. Nunca copiar service_role al frontend.
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_PROJECT_URL = Deno.env.get('SUPABASE_URL')!;
const SECRET = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const origins = (Deno.env.get('ALLOWED_ORIGINS') || '').split(',').map(x=>x.trim()).filter(Boolean);
const devOrigin = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/;
const allowDev = Deno.env.get('ALLOW_LOCAL_DEV') === 'true';
const turnstileSecret = Deno.env.get('TURNSTILE_SECRET') || '';
const consentVersion = Deno.env.get('CONSENT_VERSION') || ''; 

const supa = createClient(SUPABASE_PROJECT_URL, SECRET, {
  auth: {
    persistSession: false,
    autoRefreshToken: false
  }
});

const required = ['actividad','sentado','sueno','descanso','frutas','procesados','agua','tabaco','alcohol','estres'];
function validAnswers(a:unknown):boolean {
 if(!a || typeof a!=='object' || Array.isArray(a))return false;
 const r=a as Record<string,unknown>;if(Object.keys(r).length!==12)return false;
 if(!required.every(k=>Number.isInteger(r[k])&&(r[k] as number)>=0&&(r[k] as number)<=3))return false;
 for(const [key,max,exclusive,otherIndex] of [['cronicas',9,[0],9],['familiares',10,[0,1],10]] as const){
  const v=r[key] as {selected?:unknown;other?:unknown}|undefined;
  if(!v||typeof v!=='object'||!Array.isArray(v.selected)||!v.selected.length||v.selected.length>max+1||typeof v.other!=='string')return false;
  if(Object.keys(v).length!==2 || !v.selected.every(n=>Number.isInteger(n)&&n>=0&&n<=max) || new Set(v.selected).size!==v.selected.length)return false;
  if(v.selected.some(n=>exclusive.includes(n as never))&&v.selected.length>1)return false;
  if(v.selected.includes(otherIndex)){if(v.other.trim().length<2||v.other.length>120)return false}
  else if(v.other!=='')return false;
 }
 return true;
}
function res(data:unknown,status:number,origin:string){return new Response(JSON.stringify(data),{status,headers:{'content-type':'application/json; charset=utf-8','cache-control':'no-store','access-control-allow-origin':origin,'access-control-allow-headers':'authorization, x-client-info, apikey, content-type','access-control-allow-methods':'POST, OPTIONS','vary':'Origin'}})}
async function verifyTurnstile(token: string, origin: string): Promise<boolean> {
 if(!turnstileSecret || !token || token.length>2048)return false;
 const data = new URLSearchParams({secret:turnstileSecret,response:token});
 const result = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify',{
  method:'POST',body:data,headers:{'Content-Type':'application/x-www-form-urlencoded'}
 });
 if(!result.ok)return false;
 const check=await result.json();
 return check.success===true && check.hostname===new URL(origin).hostname;
}
serve(async req=>{
 const origin=req.headers.get('origin')||'';
 if(!origin||!(origins.includes(origin)||(allowDev&&devOrigin.test(origin))))return new Response('Origen no autorizado',{status:403});
 if(req.method==='OPTIONS')return res({},200,origin);
 if(req.method!=='POST')return res({error:'Método no permitido'},405,origin);
 if(!turnstileSecret||!consentVersion||consentVersion==='PENDIENTE')return res({error:'El registro aún no está habilitado por NUMED'},503,origin);
 try {
  const raw=await req.text();if(raw.length>18000)return res({error:'Formulario demasiado grande'},413,origin);
  const body=JSON.parse(raw);if(!body||typeof body!=='object'||Array.isArray(body))return res({error:'Formulario inválido'},400,origin);
  const {nombres,apellidos,fecha_nacimiento,cedula,whatsapp,correo,respuestas,consentimiento,captcha_token,solicitud_id}=body;
  if(typeof nombres!=='string'||typeof apellidos!=='string'||typeof fecha_nacimiento!=='string'||typeof cedula!=='string'||typeof whatsapp!=='string'||typeof correo!=='string'||consentimiento!==true||!validAnswers(respuestas))return res({error:'Revisa los datos y las respuestas del cuestionario'},400,origin);
  if(nombres.trim().length<2||nombres.length>80||apellidos.trim().length<2||apellidos.length>80||!/^[0-9]{3}-[0-9]{7}-[0-9]$/.test(cedula)||!/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/.test(fecha_nacimiento)||correo.length>150||whatsapp.length>22||!solicitud_id||!(/^[a-f0-9-]{36}$/i).test(solicitud_id))return res({error:'Datos de registro inválidos'},400,origin);
  if(typeof captcha_token!=='string'||!await verifyTurnstile(captcha_token,origin))return res({error:'No se pudo validar la verificación de seguridad. Inténtalo otra vez.'},403,origin);
  const {data,error}=await supa.rpc('eb_registrar_y_responder',{
   p_nombres:nombres.trim(),p_apellidos:apellidos.trim(),p_fecha_nacimiento:fecha_nacimiento,
   p_cedula:cedula,p_whatsapp:whatsapp.trim(),p_correo:correo.toLowerCase().trim(),p_respuestas:respuestas,p_consentimiento:true,
   p_consentimiento_version:consentVersion,p_solicitud_id:solicitud_id
  });
  if(error){console.error('NUMED ingreso:',error.code);return res({error:'No se pudo registrar. Si ya te evaluaste anteriormente, consulta en recepción para verificar tu identidad.'},400,origin)}
  return res({codigo:data.codigo},201,origin);
 }catch(e){console.error('NUMED server',String(e));return res({error:'Ocurrió un error al procesar el formulario'},500,origin)}
});

import { supabase } from './supabase.js';

const form=document.querySelector('#eventForm'),rouletteOptions=document.querySelector('#rouletteOptions'),message=document.querySelector('#eventMessage');
const {data:{session}}=await supabase.auth.getSession();
if(!session)location.href='login.html';

function makeSlug(title){
  const name=title.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/(^-|-$)/g,'').slice(0,68)||'evento';
  return `${name}-${crypto.randomUUID().slice(0,6)}`;
}

document.querySelectorAll('[name=eventType]').forEach(input=>input.addEventListener('change',()=>rouletteOptions.hidden=document.querySelector('[name=eventType]:checked').value!=='roulette'));
form.addEventListener('submit',async event=>{
  event.preventDefault();
  const data=new FormData(form),title=data.get('title').trim(),eventType=data.get('eventType'),layout=eventType==='roulette'?data.get('layout'):'slots',palette=document.querySelector('[name=palette]:checked'),slug=makeSlug(title);
  message.textContent='Criando…';
  const {data:id,error}=await supabase.rpc('roleta_create_event',{p_title:title,p_slug:slug,p_layout:layout,p_primary_color:palette?.dataset.primary||'#681D30',p_secondary_color:palette?.dataset.secondary||'#C79339',p_event_type:eventType});
  if(error){message.textContent='Não foi possível criar agora. Tente novamente.';return}
  location.href=eventType==='list_draw'?`lista.html?event=${id}`:'./';
});

import { supabase } from './supabase.js';

if ('serviceWorker' in navigator) navigator.serviceWorker.register('./sw.js');
const account=document.querySelector('.account'),list=document.querySelector('#eventList'),newEvent=document.querySelector('#newEvent'),heroCreate=document.querySelector('.hero .primary');
const esc=value=>String(value??'').replace(/[&<>'"]/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[char]));
function createEvent(){location.href='novo-evento.html'}
async function loadEvents(){
  const {data,error}=await supabase.rpc('roleta_list_my_events');
  if(error){list.innerHTML='<p>Não foi possível carregar os eventos.</p>';return}
  if(!data?.length){list.innerHTML='<span>◌</span><h3>Nenhum evento criado</h3><p>Crie o primeiro evento para configurar seus prêmios e a tela do cliente.</p>';return}
  list.className='event-list';
  list.innerHTML=data.map(event=>{
    const isList=event.event_type==='list_draw',open=isList?`lista.html?event=${event.id}`:`participar.html?evento=${event.slug}`;
    return `<article class="event"><i style="background:${esc(event.primary_color)}"></i><div><b>${esc(event.title)}</b><small>${isList?'Sorteio por Lista':event.layout==='wheel'?'Roleta circular':'Caça-níquel'} · ${esc(event.status)}</small></div><span class="event-actions"><a href="${open}">${isList?'Gerenciar':'Abrir'} ↗</a><a href="relatorio.html?evento=${event.id}">Relatório ↗</a></span></article>`;
  }).join('');
}
const {data:{session}}=await supabase.auth.getSession();
if(!session){
  account.textContent='Entrar';account.onclick=()=>location.href='login.html';newEvent.onclick=()=>location.href='login.html';heroCreate.onclick=()=>location.href='login.html';
}else{
  account.textContent='Sair';account.onclick=async()=>{await supabase.auth.signOut();location.reload()};newEvent.onclick=createEvent;heroCreate.onclick=createEvent;loadEvents();
}

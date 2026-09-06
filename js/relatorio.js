import { supabase } from './supabase.js';
import * as XLSX from 'https://cdn.jsdelivr.net/npm/xlsx@0.18.5/+esm';

const eventId=new URLSearchParams(location.search).get('evento');
const byId=id=>document.querySelector(`#${id}`),esc=value=>String(value??'').replace(/[&<>'"]/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[char]));
const date=value=>value?new Date(value).toLocaleString('pt-BR'):'—';
let report;

function table(headId,bodyId,rows,columns){
  byId(headId).innerHTML=`<tr>${columns.map(column=>`<th>${esc(column.label)}</th>`).join('')}</tr>`;
  byId(bodyId).innerHTML=rows.length?rows.map(row=>`<tr>${columns.map(column=>`<td>${esc(column.value(row))}</td>`).join('')}</tr>`).join(''):`<tr><td colspan="${columns.length}" class="muted">Ainda não há dados.</td></tr>`;
}
function renderRoulette(){
  const s=report.summary;
  byId('summary').innerHTML=`<article><b>Participações</b><strong>${s.participants}</strong><small>clientes cadastrados</small></article><article><b>Giros</b><strong>${s.spins}</strong><small>histórico completo</small></article><article><b>Cupons gerados</b><strong>${s.coupons}</strong><small>para conferência</small></article>`;
  byId('detailsLabel').textContent='PRÊMIOS ENTREGUES';
  table('prizesHead','prizesBody',report.prizes,[{label:'Prêmio',value:r=>`${r.symbol||''} ${r.title}`},{label:'Tipo',value:r=>r.kind==='coupon'?'Cupom':r.kind==='gift'?'Brinde':'Giro extra'},{label:'Entregues',value:r=>r.awarded}]);
  table('peopleHead','peopleBody',report.participants,[{label:'Nome',value:r=>r.name},{label:'WhatsApp',value:r=>r.whatsapp},{label:'Instagram',value:r=>r.instagram||'—'},{label:'E-mail',value:r=>r.email||'—'},{label:'Giros',value:r=>r.spins},{label:'Cupons',value:r=>r.coupons||'—'}]);
  table('historyHead','historyBody',report.spins,[{label:'Data',value:r=>date(r.created_at)},{label:'Nome',value:r=>r.name},{label:'WhatsApp',value:r=>r.whatsapp},{label:'Prêmio',value:r=>`${r.symbol||''} ${r.prize}`},{label:'Cupom',value:r=>r.coupon||'—'}]);
}
function renderList(){
  const s=report.summary,winner=report.winner;
  byId('summary').innerHTML=`<article><b>Registros</b><strong>${s.entries}</strong><small>uma chance por pessoa</small></article><article><b>Sorteios</b><strong>${s.draws}</strong><small>resultado registrado</small></article><article><b>Status</b><strong>${report.event.status==='closed'?'Fechado':'Aberto'}</strong><small>do evento</small></article>`;
  byId('detailsLabel').textContent='RESULTADO';
  table('prizesHead','prizesBody',winner?[winner]:[],[{label:'Registro',value:r=>r.registration_number},{label:'Vencedor',value:r=>r.name},{label:'Data do sorteio',value:r=>date(r.drawn_at)}]);
  if(winner){byId('winnerPanel').hidden=false;byId('winnerPanel').innerHTML=`<div class="winner"><p class="eyebrow">VENCEDOR</p><h2>${esc(winner.name)}</h2><p>Registro nº ${esc(winner.registration_number)} · sorteado em ${esc(date(winner.drawn_at))}</p></div>`;}
  byId('peopleLabel').textContent='LISTA DE PARTICIPANTES';
  table('peopleHead','peopleBody',report.entries,[{label:'Registro',value:r=>r.registration_number},{label:'Nome',value:r=>r.name},{label:'WhatsApp',value:r=>r.whatsapp||'—'},{label:'Instagram',value:r=>r.instagram||'—'},{label:'E-mail',value:r=>r.email||'—'}]);
  byId('historyLabel').textContent='INFORMAÇÕES DO SORTEIO';
  table('historyHead','historyBody',winner?[winner]:[],[{label:'Registro vencedor',value:r=>r.registration_number},{label:'Nome',value:r=>r.name},{label:'Data',value:r=>date(r.drawn_at)}]);
}
function download(){
  const book=XLSX.utils.book_new(),base=[{'Evento':report.event.title,'Tipo':report.event.type==='roulette'?'Roleta de Prêmios':'Sorteio por Lista','Status':report.event.status,'Gerado em':new Date().toLocaleString('pt-BR')}];
  XLSX.utils.book_append_sheet(book,XLSX.utils.json_to_sheet(base),'Resumo');
  if(report.event.type==='roulette'){
    XLSX.utils.book_append_sheet(book,XLSX.utils.json_to_sheet(report.participants.map(r=>({Nome:r.name,WhatsApp:r.whatsapp,Instagram:r.instagram||'',Email:r.email||'',Giros:r.spins,Cupons:r.coupons||''}))),'Participantes');
    XLSX.utils.book_append_sheet(book,XLSX.utils.json_to_sheet(report.spins.map(r=>({Data:date(r.created_at),Nome:r.name,WhatsApp:r.whatsapp,Prêmio:r.prize,Cupom:r.coupon||''}))),'Giros');
  }else{
    XLSX.utils.book_append_sheet(book,XLSX.utils.json_to_sheet(report.entries.map(r=>({'Nº registro':r.registration_number,Nome:r.name,WhatsApp:r.whatsapp||'',Instagram:r.instagram||'',Email:r.email||''}))),'Participantes');
  }
  XLSX.writeFile(book,`relatorio-${report.event.title.replace(/[^a-z0-9]+/gi,'-').toLowerCase()}.xlsx`);
}
const {data:{session}}=await supabase.auth.getSession();
if(!session||!eventId)location.href='login.html';
const {data,error}=await supabase.rpc('roleta_get_event_report',{p_event_id:eventId});
if(error){byId('reportTitle').textContent='Não foi possível abrir o relatório';byId('reportMeta').textContent='Entre novamente e tente abrir pelo painel.';byId('print').disabled=true;byId('excel').disabled=true;}else{
  report=data;byId('reportTitle').textContent=report.event.title;byId('reportMeta').textContent=`${report.event.type==='roulette'?'Roleta de Prêmios':'Sorteio por Lista'} · criado em ${date(report.event.created_at)}`;
  report.event.type==='roulette'?renderRoulette():renderList();
}
byId('print').addEventListener('click',()=>window.print());byId('excel').addEventListener('click',download);

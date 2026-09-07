import { supabase } from './supabase.js';

const form=document.querySelector('#eventForm'),rouletteOptions=document.querySelector('#rouletteOptions'),message=document.querySelector('#eventMessage'),rows=document.querySelector('#prizeRows'),total=document.querySelector('#chanceTotal'),createButton=form.querySelector('.primary');
const {data:{session}}=await supabase.auth.getSession();
if(!session)location.href='login.html';

let prizes=[
  {title:'Chocolate',kind:'gift',weight:30},
  {title:'Gire novamente',kind:'spin_again',weight:10},
  {title:'Cupom 10% OFF',kind:'coupon',weight:40},
  {title:'Cupom 20% OFF',kind:'coupon',weight:20}
];
const esc=value=>String(value??'').replace(/[&<>'"]/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[char]));
function makeSlug(title){const name=title.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/(^-|-$)/g,'').slice(0,68)||'evento';return `${name}-${crypto.randomUUID().slice(0,6)}`;}
function selectedType(){return document.querySelector('[name=eventType]:checked').value}
function totalWeight(){return prizes.reduce((sum,prize)=>sum+(Number(prize.weight)||0),0)}
function updateTotal(){const sum=totalWeight(),valid=selectedType()!=='roulette'||(prizes.length>0&&sum===100&&prizes.every(prize=>prize.title.trim()&&Number.isInteger(Number(prize.weight))&&Number(prize.weight)>0));total.textContent=sum===100?'Total: 100% — pronto para salvar.':sum<100?`Total: ${sum}% — faltam ${100-sum}%.`:`Total: ${sum}% — sobram ${sum-100}%.`;total.className=`chance-total ${sum===100?'ok':'error'}`;createButton.disabled=!valid;}
function renderPrizes(){
  rows.innerHTML=prizes.map((prize,index)=>`<div class="prize-row"><label>Prêmio<input data-field="title" data-index="${index}" value="${esc(prize.title)}" maxlength="80"></label><label>Resultado<select data-field="kind" data-index="${index}"><option value="gift" ${prize.kind==='gift'?'selected':''}>Brinde</option><option value="coupon" ${prize.kind==='coupon'?'selected':''}>Cupom</option><option value="spin_again" ${prize.kind==='spin_again'?'selected':''}>Gire novamente</option></select></label><label>Chance (%)<input data-field="weight" data-index="${index}" type="number" min="1" max="100" step="1" value="${esc(prize.weight)}"></label><button type="button" data-remove="${index}" aria-label="Remover prêmio">×</button></div>`).join('');
  rows.querySelectorAll('[data-field]').forEach(input=>['input','change'].forEach(type=>input.addEventListener(type,event=>{const index=Number(event.target.dataset.index),field=event.target.dataset.field;prizes[index][field]=event.target.value;updateTotal();})));
  rows.querySelectorAll('[data-remove]').forEach(button=>button.addEventListener('click',()=>{prizes.splice(Number(button.dataset.remove),1);renderPrizes();}));
  updateTotal();
}
document.querySelector('#addPrize').addEventListener('click',()=>{prizes.push({title:'Novo prêmio',kind:'gift',weight:1});renderPrizes();});
document.querySelectorAll('[name=eventType]').forEach(input=>input.addEventListener('change',()=>{rouletteOptions.hidden=selectedType()!=='roulette';updateTotal();}));
renderPrizes();
form.addEventListener('submit',async event=>{
  event.preventDefault();
  const data=new FormData(form),title=data.get('title').trim(),eventType=selectedType(),layout=eventType==='roulette'?data.get('layout'):'slots',palette=document.querySelector('[name=palette]:checked'),slug=makeSlug(title),preparedPrizes=prizes.map(prize=>({title:prize.title.trim(),kind:prize.kind,weight:Number(prize.weight)}));
  if(eventType==='roulette'&&totalWeight()!==100){updateTotal();return}
  message.textContent='Criando…';
  const {data:id,error}=await supabase.rpc('roleta_create_event',{p_title:title,p_slug:slug,p_layout:layout,p_primary_color:palette?.dataset.primary||'#681D30',p_secondary_color:palette?.dataset.secondary||'#C79339',p_event_type:eventType,p_prizes:eventType==='roulette'?preparedPrizes:null});
  if(error){message.textContent='Não foi possível criar. Confira se os prêmios somam 100%.';return}
  location.href=eventType==='list_draw'?`lista.html?event=${id}`:'./';
});

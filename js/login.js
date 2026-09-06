import { supabase } from './supabase.js';
const form=document.querySelector('#loginForm'),message=document.querySelector('#loginMessage');
form.addEventListener('submit',async e=>{e.preventDefault();message.textContent='Entrando…';const fd=new FormData(form);const {error}=await supabase.auth.signInWithPassword({email:fd.get('email'),password:fd.get('password')});if(error){message.textContent='E-mail ou senha não conferem.';return}location.href='./'});

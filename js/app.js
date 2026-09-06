if ('serviceWorker' in navigator) navigator.serviceWorker.register('./sw.js');
document.querySelectorAll('.primary,.outline,.account').forEach(button=>button.addEventListener('click',()=>alert('A área administrativa será liberada após conectar o login Supabase.')));

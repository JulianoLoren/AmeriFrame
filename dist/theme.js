const root=document.documentElement;
let language='vi';
export function updateThemeLabels(lang){
 language=lang;
 const labels=lang==='vi'?{light:'Trắng',dark:'Đen',group:'Giao diện'}:{light:'Light',dark:'Dark',group:'Appearance'};
 document.getElementById('theme-picker').setAttribute('aria-label',labels.group);
 for(const theme of ['light','dark']){
  const button=document.getElementById('theme-'+theme);
  button.querySelector('.theme-button-label').textContent=labels[theme];
  button.setAttribute('aria-label',`${labels.group}: ${labels[theme]}`);
  button.title=`${labels.group}: ${labels[theme]}`;
  button.setAttribute('aria-pressed',root.dataset.theme===theme);
 }
}
function applyTheme(theme,persist=false){
 root.dataset.theme=theme;
 document.querySelector('meta[name="theme-color"]').content=theme==='dark'?'#101010':'#fafafa';
 if(persist){try{localStorage.setItem('mosaic-theme',theme);}catch{}}
 updateThemeLabels(language);
 document.dispatchEvent(new Event('mosaic-theme-change'));
}
for(const theme of ['light','dark'])document.getElementById('theme-'+theme).addEventListener('click',()=>applyTheme(theme,true));
const preference=matchMedia('(prefers-color-scheme: dark)');
preference.addEventListener('change',event=>{let saved;try{saved=localStorage.getItem('mosaic-theme');}catch{}if(!['light','dark'].includes(saved))applyTheme(event.matches?'dark':'light');});
applyTheme(root.dataset.theme==='dark'?'dark':'light');

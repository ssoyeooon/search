(function(){
  var q=document.getElementById('q'), runBtn=document.getElementById('runSingle');
  if(runBtn) runBtn.addEventListener('click', function(){ var opts=document.getElementById('file-opts'); var rb=document.getElementById('runBatch'); if(opts && opts.style.display!=='none' && rb){ rb.click(); } else if(q){ q.dispatchEvent(new Event('input')); } });
  // 탭 전환 (entity-logic.js 로드/캐시 상태와 무관하게 항상 동작하도록 위임 처리)
  var acTabs=document.getElementById('acSubTabs');
  if(acTabs){
    acTabs.addEventListener('click', function(e){
      var b=e.target.closest('button[data-tab]'); if(!b) return;
      acTabs.querySelectorAll('button').forEach(function(x){ x.classList.remove('active'); });
      document.querySelectorAll('#viewAutocomplete .panel').forEach(function(x){ x.classList.remove('active'); });
      b.classList.add('active');
      var p=document.getElementById(b.dataset.tab); if(p) p.classList.add('active');
    });
  }
  var file=document.getElementById('file'), clr=document.getElementById('fileClear');
  if(file&&clr){
    file.addEventListener('change', function(e){ clr.style.display = (e.target.files&&e.target.files.length) ? 'flex' : 'none'; });
    clr.addEventListener('click', function(){
      file.value='';
      var opts=document.getElementById('file-opts'); if(opts) opts.style.display='none';
      var st=document.getElementById('file-status'); if(st) st.innerHTML='';
      clr.style.display='none';
    });
  }
  var fileUp=document.getElementById('fileUp'), clrUp=document.getElementById('fileClearUp');
  if(fileUp&&clrUp){
    fileUp.addEventListener('change', function(e){ clrUp.style.display=(e.target.files&&e.target.files.length)?'flex':'none'; });
    clrUp.addEventListener('click', function(){ fileUp.value=''; clrUp.style.display='none'; });
  }
  var acf=document.getElementById('acFile'), acclr=document.getElementById('acFileClear');
  if(acf&&acclr){
    acf.addEventListener('change', function(e){ acclr.style.display=(e.target.files&&e.target.files.length)?'flex':'none'; });
    acclr.addEventListener('click', function(){ acf.value=''; var o=document.getElementById('acOpts'); if(o)o.style.display='none'; acclr.style.display='none'; });
  }
})();

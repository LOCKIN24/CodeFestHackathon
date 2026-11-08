import { BROWSE_TIMING } from './scene.js';
import { classifyGesture } from './gesture.js';
import { createPaperCanvas, createStampCanvas, SLOT_CENTERS } from './textures.js';
const $=id=>document.getElementById(id);
const drinkName=stamp=>stamp.type==='milk'?'鮮奶':'豆漿';
const dateLabel=stamp=>{const [y,m,d]=stamp.date.slice(0,10).split('-').map(Number);return `${y} 年 ${m} 月 ${d} 日`;};

export function createPassportBrowser({stage,getScene,getState,prefersReduced,isCollecting,announce}) {
  const lifecycle = new AbortController();
  const listen = (target, event, handler) => target.addEventListener(event, handler, {signal:lifecycle.signal});
  const dialog=$('passport-browser'),details=$('stamp-details'),mount=$('browse-stage-mount');
  const home=document.createComment('護照原始位置');stage.before(home);
  let stamps=[],spread=0,total=2,opening=false,turning=false,gesture=null,raf=0,selected=null,focusBefore=null,scene=null,backdropPressed=false;
  let last=0,elapsed=0;
  const fallbackCanvases=[];
  function targets() {
    if(scene)return scene.stampTargets();
    return stamps.slice(spread*8,spread*8+8).map((stamp,index)=>{
      const bounds=fallbackCanvases[Math.floor(index/4)].getBoundingClientRect(),p=SLOT_CENTERS[index%4];
      return {stamp,x:bounds.left+p.u*bounds.width,y:bounds.top+p.v*bounds.height};
    });
  }
  function updateHotspots() {
    const focused=document.activeElement?.dataset?.stampId;
    $('stamp-hotspots').replaceChildren();if(opening||turning||!dialog.open)return;
    for(const {stamp,x,y} of targets()) {
      const button=document.createElement('button');button.className='stamp-hotspot';button.dataset.stampId=stamp.id;
      button.setAttribute('aria-label',`查看${drinkName(stamp)}印章，${dateLabel(stamp)}`);
      button.style.left=`${x}px`;button.style.top=`${y}px`;
      listen(button,'click',()=>showDetails(stamp));$('stamp-hotspots').append(button);
      if(focused===stamp.id)button.focus({preventScroll:true});
    }
  }
  function updateNav() {
    $('previous-spread').disabled=opening||turning||spread===0;
    $('next-spread').disabled=opening||turning||spread===total-1;
    $('spread-status').textContent=`${spread+1} / ${total}`;
    $('spread-status').setAttribute('aria-label',`第 ${spread+1} 個集章跨頁，共 ${total} 個`);
    $('browse-hint').textContent=opening?'正在翻到你的集章頁…':stamps.length?'左右滑動翻頁・輕點印章查看收藏':'還沒有印章，留給下一次的小美好。';
    dialog.dataset.spread=String(spread);dialog.dataset.turning=String(turning);dialog.dataset.opening=String(opening);
    dialog.setAttribute('aria-busy',String(opening||turning));
    updateHotspots();
  }
  function drawFallback() {
    fallbackCanvases.forEach(canvas=>canvas.remove());fallbackCanvases.length=0;
    let wrapper=mount.querySelector('.browse-fallback');
    if(!wrapper){wrapper=document.createElement('div');wrapper.className='browse-fallback';mount.append(wrapper);}
    for(let side=0;side<2;side++){
      const canvas=createPaperCanvas({side:side?'right':'left',pageNumber:spread*2+side+1,stamps:stamps.slice(spread*8+side*4,spread*8+side*4+4).map((s,slot)=>({...s,slot}))});
      wrapper.append(canvas);fallbackCanvases.push(canvas);
    }
  }
  function open() {
    if(dialog.open||isCollecting())return;
    focusBefore=document.activeElement;stamps=getState().stamps;
    // 實體護照預留兩個集章跨頁；超過八枚時自動延伸。
    total=Math.max(2,Math.ceil((stamps.length+1)/8));spread=Math.max(0,Math.floor((stamps.length-1)/8));
    scene=getScene();document.body.classList.add('browsing');mount.append(stage);dialog.showModal();
    if(scene)scene.startBrowsing(stamps,spread);else {stage.hidden=true;drawFallback();}
    stage.querySelector('canvas').tabIndex=-1;
    opening=Boolean(scene&&!prefersReduced());updateNav();
    if(opening){
      last=0;elapsed=0;scene.browseOpeningFrame(0);announce('正在打開護照。');
      const duration=BROWSE_TIMING.expand+BROWSE_TIMING.open+BROWSE_TIMING.find;
      function frame(now){
        if(!dialog.open)return;
        if(last&&!document.hidden)elapsed+=Math.min(now-last,80);last=now;
        scene.browseOpeningFrame(Math.min(elapsed,duration));
        if(elapsed>=duration){opening=false;updateNav();announce(`已打開護照，共 ${stamps.length} 枚印章。`);return;}
        raf=requestAnimationFrame(frame);
      }
      raf=requestAnimationFrame(frame);
    }else announce(`已打開護照，共 ${stamps.length} 枚印章。`);
  }
  function close() {
    if(details.open)closeDetails();
    cancelAnimationFrame(raf);opening=false;turning=false;gesture=null;scene?.clearBrowseTurn();
    if(dialog.open)dialog.close();home.after(stage);stage.hidden=false;
    mount.querySelector('.browse-fallback')?.remove();fallbackCanvases.length=0;
    document.body.classList.remove('browsing');
    if(scene){scene.idle();scene.resize();scene.render();}
    $('stamp-hotspots').replaceChildren();focusBefore?.focus({preventScroll:true});announce('已關閉護照。');
  }
  function recover() {
    if(!dialog.open)return;
    cancelAnimationFrame(raf);gesture=null;opening=false;turning=false;scene?.clearBrowseTurn();scene=null;
    stage.hidden=true;drawFallback();updateNav();announce('收藏都還在，可以繼續翻閱。');
  }
  function turn(direction) {
    if(!dialog.open||details.open||opening||turning)return;
    const next=spread+direction;
    if(next<0||next>=total){announce(direction<0?'已經是第一個集章跨頁。':'已經是最後一個集章跨頁。');return;}
    turning=true;gesture=null;updateNav();
    if(!scene||prefersReduced()) {
      spread=next;if(scene){scene.setBrowseSpread(spread);scene.render();}else drawFallback();
      turning=false;updateNav();return;
    }
    scene.startBrowseTurn(direction,next);last=0;elapsed=0;
    function frame(now) {
      if(!dialog.open)return;
      if(last&&!document.hidden)elapsed+=Math.min(now-last,80);last=now;
      scene.browseTurnFrame(Math.min(1,elapsed/BROWSE_TIMING.turn));
      if(elapsed>=BROWSE_TIMING.turn){scene.finishBrowseTurn();spread=next;turning=false;updateNav();return;}
      raf=requestAnimationFrame(frame);
    }
    raf=requestAnimationFrame(frame);
  }
  function showDetails(stamp) {
    if(!stamp||opening||turning||details.open||!dialog.open)return;
    backdropPressed=false;
    selected=stamp;$('stamp-drink').textContent=drinkName(stamp);$('stamp-date').textContent=`收藏於 ${dateLabel(stamp)}`;
    // 使用同一張印章圖，種子不影響飲品意義或日期。
    const art=createStampCanvas(stamp.type);$('detail-art').replaceChildren(art);
    details.showModal();$('close-stamp-details').focus({preventScroll:true});
  }
  function closeDetails() {
    details.close();
    const target=[...$('stamp-hotspots').children].find(button=>button.dataset.stampId===selected?.id);
    target?.focus({preventScroll:true});selected=null;
  }
  function fallbackStampAt(x,y) {
    return targets().find(t=>{
      const index=stamps.findIndex(s=>s.id===t.stamp.id)%8,bounds=fallbackCanvases[Math.floor(index/4)].getBoundingClientRect();
      return Math.pow((x-t.x)/(153/768*bounds.width),2)+Math.pow((y-t.y)/(153/1080*bounds.height),2)<=1;
    })?.stamp;
  }
  listen(mount,'pointerdown',e=>{
    if(!e.isPrimary){gesture=null;return;}
    if(opening||turning||details.open||e.button!==0)return;
    gesture={id:e.pointerId,x:e.clientX,y:e.clientY,maxDistance:0,start:performance.now()};
    mount.setPointerCapture(e.pointerId);
  });
  listen(mount,'pointermove',e=>{
    if(gesture?.id!==e.pointerId)return;
    gesture.maxDistance=Math.max(gesture.maxDistance,Math.hypot(e.clientX-gesture.x,e.clientY-gesture.y));
  });
  listen(mount,'pointerup',e=>{
    if(gesture?.id!==e.pointerId)return;
    const current=gesture;gesture=null;
    if(mount.hasPointerCapture(e.pointerId))mount.releasePointerCapture(e.pointerId);
    const dx=e.clientX-current.x,dy=e.clientY-current.y;
    const action=classifyGesture({dx,dy,maxDistance:Math.max(current.maxDistance,Math.hypot(dx,dy)),duration:performance.now()-current.start});
    if(action==='next')turn(1);else if(action==='previous')turn(-1);
    else if(action==='tap')showDetails(scene?scene.stampAt(e.clientX,e.clientY):fallbackStampAt(e.clientX,e.clientY));
  });
  listen(mount,'pointercancel',()=>{gesture=null;});
  // 觸控的隱式 capture 從 Canvas 移交至容器時，也會從子元素冒泡此事件。
  listen(mount,'lostpointercapture',e=>{if(e.target===mount)gesture=null;});
  listen(window,'blur',()=>{gesture=null;});
  listen(document,'visibilitychange',()=>{gesture=null;last=0;});
  listen($('open-passport'),'click',open);
  listen($('close-passport'),'click',close);
  listen($('previous-spread'),'click',()=>turn(-1));listen($('next-spread'),'click',()=>turn(1));
  listen($('close-stamp-details'),'click',closeDetails);listen($('return-to-passport'),'click',closeDetails);
  listen(details,'cancel',e=>{e.preventDefault();closeDetails();});
  function isBackdrop(e){const r=details.getBoundingClientRect();return e.target===details&&(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom);}
  listen(details,'pointerdown',e=>{backdropPressed=isBackdrop(e);});
  listen(details,'pointercancel',()=>{backdropPressed=false;});
  // 開啟面板那次輕點後的合成 click 不得立即關掉剛開啟的面板。
  listen(details,'click',e=>{if(backdropPressed&&isBackdrop(e))closeDetails();backdropPressed=false;});
  listen(dialog,'cancel',e=>{e.preventDefault();close();});
  listen(dialog,'keydown',e=>{
    if(details.open)return;
    if(e.key==='ArrowLeft'){e.preventDefault();turn(-1);}else if(e.key==='ArrowRight'){e.preventDefault();turn(1);}
  });
  const observer = new ResizeObserver(()=>{if(dialog.open&&!opening&&!turning)updateHotspots();});observer.observe(mount);
  return {open,close,recover, suspend(){cancelAnimationFrame(raf);gesture=null;if(dialog.open)close();}, dispose(){cancelAnimationFrame(raf);if(dialog.open)close();observer.disconnect();lifecycle.abort();}};
}

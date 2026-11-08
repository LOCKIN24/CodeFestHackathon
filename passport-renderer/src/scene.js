import * as THREE from 'three';
import { createCoverCanvas, createPaperCanvas, createLeatherCanvas, createWoodCanvas, SLOT_CENTERS } from './textures.js';

// 所有階段以毫秒計；接觸點由同一個時間軸驅動工具位置與印泥。
export const TIMING = Object.freeze({ appear: 600, open: 800, find: 1050, stamp: 1000, admire: 1200, close: 1100 });
export const STAMP_MOTION = Object.freeze({ enter: .28, contact: .46, release: .61, leave: .95 });
export const TOTAL_DURATION = Object.values(TIMING).reduce((a, b) => a + b, 0);
export const BROWSE_TIMING = Object.freeze({ expand: 420, open: 650, find: 800, turn: 540 });
const W = 2.42, H = 3.46, PAGE_Z = .132;
const IDLE_X = -(W + .10) / 2, IDLE_Y = -.18;
const clamp = (n) => Math.max(0, Math.min(1, n));
const smooth = (t) => { t = clamp(t); return t * t * (3 - 2 * t); };
const cubic = (t) => 1 - Math.pow(1 - clamp(t), 3);
const mix = (a, b, t) => a + (b - a) * t;
export const EASING = { smooth, cubic };

function texture(canvas) {
  const tex = new THREE.CanvasTexture(canvas);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.anisotropy = 4;
  return tex;
}
function roundShape(w, h, r) {
  const s = new THREE.Shape();
  s.moveTo(r, -h / 2); s.lineTo(w - r, -h / 2);
  s.quadraticCurveTo(w, -h / 2, w, -h / 2 + r);
  s.lineTo(w, h / 2 - r); s.quadraticCurveTo(w, h / 2, w - r, h / 2);
  s.lineTo(r, h / 2); s.quadraticCurveTo(0, h / 2, 0, h / 2 - r);
  s.lineTo(0, -h / 2 + r); s.quadraticCurveTo(0, -h / 2, r, -h / 2);
  return s;
}
function faceGeometry(w, h) {
  const g = new THREE.ShapeGeometry(roundShape(w, h, .08), 2);
  const p = g.attributes.position, uv = g.attributes.uv;
  for (let i = 0; i < p.count; i++) uv.setXY(i, p.getX(i) / w, (p.getY(i) + h / 2) / h);
  return g;
}
function createCover(leather, front = false) {
  const group = new THREE.Group();
  const body = new THREE.Mesh(new THREE.ExtrudeGeometry(roundShape(W + .10, H + .18, .12), {
    depth: .06, bevelEnabled: true, bevelSegments: 1, steps: 1, bevelSize: .04, bevelThickness: .025, curveSegments: 2,
  }), new THREE.MeshStandardMaterial({ color: '#d6dfe6', map: leather, roughness: .89, flatShading: true }));
  body.castShadow = true; body.receiveShadow = true; group.add(body);
  const top = new THREE.Mesh(faceGeometry(W + .10, H + .18), new THREE.MeshStandardMaterial({
    map: texture(front ? createCoverCanvas() : createPaperCanvas({ variant: 'notes' })), roughness: 1,
  }));
  top.position.z = .086; group.add(top);
  if (front) {
    const linerGeo = faceGeometry(W + .04, H + .10);
    const uv = linerGeo.attributes.uv;
    for (let i = 0; i < uv.count; i++) uv.setX(i, 1 - uv.getX(i));
    const liner = new THREE.Mesh(linerGeo, new THREE.MeshStandardMaterial({ map: texture(createPaperCanvas({ variant: 'intro' })), side: THREE.BackSide, roughness: 1 }));
    liner.position.z = -.026; group.add(liner);
  }
  return group;
}
function pageMesh(canvas, back = false) {
  // 十六道可彎折切面形成紙頁；正反面各有自己的貼圖與朝向。
  const geo = new THREE.PlaneGeometry(W, H, 16, 4);
  const pos = geo.attributes.position, uv = geo.attributes.uv;
  for (let i = 0; i < pos.count; i++) {
    pos.setX(i, pos.getX(i) + W / 2);
    if (back) uv.setX(i, 1 - uv.getX(i));
  }
  const m = new THREE.Mesh(geo, new THREE.MeshStandardMaterial({ map: texture(canvas), side: back ? THREE.BackSide : THREE.FrontSide, roughness: 1, flatShading: true }));
  m.castShadow = true; m.receiveShadow = true;
  m.userData.original = Float32Array.from(pos.array);
  m.userData.back = back;
  return m;
}
function setCurl(mesh, amount) {
  const p = mesh.geometry.attributes.position, source = mesh.userData.original;
  for (let i = 0; i < p.count; i++) {
    const x = source[i * 3];
    p.setZ(i, Math.sin(x / W * Math.PI) * amount + (mesh.userData.back ? -.004 : .004));
  }
  p.needsUpdate = true; mesh.geometry.computeVertexNormals();
}
function replaceTexture(mesh, canvas) {
  mesh.material.map.dispose(); mesh.material.map = texture(canvas); mesh.material.needsUpdate = true;
}
function cylinder(radiusTop, radiusBottom, height, segments, color, z) {
  const obj = new THREE.Mesh(new THREE.CylinderGeometry(radiusTop, radiusBottom, height, segments),
    new THREE.MeshStandardMaterial({ color, roughness: .54, metalness: color === '#ae8850' ? .65 : 0, flatShading: true }));
  obj.rotation.x = Math.PI / 2; obj.position.z = z; obj.castShadow = true; return obj;
}
function createStampTool() {
  const group = new THREE.Group();
  group.add(cylinder(.43, .43, .055, 10, '#3c3834', .0275));
  group.add(cylinder(.44, .48, .14, 10, '#ae8850', .125));
  group.add(cylinder(.27, .43, .055, 10, '#c6a66e', .222));
  const points = [[.16,0],[.13,.13],[.12,.28],[.17,.41],[.25,.50],[.28,.65],[.22,.80],[0,.86]].map(([x,y]) => new THREE.Vector2(x,y));
  const handle = new THREE.Mesh(new THREE.LatheGeometry(points, 8), new THREE.MeshStandardMaterial({ map: texture(createWoodCanvas()), roughness: .68, flatShading: true }));
  handle.rotation.x = Math.PI / 2; handle.position.z = .245; handle.castShadow = true; group.add(handle);
  group.visible = false; return group;
}

export class PassportScene {
  constructor(canvas, container, callbacks = {}) {
    this.canvas = canvas; this.container = container; this.callbacks = callbacks;
    const context=canvas.getContext('webgl2',{antialias:true,alpha:true});
    if(!context)throw new Error('此瀏覽器改用靜態集章顯示。');
    this.renderer = new THREE.WebGLRenderer({ canvas, context, antialias: true, alpha: true });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.setClearColor(0x000000, 0);
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping; this.renderer.toneMappingExposure = .94;
    this.scene = new THREE.Scene();
    this.camera = new THREE.PerspectiveCamera(32, 1, .1, 60);
    this.scene.add(new THREE.HemisphereLight('#fff6e3', '#c5b7a1', 1.35));
    const key = new THREE.DirectionalLight('#fff0d5', 1.7); key.position.set(-3, 5, 9);
    key.castShadow = true; key.shadow.mapSize.set(2048,2048);
    Object.assign(key.shadow.camera, { left: -6, right: 6, top: 6, bottom: -6, near: .1, far: 25 });
    key.shadow.normalBias = .025; key.shadow.bias = -.0002; key.shadow.radius = 4;
    this.scene.add(key);
    const fill = new THREE.DirectionalLight('#e4edff', .55); fill.position.set(4,-2,5); this.scene.add(fill);
    const floor = new THREE.Mesh(new THREE.PlaneGeometry(80,80), new THREE.ShadowMaterial({ color: '#5e4b31', opacity: .12 }));
    floor.position.z = -.12; floor.receiveShadow = true; this.scene.add(floor);
    // 柔邊接觸陰影補足低多邊形實體的重量，沒有外部圖片。
    const shadowCanvas = document.createElement('canvas'); shadowCanvas.width = shadowCanvas.height = 128;
    const ctx = shadowCanvas.getContext('2d'); const grad = ctx.createRadialGradient(64,64,10,64,64,64);
    grad.addColorStop(0,'rgba(69,54,28,.21)'); grad.addColorStop(1,'rgba(69,54,28,0)'); ctx.fillStyle=grad;ctx.fillRect(0,0,128,128);
    this.contactShadow = new THREE.Mesh(new THREE.PlaneGeometry(4.1,4.9), new THREE.MeshBasicMaterial({ map: texture(shadowCanvas), transparent:true, depthWrite:false }));
    this.contactShadow.position.z = -.115; this.scene.add(this.contactShadow);
    this.book = new THREE.Group(); this.scene.add(this.book);
    const leather = texture(createLeatherCanvas());
    this.backCover = createCover(leather); this.backCover.position.set(-.03,0,-.06); this.book.add(this.backCover);
    // 可見書口：每層皆為薄實體，不用平面圖片模擬厚度。
    for(let i=0;i<11;i++) {
      const sheet = new THREE.Mesh(new THREE.BoxGeometry(W-.02,H-.035,.012), new THREE.MeshStandardMaterial({color:i%3===0?'#d5c8a9':'#e9ddbf',roughness:1,flatShading:true}));
      sheet.position.set(W/2,0,.015+i*.0105); sheet.receiveShadow=true;sheet.castShadow=true;this.book.add(sheet);
    }
    this.rightPage = pageMesh(createPaperCanvas({side:'right'})); setCurl(this.rightPage,0);this.rightPage.position.z=PAGE_Z;this.book.add(this.rightPage);
    this.leaves = [];
    for(let i=0;i<3;i++) {
      const leaf=new THREE.Group();const front=pageMesh(createPaperCanvas({variant:i%2?'notes':'intro',pageNumber:i*2+1}));
      const back=pageMesh(createPaperCanvas({variant:i===2?'collection':'notes',side:'left',pageNumber:i*2+2}),true);
      leaf.add(front,back);leaf.userData={front,back,index:i};this.book.add(leaf);this.leaves.push(leaf);
    }
    this.cover = createCover(leather,true);this.book.add(this.cover);
    const spine = new THREE.Mesh(new THREE.BoxGeometry(.09,H+.13,.28),new THREE.MeshStandardMaterial({color:'#182c40',roughness:.9,flatShading:true}));
    spine.position.set(-.035,0,.07);spine.castShadow=true;this.book.add(spine);
    // 深藍書籤的末端也使用真正幾何。
    const ribbon = new THREE.Mesh(new THREE.BoxGeometry(.12,.36,.014),new THREE.MeshStandardMaterial({color:'#b89b61',roughness:.95}));ribbon.position.set(W*.75,-H/2-.08,.018);this.book.add(ribbon);
    this.tool = createStampTool();this.book.add(this.tool);
    this.active = false;this.idle();
    this.resizeObserver = new ResizeObserver(()=>{this.resize();if(!this.active||this.browsing)this.render();});
    this.resizeObserver.observe(container);this.resize();this.render();
    this.onLost=e=>{e.preventDefault();if(!this.disposed)this.callbacks.onContextLost?.();};
    this.onRestored=()=>{if(!this.disposed)this.render();};
    canvas.addEventListener('webglcontextlost',this.onLost);
    canvas.addEventListener('webglcontextrestored',this.onRestored);
  }
  resize() {
    if(this.disposed)return;
    const {width,height}=this.container.getBoundingClientRect();if(!width||!height)return;
    this.renderer.setSize(width,height,false);this.camera.aspect=width/height;
    const isActive=this.active;
    // 直式手機保留完整跨頁與工具的安全邊界；橫式畫面則以高度約束。
    const fitWidth=isActive?5.8:3.8, fitHeight=isActive?6.7:5.35;
    const distance=Math.max(fitHeight,fitWidth/this.camera.aspect)/(2*Math.tan(THREE.MathUtils.degToRad(16)));
    this.viewDistance=distance;
    const tilt=isActive?.35:0;
    this.setCameraTilt(tilt);
    this.camera.updateProjectionMatrix();
  }
  setCameraTilt(tilt) {
    const distance=this.viewDistance;
    if(!distance)return;
    this.camera.position.set(0,-distance*Math.sin(tilt),distance*Math.cos(tilt));
    this.camera.lookAt(0,.1*(tilt/.35),0);
  }
  idle() {
    this.clearBrowseTurn();this.browseCanvasCache?.clear();this.browsing=false;this.active=false;this.book.visible=true;this.tool.visible=false;this.book.position.set(IDLE_X,IDLE_Y,.02);
    this.book.scale.setScalar(1);
    this.book.rotation.set(0,0,0);this.cover.rotation.y=0;this.cover.position.z=.22;
    this.leaves.forEach((leaf,i)=>this.setLeaf(i,0));this.canvas.style.opacity='1';
    this.contactShadow.position.x=0;this.contactShadow.scale.x=.8;
  }
  setLeaf(index,p) {
    const leaf=this.leaves[index];
    leaf.rotation.y=-Math.PI*p;
    leaf.position.z=mix(.195-index*.018,.075+index*.016,p);
    const curl=Math.sin(Math.PI*p)*.20;
    setCurl(leaf.userData.front,curl);setCurl(leaf.userData.back,curl);
  }
  prepare(stamps, latest) {
    this.stamps=stamps;this.latest=latest;this.inked=false;
    const idx=Math.max(0,stamps.findIndex(s=>s.id===latest.id));this.spread=Math.floor(idx/8);this.targetIndex=idx%8;
    this.setCollection(false);
    // 提前產生並上傳完成頁，按壓瞬間只切換貼圖，不做大量像素運算。
    this.inkTextures=this.collectionCanvases(true).map(texture);
    this.inkTextures.forEach(map=>this.renderer.initTexture(map));
    this.leaves.forEach((_,i)=>this.setLeaf(i,1));
    this.target=this.surfacePoint();
    this.active=true;this.resize();this.book.rotation.set(0,0,-.035);this.tool.visible=false;
  }
  surfacePoint() {
    const point=SLOT_CENTERS[this.targetIndex%4], left=this.targetIndex<4;
    const page=left?this.leaves[2]:this.rightPage;
    const local=new THREE.Vector3(left?(1-point.u)*W:point.u*W,(.5-point.v)*H,left?-.004:.004);
    this.book.updateMatrixWorld(true);
    return this.book.worldToLocal(page.localToWorld(local));
  }
  collectionCanvases(includeLatest) {
    const pageStamps=this.stamps.slice(this.spread*8,this.spread*8+8);
    const make=(side)=>pageStamps.slice(side*4,side*4+4).map((s,i)=>({...s,slot:i})).filter(s=>includeLatest||s.id!==this.latest.id);
    const left=createPaperCanvas({side:'left',stamps:make(0),pageNumber:this.spread*2+1,highlightSlot:!includeLatest&&this.targetIndex<4?this.targetIndex:-1});
    const right=createPaperCanvas({side:'right',stamps:make(1),pageNumber:this.spread*2+2,highlightSlot:!includeLatest&&this.targetIndex>=4?this.targetIndex-4:-1});
    return [left,right];
  }
  setCollection(includeLatest) {
    const [left,right]=this.collectionCanvases(includeLatest);
    replaceTexture(this.leaves[2].userData.back,left);replaceTexture(this.rightPage,right);
  }
  reveal() {
    if(this.inked)return;
    [this.leaves[2].userData.back,this.rightPage].forEach((mesh,i)=>{
      mesh.material.map.dispose();mesh.material.map=this.inkTextures[i];mesh.material.needsUpdate=true;
    });
    this.inked=true;
    // 同一次畫格：工具底部已被放置在紙面上，才提交印章。
    this.callbacks.onContact?.({id:this.latest.id,type:this.latest.type,contactDistance:this.tool.position.distanceTo(this.surfacePoint())});
  }
  frame(elapsed,reduced=false) {
    this.book.visible=true;this.canvas.style.opacity='1';this.setCameraTilt(.35);
    const {appear,open,find,stamp,admire,close}=TIMING;
    const a=appear,o=a+open,f=o+find,s=f+stamp,d=s+admire;
    let phase='appear';
    this.book.position.set(0,0,.02);this.book.rotation.set(0,0,-.035);this.cover.position.z=.015;
    this.rightPage.position.z=PAGE_Z;
    this.cover.rotation.y=-Math.PI;this.leaves.forEach((_,i)=>this.setLeaf(i,1));this.tool.visible=false;
    this.contactShadow.scale.x=1.45;this.contactShadow.position.x=0;
    if(reduced) {
      phase=this.inked?'admire':'stamp';
      this.tool.position.copy(this.target);this.reveal();this.tool.visible=false;
    } else if(elapsed<a) {
      const p=clamp(elapsed/appear),e=cubic(p);phase='appear';
      this.book.position.set(IDLE_X,IDLE_Y-.47*(1-e),.02+.45*(1-e));this.book.rotation.set(0,0,0);this.setCameraTilt(0);
      this.cover.rotation.y=0;this.cover.position.z=.22;this.leaves.forEach((_,i)=>this.setLeaf(i,0));
      this.canvas.style.opacity=String(smooth(p/.45));this.contactShadow.scale.x=.8;
    } else if(elapsed<o) {
      const p=smooth((elapsed-a)/open);phase='open';
      this.book.position.x=mix(IDLE_X,0,p);this.book.position.y=mix(IDLE_Y,0,p);this.book.rotation.set(0,0,-.035*p);this.setCameraTilt(.35*p);
      this.cover.rotation.y=-Math.PI*p;this.cover.position.z=mix(.22,.015,p);this.leaves.forEach((_,i)=>this.setLeaf(i,0));
      this.contactShadow.scale.x=mix(.8,1.45,p);
    } else if(elapsed<f) {
      phase='find';const t=(elapsed-o)/find;
      this.leaves.forEach((_,i)=>this.setLeaf(i,smooth((t-i*.21)/.58)));
    } else if(elapsed<s) {
      phase='stamp';const t=(elapsed-f)/stamp;const m=STAMP_MOTION;
      const pressure=Math.sin(Math.PI*clamp((t-m.contact)/(m.release-m.contact)))*.006;
      if(this.targetIndex<4)this.leaves[2].position.z-=pressure;else this.rightPage.position.z-=pressure;
      this.target=this.surfacePoint();
      this.tool.visible=t<m.leave;
      let height=1.75,offset=.45,tilt=-.16;
      if(t<m.enter) {const p=cubic(t/m.enter);height=mix(2.5,1.05,p);offset=mix(.6,0,p);tilt=mix(-.25,0,p);}
      else if(t<m.contact){const p=clamp((t-m.enter)/(m.contact-m.enter));height=1.05*(1-p*p*p);offset=0;tilt=0;}
      else if(t<m.release){height=0;offset=0;tilt=0;}
      else {const p=cubic((t-m.release)/(m.leave-m.release));height=2.7*p;offset=.5*p;tilt=.18*p;}
      this.tool.position.copy(this.target);this.tool.position.z+=height;this.tool.position.y+=offset;this.tool.rotation.set(tilt,0,-.14);
      if(t>=m.contact&&!this.inked){this.tool.position.copy(this.target);this.reveal();}
      if(t>=m.contact){const bounce=Math.exp(-(t-m.contact)*24)*Math.sin((t-m.contact)*52);this.book.position.z-=.015*bounce;}
    } else if(elapsed<d) {phase='admire';if(!this.inked){this.tool.position.copy(this.target);this.reveal();}}
    else {
      phase='close';const t=clamp((elapsed-d)/close);
      // 紙頁依反序先合攏，全部落下後才蓋封面，最後整本離場。
      this.leaves.forEach((_,i)=>this.setLeaf(i,1-smooth((t-(2-i)*.065)/.25)));
      const coverP=smooth((t-.39)/.32);this.cover.rotation.y=-Math.PI*(1-coverP);this.cover.position.z=mix(.015,.22,coverP);
      this.book.position.x=IDLE_X*coverP;this.book.rotation.z=mix(-.035,0,coverP);this.setCameraTilt(.35*(1-coverP));this.contactShadow.scale.x=mix(1.45,.8,coverP);
      const exit=smooth((t-.73)/.27);this.book.position.y=mix(0,IDLE_Y,coverP)-.62*exit;this.book.position.z=.02+.35*exit;
      this.canvas.style.opacity=String(1-exit);
    }
    this.callbacks.onPhase?.(phase);this.render();return phase;
  }
  browseCanvases(spread) {
    if(this.browseCanvasCache?.has(spread))return this.browseCanvasCache.get(spread);
    const canvases=[0,1].map(side=>createPaperCanvas({side:side?'right':'left',pageNumber:spread*2+side+1,
      stamps:this.browseStamps.slice(spread*8+side*4,spread*8+side*4+4).map((s,slot)=>({...s,slot}))}));
    if(this.browseCanvasCache.size>=3)this.browseCanvasCache.delete(this.browseCanvasCache.keys().next().value);
    this.browseCanvasCache.set(spread,canvases);return canvases;
  }
  setBrowseSpread(spread) {
    this.browseSpread=spread;
    const [left,right]=this.browseCanvases(spread);
    replaceTexture(this.leaves[2].userData.back,left);replaceTexture(this.rightPage,right);
  }
  startBrowsing(stamps,spread=0) {
    this.clearBrowseTurn();this.browseCanvasCache=new Map();this.browseStamps=stamps;this.browsing=true;this.active=true;
    this.book.visible=true;this.book.scale.setScalar(1);this.canvas.style.opacity='1';this.tool.visible=false;
    this.book.position.set(0,0,.02);this.book.rotation.set(0,0,-.035);
    this.cover.rotation.y=-Math.PI;this.cover.position.z=.015;this.rightPage.position.z=PAGE_Z;
    this.leaves.forEach((_,i)=>this.setLeaf(i,1));
    this.contactShadow.position.x=0;this.contactShadow.scale.x=1.45;
    this.setBrowseSpread(spread);this.resize();this.render();
  }
  browseOpeningFrame(elapsed) {
    const {expand,open,find}=BROWSE_TIMING;this.setCameraTilt(.35);
    this.book.scale.setScalar(1);this.book.position.set(0,0,.02);this.book.rotation.set(0,0,-.035);
    this.cover.position.z=.015;this.cover.rotation.y=-Math.PI;
    this.rightPage.position.z=PAGE_Z;this.tool.visible=false;
    this.leaves.forEach((_,i)=>this.setLeaf(i,1));
    this.contactShadow.position.x=0;this.contactShadow.scale.x=1.45;
    if(elapsed<expand){
      const p=cubic(elapsed/expand),scale=mix(.62,1,p);
      this.book.scale.setScalar(scale);this.book.position.set(IDLE_X*scale,IDLE_Y,.02+.18*(1-p));
      this.book.rotation.set(0,0,0);this.setCameraTilt(0);
      this.cover.position.z=.22;this.cover.rotation.y=0;this.leaves.forEach((_,i)=>this.setLeaf(i,0));
      this.contactShadow.scale.x=mix(.5,.8,p);
    }else if(elapsed<expand+open){
      const p=smooth((elapsed-expand)/open);
      this.book.position.x=mix(IDLE_X,0,p);this.book.position.y=mix(IDLE_Y,0,p);this.book.rotation.set(0,0,-.035*p);this.setCameraTilt(.35*p);
      this.cover.rotation.y=-Math.PI*p;this.cover.position.z=mix(.22,.015,p);
      this.leaves.forEach((_,i)=>this.setLeaf(i,0));this.contactShadow.scale.x=mix(.8,1.45,p);
    }else{
      const p=clamp((elapsed-expand-open)/find);
      this.leaves.forEach((_,i)=>this.setLeaf(i,smooth((p-i*.21)/.58)));
    }
    this.render();
  }
  startBrowseTurn(direction,nextSpread) {
    this.clearBrowseTurn();
    const current=this.browseCanvases(this.browseSpread),next=this.browseCanvases(nextSpread);
    const forward=direction>0,leaf=new THREE.Group();
    const front=pageMesh(forward?current[1]:next[1]);
    const back=pageMesh(forward?next[0]:current[0],true);
    leaf.add(front,back);this.book.add(leaf);this.browseTurn={leaf,front,back,direction,nextSpread};
    // 翻動中的紙頁遮住舊頁；底下先放好將要顯露的集章頁。
    if(forward)replaceTexture(this.rightPage,next[1]);else replaceTexture(this.leaves[2].userData.back,next[0]);
    this.browseTurnFrame(0);
  }
  browseTurnFrame(progress) {
    const turn=this.browseTurn;if(!turn)return;
    const p=smooth(progress),angle=turn.direction>0?p:1-p;
    turn.leaf.rotation.y=-Math.PI*angle;turn.leaf.position.z=mix(.155,.12,angle);
    const curl=Math.sin(Math.PI*angle)*.22;
    setCurl(turn.front,curl);setCurl(turn.back,curl);this.render();
  }
  finishBrowseTurn() {
    if(!this.browseTurn)return;
    const next=this.browseTurn.nextSpread;this.clearBrowseTurn();this.setBrowseSpread(next);this.render();
  }
  clearBrowseTurn() {
    if(!this.browseTurn)return;
    const {leaf,front,back}=this.browseTurn;this.book.remove(leaf);
    for(const mesh of [front,back]){mesh.material.map.dispose();mesh.material.dispose();mesh.geometry.dispose();}
    this.browseTurn=null;
  }
  stampAt(clientX,clientY) {
    if(!this.browsing||this.browseTurn)return null;
    const bounds=this.canvas.getBoundingClientRect();
    const ray=new THREE.Raycaster();ray.setFromCamera(new THREE.Vector2((clientX-bounds.left)/bounds.width*2-1,-(clientY-bounds.top)/bounds.height*2+1),this.camera);
    this.book.updateMatrixWorld(true);
    const pages=[this.leaves[2].userData.back,this.rightPage],hits=ray.intersectObjects(pages);
    if(!hits.length)return null;
    const hit=hits[0],side=pages.indexOf(hit.object),u=hit.uv.x,v=1-hit.uv.y;
    const slot=SLOT_CENTERS.findIndex(p=>Math.pow((u-p.u)/(153/768),2)+Math.pow((v-p.v)/(153/1080),2)<=1);
    return slot<0?null:this.browseStamps[this.browseSpread*8+side*4+slot]??null;
  }
  stampTargets() {
    if(!this.browsing||this.browseTurn)return [];
    const bounds=this.canvas.getBoundingClientRect();this.book.updateMatrixWorld(true);
    return this.browseStamps.slice(this.browseSpread*8,this.browseSpread*8+8).map((stamp,index)=>{
      const left=index<4,p=SLOT_CENTERS[index%4],page=left?this.leaves[2]:this.rightPage;
      const world=page.localToWorld(new THREE.Vector3(left?(1-p.u)*W:p.u*W,(.5-p.v)*H,left?-.004:.004)).project(this.camera);
      return {stamp,x:bounds.left+(world.x+1)/2*bounds.width,y:bounds.top+(1-world.y)/2*bounds.height};
    });
  }
  render(){if(!this.disposed)this.renderer.render(this.scene,this.camera);}
  dispose(){
    if(this.disposed)return;this.disposed=true;this.resizeObserver.disconnect();
    this.canvas.removeEventListener('webglcontextlost',this.onLost);
    this.canvas.removeEventListener('webglcontextrestored',this.onRestored);
    this.clearBrowseTurn();
    const textures=new Set(),materials=new Set(),geometries=new Set();
    this.scene.traverse(object=>{
      if(object.geometry)geometries.add(object.geometry);
      for(const material of (Array.isArray(object.material)?object.material:[object.material])){
        if(!material)continue;materials.add(material);
        for(const value of Object.values(material))if(value?.isTexture)textures.add(value);
      }
      object.shadow?.map?.dispose();object.shadow?.mapPass?.dispose();
    });
    for(const value of this.inkTextures??[])textures.add(value);
    textures.forEach(value=>value.dispose());materials.forEach(value=>value.dispose());geometries.forEach(value=>value.dispose());
    this.browseCanvasCache?.clear();this.renderer.dispose();this.renderer.forceContextLoss();
    this.scene.clear();this.callbacks={};
  }
}

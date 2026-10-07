(() => {
  'use strict';

  const A = 'assets/';
  const world = document.getElementById('world');
  const viewport = document.getElementById('viewport');
  const hudTop = document.getElementById('hud-top');
  const taskPanel = document.getElementById('task-panel');
  const hudBottom = document.getElementById('hud-bottom');
  const modalRoot = document.getElementById('modal-root');
  const charSelect = document.getElementById('character-select');
  const toastEl = document.getElementById('toast');

  const WORLD_W = 2800, WORLD_H = 1800;
  const SALE_SPOTS = [0,1,2].map(i=>({x:2250+i*146,y:1570-i*63,cashX:2190+i*146,cashY:1460-i*63}));
  let nextSaleSpot = 0;
  const SAVE_KEY = 'farmVictoryDemoV4';

  const CHARACTERS = [
    ['farmer_male_blue_overalls','Fazendeiro Azul'],
    ['farmer_female_yellow_apron','Fazendeira Amarela'],
    ['gardener_female_green_overalls','Jardineira Verde'],
    ['vendor_male_green_apron','Fazendeiro Verde'],
    ['farm_girl_red_braids','Fazendeira Ruiva'],
    ['rancher_old_man','Fazendeiro Sênior']
  ];

  const defaultState = () => ({
    coins: 280,
    gems: 12,
    energy: 28,
    maxEnergy: 30,
    inventory: { tomato: 0, egg: 0, wheat: 0 },
    totalSold: 0,
    revenue: 0,
    pendingCash: [0,0,0],
    plantedTomatoes: 0,
    harvestedTomatoes: 0,
    wheatUnlocked: false,
    selectedCharacter: 'farmer_male_blue_overalls',
    tomatoPlots: Array.from({length:16}, (_,i) => i < 4 ? {state:'mature', t:0} : i < 8 ? {state:'growing', t:Date.now()-3500} : {state:'empty', t:0}),
    wheatPlots: Array.from({length:12}, () => ({state:'empty',t:0})),
    eggsReady: 2,
    taskIndex: 0
  });

  let state = loadState();
  let gameStarted = false;
  let player = null;
  let playerPos = {x:1380,y:1340};
  let moveTarget = null;
  let moveCallback = null;
  let walkFrame = 0, walkClock = 0;
  let lastTs = performance.now();
  let camera = {x:0,y:0};
  let customers = [];
  let customerSeq = 1;
  let lastCustomerAt = 0;
  let lastEggAt = Date.now();
  let selectedCharacter = state.selectedCharacter;
  let currentActionTimer = null;

  const taskDefs = [
    { title:'Plante 6 tomates', current:()=>Math.min(state.plantedTomatoes,6), goal:6 },
    { title:'Colha 6 tomates', current:()=>Math.min(state.harvestedTomatoes,6), goal:6 },
    { title:'Venda 8 tomates aos clientes', current:()=>Math.min(state.totalSold,8), goal:8 },
    { title:'Libere a área de trigo', current:()=>state.wheatUnlocked?1:0, goal:1 },
    { title:'Plante 4 trigos', current:()=>Math.min(state.wheatPlots.filter(p=>p.state!=='empty').length,4), goal:4 }
  ];

  function loadState(){
    try { const x = JSON.parse(localStorage.getItem(SAVE_KEY)); return x ? {...defaultState(), ...x, inventory:{...defaultState().inventory,...x.inventory}} : defaultState(); }
    catch { return defaultState(); }
  }
  function saveState(){ localStorage.setItem(SAVE_KEY, JSON.stringify(state)); }

  function el(tag, cls='', attrs={}){
    const n = document.createElement(tag); if(cls) n.className=cls;
    for(const [k,v] of Object.entries(attrs)) k==='text' ? n.textContent=v : n.setAttribute(k,v);
    return n;
  }
  function img(src, cls=''){ const n=el('img',cls); n.src=A+src; n.draggable=false; return n; }
  function toast(msg){ toastEl.textContent=msg; toastEl.classList.add('show-toast'); clearTimeout(toast._t); toast._t=setTimeout(()=>toastEl.classList.remove('show-toast'),1600); }
  function clamp(v,min,max){return Math.max(min,Math.min(max,v));}

  function showCharacterSelect(){
    charSelect.innerHTML='';
    const card=el('div','select-card'); card.innerHTML='<h1>Farm Victory</h1><p>Escolha quem vai cuidar da fazenda. Você poderá trocar depois.</p>';
    const grid=el('div','char-grid');
    CHARACTERS.forEach(([id,label])=>{
      const b=el('div','char-option'+(id===selectedCharacter?' selected':''));
      b.append(img(`character_frames/${id}/01_idle_front.png`)); b.append(el('strong','',{text:label}));
      b.onclick=()=>{selectedCharacter=id; [...grid.children].forEach(x=>x.classList.remove('selected')); b.classList.add('selected');};
      grid.append(b);
    });
    const play=el('button','play-btn',{text:'JOGAR DEMO'}); play.onclick=()=>{ state.selectedCharacter=selectedCharacter; saveState(); charSelect.style.display='none'; startGame(); };
    card.append(grid,play); charSelect.append(card);
  }

  function addImage(src,x,y,w,z=10,cls='world-object'){
    const n=img(src,cls); n.style.left=x+'px'; n.style.top=y+'px'; n.style.width=w+'px'; n.style.zIndex=z; world.append(n); return n;
  }

  function buildWorld(){
    world.innerHTML='';
    customers.forEach(c=>{ try{c.el.remove();c.bubble.remove();}catch{} });
    customers=[];
    // One continuous ground surface; props and fields sit above it.
    const ground=el('div','grass-surface'); world.append(ground);
    // Diamond lattice: adjacent top faces overlap, with no exposed dirt seams.
    for(let row=-2;row<23;row++){
      for(let col=-2;col<13;col++){
        const tile=img('terrain/grass_01.png','grass-diamond');
        tile.style.left=(col*296+(row%2)*148-150)+'px';
        tile.style.top=(row*94-130)+'px'; tile.style.zIndex=row+3;ground.append(tile);
      }
    }
    // Water band / bridge at bottom-right.
    for(let x=1860;x<2800;x+=280) addImage('terrain/water_01.png',x,1470,310,3);
    addImage('terrain/water_bank_01.png',1780,1390,370,4);
    addImage('terrain/water_bank_01.png',2380,1390,370,4);
    addImage('terrain/bridge.png',2140,1410,420,35);

    // Walkable paths: wide and uncluttered.
    path(1230,180,160,1220,'v');
    path(420,1240,1880,145,'h');
    path(1420,360,720,145,'h');
    path(2130,370,150,1050,'v');

    // Main buildings.
    addImage('buildings/house.png',340,170,520,38);
    addImage('buildings/barn.png',1040,130,520,39);
    addImage('buildings/chicken_coop.png',1500,1000,430,48,'world-object interactable').onclick=(e)=>{e.stopPropagation(); interactCoop();};
    const market=addImage('buildings/market.png',2170,1040,520,55,'world-object interactable'); market.onclick=(e)=>{e.stopPropagation(); goToMarket();};

    // Props around buildings only; leave gameplay routes open.
    addImage('props/well.png',250,790,230,25); addImage('props/mailbox.png',720,450,120,30);
    addImage('props/hay_bale.png',1320,410,120,25); addImage('props/barrel.png',1450,430,90,25);
    addImage('props/lantern_post.png',1130,510,105,42); addImage('props/lantern_post.png',2050,1140,105,42);
    addImage('vegetation/sunflower.png',340,1110,120,18); addImage('vegetation/rock.png',450,1450,150,15);

    // Edge vegetation framing.
    const trees=[
      [70,40,'tree_apple_01'],[220,60,'tree_green'],[2500,80,'tree_pine_01'],[2650,180,'tree_apple_02'],
      [30,1200,'tree_green'],[2600,1040,'tree_pine_02'],[1720,230,'tree_green'],[2390,220,'tree_apple_01']
    ];
    trees.forEach(([x,y,n])=>addImage(`trees/${n}.png`,x,y,260,22));
    [[80,650],[300,570],[1760,120],[2550,780],[1680,1420],[620,1500]].forEach(([x,y],i)=>addImage(`vegetation/${i%2?'bush_pink':'bush_white'}.png`,x,y,125,14));

    // Tomato field.
    const lab=el('div','section-label',{text:'CAMPO DE TOMATE • 4 × 4'}); lab.style.left='820px'; lab.style.top='590px'; world.append(lab);
    const field=el('div'); field.id='tomato-field'; world.append(field); renderTomatoField();

    // Chicken visuals.
    addImage('chickens/chicken_white_idle_01.png',1690,1260,92,65);
    addImage('chickens/chicken_brown_idle_01.png',1780,1290,92,66);
    const egg=addImage('props/nest_egg.png',1630,1315,105,67,'world-object interactable'); egg.id='egg-nest'; egg.onclick=(e)=>{e.stopPropagation(); interactCoop();};

    // Expansion area.
    const expansion=el('div', state.wheatUnlocked?'':'locked'); expansion.id='expansion'; expansion.classList.add('interactable'); expansion.onclick=(e)=>{e.stopPropagation(); attemptExpansion();}; world.append(expansion);
    const sign=el('div','section-label',{text:state.wheatUnlocked?'TRIGO LIBERADO':'EXPANSÃO • TRIGO'}); sign.style.left='1940px'; sign.style.top='440px'; world.append(sign);
    if(!state.wheatUnlocked){
      addImage('trees/tree_green.png',1740,515,250,26); addImage('trees/tree_pine_01.png',2290,470,260,26); addImage('trees/tree_apple_01.png',2410,740,250,26);
      addImage('vegetation/grass_tuft_01.png',1990,860,150,15); addImage('vegetation/rock.png',2210,860,150,15);
    }
    const wheat=el('div'); wheat.id='wheat-field'; if(!state.wheatUnlocked) wheat.classList.add('hidden'); world.append(wheat); renderWheatField();

    // Customers buy outside the fence; cash stays on the farm side.
    addImage('fences/fence_corner_large.png',2040,1400,150,84);
    SALE_SPOTS.forEach((spot,i)=>addImage('fences/fence_long.png',2160+i*146,1385-i*63,220,83-i));
    // Money pile at market.
    const cash=el('div','market-cash'); cash.id='market-cash'; world.append(cash); renderCashPile();

    // Interaction prompt.
    const prompt=el('div'); prompt.id='interaction-prompt'; world.append(prompt);

    // Player.
    player=img(`character_frames/${state.selectedCharacter}/01_idle_front.png`); player.id='player'; player.style.left=playerPos.x+'px'; player.style.top=playerPos.y+'px'; world.append(player);

    const help=el('div','',{text:'Clique no chão para caminhar. Clique em uma célula para plantar/colher. Clientes compram na cerca. Clique nos dólares para recolher.'}); help.id='help-strip'; viewport.append(help);

    world.addEventListener('pointerdown', onWorldPointer);
  }

  function path(x,y,w,hOrClass,orient){
    const p=el('div','path '+orient); p.style.left=x+'px'; p.style.top=y+'px';
    if(orient==='v'){p.style.height=hOrClass+'px';} else {p.style.width=w+'px';}
    world.append(p);
  }

  function cropImg(type,stateName){
    if(stateName==='empty') return `crops/${type}_seed.png`;
    if(stateName==='seed') return `crops/${type}_seed.png`;
    if(stateName==='growing') return `crops/${type}_growing.png`;
    return `crops/${type}_mature.png`;
  }

  function renderTomatoField(){
    const field=document.getElementById('tomato-field'); if(!field)return; field.innerHTML='';
    state.tomatoPlots.forEach((p,i)=>{
      const cell=el('div','plot '+p.state); cell.dataset.index=i;
      positionPlot(cell,i,'tomato');
      const im=img(cropImg('tomato',p.state)); cell.append(im);
      if(p.state==='mature') cell.append(el('div','ready',{text:'✓'}));
      if(p.state==='seed'||p.state==='growing') cell.append(el('div','timer',{text:cropRemaining(p,'tomato')+'s'}));
      cell.onclick=(e)=>{e.stopPropagation(); handleTomatoPlot(i);};
      field.append(cell);
    });
  }
  function renderWheatField(){
    const field=document.getElementById('wheat-field'); if(!field)return; field.innerHTML='';
    state.wheatPlots.forEach((p,i)=>{
      const cell=el('div','wheat-plot '+p.state); positionPlot(cell,i,'wheat'); const im=img(cropImg('wheat',p.state)); cell.append(im);
      if(p.state==='seed'||p.state==='growing') cell.append(el('div','timer',{text:cropRemaining(p)+'s'}));
      cell.onclick=(e)=>{e.stopPropagation(); handleWheatPlot(i);}; field.append(cell);
    });
  }
  function cropRemaining(p,type='wheat'){ const age=(Date.now()-p.t)/1000; const phase=type==='tomato'?3:4; return Math.max(0,Math.ceil((p.state==='seed'?phase:phase*2)-age)); }

  function handleTomatoPlot(i){
    const p=state.tomatoPlots[i]; const pos=plotWorldPos(i,'tomato');
    if(p.state==='empty') moveTo(pos.x,pos.y,()=>plantCrop('tomato',i));
    else if(p.state==='mature') moveTo(pos.x,pos.y,()=>harvestCrop('tomato',i));
    else toast('Ainda está crescendo.');
  }
  function handleWheatPlot(i){
    if(!state.wheatUnlocked) return toast('Primeiro libere a nova área.');
    const p=state.wheatPlots[i]; const pos=plotWorldPos(i,'wheat');
    if(p.state==='empty') moveTo(pos.x,pos.y,()=>plantCrop('wheat',i));
    else if(p.state==='mature') moveTo(pos.x,pos.y,()=>harvestCrop('wheat',i));
    else toast('O trigo ainda está crescendo.');
  }
  function plotLocalPos(i,type){
    const col=i%4,row=Math.floor(i/4);
    return {x:(type==='tomato'?310:260)+(col-row)*86,y:100+(col+row)*48};
  }
  function positionPlot(cell,i,type){
    const pos=plotLocalPos(i,type);
    cell.style.left=(pos.x-92)+'px';cell.style.top=(pos.y-184)+'px';
    cell.style.zIndex=10+Math.floor(i/4)+i%4;
  }
  function plotWorldPos(i,type){
    const pos=plotLocalPos(i,type);
    return {x:(type==='tomato'?760:1840)+pos.x,y:(type==='tomato'?650:570)+pos.y+32};
  }
  function useEnergy(n){ if(state.energy<n){toast('Energia insuficiente. Aguarde a recuperação.'); return false;} state.energy-=n; return true; }
  function plantCrop(type,i){
    if(!useEnergy(1))return;
    if(state.coins<2){toast('Você precisa de $2 para a semente.'); return;}
    state.coins-=2;
    const plots=type==='tomato'?state.tomatoPlots:state.wheatPlots; plots[i]={state:'seed',t:Date.now()};
    if(type==='tomato') state.plantedTomatoes++;
    playAction('14_action_harvest.png',650); toast(type==='tomato'?'Tomate plantado!':'Trigo plantado!'); updateAll(); saveState();
  }
  function harvestCrop(type,i){
    if(!useEnergy(1))return;
    const plots=type==='tomato'?state.tomatoPlots:state.wheatPlots; plots[i]=type==='tomato'?{state:'seed',t:Date.now()}:{state:'empty',t:0};
    state.inventory[type==='tomato'?'tomato':'wheat']++;
    if(type==='tomato') state.harvestedTomatoes++;
    playAction('14_action_harvest.png',650); burst(type==='tomato'?'vfx/harvest_tomato.png':'vfx/harvest_wheat.png',playerPos.x,playerPos.y-90,140); toast(type==='tomato'?'+1 tomate':'+1 trigo'); updateAll(); tryServeCustomers(); saveState();
  }

  function interactCoop(){
    moveTo(1580,1290,()=>{
      if(state.eggsReady<=0) return toast('As galinhas ainda estão produzindo ovos.');
      const n=state.eggsReady; state.inventory.egg+=n; state.eggsReady=0; playAction('15_action_carry.png',700); toast(`+${n} ovos coletados`); updateAll(); tryServeCustomers(); saveState();
    });
  }
  function goToMarket(){ moveTo(2110,1265,()=>toast('Banca pronta. Os clientes compram o que você tiver em estoque.')); }

  function attemptExpansion(){
    if(state.wheatUnlocked) return toast('Área de trigo já liberada.');
    moveTo(1660,690,()=>{
      if(state.coins<500) return toast(`Faltam $${500-state.coins} para liberar a área.`);
      state.coins-=500; state.wheatUnlocked=true; burst('vfx/star.png',1960,550,170); toast('Nova área liberada! Trigo disponível.'); buildWorld(); updateAll(); saveState();
    });
  }

  function onWorldPointer(e){
    if(!gameStarted) return;
    if(e.target.closest('.interactable,.plot,.wheat-plot')) return;
    const r=viewport.getBoundingClientRect(); const x=e.clientX-r.left+camera.x, y=e.clientY-r.top+camera.y;
    // Keep away from non-walkable crop/building centers via simple safe clamping.
    moveTo(clamp(x,120,WORLD_W-120),clamp(y,220,WORLD_H-120));
  }

  function moveTo(x,y,cb=null){ moveTarget={x,y}; moveCallback=cb; }
  function playAction(frame,duration){
    clearTimeout(currentActionTimer); if(!player)return; player.src=A+`character_frames/${state.selectedCharacter}/${frame}`;
    currentActionTimer=setTimeout(()=>{ if(player&&!moveTarget) player.src=A+`character_frames/${state.selectedCharacter}/01_idle_front.png`; },duration);
  }

  function sideWalkFrame(dx,phase){
    const index=(dx<0?0:2)+(phase%2);
    return `${String(9+index).padStart(2,'0')}_walk_side_0${index+1}.png`;
  }

  function updateMovement(dt){
    if(!player||!moveTarget)return;
    const dx=moveTarget.x-playerPos.x, dy=moveTarget.y-playerPos.y; const dist=Math.hypot(dx,dy);
    const speed=250;
    if(dist<8){
      playerPos={...moveTarget}; moveTarget=null; player.style.transform='translate(-50%,-88%) scaleX(1)'; player.style.left=playerPos.x+'px'; player.style.top=playerPos.y+'px'; player.src=A+`character_frames/${state.selectedCharacter}/01_idle_front.png`;
      const cb=moveCallback; moveCallback=null; if(cb) setTimeout(cb,120); return;
    }
    const step=Math.min(dist,speed*dt); playerPos.x+=dx/dist*step; playerPos.y+=dy/dist*step;
    walkClock+=dt; if(walkClock>.13){walkClock=0;walkFrame=(walkFrame+1)%4;}
    const side=Math.abs(dx)>Math.abs(dy)*.65;
    let frame;
    if(side){ frame=sideWalkFrame(dx,walkFrame); player.style.transform='translate(-50%,-88%) scaleX(1)'; }
    else if(dy<0){ frame=`${String(7+(walkFrame%2)).padStart(2,'0')}_walk_back_0${(walkFrame%2)+1}.png`; player.style.transform='translate(-50%,-88%) scaleX(1)'; }
    else { frame=`${String(5+(walkFrame%2)).padStart(2,'0')}_walk_front_0${(walkFrame%2)+1}.png`; player.style.transform='translate(-50%,-88%) scaleX(1)'; }
    player.src=A+`character_frames/${state.selectedCharacter}/${frame}`;
    player.style.left=playerPos.x+'px'; player.style.top=playerPos.y+'px';
  }

  function updateCamera(){
    const vw=viewport.clientWidth,vh=viewport.clientHeight;
    const tx=clamp(playerPos.x-vw*.54,0,WORLD_W-vw); const ty=clamp(playerPos.y-vh*.55,0,WORLD_H-vh);
    camera.x += (tx-camera.x)*.075; camera.y += (ty-camera.y)*.075;
    world.style.transform=`translate(${-camera.x}px,${-camera.y}px)`;
  }

  function spawnCustomer(now){
    if(customers.length>=3) return;
    const pool=CHARACTERS.map(x=>x[0]).filter(id=>id!==state.selectedCharacter);
    const id=pool[(customerSeq-1)%pool.length];
    const wantsEgg = customerSeq%4===0;
    const item=wantsEgg?'egg':'tomato'; const qty=wantsEgg?1:1+(customerSeq%3);
    let spotIndex=-1;
    for(let offset=0;offset<SALE_SPOTS.length;offset++){
      const candidate=(nextSaleSpot+offset)%SALE_SPOTS.length;
      if(!customers.some(c=>c.spotIndex===candidate && c.status!=='leaving')){spotIndex=candidate;break;}
    }
    if(spotIndex<0)return;
    nextSaleSpot=(spotIndex+1)%SALE_SPOTS.length;
    const spot=SALE_SPOTS[spotIndex];
    const c={id:customerSeq++, charId:id, item, qty, spotIndex, x:2740,y:1430,targetX:spot.x,targetY:spot.y,status:'walking',frame:0,clock:0,serveAt:0};
    c.el=img(`character_frames/${id}/09_walk_side_01.png`,'customer'); c.el.style.left=c.x+'px';c.el.style.top=c.y+'px'; world.append(c.el);
    c.bubble=el('div','customer-bubble',{text:`${item==='tomato'?'🍅':'🥚'} × ${qty}`}); world.append(c.bubble); customers.push(c); lastCustomerAt=now;
  }
  function updateCustomers(dt,now){
    customers.forEach((c,idx)=>{
      if(c.status==='walking'){
        const dx=c.targetX-c.x,dy=c.targetY-c.y,dist=Math.hypot(dx,dy); const speed=120;
        if(dist<5){c.x=c.targetX;c.y=c.targetY;c.status='waiting';c.serveAt=now+800;c.el.src=A+`character_frames/${c.charId}/03_idle_side_a.png`;}
        else {const s=Math.min(dist,speed*dt);c.x+=dx/dist*s;c.y+=dy/dist*s;c.clock+=dt;if(c.clock>.16){c.clock=0;c.frame=(c.frame+1)%4;} c.el.src=A+`character_frames/${c.charId}/${sideWalkFrame(dx,c.frame)}`;c.el.style.transform='translate(-50%,-85%) scaleX(1)';}
      } else if(c.status==='waiting' && now>=c.serveAt){
        const have=state.inventory[c.item];
        if(have>=c.qty){ serveCustomer(c); }
        else { c.bubble.classList.add('waiting'); c.bubble.textContent=`${c.item==='tomato'?'🍅':'🥚'} × ${c.qty} • aguardando`; c.serveAt=now+1400; }
      } else if(c.status==='leaving'){
        const dx=2740-c.x,dy=1510-c.y,dist=Math.hypot(dx,dy); if(dist<8){c.remove=true;} else {const s=Math.min(dist,145*dt);c.x+=dx/dist*s;c.y+=dy/dist*s;c.clock+=dt;if(c.clock>.16){c.clock=0;c.frame=(c.frame+1)%4;} c.el.src=A+`character_frames/${c.charId}/${sideWalkFrame(dx,c.frame)}`;c.el.style.transform='translate(-50%,-85%) scaleX(1)';}
      }
      c.el.style.left=c.x+'px';c.el.style.top=c.y+'px'; c.bubble.style.left=c.x+'px';c.bubble.style.top=(c.y-95)+'px';
    });
    customers.filter(c=>c.remove).forEach(c=>{c.el.remove();c.bubble.remove();}); customers=customers.filter(c=>!c.remove);
  }
  function serveCustomer(c){
    state.inventory[c.item]-=c.qty; const unit=c.item==='tomato'?24:18; const total=unit*c.qty; state.pendingCash[c.spotIndex]+=total;state.revenue+=total;if(c.item==='tomato')state.totalSold+=c.qty;
    c.status='leaving';c.bubble.classList.remove('waiting');c.bubble.textContent=`$${total} deixados ✓`;c.serveAt=Infinity; burst('vfx/coin.png',SALE_SPOTS[c.spotIndex].x,SALE_SPOTS[c.spotIndex].cashY,105); renderCashPile(); advanceTasks(); updateAll(); saveState();
  }
  function tryServeCustomers(){customers.forEach(c=>{if(c.status==='waiting')c.serveAt=0;});}

  function renderCashPile(){
    const cash=document.getElementById('market-cash'); if(!cash)return; cash.innerHTML='';
    state.pendingCash.forEach((amount,index)=>{
      if(amount<=0)return;
      const spot=SALE_SPOTS[index];
      const pile=el('button','cash-pile interactable',{'aria-label':`Recolher $${amount}`,type:'button'});
      pile.style.left=(spot.cashX-55)+'px';pile.style.top=(spot.cashY-70)+'px';
      pile.append(el('span','cash-bundle',{text:'💵'}),el('strong','',{text:`$${amount}`}));
      pile.onclick=e=>{e.stopPropagation();collectCash(index);};cash.append(pile);
    });
  }
  function collectCash(index){
    const spot=SALE_SPOTS[index];
    moveTo(spot.cashX,spot.cashY,()=>{
      const amount=state.pendingCash[index]; if(amount<=0)return;
      state.pendingCash[index]=0;state.coins+=amount;
      playAction('15_action_carry.png',700);toast(`+$${amount} recolhidos!`);
      burst('vfx/coin.png',spot.cashX,spot.cashY-65,100);updateAll();saveState();
    });
  }

  function burst(asset,x,y,w){ const n=addImage(asset,x-w/2,y-w/2,w,3000); n.style.transition='transform .7s ease,opacity .7s ease'; setTimeout(()=>{n.style.transform='translateY(-60px) scale(1.15)';n.style.opacity='0';},20);setTimeout(()=>n.remove(),780); }

  function updateCropStates(){
    let changed=false;
    const now=Date.now();
    const check=(plots,phase)=>plots.forEach(p=>{
      if(p.state!=='seed'&&p.state!=='growing')return;
      const age=now-p.t;
      const next=age>=phase*2?'mature':age>=phase?'growing':'seed';
      if(p.state!==next){p.state=next;changed=true;}
    });
    check(state.tomatoPlots,3000);check(state.wheatPlots,4000);
    if(changed){renderTomatoField();renderWheatField();saveState();}

  }
  function updateEggs(now){ if(now-lastEggAt>12000 && state.eggsReady<6){state.eggsReady++;lastEggAt=now;updateAll();} }
  function regenEnergy(now){ if(!regenEnergy.last)regenEnergy.last=now; if(now-regenEnergy.last>8000){regenEnergy.last=now;if(state.energy<state.maxEnergy){state.energy++;updateHUD();}} }

  function advanceTasks(){
    while(state.taskIndex<taskDefs.length-1 && taskDefs[state.taskIndex].current()>=taskDefs[state.taskIndex].goal){state.taskIndex++;toast('Tarefa concluída! Nova tarefa liberada.');}
  }
  function updateTasks(){ advanceTasks(); taskPanel.innerHTML=''; const d=taskDefs[state.taskIndex]; const cur=d.current();const pct=Math.min(100,cur/d.goal*100); const t=el('div','task');t.innerHTML=`<strong>${d.title}</strong><span>${cur}/${d.goal}</span><div class="progress"><i style="width:${pct}%"></i></div>`;taskPanel.append(t); }

  function updateHUD(){
    hudTop.innerHTML='';
    hudTop.append(resource('ui/coin_bar.png',`$ ${state.coins}`),resource('ui/gem_bar.png',`${state.gems}`),resource('ui/energy_bar.png',`${state.energy}/${state.maxEnergy}`));
    const gear=el('button','hud-btn');gear.style.width='58px';gear.style.height='58px';gear.append(img('ui/settings.png'));gear.onclick=()=>openSettings();gear.style.pointerEvents='auto';hudTop.append(gear);
  }
  function resource(icon,text){const r=el('div','resource');r.append(img(icon));r.append(el('span','',{text}));return r;}
  function updateBottom(){
    hudBottom.innerHTML='';
    const buttons=[['ui/button_shop.png','Loja',openShop],['ui/button_inventory.png','Inventário',openInventory],['ui/button_tasks.png','Tarefas',openTasks],['ui/button_map.png','Mapa',openMap],['ui/button_build.png','Expandir',()=>attemptExpansion()]];
    buttons.forEach(([icon,label,fn])=>{const b=el('button','hud-btn');b.append(img(icon),el('span','',{text:label}));b.onclick=fn;hudBottom.append(b);});
  }
  function updateAll(){updateHUD();updateTasks();renderTomatoField();renderWheatField();renderCashPile();}

  function openPanel(title,html,extraClass=''){
    modalRoot.innerHTML='';const m=el('div','modal');const p=el('div','panel '+extraClass);p.innerHTML=`<h2>${title}</h2>${html}`;const c=el('button','close-btn',{text:'Fechar'});c.onclick=()=>modalRoot.innerHTML='';p.append(c);m.append(p);modalRoot.append(m);m.onclick=(e)=>{if(e.target===m)modalRoot.innerHTML='';};
  }
  function openInventory(){openPanel('Mochila',`<div class="panel-grid"><div class="item-row">🍅 Tomates <b>${state.inventory.tomato}</b></div><div class="item-row">🥚 Ovos <b>${state.inventory.egg}</b></div><div class="item-row">🌾 Trigo <b>${state.inventory.wheat}</b></div><div class="item-row">💵 Receita <b>$${state.revenue}</b></div></div>`);}
  function openShop(){openPanel('Loja da fazenda',`<p>Para esta demo, cada semente custa <b>$2</b> e é comprada automaticamente ao plantar.</p><div class="panel-grid"><div class="item-row">🍅 Semente de tomate <b>$2</b></div><div class="item-row">🌾 Semente de trigo <b>$2</b></div></div>`);}
  function openTasks(){const list=taskDefs.map((d,i)=>`<div class="item-row">${i<state.taskIndex?'✓':i===state.taskIndex?'▶':'🔒'} ${d.title}<b>${d.current()}/${d.goal}</b></div>`).join('');openPanel('Progressão',`<div>${list}</div>`);}
  function openMap(){openPanel('Mapa da propriedade',`<p><b>Área inicial:</b> casa, campo 4×4 de tomate, galinheiro e banca.</p><p><b>Nova área:</b> campo de trigo ${state.wheatUnlocked?'liberado ✓':'bloqueado por $500'}.</p><p>Use o mapa grande caminhando pela fazenda; a câmera acompanha o personagem suavemente.</p>`);}
  function openSettings(){openPanel('Configurações',`<p>Estado salvo automaticamente no navegador.</p><button id="change-char" class="close-btn">Trocar personagem</button> <button id="reset-game" class="close-btn reset-btn">Reiniciar demo</button>`);setTimeout(()=>{document.getElementById('change-char').onclick=()=>{modalRoot.innerHTML='';charSelect.style.display='grid';showCharacterSelect();};document.getElementById('reset-game').onclick=()=>{localStorage.removeItem(SAVE_KEY);location.reload();};},0);}

  function startGame(){ if(gameStarted)return; gameStarted=true; buildWorld(); updateHUD();updateBottom();updateTasks(); lastCustomerAt=performance.now()-6500; requestAnimationFrame(loop); }
  function loop(ts){
    const dt=Math.min(.033,(ts-lastTs)/1000);lastTs=ts;
    updateMovement(dt);updateCamera();updateCustomers(dt,ts); if(ts-lastCustomerAt>8000)spawnCustomer(ts); updateCropStates();updateEggs(Date.now());regenEnergy(Date.now());
    if(gameStarted)requestAnimationFrame(loop);
  }

  // periodic save and first screen
  setInterval(()=>{if(gameStarted)saveState();},3000);
  showCharacterSelect();
})();

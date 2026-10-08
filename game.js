(() => {
  'use strict';

  const A = 'assets/';
  const spriteCache = new Map();
  const world = document.getElementById('world');
  const viewport = document.getElementById('viewport');
  const uiRoot=document.getElementById('ui-root');
  function fitInterface(){
    const view=window.visualViewport;
    uiRoot.style.left=(view?view.offsetLeft:0)+'px';uiRoot.style.top=(view?view.offsetTop:0)+'px';
    uiRoot.style.width=(view?view.width:window.innerWidth)+'px';uiRoot.style.height=(view?view.height:window.innerHeight)+'px';
  }
  window.addEventListener('resize',fitInterface);
  if(window.visualViewport){window.visualViewport.addEventListener('resize',fitInterface);window.visualViewport.addEventListener('scroll',fitInterface);}
  fitInterface();
  const hudTop = document.getElementById('hud-top');
  const taskPanel = document.getElementById('task-panel');
  const hudBottom = document.getElementById('hud-bottom');
  const modalRoot = document.getElementById('modal-root');
  const charSelect = document.getElementById('character-select');
  const toastEl = document.getElementById('toast');

  const WORLD_W = 2800, WORLD_H = 2100;
  const FENCE = {x:2120,y:1760,stepX:148,stepY:-52};
  const fenceY=x=>FENCE.y+(x-FENCE.x)*FENCE.stepY/FENCE.stepX;
  const SALE_SPOTS = [2300,2480,2660].map(x=>({x,y:fenceY(x)+65}));
  const CASH_AREA = {x:2190,y:1445,bundleValue:24};
  const MARKET_DROP = {x:2390,y:1430,radius:50};
  const joystick = {pointer:null,x:0,y:0,originX:0,originY:0,el:null,knob:null};
  const PRODUCTS = {tomato:{icon:'🍅',price:24},egg:{icon:'🥚',price:7},wheat:{icon:'🌾',price:32},milk:{icon:'🥛',price:30}};
  const EGG_VARIANTS = ['white','cream','beige','tan','brown','speckled'];
  let eggVisualSignature = null;
  const MAX_EGGS = 7;
  const EGG_PRODUCTION_MS = 30000;
  const EGG_SPOTS = Array.from({length:MAX_EGGS},(_,i)=>({x:1565+((i*97)%310),y:1410+((i*53)%125),angle:65+((i*37)%55)}));
  function randomEggVariant(){return EGG_VARIANTS[Math.floor(Math.random()*EGG_VARIANTS.length)];}
  const CHICKEN_PRICE = 750, MAX_CHICKENS = 7;
  const COW_PRICE=2500, MAX_COWS=7;
  const MILK_PRODUCTION_MS=120000, MILK_LIFETIME_MS=180000;
  const MILK_AREA={x:680,y:1505};
  const milkSpot=slot=>({x:MILK_AREA.x+200+(Math.floor(slot/7)-(slot%7))*35,y:MILK_AREA.y+80+((slot%7)+Math.floor(slot/7))*18});
  let milkVisualSignature=null;
  const COW_BREEDS=['black_white','dark_brown_white','light_brown_white'];
  function randomCowBreed(existing){
    const counts=COW_BREEDS.map(b=>existing.filter(color=>color===b).length);
    const minimum=Math.min(...counts),options=COW_BREEDS.filter((_,i)=>counts[i]===minimum);
    return options[Math.floor(Math.random()*options.length)];
  }
  const COW_FRAMES=['01_idle_01','02_blink','03_walk_01','04_walk_02','05_walk_03','06_walk_04','07_graze','08_happy'];
  function cowSprite(breed,frame){return `animals/cows/cow_${breed}/frames/cow_${breed}_${COW_FRAMES[frame]}.png`;}
  let nextSaleSpot = 0;
  let nearbyPlots = new Set();
  const CROP_TIMING = {seedMs:10000,matureMs:25000};
  let lastCropTimerSecond=-1;
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
    inventory: { tomato: 0, egg: 0, wheat: 0, milk: 0 },
    totalSold: 0,
    wheatSold: 0,
    revenue: 0,
    pendingCash: [0,0,0],
    marketStock: {tomato:0,egg:0,wheat:0,milk:0},
    plantedTomatoes: 0,
    harvestedTomatoes: 0,
    wheatUnlocked: false,
    selectedCharacter: 'farmer_male_blue_overalls',
    tomatoPlots: Array.from({length:16}, (_,i) => i < 4 ? {state:'mature', t:0} : i < 8 ? {state:'growing', t:Date.now()-12000} : {state:'empty', t:0}),
    wheatPlots: Array.from({length:12}, () => ({state:'empty',t:0})),
    eggsReady: 2,
    eggVariants: [randomEggVariant(),randomEggVariant()],
    eggSlots: [0,1],
    chickenCount: 2,
    cowBreeds: [],
    cowColorVersion: 1,
    milkCycleStart: 0, milkGenerated: false, milkBottles: [],
    taskIndex: 0
  });

  let state = loadState();
  let gameStarted = false;
  let player = null;
  let playerPos = {x:1380,y:1340};
  // Randomize within reserved clearings; keep the layout stable in this save.
  if(!Number.isInteger(state.buildingSeed))state.buildingSeed=Math.floor(Math.random()*2147483646)+1;
  const EXTRA_BUILDINGS = createExtraBuildings(state.buildingSeed);
  function createExtraBuildings(seed){
    const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
    const assets=[
      {asset:'granary.png',ratio:1251/1252},
      {asset:'veterinary_clinic.png',ratio:1214/1274},
      {asset:'industry/workshop.png',ratio:1249/1258}
    ];
    for(let i=assets.length-1;i>0;i--){const j=Math.floor(random()*(i+1));[assets[i],assets[j]]=[assets[j],assets[i]];}
    const buildings=[[1040,1500],[1370,1500],[1940,60]].map(([x,y],i)=>{
      const width=250+Math.floor(random()*20);
      return {...assets[i],x:x+Math.floor(random()*20)-10,y:y+Math.floor(random()*16)-8,width,height:width*assets[i].ratio};
    });
    // The milking enclosure needs a full building scale and its own clearing.
    buildings.push({asset:'dairy/milking_barn_empty.png',ratio:1195/1273,x:180,y:900,width:760,height:760*1195/1273});
    return buildings;
  }
  const BUILDING_COLLIDERS = [];
  const SOLID_IMAGE_RATIOS = {
    'buildings/house.png':471/512,'buildings/barn.png':448/536,
    'buildings/chicken_coop.png':445/614,'buildings/market.png':450/593,
    'trees/tree_green.png':325/248,'trees/tree_apple_01.png':327/254,
    'trees/tree_apple_02.png':325/238,'trees/tree_pine_01.png':333/218,
    'trees/tree_pine_02.png':334/219
  };
  const PLAYER_RADIUS = 16;
  let moveWaypoints = [];
  let moveTarget = null;
  let moveCallback = null;
  let walkFrame = 0, walkClock = 0;
  let lastTs = performance.now();
  let camera = {x:0,y:0,scale:1};
  let customers = [];
  let chickens = [];
  let cows = [];
  const CHICKEN_FRAME_COUNTS = {white:{idle:4,walk:4,peck:4},brown:{idle:2,walk:4,peck:4}};
  const CHICKEN_PHASES = [{mode:'idle',duration:2},{mode:'walk',duration:2.4},{mode:'peck',duration:2.8},{mode:'walk',duration:2.4}];
  let customerSeq = 1;
  let lastCustomerAt = 0;
  let lastEggAt = Date.now();
  let selectedCharacter = state.selectedCharacter;
  let currentActionTimer = null;
  let uiDirty = false;
  let harvestAction = null;
  const TOMATO_HARVEST_SCALE = .235;
  const TOMATO_HARVEST_LAYOUT = [
    {width:365,footY:546},{width:378,footY:573},{width:378,footY:514},
    {width:378,footY:570},{width:378,footY:550},{width:362,footY:552}
  ];
  const TOMATO_HARVEST_FRAMES = Array.from({length:6},(_,i)=>`characters/actions/tomato_harvest_vacuum/frames/tomato_harvest_vacuum_${String(i+1).padStart(2,'0')}.png`);
  TOMATO_HARVEST_FRAMES.forEach(preloadSprite);

  const WHEAT_HARVEST_NAMES = ['01_approach','02_prepare','03_raise_sickle','04_swing','05_cutting','06_more_cut','07_gather','08_pick_up','09_hold_bundle','10_carry','11_walk_away','12_exit'];
  const WHEAT_HARVEST_FRAMES = WHEAT_HARVEST_NAMES.map(name=>`characters/actions/wheat_harvest_sickle/frames/wheat_harvest_sickle_${name}.png`);
  const WHEAT_HARVEST_LAYOUT = [
    {width:230,footY:284},{width:191,footY:280},{width:213,footY:303},
    {width:217,footY:256},{width:221,footY:237},{width:227,footY:249},
    {width:217,footY:242},{width:209,footY:255},{width:199,footY:236},
    {width:237,footY:265},{width:151,footY:211},{width:245,footY:245}
  ];
  WHEAT_HARVEST_FRAMES.forEach(preloadSprite);
  const HARVEST_ANIMATIONS = {
    tomato:{frames:TOMATO_HARVEST_FRAMES,layout:TOMATO_HARVEST_LAYOUT,scale:TOMATO_HARVEST_SCALE,frameMs:1000/12},
    wheat:{frames:WHEAT_HARVEST_FRAMES,layout:WHEAT_HARVEST_LAYOUT,scale:.5,frameMs:1000/12},
    plant_wheat:{frames:['characters/actions/farmer_plant_wheat.png'],layout:[{width:1254,footY:1160}],scale:.095,frameMs:650},
    collect_eggs:{frames:['characters/actions/farmer_collect_eggs.png'],layout:[{width:1254,footY:1170}],scale:.105,frameMs:650},
    plant_corn:{frames:['characters/actions/farmer_plant_corn.png'],layout:[{width:1254,footY:1140}],scale:.095,frameMs:650}
  };

  preloadSprite('characters/actions/farmer_carry_eggs.png');
  ['plant_wheat','plant_corn','collect_eggs'].forEach(type=>HARVEST_ANIMATIONS[type].frames.forEach(preloadSprite));

  for(const color of ['white','brown'])for(const mode of ['idle','walk','peck'])for(let frame=1;frame<=CHICKEN_FRAME_COUNTS[color][mode];frame++)preloadSprite(`chickens/chicken_${color}_${mode}_${String(frame).padStart(2,'0')}.png`);

  preloadSprite('resources/milk-bottom.png');
  COW_BREEDS.forEach(breed=>COW_FRAMES.forEach((_,frame)=>preloadSprite(cowSprite(breed,frame))));
  EGG_VARIANTS.forEach(color=>preloadSprite(`resources/eggs/egg_${color}_01.png`));

  const taskDefs = [
    { title:'Plante 6 tomates', current:()=>Math.min(state.plantedTomatoes,6), goal:6 },
    { title:'Colha 6 tomates', current:()=>Math.min(state.harvestedTomatoes,6), goal:6 },
    { title:'Venda 8 tomates aos clientes', current:()=>Math.min(state.totalSold,8), goal:8 },
    { title:'Libere a área de trigo', current:()=>state.wheatUnlocked?1:0, goal:1 },
    { title:'Plante 4 trigos', current:()=>Math.min(state.wheatPlots.filter(p=>p.state!=='empty').length,4), goal:4 },
    { title:'Adicione uma fila por $2.500', current:()=>Math.min(extraFieldRows(),1), goal:1 },
    { title:'Amplie também o outro campo • $2.500', current:()=>Math.min(extraFieldRows(),2), goal:2 }
  ];

  function loadState(){
    try {
      const saved=JSON.parse(localStorage.getItem(SAVE_KEY)),initial=defaultState();
      const result=saved?{...initial,...saved,inventory:{...initial.inventory,...saved.inventory},marketStock:{...initial.marketStock,...saved.marketStock}}:initial;
      result.cowBreeds=(Array.isArray(result.cowBreeds)?result.cowBreeds:[]).filter(b=>COW_BREEDS.includes(b)).slice(0,MAX_COWS);
      if(saved&&saved.cowColorVersion!==1){
        const count=result.cowBreeds.length;result.cowBreeds=[];
        for(let i=0;i<count;i++)result.cowBreeds.push(randomCowBreed(result.cowBreeds));
      }
      result.cowColorVersion=1;
      result.milkCycleStart=Number.isFinite(result.milkCycleStart)&&result.milkCycleStart>0?result.milkCycleStart:0;
      result.milkGenerated=result.milkGenerated===true;
      result.milkBottles=[...new Set(Array.isArray(result.milkBottles)?result.milkBottles:[])].filter(slot=>Number.isInteger(slot)&&slot>=0&&slot<MAX_COWS*3);
      result.chickenCount=clamp(Math.floor(Number(result.chickenCount)||2),2,MAX_CHICKENS);
      result.eggsReady=clamp(Math.floor(Number(result.eggsReady)||0),0,MAX_EGGS);
      const colors=Array.isArray(result.eggVariants)?result.eggVariants:[];
      result.eggVariants=Array.from({length:result.eggsReady},(_,i)=>EGG_VARIANTS.includes(colors[i])?colors[i]:randomEggVariant());
      const slots=Array.isArray(result.eggSlots)?result.eggSlots:[];
      result.eggSlots=[];
      for(let i=0;i<result.eggsReady;i++){
        const slot=slots[i];
        result.eggSlots.push(Number.isInteger(slot)&&slot>=0&&slot<MAX_EGGS&&!result.eggSlots.includes(slot)?slot:EGG_SPOTS.findIndex((_,j)=>!result.eggSlots.includes(j)));
      }
      return result;
    }catch{return defaultState();}
  }
  function saveState(){ localStorage.setItem(SAVE_KEY, JSON.stringify(state)); }

  function el(tag, cls='', attrs={}){
    const n = document.createElement(tag); if(cls) n.className=cls;
    for(const [k,v] of Object.entries(attrs)) k==='text' ? n.textContent=v : n.setAttribute(k,v);
    return n;
  }
  function img(src, cls=''){ const n=el('img',cls); n.src=A+src; n.draggable=false; return n; }
  function preloadSprite(src){
    // Retain decoded images so the first animation does not wait for disk or decoding.
    const n=img(src);spriteCache.set(src,n);
    if(n.decode)n.decode().catch(()=>{});
  }
  function setSprite(node,src){
    if(node.dataset.sprite===src)return;
    node.dataset.sprite=src;node.src=A+src;
  }
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
    const n=img(src,cls); n.style.left=x+'px'; n.style.top=y+'px'; n.style.width=w+'px'; n.style.zIndex=z; world.append(n);
    if(src.startsWith('buildings/')||src.startsWith('trees/')){
      const extra=EXTRA_BUILDINGS.find(b=>'buildings/'+b.asset===src);
      const h=w*(SOLID_IMAGE_RATIOS[src]??extra?.ratio??1);
      const tree=src.startsWith('trees/');
      // Collide with the base on the ground, rather than the roof or canopy.
      BUILDING_COLLIDERS.push(src==='buildings/market.png'?{left:2200,right:2650,top:1180,bottom:1395}:{left:x+w*(tree?.27:.06),right:x+w*(tree?.73:.94),top:y+h*(tree?.7:.52),bottom:y+h*.97});
    }
    return n;
  }

  function buildWorld(){
    harvestAction=null;
    BUILDING_COLLIDERS.length=0;
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

    const drop=el('button','market-drop interactable',{type:'button','aria-label':'Descarregar produtos na banca'});
    drop.style.left=(MARKET_DROP.x-90)+'px';drop.style.top=(MARKET_DROP.y-50)+'px';
    drop.append(img('ui/controls/interaction_ring.png'),el('span','',{text:'DESCARREGAR'}));
    drop.onclick=e=>{e.stopPropagation();goToMarket();};world.append(drop);

    EXTRA_BUILDINGS.forEach(b=>{
      const building=addImage(`buildings/${b.asset}`,b.x,b.y,b.width,46);
      if(b.asset.includes('milking')){building.classList.add('interactable');building.onclick=e=>{e.stopPropagation();openShop();};}
    });
    buildCows();
    const milkArea=el('div','milk-area');milkArea.id='milk-area';
    milkArea.style.left=MILK_AREA.x+'px';milkArea.style.top=MILK_AREA.y+'px';world.append(milkArea);
    milkVisualSignature=null;updateMilk(Date.now());renderMilk();
    saveState();

    // Props around buildings only; leave gameplay routes open.
    addImage('props/well.png',250,790,230,25); addImage('props/mailbox.png',720,450,120,30);
    addImage('props/hay_bale.png',1320,410,120,25); addImage('props/barrel.png',1450,430,90,25);
    addImage('props/lantern_post.png',1130,510,105,42); addImage('props/lantern_post.png',2020,1080,105,42);
    addImage('vegetation/sunflower.png',230,510,120,40); addImage('vegetation/rock.png',1960,1500,150,15);

    // Small accents around the market; keep delivery and collection lanes clear.
    addImage('props/tomato_barrel.png',2180,1115,95,57);
    addImage('props/crate_02.png',2610,1210,95,58);
    addImage('props/flower_pot.png',2650,1070,75,56);
    addImage('vegetation/flower_white_small.png',2050,1570,75,14);
    addImage('vegetation/grass_tuft_02.png',2680,1670,85,14);

    // Edge vegetation framing.
    const trees=[
      [70,40,'tree_apple_01'],[220,60,'tree_green'],[2500,80,'tree_pine_01'],[2650,180,'tree_apple_02'],
      [20,620,'tree_green'],[2600,1040,'tree_pine_02'],[1720,230,'tree_green'],[2390,220,'tree_apple_01']
    ];
    trees.forEach(([x,y,n])=>addImage(`trees/${n}.png`,x,y,260,22));
    [[80,650],[300,570],[1760,120],[2550,780],[1680,1420],[1980,920]].forEach(([x,y],i)=>addImage(`vegetation/${i%2?'bush_pink':'bush_white'}.png`,x,y,125,14));

    // Tomato field.
    const lab=el('div','section-label',{text:`CAMPO DE TOMATE • 4 × ${state.tomatoPlots.length/4}`}); lab.id='tomato-field-label'; lab.style.left='820px'; lab.style.top='590px'; world.append(lab);
    const field=el('div'); field.id='tomato-field'; world.append(field); renderTomatoField();

    // Chicken visuals.
    buildChickens();
    const nest=el('button','egg-nest interactable',{type:'button','aria-label':'Recolher ovos do galinheiro'});
    nest.id='egg-nest';nest.onclick=e=>{e.stopPropagation();interactCoop();};world.append(nest);
    eggVisualSignature=null;renderEggs();

    // Expansion area.
    const expansion=el('div', state.wheatUnlocked?'':'locked'); expansion.id='expansion'; expansion.classList.add('interactable'); expansion.onclick=(e)=>{e.stopPropagation(); attemptExpansion();}; world.append(expansion);
    const sign=el('div','section-label',{text:state.wheatUnlocked?'TRIGO LIBERADO':'EXPANSÃO • TRIGO'}); sign.style.left='1940px'; sign.style.top='440px'; world.append(sign);
    if(!state.wheatUnlocked){
      addImage('trees/tree_green.png',1740,515,250,26); addImage('trees/tree_pine_01.png',2290,470,260,26); addImage('trees/tree_apple_01.png',2410,740,250,26);
      addImage('vegetation/grass_tuft_01.png',1990,860,150,15); addImage('vegetation/rock.png',2210,860,150,15);
    }
    const wheat=el('div'); wheat.id='wheat-field'; if(!state.wheatUnlocked) wheat.classList.add('hidden'); world.append(wheat); renderWheatField();

    // Customers buy outside the fence; cash stays on the farm side.
    for(let i=4;i>=0;i--)addImage('fences/fence_long.png',FENCE.x-39+i*FENCE.stepX,FENCE.y-192+i*FENCE.stepY,220,80+(4-i),'world-object buyer-fence');
    // Money pile at market.
    const cash=el('div','market-cash'); cash.id='market-cash'; world.append(cash); renderCashPile();

    // Interaction prompt.
    const prompt=el('div'); prompt.id='interaction-prompt'; world.append(prompt);

    // Player.
    player=img(`character_frames/${state.selectedCharacter}/01_idle_front.png`); player.id='player'; player.style.left=playerPos.x+'px'; player.style.top=playerPos.y+'px'; world.append(player);

    const help=el('div','',{text:'Clique no chão para caminhar. Passe sobre os canteiros para colher ou plantar. Arraste o círculo para caminhar. Descarregue na banca e recolha os dólares na cerca.'}); help.id='help-strip';document.getElementById('help-strip')?.remove();uiRoot.append(help);

    world.addEventListener('pointerdown', onWorldPointer);
    setupJoystick();
  }

  function buildChickens(){
    chickens.forEach(bird=>bird.el.remove());chickens=[];
    const homes=[[1735,1360],[1825,1390],[1640,1380],[1710,1440],[1840,1460],[1580,1440],[1770,1500]];
    homes.slice(0,state.chickenCount).map(([x,y],index)=>({color:index%2?'brown':'white',x,y,phase:index%2?2:0})).forEach(config=>{
      const bird={...config,homeX:config.x,homeY:config.y,elapsed:0,waypoint:0,fromX:config.x,fromY:config.y,targetX:config.x,targetY:config.y,facing:1};
      bird.el=img(`chickens/chicken_${bird.color}_idle_01.png`,'world-object animated-chicken');
      world.append(bird.el);chickens.push(bird);
    });
    updateChickens(0);
  }
  function updateChickens(dt){
    const offsets=[[45,12],[-25,30],[15,-10],[0,0]];
    for(const bird of chickens){
      bird.elapsed+=dt;
      while(bird.elapsed>=CHICKEN_PHASES[bird.phase].duration){
        bird.elapsed-=CHICKEN_PHASES[bird.phase].duration;bird.phase=(bird.phase+1)%CHICKEN_PHASES.length;
        if(CHICKEN_PHASES[bird.phase].mode==='walk'){
          const offset=offsets[bird.waypoint++%offsets.length];bird.fromX=bird.x;bird.fromY=bird.y;
          bird.targetX=bird.homeX+offset[0];bird.targetY=bird.homeY+offset[1];
          bird.facing=bird.targetX<bird.x?-1:1;
        }
      }
      const phase=CHICKEN_PHASES[bird.phase];
      if(phase.mode==='walk'){
        const progress=Math.min(1,bird.elapsed/phase.duration);
        bird.x=bird.fromX+(bird.targetX-bird.fromX)*progress;bird.y=bird.fromY+(bird.targetY-bird.fromY)*progress;
      }
      const frame=1+Math.floor(bird.elapsed*8)%CHICKEN_FRAME_COUNTS[bird.color][phase.mode];
      setSprite(bird.el,`chickens/chicken_${bird.color}_${phase.mode}_${String(frame).padStart(2,'0')}.png`);
      bird.el.style.left=bird.x+'px';bird.el.style.top=bird.y+'px';bird.el.style.zIndex=65+(bird.color==='brown'?1:0);
      bird.el.style.transform=`translate(-50%,-100%) scaleX(${bird.facing})`;
    }
  }

  function buildCows(){
    cows.forEach(cow=>cow.el.remove());cows=[];
    const barn=EXTRA_BUILDINGS.find(b=>b.asset.includes('milking'));
    // Seven separate resting spots inside the isometric enclosure.
    const slots=[[0,0],[1,0],[2,0],[0,1],[1,1],[2,1],[1,2]];
    for(let i=slots.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[slots[i],slots[j]]=[slots[j],slots[i]];}
    state.cowBreeds.forEach((breed,index)=>{
      const [col,row]=slots[index];
      const x=barn.x+barn.width*(.23+col*.18+row*.11);
      const y=barn.y+barn.height*(.72-col*.065+row*.07);
      const cow={breed,x,y,homeX:x,homeY:y,fromX:x,fromY:y,targetX:x,targetY:y,mode:'idle',elapsed:0,duration:2+Math.random()*3,facing:1};
      cow.el=img(cowSprite(breed,0),'world-object animated-cow');world.append(cow.el);cows.push(cow);
    });
    updateCows(0);
  }
  function updateCows(dt){
    for(const cow of cows){
      cow.elapsed+=dt;
      if(cow.elapsed>=cow.duration){
        cow.elapsed=0;
        cow.mode=['idle','walk','graze','happy'][Math.floor(Math.random()*4)];
        cow.duration=cow.mode==='walk'?2.5:2+Math.random()*3;
        if(cow.mode==='walk'){
          cow.fromX=cow.x;cow.fromY=cow.y;
          cow.targetX=cow.homeX+(Math.random()-.5)*28;cow.targetY=cow.homeY+(Math.random()-.5)*14;
          cow.facing=cow.targetX<cow.x?1:-1;
        }
      }
      if(cow.mode==='walk'){
        const progress=Math.min(1,cow.elapsed/cow.duration);
        cow.x=cow.fromX+(cow.targetX-cow.fromX)*progress;cow.y=cow.fromY+(cow.targetY-cow.fromY)*progress;
      }
      const frame=cow.mode==='walk'?2+Math.floor(cow.elapsed*8)%4:cow.mode==='graze'?6:cow.mode==='happy'?7:cow.elapsed%cow.duration>cow.duration-.2?1:0;
      setSprite(cow.el,cowSprite(cow.breed,frame));
      cow.el.style.left=cow.x+'px';cow.el.style.top=cow.y+'px';
      cow.el.style.zIndex=47+Math.round((cow.y-1450)/20);
      cow.el.style.transform=`translate(-50%,-100%) scaleX(${cow.facing})`;
    }
  }
  function buyCow(){
    if(state.cowBreeds.length>=MAX_COWS)return toast('Limite de 7 vaquinhas atingido.');
    if(state.coins<COW_PRICE)return toast(`Faltam $${COW_PRICE-state.coins} para comprar uma vaquinha.`);
    state.coins-=COW_PRICE;
    if(!state.cowBreeds.length){state.milkCycleStart=Date.now();state.milkGenerated=false;state.milkBottles=[];}
    state.cowBreeds.push(randomCowBreed(state.cowBreeds));
    buildCows();updateAll();saveState();openShop();
    toast(`Vaquinha comprada! ${state.cowBreeds.length}/${MAX_COWS} no curral.`);
  }

  function path(x,y,w,hOrClass,orient){
    const p=el('div','path '+orient); p.style.left=x+'px'; p.style.top=y+'px';
    if(orient==='v'){p.style.height=hOrClass+'px';} else {p.style.width=w+'px';}
    world.append(p);
  }

  const CROP_ASSETS = {
    tomato: {empty:'crops/tomato_seed.png',seed:'crops/tomato_seed.png',growing:'crops/tomato_growing.png',mature:'crops/tomato_mature.png'},
    wheat: {empty:'crops/wheat_seed.png',seed:'crops/wheat_seed.png',growing:'crops/wheat_growing.png',mature:'crops/wheat_mature.png'}
  };
  function cropImg(type,stateName){
    const assets=CROP_ASSETS[type];
    if(!assets)throw new Error(`Unknown crop: ${type}`);
    return assets[stateName] || assets.empty;
  }

  function renderTomatoField(){
    const field=document.getElementById('tomato-field'); if(!field)return; field.innerHTML='';
    const label=document.getElementById('tomato-field-label');if(label)label.textContent=`CAMPO DE TOMATE • 4 × ${state.tomatoPlots.length/4}`;
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
      const cell=el('div','wheat-plot '+p.state); cell.dataset.index=i; positionPlot(cell,i,'wheat'); const im=img(cropImg('wheat',p.state)); cell.append(im);
      if(p.state==='seed'||p.state==='growing') cell.append(el('div','timer',{text:cropRemaining(p)+'s'}));
      if(p.state==='mature')cell.append(el('div','ready',{text:'✓'}));
      cell.onclick=(e)=>{e.stopPropagation(); handleWheatPlot(i);}; field.append(cell);
    });
  }
  function cropRemaining(p){const age=Date.now()-p.t;return Math.max(0,Math.ceil(((p.state==='seed'?CROP_TIMING.seedMs:CROP_TIMING.matureMs)-age)/1000));}

  function handleTomatoPlot(i){
    updateCropStates();
    const p=state.tomatoPlots[i]; const pos=plotWorldPos(i,'tomato');
    if(p.state==='empty') moveTo(pos.x,pos.y,()=>plantCrop('tomato',i));
    else if(p.state==='mature') moveTo(pos.x,pos.y,()=>harvestCrop('tomato',i));
    else toast('Ainda está crescendo.');
  }
  function handleWheatPlot(i){
    updateCropStates();
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
    return {x:(type==='tomato'?760:1840)+pos.x,y:(type==='tomato'?650:570)+pos.y+12};
  }
  function useEnergy(n){ if(state.energy<n){toast('Energia insuficiente. Aguarde a recuperação.'); return false;} state.energy-=n; return true; }
  function plantCrop(type,i){
    const plots=type==='tomato'?state.tomatoPlots:type==='wheat'?state.wheatPlots:null;
    if(!plots||!plots[i]||plots[i].state!=='empty')return false;
    if(type==='wheat'&&!state.wheatUnlocked)return false;
    // Contact always starts planting; resources never go negative.
    state.coins=Math.max(0,state.coins-2);
    state.energy=Math.max(0,state.energy-1);
    plots[i]={state:'seed',t:Date.now()};
    if(type==='tomato')state.plantedTomatoes++;
    playPlantingAnimation(type);
    toast(type==='tomato'?'Tomate plantado!':'Trigo plantado!');updateAll();saveState();
    return true;
  }
  function harvestCrop(type,i){
    // Readiness is checked now; playback never delays inventory or another harvest.
    updateCropStates();
    if((type==='tomato'?state.tomatoPlots:state.wheatPlots)[i].state!=='mature')return;
    state.energy=Math.max(0,state.energy-1);
    const plots=type==='tomato'?state.tomatoPlots:state.wheatPlots; plots[i]={state:'empty',t:0};
    state.inventory[type==='tomato'?'tomato':'wheat']++;
    if(type==='tomato') state.harvestedTomatoes++;
    playHarvestAnimation(type); burst(type==='tomato'?'vfx/harvest_tomato.png':'vfx/harvest_wheat.png',playerPos.x,playerPos.y-90,140); toast(type==='tomato'?'+1 tomate':'+1 trigo'); updateAll(); tryServeCustomers(); saveState();
  }

  function interactCoop(){
    if(!state.eggsReady)return toast('As galinhas ainda estão produzindo ovos.');
    const spot=EGG_SPOTS[state.eggSlots[0]];
    moveTo(spot.x,spot.y,collectNearbyEggs);
  }
  function collectNearbyEggs(){
    let collected=0;
    for(let i=state.eggSlots.length-1;i>=0;i--){
      const spot=EGG_SPOTS[state.eggSlots[i]];
      if(Math.hypot(playerPos.x-spot.x,playerPos.y-spot.y)>40)continue;
      state.eggSlots.splice(i,1);state.eggVariants.splice(i,1);collected++;
    }
    if(!collected)return;
    state.eggsReady-=collected;state.inventory.egg+=collected;
    if(!harvestAction)playHarvestAnimation('collect_eggs');
    toast(`+${collected} ovos coletados`);updateAll();saveState();
  }
  function restorePlayerSprite(){
    if(!player||harvestAction)return;
    if(state.inventory.egg>0){
      player.style.width='125px';player.style.transform='translate(-50%,-116px) scaleX(1)';
      setSprite(player,'characters/actions/farmer_carry_eggs.png');
    }else{
      player.style.width='';player.style.transform='translate(-50%,-88%) scaleX(1)';
      setSprite(player,`character_frames/${state.selectedCharacter}/01_idle_front.png`);
    }
  }
  function goToMarket(){ moveTo(MARKET_DROP.x,MARKET_DROP.y,()=>unloadProducts(true)); }
  function unloadProducts(showEmpty=false){
    if(Math.hypot(playerPos.x-MARKET_DROP.x,playerPos.y-MARKET_DROP.y)>MARKET_DROP.radius)return;
    let count=0;
    for(const item of Object.keys(PRODUCTS)){
      const qty=state.inventory[item];count+=qty;state.marketStock[item]+=qty;state.inventory[item]=0;
    }
    if(count){playAction('15_action_carry.png',700);toast(`${count} produtos descarregados na banca!`);updateAll();tryServeCustomers();saveState();}
    else if(showEmpty)toast('Sua mochila está vazia. Colha produtos para abastecer a banca.');
  }
  function setupJoystick(){
    if(joystick.el)return;
    const control=el('div','player-joystick',{'aria-label':'Arraste para mover o fazendeiro'});
    const base=img('ui/controls/joystick_base.png');const knob=img('ui/controls/joystick_knob.png','joystick-knob');
    control.append(base,knob,el('span','',{text:'ARRASTE'}));viewport.append(control);joystick.el=control;joystick.knob=knob;
    const update=e=>{
      const dx=e.clientX-joystick.originX,dy=e.clientY-joystick.originY,d=Math.hypot(dx,dy),scale=d>40?40/d:1;
      joystick.x=d<7?0:dx*scale/40;joystick.y=d<7?0:dy*scale/40;
      knob.style.transform=`translate(${joystick.x*40}px,${joystick.y*40}px)`;
    };
    control.onpointerdown=e=>{
      if(joystick.pointer!==null||e.button>0)return;e.preventDefault();e.stopPropagation();
      const r=control.getBoundingClientRect();joystick.originX=r.left+r.width/2;joystick.originY=r.top+r.height/2;
      joystick.pointer=e.pointerId;moveWaypoints=[];moveTarget=null;moveCallback=null;clearTimeout(currentActionTimer);control.setPointerCapture(e.pointerId);update(e);
    };
    control.onpointermove=e=>{if(e.pointerId===joystick.pointer){e.preventDefault();update(e);}};
    const stop=e=>{if(e.pointerId!==joystick.pointer)return;joystick.pointer=null;joystick.x=joystick.y=0;knob.style.transform='';moveTarget=null;moveCallback=null;if(player&&!harvestAction)restorePlayerSprite();};
    control.onpointerup=stop;control.onpointercancel=stop;control.onlostpointercapture=stop;
    window.addEventListener('blur',()=>{if(joystick.pointer!==null)stop({pointerId:joystick.pointer});});
  }
  function positionJoystick(){
    if(!joystick.el||joystick.pointer!==null)return;
    joystick.el.style.left=clamp((playerPos.x-camera.x)*camera.scale+85,75,viewport.clientWidth-75)+'px';
    joystick.el.style.top=clamp((playerPos.y-camera.y)*camera.scale+5,75,viewport.clientHeight-155)+'px';
  }

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
    const r=viewport.getBoundingClientRect(); const x=(e.clientX-r.left)/camera.scale+camera.x, y=(e.clientY-r.top)/camera.scale+camera.y;
    // Keep away from non-walkable crop/building centers via simple safe clamping.
    moveTo(clamp(x,120,WORLD_W-120),clamp(y,220,WORLD_H-120));
  }

  function constrainToFence(pos,inside){
    const limit=fenceY(pos.x)+(inside?-30:38);
    return {x:pos.x,y:inside?Math.min(pos.y,limit):Math.max(pos.y,limit)};
  }
  function blockedByBuilding(pos){
    return BUILDING_COLLIDERS.some(b=>pos.x>b.left-PLAYER_RADIUS&&pos.x<b.right+PLAYER_RADIUS&&pos.y>b.top-PLAYER_RADIUS&&pos.y<b.bottom+PLAYER_RADIUS);
  }
  function walkable(pos){return pos.y<=fenceY(pos.x)-30+.01&&!blockedByBuilding(pos);}
  function clearRoute(a,b){
    const steps=Math.max(1,Math.ceil(Math.hypot(b.x-a.x,b.y-a.y)/8));
    for(let i=0;i<=steps;i++)if(!walkable({x:a.x+(b.x-a.x)*i/steps,y:a.y+(b.y-a.y)*i/steps}))return false;
    return true;
  }
  function routeTo(target){
    const nodes=[{...playerPos},target];
    for(const b of BUILDING_COLLIDERS)for(const x of [b.left-PLAYER_RADIUS-3,b.right+PLAYER_RADIUS+3])for(const y of [b.top-PLAYER_RADIUS-3,b.bottom+PLAYER_RADIUS+3]){
      const p={x,y};if(walkable(p))nodes.push(p);
    }
    const distance=nodes.map(()=>Infinity),previous=nodes.map(()=>-1),visited=new Set();distance[0]=0;
    while(visited.size<nodes.length){
      let best=-1;for(let i=0;i<nodes.length;i++)if(!visited.has(i)&&(best<0||distance[i]<distance[best]))best=i;
      if(best<0||!Number.isFinite(distance[best]))break;if(best===1)break;visited.add(best);
      for(let i=0;i<nodes.length;i++)if(!visited.has(i)&&clearRoute(nodes[best],nodes[i])){
        const cost=distance[best]+Math.hypot(nodes[i].x-nodes[best].x,nodes[i].y-nodes[best].y);
        if(cost<distance[i]){distance[i]=cost;previous[i]=best;}
      }
    }
    if(!Number.isFinite(distance[1]))return [];
    const route=[];for(let i=1;i!==0;i=previous[i])route.unshift(nodes[i]);return route;
  }
  function moveTo(x,y,cb=null){
    let target=constrainToFence({x,y},true);
    if(blockedByBuilding(target)){
      const options=[];
      for(const b of BUILDING_COLLIDERS){
        options.push({x:b.left-PLAYER_RADIUS-2,y:target.y},{x:b.right+PLAYER_RADIUS+2,y:target.y},{x:target.x,y:b.top-PLAYER_RADIUS-2},{x:target.x,y:b.bottom+PLAYER_RADIUS+2});
      }
      options.sort((a,b)=>Math.hypot(a.x-target.x,a.y-target.y)-Math.hypot(b.x-target.x,b.y-target.y));
      target=options.find(walkable)||target;
    }
    moveWaypoints=routeTo(target);moveTarget=moveWaypoints.shift()||null;moveCallback=moveTarget?cb:null;
  }
  function moveWithCollisions(from,to){
    let pos={...from};const steps=Math.max(1,Math.ceil(Math.hypot(to.x-from.x,to.y-from.y)/4));
    const dx=(to.x-from.x)/steps,dy=(to.y-from.y)/steps;
    for(let i=0;i<steps;i++){
      const next=constrainToFence({x:pos.x+dx,y:pos.y+dy},true);
      if(!blockedByBuilding(next)){pos=next;continue;}
      const horizontal=constrainToFence({x:next.x,y:pos.y},true);if(!blockedByBuilding(horizontal))pos=horizontal;
      const vertical=constrainToFence({x:pos.x,y:next.y},true);if(!blockedByBuilding(vertical))pos=vertical;
    }
    return pos;
  }
  function playAction(frame,duration){
    if(harvestAction)return;
    clearTimeout(currentActionTimer); if(!player)return; setSprite(player,`character_frames/${state.selectedCharacter}/${frame}`);
    currentActionTimer=setTimeout(()=>{ if(player&&!moveTarget) restorePlayerSprite(); },duration);
  }

  function playPlantingAnimation(type){
    const action=`plant_${type}`;
    if(HARVEST_ANIMATIONS[action]){
      if(harvestAction&&harvestAction.type!==action)harvestAction=null;
      playHarvestAnimation(action);
    }
    else playAction('14_action_harvest.png',650);
  }
  function playHarvestAnimation(type){
    if(!player||harvestAction)return;
    if(!HARVEST_ANIMATIONS[type])return;
    clearTimeout(currentActionTimer);
    harvestAction={type,started:performance.now(),frame:-1};
    player.classList.add('crop-harvesting');
    updateHarvestAnimation(performance.now());
  }
  function updateHarvestAnimation(now){
    if(!harvestAction||!player)return;
    const animation=HARVEST_ANIMATIONS[harvestAction.type];
    const frame=Math.floor((now-harvestAction.started)/animation.frameMs);
    if(frame>=animation.frames.length){
      harvestAction=null;player.classList.remove('crop-harvesting');player.style.width='';
      player.style.transform='translate(-50%,-88%) scaleX(1)';
      restorePlayerSprite();return;
    }
    if(frame!==harvestAction.frame){
      harvestAction.frame=frame;
      const layout=animation.layout[frame];
      player.style.width=(layout.width*animation.scale)+'px';
      player.style.transform=`translate(-42%,${7-layout.footY*animation.scale}px) scaleX(1)`;
      setSprite(player,animation.frames[frame]);
    }
  }

  function sideWalkFrame(dx,phase){
    const index=(dx<0?0:2)+(phase%2);
    return `${String(9+index).padStart(2,'0')}_walk_side_0${index+1}.png`;
  }

  function updateMovement(dt){
    if(joystick.pointer!==null){
      moveWaypoints=[];
      if(Math.hypot(joystick.x,joystick.y)<.01){moveTarget=null;if(player&&!harvestAction)restorePlayerSprite();return;}
      moveTarget={x:clamp(playerPos.x+joystick.x*100,120,WORLD_W-120),y:clamp(playerPos.y+joystick.y*100,220,WORLD_H-120)};moveCallback=null;
    }
    if(moveTarget)moveTarget=constrainToFence(moveTarget,true);
    if(!player||!moveTarget)return;
    const dx=moveTarget.x-playerPos.x, dy=moveTarget.y-playerPos.y; const dist=Math.hypot(dx,dy);
    const speed=250;
    if(dist<8){
      playerPos=moveWithCollisions(playerPos,moveTarget); moveTarget=moveWaypoints.shift()||null; player.style.left=playerPos.x+'px'; player.style.top=playerPos.y+'px'; if(!harvestAction){player.style.transform='translate(-50%,-88%) scaleX(1)';restorePlayerSprite();}
      if(moveTarget)return;
      const cb=moveCallback; moveCallback=null; if(cb) setTimeout(cb,120); return;
    }
    const step=Math.min(dist,speed*dt); playerPos=moveWithCollisions(playerPos,{x:playerPos.x+dx/dist*step,y:playerPos.y+dy/dist*step});
    walkClock+=dt; if(walkClock>.13){walkClock=0;walkFrame=(walkFrame+1)%4;}
    if(!harvestAction){
    const side=Math.abs(dx)>Math.abs(dy)*.65;
    let frame;
    if(side){ frame=sideWalkFrame(dx,walkFrame); player.style.transform='translate(-50%,-88%) scaleX(1)'; }
    else if(dy<0){ frame=`${String(7+(walkFrame%2)).padStart(2,'0')}_walk_back_0${(walkFrame%2)+1}.png`; player.style.transform='translate(-50%,-88%) scaleX(1)'; }
    else { frame=`${String(5+(walkFrame%2)).padStart(2,'0')}_walk_front_0${(walkFrame%2)+1}.png`; player.style.transform='translate(-50%,-88%) scaleX(1)'; }
    setSprite(player,`character_frames/${state.selectedCharacter}/${frame}`);
    if(state.inventory.egg>0)restorePlayerSprite();
    }
    player.style.left=playerPos.x+'px'; player.style.top=playerPos.y+'px';
  }

  function updateCamera(dt){
    const vw=viewport.clientWidth,vh=viewport.clientHeight;
    const barn=EXTRA_BUILDINGS.find(b=>b.asset.includes('milking'));
    const nearby=playerPos.x<1550&&playerPos.y>820;
    let scale=1,tx,ty;
    if(nearby){
      const left=barn.x-80,right=Math.max(barn.x+barn.width+80,playerPos.x+80,MILK_AREA.x+470);
      const top=barn.y-80,bottom=Math.max(barn.y+barn.height+80,playerPos.y+60,MILK_AREA.y+280);
      const usableHeight=Math.max(150,vh-220);
      scale=Math.min(1,(vw-64)/(right-left),usableHeight/(bottom-top));
      tx=(left+right)/2-vw/(2*scale);
      ty=(top+bottom)/2-(100+usableHeight/2)/scale;
    }else{tx=playerPos.x-vw*.54;ty=playerPos.y-vh*.55;}
    const follow=1-Math.exp(-5*dt);
    camera.scale+=(scale-camera.scale)*follow;
    tx=clamp(tx,0,Math.max(0,WORLD_W-vw/camera.scale));ty=clamp(ty,0,Math.max(0,WORLD_H-vh/camera.scale));
    camera.x+=(tx-camera.x)*follow;camera.y+=(ty-camera.y)*follow;
    world.style.transform=`translate3d(${-camera.x*camera.scale}px,${-camera.y*camera.scale}px,0) scale(${camera.scale})`;
  }

  function spawnCustomer(now){
    if(customers.length>=3) return;
    const pool=CHARACTERS.map(x=>x[0]).filter(id=>id!==state.selectedCharacter);
    const id=pool[(customerSeq-1)%pool.length];
    const wantsEgg = customerSeq%4===0;
    const wantsMilk=(state.cowBreeds.length>0||state.marketStock.milk>0)&&customerSeq%5===0;
    const item=wantsMilk?'milk':wantsEgg?'egg':state.wheatUnlocked&&customerSeq%3===0?'wheat':'tomato';
    const qty=item==='milk'?1+(customerSeq%3):item==='egg'?1:item==='wheat'?1+(Math.floor((customerSeq-1)/3)%3):1+(customerSeq%3);
    let spotIndex=-1;
    for(let offset=0;offset<SALE_SPOTS.length;offset++){
      const candidate=(nextSaleSpot+offset)%SALE_SPOTS.length;
      if(!customers.some(c=>c.spotIndex===candidate && c.status!=='leaving')){spotIndex=candidate;break;}
    }
    if(spotIndex<0)return;
    nextSaleSpot=(spotIndex+1)%SALE_SPOTS.length;
    const spot=SALE_SPOTS[spotIndex];
    const c={id:customerSeq++, charId:id, item, qty, spotIndex, x:2740,y:1600,targetX:spot.x,targetY:spot.y,status:'walking',frame:0,clock:0,serveAt:0};
    c.el=img(`character_frames/${id}/09_walk_side_01.png`,'customer'); c.el.style.left=c.x+'px';c.el.style.top=c.y+'px'; world.append(c.el);
    c.bubble=el('div','customer-bubble',{text:`${PRODUCTS[item].icon} × ${qty}`}); world.append(c.bubble); customers.push(c); lastCustomerAt=now;
  }
  function updateCustomers(dt,now){
    customers.forEach((c,idx)=>{
      if(c.status==='walking'){
        const dx=c.targetX-c.x,dy=c.targetY-c.y,dist=Math.hypot(dx,dy); const speed=120;
        if(dist<5){c.x=c.targetX;c.y=c.targetY;c.status='waiting';c.serveAt=now+800;setSprite(c.el,`character_frames/${c.charId}/03_idle_side_a.png`);}
        else {const s=Math.min(dist,speed*dt);c.x+=dx/dist*s;c.y+=dy/dist*s;c.clock+=dt;if(c.clock>.16){c.clock=0;c.frame=(c.frame+1)%4;} setSprite(c.el,`character_frames/${c.charId}/${sideWalkFrame(dx,c.frame)}`);c.el.style.transform='translate(-50%,-85%) scaleX(1)';}
      } else if(c.status==='waiting' && now>=c.serveAt){
        const have=state.marketStock[c.item];
        if(have>=c.qty){ serveCustomer(c); }
        else { c.bubble.classList.add('waiting'); c.bubble.textContent=`${PRODUCTS[c.item].icon} × ${c.qty} • aguardando`; c.serveAt=now+1400; }
      } else if(c.status==='leaving'){
        const dx=2740-c.x,dy=1600-c.y,dist=Math.hypot(dx,dy); if(dist<8){c.remove=true;} else {const s=Math.min(dist,145*dt);c.x+=dx/dist*s;c.y+=dy/dist*s;c.clock+=dt;if(c.clock>.16){c.clock=0;c.frame=(c.frame+1)%4;} setSprite(c.el,`character_frames/${c.charId}/${sideWalkFrame(dx,c.frame)}`);c.el.style.transform='translate(-50%,-85%) scaleX(1)';}
      }
      const safe=constrainToFence(c,false);c.x=safe.x;c.y=safe.y;
      c.el.style.left=c.x+'px';c.el.style.top=c.y+'px'; c.bubble.style.left=c.x+'px';c.bubble.style.top=(c.y-95)+'px';
    });
    customers.filter(c=>c.remove).forEach(c=>{c.el.remove();c.bubble.remove();}); customers=customers.filter(c=>!c.remove);
  }
  function serveCustomer(c){
    const product=PRODUCTS[c.item];
    if(!product||c.status!=='waiting'||state.marketStock[c.item]<c.qty)return;
    state.marketStock[c.item]-=c.qty;const total=product.price*c.qty; state.pendingCash[c.spotIndex]+=total;state.revenue+=total;if(c.item==='tomato')state.totalSold+=c.qty;if(c.item==='wheat')state.wheatSold+=c.qty;
    c.status='leaving';c.bubble.classList.remove('waiting');c.bubble.textContent=`$${total} deixados ✓`;c.serveAt=Infinity; burst('vfx/coin.png',CASH_AREA.x,CASH_AREA.y-65,105); advanceTasks(); updateAll(); saveState();
  }
  function tryServeCustomers(){customers.forEach(c=>{if(c.status==='waiting')c.serveAt=0;});}

  function renderCashPile(){
    const cash=document.getElementById('market-cash'); if(!cash)return; cash.innerHTML='';
    const total=state.pendingCash.reduce((sum,amount)=>sum+amount,0);

    const pile=el('button','cash-grid interactable'+(total>0?' has-cash':''),{type:'button','aria-label':`Recolher $${total}`});
    pile.style.left=(CASH_AREA.x-120)+'px';pile.style.top=(CASH_AREA.y-120)+'px';
    const bundles=Math.ceil(total/CASH_AREA.bundleValue);
    const layers=Math.ceil(bundles/36);
    // A 6 by 6 diamond footprint; later payments stack above the full layer.
    for(let slot=0;slot<Math.min(36,bundles);slot++){
      const col=slot%6,row=Math.floor(slot/6);
      const height=Math.floor((bundles-1-slot)/36);
      const note=img('currency/cash_bundle_01.png','cash-grid-bundle');
      note.style.left=(93+(col-row)*15)+'px';
      note.style.top=(30+(col+row)*11-Math.min(height,3)*4)+'px';
      note.style.zIndex=1+col+row;
      pile.append(note);
    }
    pile.append(el('strong','cash-grid-total',{text:total>0?`RECOLHER $${total}${layers>1?' • '+layers+' camadas':''}`:'DINHEIRO'}));
    pile.onclick=e=>{e.stopPropagation();collectCash();};cash.append(pile);
  }
  function inCashArea(){
    // Match the outline: rotated 200px square, compressed vertically by .56.
    const dx=playerPos.x-CASH_AREA.x;
    const dy=playerPos.y-(CASH_AREA.y-10);
    return Math.abs(dx)/142+Math.abs(dy)/80<=1.12;
  }
  function collectCash(){moveTo(CASH_AREA.x,CASH_AREA.y,pickupCash);}
  function pickupCash(){
    if(!inCashArea())return;
    const amount=state.pendingCash.reduce((sum,value)=>sum+value,0);if(amount<=0)return;
    state.pendingCash=[0,0,0];state.coins+=amount;
    if(!moveTarget)playAction('15_action_carry.png',700);
    toast(`+$${amount} recolhidos!`);
    const feedback=el('div','cash-pickup-feedback',{text:`+$${amount}`});
    feedback.style.left=playerPos.x+'px';feedback.style.top=(playerPos.y-110)+'px';world.append(feedback);
    setTimeout(()=>feedback.remove(),1200);
    burst('currency/cash_bundle_01.png',playerPos.x,playerPos.y-80,65);
    updateAll();saveState();
    hudTop.classList.remove('cash-collected');void hudTop.offsetWidth;hudTop.classList.add('cash-collected');
  }

  function burst(asset,x,y,w){ const n=addImage(asset,x-w/2,y-w/2,w,3000); n.style.transition='transform .7s ease,opacity .7s ease'; setTimeout(()=>{n.style.transform='translateY(-60px) scale(1.15)';n.style.opacity='0';},20);setTimeout(()=>n.remove(),780); }

  function interactNearbyPlots(){
    updateCropStates();
    const current=new Set();
    for(const type of ['tomato','wheat']){
      if(type==='wheat'&&!state.wheatUnlocked)continue;
      const plots=type==='tomato'?state.tomatoPlots:state.wheatPlots;
      plots.forEach((plot,index)=>{
        const pos=plotWorldPos(index,type);
        // Soil diamond plus the player's contact radius: touching an edge is enough.
        const dx=Math.abs(playerPos.x-pos.x),dy=Math.abs(playerPos.y-pos.y);
        if(Math.max(0,dx-24)/92+Math.max(0,dy-24)/52>1)return;
        const key=`${type}:${index}`;
        if(nearbyPlots.has(key)&&plot.state!=='mature'){current.add(key);return;}
        if(plot.state==='mature'){harvestCrop(type,index);if(plots[index].state!=='mature')current.add(key);}
        else if(plot.state==='empty'){plantCrop(type,index);if(plots[index].state!=='empty')current.add(key);}
        // Growing crops can become harvestable while the player is still nearby.

      });
    }
    nearbyPlots=current;
  }

  function updateCropStates(){
    let changed=false;
    const now=Date.now();
    const check=(plots)=>plots.forEach(p=>{
      if(p.state!=='seed'&&p.state!=='growing')return;
      const age=now-p.t;
      const next=age>=CROP_TIMING.matureMs?'mature':age>=CROP_TIMING.seedMs?'growing':'seed';
      if(p.state!==next){p.state=next;changed=true;}
    });
    check(state.tomatoPlots);check(state.wheatPlots);
    if(changed){updateAll();saveState();}

  }
  function updateCropTimers(){
    const second=Math.floor(Date.now()/1000);if(second===lastCropTimerSecond)return;lastCropTimerSecond=second;
    for(const type of ['tomato','wheat']){
      const field=document.getElementById(`${type}-field`);if(!field)continue;
      const plots=type==='tomato'?state.tomatoPlots:state.wheatPlots;
      for(const cell of field.children){const timer=cell.querySelector('.timer');if(timer)timer.textContent=cropRemaining(plots[Number(cell.dataset.index)])+'s';}
    }
  }
  function updateMilk(now){
    if(!state.cowBreeds.length)return;
    if(!state.milkCycleStart){state.milkCycleStart=now;saveState();return;}
    const cycleMs=MILK_PRODUCTION_MS+MILK_LIFETIME_MS;
    const elapsed=now-state.milkCycleStart;
    if(elapsed>=cycleMs){
      state.milkCycleStart+=Math.floor(elapsed/cycleMs)*cycleMs;
      state.milkBottles=[];state.milkGenerated=false;updateAll();saveState();
    }
    if(now-state.milkCycleStart>=MILK_PRODUCTION_MS&&!state.milkGenerated){
      state.milkBottles=Array.from({length:state.cowBreeds.length*3},(_,i)=>i);
      state.milkGenerated=true;updateAll();saveState();
    }
  }
  function collectNearbyMilk(){
    let count=0;
    state.milkBottles=state.milkBottles.filter(slot=>{
      const p=milkSpot(slot);
      if(Math.hypot(playerPos.x-p.x,playerPos.y-p.y)<=40){count++;return false;}
      return true;
    });
    if(!count)return;
    state.inventory.milk+=count;toast(`+${count} garrafas de leite`);
    if(!harvestAction)playAction('15_action_carry.png',700);
    updateAll();saveState();
  }
  function renderMilk(){
    const area=document.getElementById('milk-area');if(!area)return;
    const signature=state.milkBottles.join(',')+'|'+state.cowBreeds.length;
    if(signature===milkVisualSignature)return;milkVisualSignature=signature;area.innerHTML='';
    if(!state.cowBreeds.length){area.style.display='none';return;}area.style.display='block';
    for(const slot of state.milkBottles){
      const p=milkSpot(slot),bottle=img('resources/milk-bottom.png','milk-bottle');
      bottle.style.left=(p.x-MILK_AREA.x-45)+'px';bottle.style.top=(p.y-MILK_AREA.y-96)+'px';bottle.style.zIndex=1+Math.floor(slot/7);area.append(bottle);
    }
    area.append(el('span','milk-label',{text:state.milkBottles.length?`LEITE • ${state.milkBottles.length} GARRAFAS`:'ÁREA DE COLETA • LEITE'}));
  }

  function renderEggs(){
    const nest=document.getElementById('egg-nest');if(!nest)return;
    const signature=state.eggVariants.map((color,i)=>color+state.eggSlots[i]).join(',');if(signature===eggVisualSignature)return;
    const previousCount=eggVisualSignature?eggVisualSignature.split(',').length:0;
    eggVisualSignature=signature;nest.innerHTML='';
    state.eggVariants.forEach((color,index)=>{
      const egg=img(`resources/eggs/egg_${color}_01.png`,'produced-egg'+(index>=previousCount?' new-egg':''));
      const spot=EGG_SPOTS[state.eggSlots[index]];
      egg.style.left=(spot.x-1540-17)+'px';egg.style.top=(spot.y-1390-17)+'px';
      egg.style.setProperty('--egg-angle',spot.angle+'deg');
      egg.style.zIndex=Math.round(spot.y-1390);nest.append(egg);
    });
    nest.append(el('span','egg-nest-label',{text:state.eggsReady?`RECOLHER ${state.eggsReady} OVOS`:'PRODUZINDO OVOS'}));
    nest.setAttribute('aria-label',`Recolher ${state.eggsReady} ovos do galinheiro`);
  }
  function updateEggs(now){
    const interval=EGG_PRODUCTION_MS/state.chickenCount;
    const cycles=Math.floor((now-lastEggAt)/interval);if(cycles<1)return;
    lastEggAt+=cycles*interval;
    const next=Math.min(MAX_EGGS,state.eggsReady+cycles);
    if(next!==state.eggsReady){
      for(let i=state.eggsReady;i<next;i++){
        state.eggVariants.push(randomEggVariant());
        state.eggSlots.push(EGG_SPOTS.findIndex((_,slot)=>!state.eggSlots.includes(slot)));
      }
      state.eggsReady=next;updateAll();saveState();
    }
  }
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
    const buttons=[['ui/button_shop.png','Loja',openShop],['ui/button_inventory.png','Inventário',openInventory],['ui/button_tasks.png','Tarefas',openTasks],['ui/button_map.png','Mapa',openMap],['ui/button_build.png','Expandir',openExpansions]];
    buttons.forEach(([icon,label,fn])=>{const b=el('button','hud-btn');b.append(img(icon),el('span','',{text:label}));b.onclick=fn;hudBottom.append(b);});
  }
  function updateAll(){uiDirty=true;}
  function flushUI(){if(!uiDirty)return;uiDirty=false;updateHUD();updateTasks();renderTomatoField();renderWheatField();renderCashPile();renderEggs();renderMilk();}

  function openPanel(title,html,extraClass=''){
    modalRoot.innerHTML='';const m=el('div','modal');const p=el('div','panel '+extraClass);p.innerHTML=`<h2>${title}</h2>${html}`;const c=el('button','close-btn',{text:'Fechar'});c.onclick=()=>modalRoot.innerHTML='';p.append(c);m.append(p);modalRoot.append(m);m.onclick=(e)=>{if(e.target===m)modalRoot.innerHTML='';};
  }
  function openInventory(){openPanel('Mochila',`<div class="panel-grid"><div class="item-row">🍅 Tomates <b>${state.inventory.tomato}</b></div><div class="item-row">🥚 Ovos <b>${state.inventory.egg}</b></div><div class="item-row">🌾 Trigo <b>${state.inventory.wheat}</b></div><div class="item-row">🏪 Na banca <b>${state.marketStock.tomato} 🍅 / ${state.marketStock.egg} 🥚 / ${state.marketStock.wheat} 🌾</b></div><div class="item-row">🥛 Leite na mochila <b>${state.inventory.milk}</b></div><div class="item-row">🥛 Leite na banca <b>${state.marketStock.milk}</b></div><div class="item-row">🐔 Galinhas <b>${state.chickenCount}/${MAX_CHICKENS}</b></div><div class="item-row">🐄 Vaquinhas <b>${state.cowBreeds.length}/${MAX_COWS}</b></div><div class="item-row">🌾 Trigos vendidos <b>${state.wheatSold}</b></div><div class="item-row">💵 Receita <b>$${state.revenue}</b></div></div>`);}
  function extraFieldRows(){return (state.tomatoPlots.length-16+state.wheatPlots.length-12)/4;}
  function addFieldRow(type){
    if(type!=='tomato'&&type!=='wheat')return;
    const plots=type==='tomato'?state.tomatoPlots:state.wheatPlots;
    const initial=type==='tomato'?16:12;
    if(plots.length>=initial+4)return toast('Este campo já recebeu sua nova fila.');
    if(type==='wheat'&&!state.wheatUnlocked)return toast('Libere a área de trigo primeiro.');
    if(state.coins<2500)return toast(`Faltam $${2500-state.coins} para adicionar a fila.`);
    state.coins-=2500;plots.push(...Array.from({length:4},()=>({state:'empty',t:0})));
    nearbyPlots.clear();updateAll();saveState();openExpansions();
    toast(`Nova fila de ${type==='tomato'?'tomate':'trigo'} liberada! +4 canteiros`);
  }
  function openExpansions(){
    const option=(type,label,initial)=>{
      const plots=type==='tomato'?state.tomatoPlots:state.wheatPlots;
      const bought=plots.length>=initial+4;
      const locked=type==='wheat'&&!state.wheatUnlocked;
      const disabled=bought||locked||state.coins<2500;
      return `<div class="expansion-option"><strong>${label} • ${plots.length/4} filas</strong><p>${bought?'Nova fila adicionada ✓':locked?'Libere a área de trigo para ampliar.':'+1 fila com 4 canteiros • $2.500'}</p><button id="add-row-${type}" class="close-btn" ${disabled?'disabled':''}>${bought?'Concluído':locked?'Área bloqueada':state.coins<2500?'Faltam $'+(2500-state.coins):'Adicionar fila • $2.500'}</button></div>`;
    };
    openPanel('Desafios de expansão',`<p>Junte os dólares das vendas e escolha qual campo ampliar. Saldo disponível: <b>$${state.coins}</b>.</p>${!state.wheatUnlocked?'<button id="unlock-wheat" class="close-btn">Liberar área de trigo • $500</button>':''}<div class="panel-grid">${option('tomato','🍅 Campo de tomate',16)}${option('wheat','🌾 Campo de trigo',12)}</div>`);
    document.getElementById('add-row-tomato').onclick=()=>addFieldRow('tomato');
    document.getElementById('add-row-wheat').onclick=()=>addFieldRow('wheat');
    const unlock=document.getElementById('unlock-wheat');if(unlock)unlock.onclick=()=>{modalRoot.innerHTML='';attemptExpansion();};
  }
  function buyChicken(){
    if(state.chickenCount>=MAX_CHICKENS)return toast('Limite de 7 galinhas atingido.');
    if(state.coins<CHICKEN_PRICE)return toast(`Faltam $${CHICKEN_PRICE-state.coins} para comprar uma galinha.`);
    state.coins-=CHICKEN_PRICE;state.chickenCount++;
    lastEggAt=Date.now();buildChickens();updateAll();saveState();openShop();
    toast(`Galinha comprada! ${state.chickenCount}/${MAX_CHICKENS} no galinheiro.`);
  }
  function openShop(){
    const full=state.chickenCount>=MAX_CHICKENS,poor=state.coins<CHICKEN_PRICE;
    const cowsFull=state.cowBreeds.length>=MAX_COWS,cowsPoor=state.coins<COW_PRICE;
    openPanel('Loja da fazenda',`<p>O plantio é automático ao tocar no canteiro. Custo nominal da semente: <b>$2</b>.</p><div class="panel-grid"><div class="item-row">🍅 Semente de tomate <b>$2</b></div><div class="item-row">🌾 Semente de trigo <b>$2</b></div></div><div class="expansion-option"><strong>Galinheiro • ${state.chickenCount}/${MAX_CHICKENS} galinhas</strong><p>Cada galinha custa $750 e produz 1 ovo a cada ${EGG_PRODUCTION_MS/1000} segundos, com surgimento gradual. Cada ovo vendido vale <b>$7</b>. O ninho comporta ${MAX_EGGS} ovos.</p><button id="buy-chicken" class="close-btn" ${full||poor?'disabled':''}>${full?'Limite de 7 atingido':poor?'Faltam $'+(CHICKEN_PRICE-state.coins):'Comprar galinha • $750'}</button></div><div class="expansion-option"><strong>Curral de ordenha • ${state.cowBreeds.length}/${MAX_COWS} vaquinhas</strong><p>Cada vaquinha custa <b>$2.500</b>. A pelagem é aleatória e o curral comporta até 7 vaquinhas. Cada uma produz 3 garrafas após 2 minutos. Recolha ao encostar na área de leite; cada garrafa vale $30. As garrafas no chão somem após 3 minutos e começa um novo ciclo.</p><button id="buy-cow" class="close-btn" ${cowsFull||cowsPoor?'disabled':''}>${cowsFull?'Limite de 7 atingido':cowsPoor?'Faltam $'+(COW_PRICE-state.coins):'Comprar vaquinha • $2.500'}</button></div>`);
    document.getElementById('buy-chicken').onclick=buyChicken;
    document.getElementById('buy-cow').onclick=buyCow;
  }
  function openTasks(){const list=taskDefs.map((d,i)=>`<div class="item-row">${i<state.taskIndex?'✓':i===state.taskIndex?'▶':'🔒'} ${d.title}<b>${d.current()}/${d.goal}</b></div>`).join('');openPanel('Progressão',`<div>${list}</div>`);}
  function openMap(){openPanel('Mapa da propriedade',`<p><b>Área inicial:</b> casa, campo de tomate com ${state.tomatoPlots.length/4} filas, galinheiro e banca.</p><p><b>Nova área:</b> campo de trigo ${state.wheatUnlocked?'liberado ✓':'bloqueado por $500'}.</p><p>Use o mapa grande caminhando pela fazenda; a câmera acompanha o personagem suavemente.</p>`);}
  function openSettings(){openPanel('Configurações',`<p>Estado salvo automaticamente no navegador.</p><button id="change-char" class="close-btn">Trocar personagem</button> <button id="reset-game" class="close-btn reset-btn">Reiniciar demo</button>`);setTimeout(()=>{document.getElementById('change-char').onclick=()=>{modalRoot.innerHTML='';charSelect.style.display='grid';showCharacterSelect();};document.getElementById('reset-game').onclick=()=>{localStorage.removeItem(SAVE_KEY);location.reload();};},0);}

  function startGame(){ if(gameStarted)return; gameStarted=true; updateHUD();updateBottom();updateTasks();buildWorld(); lastCustomerAt=performance.now()-6500;lastTs=performance.now();requestAnimationFrame(loop); }
  function loop(ts){
    const dt=Math.min(.033,(ts-lastTs)/1000);lastTs=ts;
    updateHarvestAnimation(ts);updateMovement(dt);updateChickens(dt);updateCows(dt);updateCamera(dt);positionJoystick();unloadProducts();updateCustomers(dt,ts); if(ts-lastCustomerAt>8000)spawnCustomer(ts); pickupCash();updateMilk(Date.now());collectNearbyMilk();collectNearbyEggs();interactNearbyPlots();updateEggs(Date.now());regenEnergy(Date.now());flushUI();updateCropTimers();
    if(gameStarted)requestAnimationFrame(loop);
  }

  // periodic save and first screen
  setInterval(()=>{if(gameStarted)saveState();},3000);
  showCharacterSelect();
})();

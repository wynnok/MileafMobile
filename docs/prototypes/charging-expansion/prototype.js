// Three structures for the existing Charging area, ?variant=A|B|C. Review artifacts only.
// The full proposal is the default; "existing" shows the frozen API's actual boundary.
const query = new URLSearchParams(location.search);
const S = {
  variant:['A','B','C'].includes(query.get('variant'))?query.get('variant'):'A',
  mode:query.get('mode')==='existing'?'existing':'vision',theme:query.get('theme')==='dark'?'dark':'light',
  size:query.get('size')==='200'?'200':'100',data:query.get('data')||'normal',period:query.get('period')==='7'?7:30,
  currency:query.get('currency')==='none'?'none':'CNY',metric:'energy',curve:'power',axis:'time',
  record:Number(query.get('record')||301),point:7,day:27,focus:query.get('focus')||'main',
  place:null,type:'all',search:'',sort:'date',loaded:6,dayFilter:null,help:null,
  compare:query.get('compare')==='1',export:query.get('export')==='1',screen:query.get('screen')||'list',full:query.get('full')==='1',
};
const variants={A:{name:'补能账本',tag:'费用 → 补能 → 过程',reason:'推荐作为默认入口。先知道钱花在哪里，再用地点和曲线找回每次补能。'},
  B:{name:'时间日历',tag:'日历 → 时间 → 习惯',reason:'适合关心充电安排的人。先找某一天，再看充电时段、记录时长和电量区间。'},
  C:{name:'地点足迹',tag:'地点 → 账目 → 记录',reason:'适合经常异地补能的人。先认出地点，再看自己的历史费用与补能记录。'}};
const icon=(name,size=20)=>{
  const paths={leaf:'M12 2c4 4 4 7 0 10-4-3-4-6 0-10ZM3 10c6 0 9 3 9 10-6-1-9-4-9-10Zm18 0c0 6-3 9-9 10 0-7 3-10 9-10Z',
    bolt:'m13 2-8 12h6l-1 8 9-13h-7l1-7Z',home:'m3 11 9-8 9 8M5 10v11h5v-7h4v7h5V10',car:'M5 6 3 13v6h3v-3h12v3h3v-6l-2-7H5Zm-1 7h16M7 6l-1 7m11-7 1 7M6 15h1m10 0h1',
    chart:'M4 20V10h3v10M10 20V4h3v16m3 0V8h3v12',chevron:'m9 5 7 7-7 7',back:'m14 5-7 7 7 7M7 12h13',refresh:'M20 8V3l-4 4a8 8 0 1 0 3 10M20 8h-6',
    pin:'M19 10c0 6-7 12-7 12S5 16 5 10a7 7 0 1 1 14 0Z M14 10a2 2 0 1 1-4 0 2 2 0 0 1 4 0Z',clock:'M12 7v5l4 2M22 12a10 10 0 1 1-20 0 10 10 0 0 1 20 0Z',
    search:'m16 16 5 5M18 10a8 8 0 1 1-16 0 8 8 0 0 1 16 0Z',info:'M12 11v6m0-11v1M22 12a10 10 0 1 1-20 0 10 10 0 0 1 20 0Z',building:'M4 22V3h16v19M8 7h2m4 0h2M8 11h2m4 0h2M8 15h2m4 0h2M10 22v-4h4v4'};
  return `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="${paths[name]||paths.bolt}"/></svg>`;
};
const esc=v=>String(v).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
const number=(n,d=1)=>n===null||n===undefined?'—':n.toFixed(d).replace(/\.0$/,'');
const money=(n,d=2)=>n===null?'—':`${number(n,d)} <small>${S.currency==='CNY'?'CNY':'币种未知'}</small>`;
const moneyText=n=>n===null?'—（费用未知）':`${number(n,2)} ${S.currency==='CNY'?'CNY':'（币种未知）'}`;
const local=d=>new Date(d.getTime()+8*3600000);
const dayOf=d=>local(d).getUTCDate();
const hourOf=d=>`${String(local(d).getUTCHours()).padStart(2,'0')}:${String(local(d).getUTCMinutes()).padStart(2,'0')}`;
const dateOf=d=>`${local(d).getUTCMonth()+1}月${dayOf(d)}日`;
const duration=m=>m===null?'进行中':m<60?`${m}分钟`:`${Math.floor(m/60)}小时${m%60?m%60+'分':''}`;
const full=()=>S.mode==='vision';
function records(){
  if(S.data==='empty')return [];
  const start=Date.parse(S.period===7?'2026-10-21T00:00:00+08:00':'2026-09-28T00:00:00+08:00');
  return CHARGE_RECORDS.filter(r=>(full()?r.end:r.start).getTime()>=start).map(r=>S.data==='missing'&&r.id===301?{...r,cost:null,used:null,socEnd:null}:r);
}
function totals(){return chargeFixtureTotals(records());}
function matched(){
  return records().filter(r=>(!S.place||r.place.id===S.place)&&(!S.dayFilter||dayOf(full()?r.end:r.start)===S.dayFilter)
    &&(S.type==='all'||r.type===S.type)&&(!S.search||r.place.name.includes(S.search))).sort((a,b)=>{
    if(S.sort==='price'){const x=a.cost===null||!a.added?Infinity:a.cost/a.added,y=b.cost===null||!b.added?Infinity:b.cost/b.added;return x-y||b.start-a.start;}
    if(S.sort==='duration')return b.duration-a.duration||b.start-a.start;
    return b.start-a.start;
  });
}
function picked(){return S.record===302&&S.data==='ongoing'?CHARGE_ACTIVE:records().find(r=>r.id===S.record)||records()[0]||null;}
function button(label,action,extra='',cls='text-button'){return `<button class="${cls}" data-action="${action}" ${extra}>${label}</button>`;}
function heading(title,side=''){return `<div class="section-head"><h2>${title}</h2>${side}</div>`;}
function info(key,label='口径'){return button(label,'help',`data-key="${key}"`);}
function appHeader(detail=false){return detail?`<header class="app-head"><div class="detail-head">${button(icon('back'),'back','aria-label="返回充电"','icon-button')}<span>充电回顾</span></div>${button(icon('refresh'),'refresh','aria-label="刷新充电明细"','icon-button')}</header>`:
  `<header class="app-head"><div class="app-brand">${icon('leaf',24)}行笺</div><button class="vehicle" data-action="help" data-key="vehicle">行笺测试车 <span>⌄</span></button>${button(icon('refresh'),'refresh','aria-label="刷新充电"','icon-button')}</header>`;}
function nav(){return `<nav class="nav" aria-label="主导航">${[['home','概览'],['car','行程'],['bolt','充电'],['chart','统计']].map(([i,n])=>`<button class="${n==='充电'?'selected':''}" data-action="${n==='充电'?'main':'help'}" data-key="nav">${icon(i)}${n}</button>`).join('')}</nav>`;}
function period(){return `<div class="period">${[30,7].map(n=>button('近'+n+'日','period',`data-value="${n}"`,S.period===n?'selected':'')).join('')}${button('自定义','help','data-key="dates"')}<span class="period-date">${S.period===7?'10.21':'09.28'}—10.27</span></div>`;}
function notices(){return S.data==='stale'?`<div class="notice">更新未完成，正在显示 17:40 的快照。${button('重试更新','refresh')}</div>`:S.data==='missing'?`<div class="notice">部分费用、结束电量和曲线读数缺失；已有数据仍可查看。</div>`:'';}
function activeCard(){return S.data==='ongoing'?`<div class="active-card" role="button" tabindex="0" data-action="record" data-id="302"><b><i class="pulse"></i>正在家里补能</b><p>60% → 进行中 · 已补入 2.2 kWh</p><small>截至 19:10 的记录 · 尚未计入已完成统计</small></div>`:'';}
function hero(compact=false){
  const t=totals();
  if(S.data==='statsfail')return `<div class="notice">期间统计暂时不可用，充电记录仍可阅读。${button('重试统计','refresh')}</div>`;
  return `<section class="hero">${compact?'':`<div class="hero-top"><span class="eyebrow">已知充电费用</span>${button(`${t.sessions}次已完成 ↗`,'records')}</div><div class="hero-money">${money(t.cost)}</div>`}
  <div class="coverage-line">${t.sessions===0?'暂无已完成费用记录':full()?`费用有记录 <b>${t.knownCount}/${t.sessions}次</b> · 对应入电 ${number(t.knownEnergy)} kWh`:'仅含费用已知记录 · 完整性暂未提供'} ${info('cost','ⓘ')}</div>
  <div class="mini-metrics"><div class="mini"><strong>${number(t.energy)}<small>kWh</small></strong><span>补入电池</span></div><div class="mini"><strong>${number(t.price,2)}</strong><span>每入电kWh · ${S.currency==='CNY'?'CNY':'币种未知'}</span></div><div class="mini"><strong>${full()?`${Math.floor(t.duration/60)}<small>时</small>${t.duration%60?`${t.duration%60}<small>分</small>`:''}`:`${t.sessions}<small>次</small>`}</strong><span>${full()?'记录充电时长':'已完成充电'}</span></div></div></section>`;
}
function trend(){
  const rows=records(),metric=S.metric,days=S.period===7?Array.from({length:7},(_,i)=>i+21):Array.from({length:30},(_,i)=>i-2);
  const buckets=days.map(d=>{
    const dayRows=rows.filter(r=>dayOf(r.end)===d),t=chargeFixtureTotals(dayRows);
    return {day:d,rows:dayRows,value:metric==='energy'?t.energy:metric==='cost'?t.cost:metric==='price'?t.price:t.sessions};
  });
  const max=Math.max(metric==='price'?1:10,...buckets.map(b=>b.value??0)),top=metric==='count'?Math.max(1,Math.ceil(max)):metric==='price'?Math.ceil(max*2)/2:Math.ceil(max/20)*20;
  const left=30,right=302,bottom=125,up=19,w=right-left,bw=w/buckets.length;
  const unit=metric==='energy'?'kWh':metric==='count'?'次':metric==='price'?`${S.currency==='CNY'?'CNY':'币种未知'}/入电kWh`:S.currency==='CNY'?'CNY':'币种未知';
  const selection=buckets.find(b=>b.day===S.day)||buckets[buckets.length-1];
  const bars=buckets.map((b,i)=>{
    const x=left+i*bw+bw*.2,height=b.value===null?0:(b.value/top)*(bottom-up);
    const mark=b.value===null?`<text x="${x+bw*.3}" y="${bottom-4}" text-anchor="middle">—</text>`:
      b.value===0?`<circle cx="${x+bw*.3}" cy="${bottom}" r="1.2" fill="var(--muted)"/>`:`<rect x="${x}" y="${bottom-height}" width="${bw*.6}" height="${height}" rx="2" fill="${b.day===S.day?'var(--green)':'var(--bar)'}"/>`;
    return `${mark}${b.day===S.day?`<path d="M${x+bw*.3} ${up}V${bottom+2}" class="picked"/>`:''}<rect x="${left+i*bw}" y="${up}" width="${bw}" height="${bottom-up+6}" fill="transparent" data-action="day" data-value="${b.day}" aria-label="${b.day>0?'10月'+b.day+'日':'9月'+(30+b.day)+'日'} ${number(b.value,2)} ${unit}"/>`;
  }).join('');
  const dayIndex=buckets.indexOf(selection),dayLabel=selection.day>0?`10月${selection.day}日`:`9月${30+selection.day}日`;
  return `<section class="chart-card">${heading('补能的节奏',info('period','已完成 · 结束日 ⓘ'))}<div class="tabs">${[['energy','电量'],['cost','费用'],['price','均价'],['count','次数']].map(([k,n])=>button(n,'metric',`data-value="${k}"`,metric===k?'selected':'')).join('')}</div>
  <svg class="chart-svg" data-chart="trend" tabindex="0" role="img" aria-label="每日${unit}图；左右键选日" viewBox="0 0 314 150"><text x="1" y="10">${unit}</text>${[0,.5,1].map(f=>`<path d="M${left} ${bottom-(bottom-up)*f}H${right}" class="grid"/><text x="24" y="${bottom-(bottom-up)*f+3}" text-anchor="end">${number(top*f,metric==='price'?1:0)}</text>`).join('')}${bars}${[0,Math.floor(days.length/2),days.length-1].map(i=>`<text x="${left+(i+.5)*bw}" y="144" text-anchor="${i===0?'start':i===days.length-1?'end':'middle'}">${days[i]>0?'10/'+days[i]:'9/'+(30+days[i])}</text>`).join('')}</svg>
  <div class="chart-reader"><span>${dayLabel} · <b>${number(selection.value,metric==='price'?2:1)} ${unit}</b></span><div class="reader-buttons">${button('‹','day',`data-value="${buckets[Math.max(0,dayIndex-1)].day}" aria-label="前一天"`,'')}${button('›','day',`data-value="${buckets[Math.min(days.length-1,dayIndex+1)].day}" aria-label="后一天"`,'')}</div></div>
  <div class="chart-note">${selection.rows.length?`${selection.rows.length}次已完成${full()?` · ${button('看当天记录 ↗','day-records')}`:` · ${button('归期说明','help','data-key="boundary"')}`}`:'这一天没有已完成的充电。'} ${metric==='price'?'均价只使用费用已知记录对应的入电量。':''}</div></section>`;
}
function composition(){
  const t=totals(),max=Math.max(t.ac,t.dc,t.unknown,1),values=[['AC',t.ac,'ac'],['DC',t.dc,'dc'],...(full()?[['未知',t.unknown,'unknown']]:[])];
  return `<section class="section">${heading('我的补能方式',info('classification','分类说明 ⓘ'))}<div class="type-rows">${values.map(([label,value,c])=>`<div class="type-row ${c}"><span>${label}</span><div class="h-track"><i style="width:${value/max*100}%"></i></div><strong>${number(value)} <small>kWh</small></strong></div>`).join('')}</div><p class="chart-note">DC 占已知分类能量 ${number(t.ac+t.dc?t.dc/(t.ac+t.dc)*100:null)}%${full()?` · 未知 ${number(t.unknown)} kWh`:' · 未知分类未并入AC'}。</p>${full()?`<p class="chart-note">记录时长：AC ${duration(t.acDuration)} · DC ${duration(t.dcDuration)}。</p>`:''}</section>`;
}
function placeGroups(){return CHARGE_PLACES.map(p=>({place:p,rows:records().filter(r=>r.place.id===p.id)})).filter(g=>g.rows.length);}
function placeCards(limit=4){
  const groups=placeGroups().sort((a,b)=>chargeFixtureTotals(b.rows).energy-chargeFixtureTotals(a.rows).energy).slice(0,limit),max=Math.max(1,...groups.map(g=>chargeFixtureTotals(g.rows).energy));
  return groups.map(g=>{const t=chargeFixtureTotals(g.rows);return `<div class="place-card"><button class="place-line" data-action="place" data-value="${g.place.id}"><span class="place-symbol ${g.place.kind==='DC'?'dc':''}">${icon(g.place.kind==='DC'?'bolt':g.place.id==='geofence:1'?'home':'building',18)}</span><span class="place-info"><b>${g.place.name}</b><small>${g.rows.length}次 · ${number(t.energy)} kWh · 费用有记录 ${t.knownCount}/${t.sessions}次</small></span><span class="place-price">${number(t.price,2)}<small>${S.currency==='CNY'?'CNY':'币种未知'}/入电kWh</small></span></button><div class="place-bar"><i style="width:${t.energy/max*100}%"></i></div></div>`;}).join('');
}
function soc(record,scale=false){return `<div class="soc-labels"><b>${record.socStart??'—'}% <span aria-hidden="true">→</span> ${record.socEnd===null?(record.active?'进行中':'—'):record.socEnd+'%'}</b><span class="soc-delta">${record.socStart!==null&&record.socEnd!==null?'增加 '+(record.socEnd-record.socStart)+' 个百分点':'结束电量尚不可用'}</span></div><div class="soc-track">${record.socStart!==null&&record.socEnd!==null?`<i style="left:${Math.min(record.socStart,record.socEnd)}%;width:${Math.abs(record.socEnd-record.socStart)}%"></i>`:''}</div>${scale?'<div class="soc-scale"><span>0%</span><span>100%</span></div>':''}`;}
function recordCard(r){return `<button class="record ${picked()?.id===r.id?'chosen':''}" data-action="record" data-id="${r.id}"><span class="record-top"><b class="record-place">${r.place.name}</b><span class="badge ${r.type==='DC'?'dc':r.type==='未知'?'unknown':''}">${r.type}</span></span><p class="record-meta">${hourOf(r.start)}—${r.end?(dayOf(r.start)!==dayOf(r.end)?'次日 ':'')+hourOf(r.end):'进行中'} · ${duration(r.duration)}</p>${soc(r)}<span class="record-results"><strong>${number(r.added)}<small>kWh 入电</small></strong><span>${money(r.cost)}</span></span><span class="record-footer"><span>${full()&&r.cost!==null&&r.added>0?`${number(r.cost/r.added,2)} ${S.currency==='CNY'?'CNY':'币种未知'}/入电kWh`:'费用 '+(r.cost===null?'未记录':'已记录')}</span><span>查看回顾 ↗</span></span></button>`;}
function recordList(rows,limit=rows.length){
  if(!rows.length)return `<div class="empty"><h3>没有匹配的充电</h3><p>试试其他日期、地点或分类。</p>${button('清除筛选','clear','','solid')}</div>`;
  let previous='';return rows.slice(0,limit).map(r=>{const day=dateOf(full()?r.end:r.start),label=day!==previous?`<p class="record-day">${day}${full()?'结束':'开始'}</p>`:'';previous=day;return label+recordCard(r);}).join('');
}
function latest(){return `<section class="section">${heading('最近的充电',button('全部记录 ↗','records'))}${recordList(records(),3)}${button(`查看${totals().sessions}次已完成记录`,'records','','all-records')}</section>`;}
function filters(){return full()?`<form class="search" id="charge-search">${icon('search',16)}<input name="place" aria-label="在整个区间搜索充电地点" placeholder="搜这段时间的充电地点" value="${esc(S.search)}"><button type="submit" aria-label="提交地点搜索">↗</button></form><div class="chips">${[['all','全部'],['AC','AC'],['DC','DC'],['未知','未知']].map(([k,n])=>button(n,'type',`data-value="${k}"`,S.type===k?'selected':'')).join('')}</div><div class="filter-line"><span>完整查询范围 · 按结束时间归期</span><select class="sort" aria-label="排序" data-control="sort">${[['date','最近结束'],['price','入电均价从低到高'],['duration','记录时长从长到短']].map(([k,n])=>`<option value="${k}" ${S.sort===k?'selected':''}>${n}</option>`).join('')}</select></div>`:`<p class="chart-note">按开始时间归期 · 分页读取；现有接口仅支持日期。</p>`;}
function recordsView(){
  const rows=matched(),t=chargeFixtureTotals(rows),active=S.place||S.search||S.type!=='all'||S.dayFilter;
  return `<div class="page-title"><h1>${S.place?'地点记录':S.dayFilter?`10月${S.dayFilter}日`:'充电记录'}</h1>${button('返回总览','main')}</div>${period()}${S.place?`<h2 class="location-title">${CHARGE_PLACES.find(p=>p.id===S.place)?.name||'未知地点'}</h2>`:''}${filters()}${full()?`<div class="filter-summary"><b>匹配 ${t.sessions}次 · ${number(t.energy)} kWh</b><br>已知费用 ${moneyText(t.cost)} · 费用有记录 ${t.knownCount}/${t.sessions}次${active?' · '+button('清除筛选','clear'):''}</div>`:''}${recordList(rows,S.loaded)}${rows.length>S.loaded?button('加载更多记录','more','','all-records'):`<p class="chart-note">已到最后一条 · ${full()?'结束':'开始'}时间归期</p>`}`;
}
function calendar(){
  const rows=records(),available=rows.filter(r=>dayOf(r.end)===S.day),t=chargeFixtureTotals(available);
  return `<section class="calendar"><div class="calendar-title"><span>2026年10月</span><small>按结束日 · ${totals().sessions}次已完成</small></div><div class="calendar-grid">${['一','二','三','四','五','六','日'].map(s=>`<span class="weekday">${s}</span>`).join('')}${'<span></span>'.repeat(3)}${Array.from({length:31},(_,i)=>{const day=i+1,list=rows.filter(r=>dayOf(r.end)===day),energy=chargeFixtureTotals(list).energy,kind=list[0]?.type,unavailable=day>27||(S.period===7&&day<21);return `<button class="calendar-day ${list.length?'has':''} ${kind==='DC'?'dc':kind==='未知'?'unknown':''} ${day===S.day?'picked-day':''} ${unavailable?'future':''}" ${unavailable?'disabled':''} data-action="day" data-value="${day}" aria-label="10月${day}日${day>27?'尚未发生':unavailable?'未选区间':`，${number(energy)} kWh`} "><span>${day}</span><small>${unavailable?'':energy?number(energy):'·'}</small></button>`;}).join('')}</div><div class="calendar-note"><span>数字是补入电量 kWh</span><span>虚淡为未选/未来</span></div></section>
  <div class="section-head"><h2>10月${S.day}日${full()?'的充电':'已完成'}</h2><span>${number(t.energy)} kWh</span></div>${full()?recordList(available):`<p class="chart-note">${button('查看归期说明','help','data-key="boundary"')} · 当前列表仍按开始日；日历不冒充可精确下钻。</p>`}`;
}
function habits(){
  const rows=records(),ac=rows.filter(r=>r.type==='AC'),starts=ac.map(r=>hourOf(r.start)),evenings=starts.filter(t=>t>='18:00'||t<'06:00').length;
  return `<section class="rhythm-card">${heading('自己的补能习惯',info('habits','只读观察 ⓘ'))}<p class="chart-note">${evenings}/${ac.length}次 AC 充电开始于 18:00—次日06:00。这里表示开始时段，不能据此推断谷电费用。</p><div class="rhythm-row"><span>夜间开始</span><div class="h-track"><i style="width:${ac.length?evenings/ac.length*100:0}%"></i></div><b>${evenings}次</b></div><div class="rhythm-row"><span>其他时段</span><div class="h-track"><i style="width:${ac.length?(ac.length-evenings)/ac.length*100:0}%"></i></div><b>${ac.length-evenings}次</b></div><p class="chart-note" style="margin-top:18px">最近3次的电量区间 · 同一0—100%尺度</p>${rows.slice(0,3).map(r=>`<div class="rhythm-row"><span>${dateOf(r.end)}</span><div class="mini-soc">${r.socEnd!==null?`<i style="left:${r.socStart}%;width:${r.socEnd-r.socStart}%"></i>`:''}</div><b>${r.socStart}→${r.socEnd??'—'}%</b></div>`).join('')}</section>`;
}
function locationMap(single=null){
  const scope=full()?records():records().slice(0,S.loaded);
  const groups=(full()?placeGroups():CHARGE_PLACES.map(p=>({place:p,rows:scope.filter(r=>r.place.id===p.id)})).filter(g=>g.rows.length)).filter(g=>g.place.x!==null&&(!single||g.place.id===single));
  return `<section class="map-card"><svg class="map-svg" viewBox="0 0 324 266" role="img" aria-label="自行绘制的合成充电地点分布示意，不是真实底图"><rect width="324" height="266" fill="var(--soft)"/><path d="M65 0 95 45 63 91 58 161 25 211 46 266H0V0M280 0 266 58 297 93 324 100V0" fill="var(--park)"/><path d="M140-20C98 40 176 84 146 144s-13 83 38 142" stroke="var(--water)" stroke-width="30" fill="none"/><g fill="none" stroke="var(--road)" stroke-width="5"><path d="M0 68 112 62 212 76 324 56M1 129 119 123 196 138 324 120M0 222 99 207 213 214 324 229M45 0 62 114 86 266M247 0 238 118 264 266"/><path d="M0 180 120 166M176 187 324 170" stroke-width="3"/></g><text x="168" y="131" transform="rotate(62 168 131)">湖 湾</text><text x="13" y="39">湖西</text><text x="270" y="34">园区</text>${groups.map((g,i)=>{const dc=g.place.kind==='DC',color=dc?'var(--amber)':'var(--green)';return `<g role="button" tabindex="0" data-action="map-place" data-value="${g.place.id}" aria-label="${g.place.name}，${g.rows.length}次${full()?'':'本页记录'}"><circle cx="${g.place.x}" cy="${g.place.y}" r="${17+g.rows.length}" fill="${color}" opacity=".13"/><circle cx="${g.place.x}" cy="${g.place.y}" r="13" fill="${color}"/><text x="${g.place.x}" y="${g.place.y+3}" text-anchor="middle" style="fill:var(--green-on);font-size:11px;font-weight:600">${full()?g.rows.length:i+1}</text><rect x="${g.place.x-48}" y="${g.place.y+20}" width="96" height="20" rx="7" fill="var(--card)"/><text x="${g.place.x}" y="${g.place.y+33}" text-anchor="middle" style="fill:var(--text)">${g.place.short}</text></g>`;}).join('')}</svg><div class="map-caption"><span>${full()?'地点数字为期间次数':'仅本页地点 · 数字对应本页地点组'} · 合成示意</span><span>${full()?'':'本页'}未定位 ${scope.filter(r=>r.place.x===null).length}次</span></div></section>`;
}
function listBody(variant){
  if(S.focus==='records')return notices()+recordsView();
  const title=`<div class="page-title"><h1>充电</h1>${button('全部记录 ↗','records')}</div>${period()}${notices()}${activeCard()}`;
  if(S.data==='empty')return title+hero()+`<div class="empty">${icon('bolt',42)}<h3>这段时间还没有充电记录</h3><p>换个区间，找回之前的补能。<br>未知费用与没有记录会分别显示。</p>${button('查看近30日示例','reset','','solid')}</div>`;
  if(S.data==='statsfail'&&variant!=='C')return title+hero()+latest();
  if(variant==='B')return title+`<p class="eyebrow">把补能放回生活的时间里</p>`+calendar()+(full()?habits():'')+`<section class="section">${heading('这一段时间',button('看全部记录','records'))}${hero()}</section>`+composition()+(full()?'':latest());
  if(variant==='C')return title+`<div class="section-head"><h2>${full()?'常去的地方，留下自己的账':'从眼前记录找回地点'}</h2></div>`+locationMap()+(full()?`<section class="section">${heading('按补入电量排序',info('places','比较说明 ⓘ'))}${placeCards()}</section>`:`<p class="chart-note">只展示当前已加载${Math.min(S.loaded,records().length)}条的地点。点地点查看其中最近的一次；不代表全区间排行。</p>`)+`<section class="section">${heading('期间账目')}${hero()}</section>`+latest();
  return title+hero()+trend()+composition()+(full()?`<section class="section">${heading('钱花在哪里',button('地点分布 ↗','locations'))}${placeCards(2)}<p class="chart-note">均价只描述自己的历史记录；不同地点的电量区间、方式和计费条件可能不同。</p></section>`:'')+latest();
}
function curve(record,small=false){
  const points=chargeSamples(record,S.data==='missing'),metric=small?'soc':S.curve,axis=small?'time':S.axis;
  const names={power:['功率','kW'],soc:['电量','%'],voltage:['电压','V'],current:['电流','A'],temp:['室外温度','°C'],range:['额定续航','km']};
  const [name,unit]=names[metric],idx=Math.min(S.point,Math.max(0,points.length-1)),selected=points[idx];
  if(!points.length||S.data==='seriesfail')return `<div class="chart-card detail-curve">${heading('充电过程')}<div class="empty"><h3>${S.data==='seriesfail'?'曲线暂时不可用':'没有过程采样'}</h3><p>本次结果仍可查看。</p>${S.data==='seriesfail'?button('重试曲线','refresh','','solid'):''}</div></div>`;
  const vals=points.map(p=>p[metric]).filter(v=>v!==null),max=Math.max(...vals),min=metric==='voltage'?Math.floor((Math.min(...vals)-10)/10)*10:metric==='temp'?Math.floor(Math.min(...vals)-2):0;
  const top=metric==='soc'?100:metric==='power'?Math.ceil(max/50)*50||10:metric==='range'?Math.ceil(max/100)*100:metric==='temp'?Math.ceil(max+2):Math.ceil(max/10)*10||10;
  const xValue=p=>axis==='soc'?p.soc:p.minute,xMin=axis==='soc'?0:0,xMax=axis==='soc'?100:record.active?20:record.duration;
  const x=p=>31+(xValue(p)-xMin)/(xMax-xMin||1)*270,y=v=>139-(v-min)/(top-min||1)*113;
  let path='',previous=false;
  for(const p of points){if(p[metric]===null||xValue(p)===null){previous=false;continue;}path+=(previous?'L':'M')+x(p).toFixed(2)+' '+y(p[metric]).toFixed(2)+' ';previous=true;}
  const ticks=axis==='soc'?[0,50,100]:[0,Math.round(xMax/2),xMax];
  return `<section class="chart-card detail-curve">${heading(small?'电量对照':name+'过程',info('sampling','采样 ⓘ'))}${small?'':`<div class="tabs">${(full()?['power','soc','voltage','current','temp','range']:['power','soc']).map(k=>button(names[k][0],'curve',`data-value="${k}"`,k===S.curve?'selected':'')).join('')}</div>${full()?`<div class="tabs">${button('按时间','axis','data-value="time"',axis==='time'?'selected':'')}${button('按电量','axis','data-value="soc"',axis==='soc'?'selected':'')}</div>`:''}`}
  <svg class="chart-svg" viewBox="0 0 314 166" data-chart="curve" tabindex="0" role="img" aria-label="${name}${unit}曲线，${axis==='soc'?'横轴电量百分比':'横轴时间'}，左右键选择采样"><text x="0" y="12">${unit}</text>${[0,.5,1].map(f=>`<path d="M31 ${139-113*f}H301" class="grid"/><text x="24" y="${142-113*f}" text-anchor="end">${number(min+(top-min)*f,0)}</text>`).join('')}<path d="${path}" class="line"/>${points.map((p,i)=>p[metric]!==null&&xValue(p)!==null?`<circle cx="${x(p)}" cy="${y(p[metric])}" r="${i===idx?4:2}" class="dot"/>`:'').join('')}${selected&&xValue(selected)!==null?`<path d="M${x(selected)} 24V139" class="picked"/>`:''}${ticks.map((t,i)=>`<text x="${31+(t-xMin)/(xMax-xMin||1)*270}" y="159" text-anchor="${i===0?'start':i===2?'end':'middle'}">${axis==='soc'?t+'%':hourOf(new Date(record.start.getTime()+t*60000))}</text>`).join('')}${points.map((p,i)=>xValue(p)!==null?`<rect x="${x(p)-7}" y="24" width="14" height="118" fill="transparent" data-action="point" data-value="${i}"/>`:'').join('')}</svg>
  <div class="chart-reader"><span>${selected?hourOf(selected.t):'—'} · <b>${selected?number(selected[metric],metric==='temp'?1:0):'—'} ${unit}</b>${metric!=='soc'&&selected?` · ${selected.soc??'—'}%`:''}</span>${small?'':`<div class="reader-buttons">${button('‹','point',`data-value="${Math.max(0,idx-1)}" aria-label="前一个采样"`,'')}${button('›','point',`data-value="${Math.min(points.length-1,idx+1)}" aria-label="后一个采样"`,'')}</div>`}</div>${small?'':`<p class="chart-note">${axis==='soc'?'同一SOC可能对应多个时刻；按原始时间顺序展示。':'曲线按记录采样显示，空值处断开。'}${record.active?' 进行中，尚无最终结果。':''}</p>`}</section>`;
}
function processSummary(r){
  if(!full()||r.active)return '';
  const process=CHARGE_PROCESS_FIXTURES[r.id];
  return `<div class="curve-stats"><div><b>${number(process?.powerMax,0)} <small>kW</small></b><span>原始记录峰值</span></div><div><b>${number(process?.powerTimeWeighted)} <small>kW</small></b><span>记录平均功率</span></div><div><b>${number(r.duration,0)} <small>分</small></b><span>记录充电时长</span></div></div><p class="chart-note">平均值与峰值由原始记录统计；抽样曲线可能未显示原始峰值。${info('time','时长说明')}</p>`;
}
function chargingWindow(r){
  if(!full()||r.active)return '';
  return `<section class="time-range"><div class="time-range-top"><div><p class="eyebrow">20% → 80% 记录用时</p><strong>${r.id===301&&r.socEnd!==null?'28 <small>分钟</small>':'—'}</strong></div>${info('window','记录依据 ⓘ')}</div>${r.id===301&&r.socEnd!==null?`<div class="soc-phases"><i style="width:3%"></i><i style="width:82%"></i><i style="width:15%"></i></div><div class="soc-phase-labels"><span>18→20% · 1分</span><span>20→80% · 28分</span><span>80→82% · 5分</span></div>`:`<p class="chart-note">这次记录未完整覆盖可用的20%—80%区间。</p>`}</section>`;
}
function energySides(r){const max=Math.max(r.added??0,r.used??0,1);return `<section class="energy-sides">${heading('两侧能量',info('energy','怎样理解 ⓘ'))}<div class="energy-side-row"><span>电网侧估算</span><div class="h-track"><i class="grid-energy" style="width:${r.used===null?0:r.used/max*100}%"></i></div><b>${number(r.used)}<small> kWh</small></b></div><div class="energy-side-row"><span>充入电池</span><div class="h-track"><i style="width:${r.added===null?0:r.added/max*100}%"></i></div><b>${number(r.added)}<small> kWh</small></b></div><p class="chart-note">相同kWh尺度分别展示；两者不能相加。电网侧值来自TeslaMate记录估算。</p></section>`;}
function costDetail(r){return `<section class="section">${heading('这一次的账',info('cost','费用口径 ⓘ'))}<div class="cost-detail"><div class="cost-row"><span>已记录费用</span><strong>${money(r.cost)}</strong></div>${full()?`<div class="cost-row"><span>每入电kWh费用</span><b>${r.cost!==null&&r.added>0?number(r.cost/r.added,2):'—'} <small>${S.currency==='CNY'?'CNY':'币种未知'}/入电kWh</small></b></div><div class="cost-row"><span>每网侧kWh费用</span><b>${r.cost!==null&&r.used>0?number(r.cost/r.used,2):'—'} <small>${S.currency==='CNY'?'CNY':'币种未知'}/网侧kWh</small></b></div>`:''}<p class="chart-note">${r.cost===0?'费用明确记录为0；保留真实零值。':r.cost===null?'这次费用未记录，不代表免费。':'按已记录总费用展示；未提供电费、服务费和停车费拆分。'} 站点币种${S.currency==='CNY'?'已选CNY':'未配置'}。</p></div></section>`;}
function detailBody(variant){
  const r=picked();if(!r)return `<div class="empty">${icon('bolt',40)}<h3>还没有可查看的充电</h3><p>从左侧更换区间，或查看其他数据状态。</p></div>`;
  const title=`${notices()}<h1 class="detail-title">${r.place.name}</h1><div class="detail-meta"><span class="badge ${r.type==='DC'?'dc':r.type==='未知'?'unknown':''}">${r.type}</span><span>${dateOf(r.start)} ${hourOf(r.start)}—${r.end?(dayOf(r.end)!==dayOf(r.start)?'次日 ':'')+hourOf(r.end):'进行中'}</span></div>
    <div class="detail-result"><div><span class="eyebrow">${r.active?'截至19:10已补入':'补入电池'}</span><strong>${number(r.added)}<small>kWh</small></strong></div><div class="side"><b>${money(r.cost)}</b><span class="eyebrow">${duration(r.duration)} · ${r.active?'尚非最终结果':'已结束'}</span></div></div><div class="detail-soc">${soc(r,true)}</div>`;
  const extras=`${energySides(r)}${costDetail(r)}<section class="section">${heading('车辆与环境',info('environment','如何解读 ⓘ'))}<div class="context-grid"><div class="context-item"><span>室外温度 · 记录均值</span><b>${number(r.outsideTemp)} <small>°C</small></b></div><div class="context-item"><span>充电方式 / 记录相数</span><b>${r.type} <small>${r.phases===null?'相数未提供':r.phases+'相'}</small></b></div>${full()?`<div class="context-item"><span>额定续航起止</span><b>${Math.round(r.socStart*4.56)} → ${r.socEnd!==null?Math.round(r.socEnd*4.56):'—'} <small>km</small></b></div><div class="context-item"><span>记录充电器品牌</span><b>${r.type==='DC'?'Tesla':'—'} <small>${r.type==='DC'?'原始字段':'未记录'}</small></b></div>`:''}</div><p class="chart-note">续航为额定口径；${full()?'变化不等于实际可行驶距离。 ':''}温度与加热状态可与功率共时查看，不能据此计算各自耗能。</p></section><details class="raw"><summary>记录明细与计算说明</summary><p>充电 #${r.id} · Asia/Shanghai<br>开始：2026年${dateOf(r.start)} ${hourOf(r.start)}<br>结束：${r.end?'2026年'+dateOf(r.end)+' '+hourOf(r.end):'尚未结束'}<br>地点：${r.place.name}<br>此页全部为固定合成样例。${full()?'峰值、均值、20–80用时及扩展序列是待新增接口的返回示意。':'当前契约仅提供功率/电量序列、两侧能量与已有明细。'} 不从图上采样重新积分或估算损耗。</p></details>`;
  const chart=curve(r)+processSummary(r);
  if(variant==='B')return title+chargingWindow(r)+chart+extras;
  if(variant==='C')return title+(full()?`${locationMap(r.place.id)}<p class="chart-note">${button('查看这个地点的历史','place',`data-value="${r.place.id}"`)} · 只属于自己的记录。</p>`:'')+chart+chargingWindow(r)+extras;
  return title+chart+chargingWindow(r)+extras;
}
function device(screen,variant=S.variant){return `<div class="device"><div class="device-label"><b>${screen==='list'?'充电主页':'单次回顾'}</b><span>${screen==='list'?variants[variant].tag:'结果 → 过程 → 账目'}</span></div><div class="phone" data-variant="${variant}"><div class="scroll" data-scroll="${screen}-${variant}">${appHeader(screen==='detail')}<main class="content ${screen==='detail'?'detail-content':''}">${screen==='list'?listBody(variant):detailBody(variant)}</main>${S.full&&S.export&&screen==='list'?nav():''}</div>${screen==='list'&&!(S.full&&S.export)?nav():''}</div></div>`;}
function selectControl(label,name,options,value){return `<label class="control">${label}<select data-control="${name}" aria-label="${label}">${options.map(([v,n])=>`<option value="${v}" ${String(value)===v?'selected':''}>${n}</option>`).join('')}</select></label>`;}
function studio(){return `<div class="studio"><aside class="review"><div class="brand">${icon('leaf',30)}行笺 <small>MILEAF</small></div><p class="kicker">CHARGING / DESIGN REVIEW</p><h1>让每一次补能，<br>都有一笔明白账。</h1><p class="intro">同一套「湖畔」视觉，三种内容优先级。先看钱、电与时间，再追到地点和过程。</p><div class="directions">${Object.entries(variants).map(([k,v])=>button(`<b>${k}</b><span>${v.name}${k==='A'?'<em>推荐</em>':''}<small>${v.tag}</small></span>`,'variant',`data-value="${k}"`,S.variant===k?'selected':'')).join('')}</div><p class="reason">${variants[S.variant].reason}</p><div class="controls">${selectControl('能力范围','mode',[['vision','完整方案 · 含待补接口'],['existing','仅现有冻结接口']],S.mode)}${selectControl('数据状态','data',[['normal','正常记录'],['missing','部分缺失'],['empty','本期无记录'],['ongoing','正在充电'],['stale','旧快照 / 更新失败'],['statsfail','仅期间统计失败'],['seriesfail','仅过程曲线失败']],S.data)}<div class="control-pair">${selectControl('外观','theme',[['light','湖畔 · 浅色'],['dark','湖畔 · 深色']],S.theme)}${selectControl('字号','size',[['100','100%'],['200','200%']],S.size)}</div>${selectControl('站点币种标签','currency',[['CNY','已选择 CNY'],['none','未配置']],S.currency)}</div><div class="boundary"><b>${full()?'完整方案：评审产品目标':'现有接口：评审可先做的部分'}</b><p>${full()?'地点汇总、费用覆盖、时长、筛选和过程分析需要后端补充；不能据此宣称已经实现。':'费用/电量日桶可用；记录按开始日、统计按结束日。暂无全局搜索、地点排行和原始峰值。'}</p><p>固定合成记录 · 无站点请求 · 无真实底图。正式Flutter页面保持原样。</p></div><div class="review-links"><a href="?compare=1&mode=${S.mode}">三个方向并排 ↗</a><a href="renders/index.html">原型图册 ↗</a><a href="README.md">操作与能力边界 ↗</a></div><p class="review-state">当前：${S.variant} / ${S.mode} / ${S.data} / ${S.theme} / ${S.size}%<br>时钟：2026.10.27 19:10 · Asia/Shanghai</p></aside><section class="canvas"><div class="canvas-head"><div><p class="kicker">${S.compare?'THREE PRIORITIES / 同一份数据':'A CHARGING STORY / 从总览进入每一次充电'}</p><h2>${S.compare?'三种入口，哪一种更像你的日常？':S.variant+' · '+variants[S.variant].name}</h2></div><span>设计原型 · 合成数据 · ${full()?'完整方案':'现有接口'}</span></div><div class="devices">${S.compare?['A','B','C'].map(v=>device('list',v)).join(''):device('list')+device('detail')}</div><p class="footer-note">${full()?'完整方案中的新增能力均有TeslaMate原始数据依据，接口需求尚待实现。':'当前输入不会伪装成完整地点统计或费用覆盖。'}<br>原型用于评审结构与交互，不代表正式App、真实站点、底图或真机验收。</p></section></div><div class="switcher">${button('←','cycle','data-value="-1" aria-label="上一个方向"','')}<span><b>${S.variant} · ${variants[S.variant].name}</b> / 3</span>${button('→','cycle','data-value="1" aria-label="下一个方向"','')}</div>`;}
const helpText={
  cost:['费用要看得明白','总费用只累加已知费用，0表示明确记录为0，未知显示—。每入电kWh费用=已知费用合计÷同一批费用已知记录的入电量，不平均各次均价。它可能包含服务费等，不能直接称电价。完整方案还要求返回已知次数、对应电量和有效分母；它们目前不在冻结API内。币种是用户选择的站点显示标签，不换汇。'],
  period:['这段时间怎样统计','近30个本地日历日为9月28日00:00到10月27日19:10；近7日为10月21日00:00起。完成统计按结束时间归期，进行中另列。跨夜会话完整归入结束日，不拆分能量到各小时。'],
  boundary:['跨夜充电属于哪一天','例如10月25日23:10到26日03:30：当前列表按开始日查到25日，统计计在26日。现有接口模式只读日图，不把它接成错误的日筛选。完整方案要求新增 time_basis=ended_at 与一致的筛选统计；旧默认行为保持。'],
  classification:['AC、DC与未知','AC/DC沿用服务端分类，未知不会归入AC。DC占比的分母是AC+DC已知分类能量。两条能量条使用相同kWh尺度，不强制合成100%。完整方案显式返回未知能量及分类覆盖；不会用“总量减AC/DC”在客户端补一个新字段。'],
  sampling:['看过程，也保留记录的边界','这是时间定位的采样曲线，0保留、null断线，孤立有效点保留。完整方案的原始峰值、时间加权均值和区间用时由服务端基于原始charges计算；不能把手机拿到的200个点当成原始极值或积分依据。按SOC查看仍保留原始时间顺序，重复SOC不合并成一个点。'],
  time:['记录时长不等于等待时间','记录充电时长来自TeslaMate的duration_min，是采样开始到结束的记录跨度；这里没有排队、插枪到拔枪或人等待的完整时长。所有记录时长都是单车会话相加，不意味着一个人实际花了相同时间等待。平均功率需按原始相邻时段加权并返回有效覆盖。'],
  window:['20%到80%是历史记录用时','主例首次有效SOC达到20%为13:13，达到80%为13:41，共28分钟；不对采样做插值。后端需要原始charges、阈值跨越规则、最大允许间隔和有效覆盖。未覆盖两个阈值、倒退/断采不满足规则、进行中都不给确定结果。它不是车型标准成绩，也不是未来充电倒计时。'],
  energy:['两侧能量，各有含义','充入电池和电网侧估算不能相加。TeslaMate的网侧能量由记录功率，或电压、电流与相数结合时间计算，不是充电运营商电表账单。当前先并列展示，不据此宣传精确损耗率、健康度或硬件效率。'],
  places:['只比较自己的历史','地点身份来自稳定围栏ID、地址ID或未定位，不靠同名合并。“家”来自此合成样例已有的围栏名，不自动把所有AC叫家充。均价需要对应费用覆盖；不同SOC、温度、方式和服务费使地点不能直接排名成“最划算”或“最快”。'],
  habits:['时间与电量区间，帮助回顾习惯','夜间定义18:00至次日06:00，只统计会话开始时刻；没有分时电价就不称谷电。电量起止条共享0–100%尺度，是端点区间，不是充电过程。没有按SOC到100%判定电池损伤或建议通用的充电上限。'],
  environment:['能观察共时变化，不能自动解释原因','TeslaMate记录室外温度、加热开关、部分充电器信息；不提供电池包温度、加热耗电量、运营商实时桩位或排队。品牌读取原始字段，DC本身不表示Tesla超充。额定续航有自己的口径，不等于实际可达里程。'],
  dates:['日期选择的正式行为','正式方案保留含首尾的本地日期选择；今天截到当前时刻、禁止未来。此原型只演示近30日与近7日两套固定窗口；自定义日历未实现。统计超过730日时保留记录入口，按能力提示，不强加列表上限。'],
  vehicle:['当前评审车辆','此原型使用一辆固定的合成测试车。正式产品沿用既有车辆切换、会话隔离和币种设置；本轮不重新设计它们。'],
  nav:['保持现有四个主入口','本轮只评审充电主页、记录与单次回顾。统计页继续承接长区间和多粒度分析；概览继续展示简短补能近况。不新增独立站点控制或车辆控制入口。'],
};
function helpSheet(){if(!S.help)return '';const [title,body]=helpText[S.help]||helpText.nav;return `<div class="sheet-shade" data-action="close-help"><section class="sheet" role="dialog" aria-modal="true" aria-labelledby="help-title"><h2 id="help-title">${title}</h2><p>${body}</p>${button('知道了','close-help')}</section></div>`;}
function syncURL(){const url=new URL(location.href);for(const k of ['variant','mode','theme','size','data','currency'])url.searchParams.set(k,S[k]);url.searchParams.set('period',String(S.period));if(S.compare)url.searchParams.set('compare','1');else url.searchParams.delete('compare');history.replaceState(null,'',url);}
function render(preserve=true){
  const focusedChart=preserve?document.activeElement?.closest?.('[data-chart]')?.dataset.chart:null;
  const old={};if(preserve)document.querySelectorAll('[data-scroll]').forEach(el=>old[el.dataset.scroll]=el.scrollTop);
  document.body.className=[S.theme==='dark'?'dark':'',S.size==='200'?'large':'',S.compare?'compare':'',S.export?'export':'',S.full?'full':''].join(' ');
  document.getElementById('app').innerHTML=(S.export?device(S.screen):studio())+helpSheet();
  if(preserve&&typeof requestAnimationFrame==='function')requestAnimationFrame(()=>{document.querySelectorAll('[data-scroll]').forEach(el=>{el.scrollTop=old[el.dataset.scroll]||0;});if(focusedChart)document.querySelector(`[data-chart="${focusedChart}"]`)?.focus({preventScroll:true});});
}
function setVariant(v){S.variant=v;S.compare=false;S.focus='main';S.place=null;S.dayFilter=null;S.search='';S.type='all';syncURL();render(false);}
function clickAction(el){
  const phoneVariant=el.closest?.('.phone')?.dataset.variant;
  if(S.compare&&phoneVariant){S.variant=phoneVariant;S.compare=false;syncURL();}
  const a=el.dataset.action,v=el.dataset.value;
  if(a==='variant'){setVariant(v);return;}
  if(a==='cycle'){const keys=['A','B','C'];setVariant(keys[(keys.indexOf(S.variant)+Number(v)+3)%3]);return;}
  if(a==='help'){S.help=el.dataset.key;render();return;}
  if(a==='close-help'){S.help=null;render();return;}
  if(a==='period'){S.period=Number(v);S.place=null;S.dayFilter=null;S.search='';S.type='all';S.loaded=6;S.day=27;syncURL();render(false);return;}
  if(a==='day'){S.day=Number(v);render();return;}
  if(a==='point'){S.point=Number(v);render();return;}
  if(a==='metric'){S.metric=v;render();return;}
  if(a==='curve'){S.curve=v;render();return;}
  if(a==='axis'){S.axis=v;render();return;}
  if(a==='record'){
    S.record=Number(el.dataset.id);S.point=7;
    if(S.export){S.screen='detail';render(false);return;}
    if(S.compare){S.compare=false;syncURL();render(false);return;}
    render();if(typeof requestAnimationFrame==='function')requestAnimationFrame(()=>{const el=document.querySelector('[data-scroll="detail-'+S.variant+'"]');if(el){el.scrollTop=0;if(innerWidth<740)el.closest('.device').scrollIntoView({behavior:'smooth',block:'start'});}});return;
  }
  if(a==='map-place'&&!full()){const r=records().slice(0,S.loaded).find(r=>r.place.id===v);if(r)clickAction({dataset:{action:'record',id:r.id}});return;}
  if(a==='place'||a==='map-place'){S.place=v;S.focus='records';S.dayFilter=null;S.search='';S.type='all';S.loaded=6;if(S.export)S.screen='list';render(false);return;}
  if(a==='locations'){setVariant('C');return;}
  if(a==='records'){S.focus='records';S.loaded=6;render(false);return;}
  if(a==='day-records'){if(!full()){S.help='boundary';render();return;}S.focus='records';S.dayFilter=S.day;S.loaded=6;render(false);return;}
  if(a==='type'){S.type=v;S.loaded=6;render();return;}
  if(a==='more'){S.loaded+=6;render();return;}
  if(a==='clear'){S.place=null;S.dayFilter=null;S.search='';S.type='all';S.sort='date';S.loaded=6;render();return;}
  if(a==='main'||a==='back'){S.focus='main';S.place=null;S.dayFilter=null;S.search='';S.type='all';if(S.export)S.screen='list';render(false);return;}
  if(a==='refresh'||a==='reset'){S.data='normal';if(a==='reset')S.period=30;S.record=301;syncURL();render();}
}
document.addEventListener('click',e=>{const target=e.target.closest('[data-action]');if(!target)return;if(e.target.closest('.sheet')&&target.classList.contains('sheet-shade'))return;clickAction(target);});
document.addEventListener('change',e=>{const key=e.target.dataset.control;if(!key)return;S[key]=e.target.value;if(key==='mode'||key==='data'){S.focus='main';S.place=null;S.search='';S.type='all';S.sort='date';S.dayFilter=null;S.axis='time';S.curve='power';S.record=S.data==='ongoing'?302:301;}syncURL();render(false);});
document.addEventListener('submit',e=>{if(e.target.id!=='charge-search')return;e.preventDefault();S.search=e.target.elements.place.value.trim();S.loaded=6;render();});
document.addEventListener('keydown',e=>{
  if(e.key==='Escape'&&S.help){S.help=null;render();return;}
  if(e.key==='Enter'&&e.target.matches('[role="button"]')){e.preventDefault();const target=e.target.closest('[data-action]');if(target)clickAction(target);return;}
  if(!['ArrowLeft','ArrowRight'].includes(e.key)||e.target.closest('input,textarea,select,[contenteditable]'))return;
  const step=e.key==='ArrowRight'?1:-1,chart=e.target.closest('[data-chart]');e.preventDefault();
  if(chart){if(chart.dataset.chart==='curve'){const n=chargeSamples(picked()||CHARGE_RECORDS[0]).length;S.point=Math.min(Math.max(S.point+step,0),n-1);}else S.day=Math.min(27,Math.max(S.period===7?21:-2,S.day+step));render();return;}
  clickAction({dataset:{action:'cycle',value:step}});
});
document.addEventListener('pointermove',e=>{
  if(e.buttons!==1)return;const chart=e.target.closest('[data-chart="curve"]');if(!chart)return;const r=picked();if(!r)return;
  const box=chart.getBoundingClientRect(),fraction=Math.max(0,Math.min(1,(e.clientX-box.left-box.width*31/314)/(box.width*270/314))),points=chargeSamples(r,S.data==='missing');
  const maximum=S.axis==='soc'?100:r.active?20:r.duration,value=fraction*maximum;
  let index=0,delta=Infinity;points.forEach((p,i)=>{const v=S.axis==='soc'?p.soc:p.minute;if(v!==null&&Math.abs(v-value)<delta){index=i;delta=Math.abs(v-value);}});
  if(index!==S.point){S.point=index;render();}
});
render(false);

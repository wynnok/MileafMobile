// THROWAWAY UI study: three structures on one document, ?variant=A|B|C.
// Lives under docs, outside Flutter assets/routes. No product runtime or writes.
const params=new URLSearchParams(location.search);
const variants={A:{name:'出行回顾',lead:'先想起一段路，再读懂每一次出发。',reason:'适合日常打开。地点识别、出行节奏与能耗结果有明确顺序。'},B:{name:'能耗透镜',lead:'这趟用了多少电，放在什么背景里看？',reason:'适合深入看数据。先比较消耗，再沿时间线查看过程。'},C:{name:'路线足迹',lead:'从去过的地方，找回一段出行。',reason:'适合回忆与探索。现阶段只画本页端点；路线档案需要扩展能力。'}};
const valid=(key,values,fallback)=>values.includes(params.get(key))?params.get(key):fallback;
const state={variant:valid('variant',['A','B','C'],'A'),theme:valid('theme',['light','dark'],'light'),
  font:valid('font',['100','200'],'100'),scope:valid('scope',['current','future'],'current'),
  scene:valid('scene',['normal','missing','empty','ongoing','stale','mapfail'],'normal'),
  period:valid('period',['7','30'],'30'),screen:valid('screen',['list','detail'],'list'),
  id:Number(params.get('id'))||1,loaded:6,day:'',chartDay:29,point:7,metric:'speed',paired:false,
  route:'',search:'',sheet:'',capture:params.get('export')==='1',full:params.get('full')==='1',compare:params.get('compare')==='1'};
const app=document.getElementById('app');
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const number=(v,places=0)=>v==null?'—':Number(v).toLocaleString('en-US',{minimumFractionDigits:places,maximumFractionDigits:places});
const referenceDates=trip=>{const end=new Date(trip.date+'T00:00:00Z'),start=new Date(end);start.setUTCDate(start.getUTCDate()-30);end.setUTCDate(end.getUTCDate()-1);const short=d=>(d.getUTCMonth()+1)+'/'+d.getUTCDate();return short(start)+'—'+short(end);};
const dateLabel=date=>`${Number(date.slice(5,7))}月${Number(date.slice(8))}日`;
const iconPaths={leaf:'M12 3c2 3 3 5 3 7a3 3 0 0 1-6 0c0-2 1-4 3-7ZM4 11c5 0 8 3 8 9-5 0-8-3-8-9Zm16 0c-5 0-8 3-8 9 5 0 8-3 8-9Z',back:'m14 5-7 7 7 7M7 12h14',next:'m10 5 7 7-7 7',calendar:'M5 5h14v15H5zM8 2v6m8-6v6M5 10h14',home:'m3 11 9-8 9 8M6 10v11h12V10M10 21v-7h4v7',car:'m5 6-2 8v5h3v-3h12v3h3v-5l-2-8ZM4 12h16M7 14h1m8 0h1',bolt:'m13 2-9 12h7l-1 8 10-13h-7z',chart:'M4 20V9h3v11m4 0V3h3v17m4 0v-7h3v7',pin:'M19 10c0 5-7 11-7 11S5 15 5 10a7 7 0 0 1 14 0ZM12 7a3 3 0 1 0 0 6 3 3 0 0 0 0-6Z',info:'M12 8h.01M12 11v6M22 12a10 10 0 1 1-20 0 10 10 0 0 1 20 0Z',refresh:'M20 8a9 9 0 1 0 0 9M20 3v6h-6',clock:'M12 7v6l4 2M22 12a10 10 0 1 1-20 0 10 10 0 0 1 20 0Z',route:'M5 5a2 2 0 1 0 0 .01M19 19a2 2 0 1 0 0 .01M7 5h7a4 4 0 0 1 0 8h-4a4 4 0 0 0 0 8h7',close:'m6 6 12 12M6 18 18 6',sun:'M12 2v2m0 16v2M2 12h2m16 0h2M5 5l2 2m10 10 2 2M5 19l2-2M17 7l2-2M17 12a5 5 0 1 1-10 0 5 5 0 0 1 10 0Z'};
const icon=(name,size=20)=>`<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="${iconPaths[name]||iconPaths.info}"/></svg>`;
const button=(label,action,extra='',cls='')=>`<button type="button" class="${cls}" data-action="${action}" ${extra}>${label}</button>`;
const pill=(text,cls='')=>`<span class="pill ${cls}">${text}</span>`;
const metric=(label,value,unit='',extra='')=>`<div class="metric"><span>${label}</span><div><strong>${value}</strong><small>${unit}</small></div>${extra?`<p>${extra}</p>`:''}</div>`;
function navigation(){return `<nav class="app-nav" aria-label="主导航">${[['home','概览'],['car','行程'],['bolt','充电'],['chart','统计']].map(([i,t])=>button(`${icon(i)}<span>${t}</span>`,t==='行程'?'list':'nav',`data-name="${t}"`,t==='行程'?'active':'')).join('')}</nav>`;}
function header(detail=false){return `<header class="app-header">${detail?button(icon('back'),'list','aria-label="返回行程列表"','icon-button'):`<div class="wordmark">${icon('leaf',24)}<b>行笺</b></div>`}<span class="header-context">${detail?'行程详情':'我的 Model Y'}</span>${button(icon(detail?'info':'calendar'),detail?'definitions':'dates',`aria-label="${detail?'指标口径':'选择日期'}"`,'icon-button')}</header>`;}
function staleBanner(){return state.scene==='stale'?`<div class="notice">保留 10/27 09:10 的记录 · 刷新未成功${button('重试','retry')}</div>`:'';}
function periodControls(){return `<div class="period-line"><div class="segmented">${['30','7'].map(p=>button(p==='30'?'近30日':'近7日','period',`data-period="${p}" aria-pressed="${state.period===p}"`,state.period===p?'selected':'')).join('')}</div>${button(`${icon('calendar',16)} 自定义`,'dates','','text-button')}</div>`;}
function rangeCaption(){return state.period==='7'?'10.21 — 10.27':'9.28 — 10.27';}
function contextCaption(){return `<p class="micro range-caption">${rangeCaption()} · 已完成行程${button(icon('info',15),'period-help','aria-label="期间统计说明"','inline-icon')}</p>`;}
function sparkChart(stats,kind='km'){
  const buckets=stats.buckets,selected=Math.min(state.chartDay,buckets.length-1),values=buckets.map(b=>b[kind]);
  const min=Math.min(0,...values.filter(v=>v!=null)),max=Math.max(kind==='wh'?220:100,...values.filter(v=>v!=null)),w=300,h=82,left=7,right=284,top=8,bottom=64;
  const x=i=>left+(i+.5)*(right-left)/buckets.length,y=v=>bottom-(v-min)/(max-min)*(bottom-top),zero=y(0),bar=(right-left)/buckets.length*.58;
  const ticks=[0,Math.floor(buckets.length/2),buckets.length-1];
  let lines='',segment=[];
  const flush=()=>{if(segment.length){lines+=`<polyline points="${segment.join(' ')}" fill="none" stroke="var(--green)" stroke-width="2"/>`;segment=[];}};
  values.forEach((v,i)=>{if(v==null)flush();else segment.push(`${x(i)},${y(v)}`);});flush();
  const plot=kind==='km'?values.map((v,i)=>v==null?'':`<rect x="${x(i)-bar/2}" y="${Math.min(zero,y(v))}" width="${bar}" height="${Math.max(1,Math.abs(zero-y(v)))}" rx="2" fill="${i===selected?'var(--green)':'var(--bar)'}"/>`).join(''):lines+values.map((v,i)=>v==null?'':`<circle cx="${x(i)}" cy="${y(v)}" r="${i===selected?4:2}" fill="var(--green)"/>`).join('');
  const b=buckets[selected];
  return `<div class="rhythm"><div class="section-line"><b>${kind==='km'?'出行节奏':'每日电耗'}</b><span class="micro">${kind==='km'?'km':'Wh/km'}</span></div><svg class="day-plot" data-day-chart="1" viewBox="0 0 ${w} ${h}" role="img" aria-label="${kind==='km'?'每日里程':'每日电耗'}，下方可逐日读取"><line x1="${left}" x2="${right}" y1="${zero}" y2="${zero}" stroke="var(--line)"/><text x="290" y="12" class="axis" text-anchor="end">${max}</text>${plot}<line x1="${x(selected)}" x2="${x(selected)}" y1="8" y2="64" stroke="var(--orange)" stroke-dasharray="3 3"/>${ticks.map(i=>`<text x="${x(i)}" y="80" class="axis" text-anchor="${i===0?'start':i===buckets.length-1?'end':'middle'}">${buckets[i].date.slice(5).replace('-','/')}</text>`).join('')}</svg><div class="day-reader">${button('‹','day-prev','aria-label="前一天"','reader-button')}<span>${dateLabel(b.date)} <b>${number(b[kind],kind==='km'?1:0)}</b> ${kind==='km'?'km':'Wh/km'}</span>${button('›','day-next','aria-label="后一天"','reader-button')}${button('看当天','open-day',`data-date="${b.date}"`,'text-button')}</div></div>`;
}
function summary(stats,variant){
  if(variant==='B')return `<section class="energy-hero"><div class="eyebrow">这段时间的估算净电耗</div><div class="hero-number">${number(stats.wh)}<small>Wh/km</small></div><div class="hero-sub">${number(stats.km,1)} km <span>·</span> ${stats.count} 次 <span>·</span> ${number(stats.energy,2)} kWh</div>${contextCaption()}</section>`;
  return `<section class="period-summary"><div class="eyebrow">这段时间，开了</div><div class="hero-number">${number(stats.km,1)}<small>km</small></div><div class="hero-sub"><b>${stats.count}</b> 次行程 <span>·</span> 估算消耗 <b>${number(stats.energy,2)}</b> kWh</div>${contextCaption()}</section>`;
}
function tripButton(trip,index,variant){
  const active=state.id===trip.id,unfinished=trip.ongoing;
  if(variant==='B'){
    const pct=trip.wh==null?0:Math.min(100,trip.wh/250*100);
    return button(`<div class="trip-top"><span>${dateLabel(trip.date)} · ${trip.start}</span>${unfinished?pill('进行中'):''}<span class="wh-number">${unfinished?'—':number(trip.wh)}<small> Wh/km</small></span></div><div class="trip-route">${trip.from}<span> → </span>${trip.to}</div><div class="energy-bar"><i style="width:${unfinished?0:pct}%"></i></div><div class="trip-bottom"><span>${unfinished?'结果待完成':number(trip.km,1)+' km · '+trip.min+' 分钟'}</span><span>${unfinished?'—':number(trip.kwh,2)} kWh</span></div>`,'trip',`data-id="${trip.id}" aria-label="${dateLabel(trip.date)} ${trip.from}到${trip.to}，查看详情"`,'energy-record '+(active?'chosen':''));
  }
  return button(`<div class="trip-top"><span>${variant==='C'?`<b class="marker-number">${index+1}</b> `:''}${trip.start}${unfinished?'':' — '+trip.end}</span>${unfinished?pill('进行中'):''}${active?'<span class="selected-word">正在查看</span>':icon('next',14)}</div><div class="trip-route">${trip.from}<span> → </span>${trip.to}</div><div class="trip-results"><strong>${unfinished?'—':number(trip.km,1)}<small> km</small></strong><span>${unfinished?'时长待完成':trip.min+' 分钟'}</span><span>${unfinished?'能量待完成':number(trip.kwh,2)+' kWh'}</span></div><div class="trip-bottom"><span>估算净电耗 <b>${unfinished?'—':number(trip.wh)}</b> Wh/km</span>${trip.id===4?pill('地点回顾','subtle'):''}</div>`,'trip',`data-id="${trip.id}"`,'trip-card '+(active?'chosen':''));
}
const mapBase=()=>`<rect width="320" height="180" fill="var(--map)"/><path d="M212-20c-14 48-45 66-36 106s-6 68-28 110h42c15-38 29-60 17-98s14-63 36-118Z" fill="var(--water)"/><g fill="var(--park)"><path d="M19 27h76v43H19zM223 108h70v51h-70zM85 150h48v45H85z"/></g><g stroke="var(--road)" fill="none" stroke-width="8"><path d="M-5 37 325 154M-8 120 115 82 324 51M49-5l8 190M260-5 238 184M101-8l56 196"/></g><g stroke="var(--map)" stroke-width="4" fill="none"><path d="M-5 37 325 154M-8 120 115 82 324 51M49-5l8 190M260-5 238 184M101-8l56 196"/></g><g class="map-label"><text x="22" y="58">城西</text><text x="244" y="137">滨江</text><text x="132" y="40">湖畔</text></g>`;
function endpointMap(records){
  const visible=records,groups=new Map();
  visible.forEach((r,i)=>{const key=r.endPoint.join(',');if(!groups.has(key))groups.set(key,{point:r.endPoint,numbers:[]});groups.get(key).numbers.push(i+1);});
  return `<section class="endpoint-map"><svg viewBox="0 0 320 180" role="img" aria-label="本页${visible.length}条起终点关系示意，不是行车轨迹">${mapBase()}${visible.map(r=>`<path d="M${r.startPoint.join(' ')}L${r.endPoint.join(' ')}" stroke="var(--green)" opacity=".4" stroke-width="1.5" stroke-dasharray="4 4"/><circle cx="${r.startPoint[0]}" cy="${r.startPoint[1]}" r="4" fill="var(--surface)" stroke="var(--green)" stroke-width="2"/>`).join('')}${[...groups.values()].map(g=>`<g role="button" tabindex="0" data-map-trip="1" data-action="trip" data-id="${visible[g.numbers[0]-1].id}" aria-label="查看本页到此最近行程，第${g.numbers[0]}条"><rect x="${g.point[0]-14}" y="${g.point[1]-11}" width="28" height="22" rx="10" fill="var(--green)"/><text x="${g.point[0]}" y="${g.point[1]+4}" text-anchor="middle" fill="var(--on-green)" font-size="10">${g.numbers.length>2?g.numbers[0]+'+'+(g.numbers.length-1):g.numbers.join(',')}</text></g>`).join('')}</svg><div class="map-caption"><span>本页端点 · ${visible.length}条</span><span>连线非行车轨迹</span></div></section>`;
}
function routePreview(){return `<section class="future-route"><div class="section-line"><div><span class="eyebrow">能力预览</span><h3>常走的那条路</h3></div>${icon('route',26)}</div><p>家 <span>→</span> 滨江园区</p><div class="mini-comparison"><span>同向历史参照</span><b>156 <small>Wh/km</small></b></div><div class="distribution"><i></i><b></b></div><div class="trip-bottom"><span>8次有效样本 · 中位数</span><span>142 — 181 Wh/km</span></div>${button('查看本期同起终点记录 →','route','','text-button')}</section>`;}
function emptyList(){return `<div class="empty-state">${icon('route',42)}<h3>这段时间，还没有行程</h3><p>换个日期，再找找想回看的那段路。</p>${button('选择日期','dates','','solid-button')}</div>`;}
function listPage(variant){
  const records=recordsFor(state),stats=statsFixture(state,records),filtered=records.filter(r=>!state.day||r.date===state.day),visible=filtered.slice(0,state.loaded);
  let previous='';
  const rows=visible.map((r,i)=>{const group=variant!=='B'&&previous!==r.date?`<div class="date-heading">${dateLabel(r.date)}<span>${new Date(r.date+'T12:00:00+08:00').toLocaleDateString('zh-CN',{weekday:'long',timeZone:'Asia/Shanghai'})}</span></div>`:'';previous=r.date;return group+tripButton(r,i,variant);}).join('');
  return `${header()}<main class="page-content list-page">${staleBanner()}<div class="title-line"><h1>行程</h1><span class="micro">${variant==='A'?'每一次出发':variant==='B'?'每一度电':'每一处足迹'}</span></div>${periodControls()}${state.scope==='future'?`<form id="search-form" class="search-box">${icon('pin',16)}<input id="location-search" aria-label="搜索本期全部起终点" placeholder="搜索这段时间的起终点" value="${esc(state.search)}"><button type="submit" class="search-submit" aria-label="搜索行程">${icon('next',16)}</button></form>`:''}${summary(stats,variant)}${variant==='C'&&records.length?endpointMap(visible):records.length?sparkChart(stats,variant==='B'?'wh':'km'):''}${state.scope==='future'&&records.length?routePreview():''}<div class="section-line record-heading"><h2>${variant==='B'?'逐趟看耗电':state.day?dateLabel(state.day)+'的行程':'出行记录'}</h2><span class="micro">${variant==='B'?'已载入 '+visible.length+' 条 · 时间倒序':'按出发时间'}</span></div>${state.day||state.route||state.search?`<div class="filter-notice">${esc(state.day?dateLabel(state.day):state.route||state.search)}${button('清除筛选 ×','clear','','text-button')}</div>`:''}${records.length?(visible.length?rows:`<p class="empty-day">当天没有行程。${button('返回完整区间','clear','','text-button')}</p>`):emptyList()}${filtered.length>visible.length?button('加载更多行程','more','','more-button'):records.length?'<p class="end-caption">本查询的行程已全部显示</p>':''}<p class="data-caption">Asia/Shanghai · 截至 10/27 19:10</p></main>${navigation()}`;
}
function routeMap(trip,series){
  if(state.scene==='mapfail')return `<section class="map-unavailable">${icon('pin',28)}<b>地图暂时无法显示</b><p>行程结果和过程图仍可查看。</p>${button('重试地图','retry-map','','text-button')}</section>`;
  const selected=series[Math.min(state.point,series.length-1)],segments=[];let segment=[];
  for(const p of series){if(!p.coord){if(segment.length)segments.push(segment);segment=[];}else segment.push(p.coord.join(','));}if(segment.length)segments.push(segment);
  const first=series[0]?.coord,last=series[series.length-1]?.coord;
  return `<section class="route-map"><svg viewBox="0 0 320 180" role="img" aria-label="${trip.from}到${trip.to}的合成路线示意${selected?.coord?'，当前选中'+selected.time:'，选中点坐标缺失'}">${mapBase()}${segments.map(s=>`<polyline points="${s.join(' ')}" fill="none" stroke="var(--surface)" stroke-width="8" stroke-linejoin="round"/><polyline points="${s.join(' ')}" fill="none" stroke="var(--green)" stroke-width="4" stroke-linejoin="round"/>`).join('')}<circle cx="${first[0]}" cy="${first[1]}" r="7" fill="var(--surface)" stroke="var(--green)" stroke-width="3"/>${!trip.ongoing&&last?`<rect x="${last[0]-6}" y="${last[1]-6}" width="12" height="12" rx="3" fill="var(--green)" stroke="var(--surface)" stroke-width="2"/>`:''}${selected?.coord?`<circle cx="${selected.coord[0]}" cy="${selected.coord[1]}" r="12" fill="var(--green)" opacity=".15"/><circle cx="${selected.coord[0]}" cy="${selected.coord[1]}" r="5" fill="var(--orange)" stroke="var(--surface)" stroke-width="2"/>`:''}</svg><div class="map-overlay"><span>${selected?.coord?selected.time+' · 已选采样':'选中点无坐标'}</span><span>路线示意</span></div><div class="map-locations"><span><i class="origin-dot"></i>${trip.from}</span><span><i class="end-dot"></i>${trip.ongoing?'行程进行中':trip.to}</span></div></section>`;
}
function tripResults(trip){return `<section class="results-grid">${metric('行驶距离',trip.ongoing?'—':number(trip.km,1),'km')}${metric('行程时长',trip.ongoing?'—':trip.min,'分钟')}${metric('估算消耗',trip.ongoing?'—':number(trip.kwh,2),'kWh')}</section>`;}
function batteryBlock(trip){
  const end=trip.ongoing?null:trip.socEnd,known=trip.socStart!=null&&end!=null,down=known?trip.socStart-end:null;
  return `<section class="battery-block"><div class="section-line"><h3>出发与到达的电量</h3><span class="micro">${known?(down>=0?'下降 '+down:'增加 '+Math.abs(down))+' 个百分点':trip.ongoing?'行程进行中':'到达值缺失'}</span></div><div class="soc-values"><span><b>${number(trip.socStart)}<small>%</small></b> <em>出发</em></span><span><em>${trip.ongoing?'到达待记录':'到达'}</em> <b>${number(end)}<small>%</small></b></span></div><div class="soc-track" role="img" aria-label="电量0到100%尺度，出发${trip.socStart}%，到达${end??'未知'}"><i class="soc-remaining" style="width:${known?Math.min(end,trip.socStart):trip.socStart}%"></i>${known?`<i class="soc-used" style="left:${Math.min(end,trip.socStart)}%;width:${Math.abs(down)}%"></i>`:''}<b style="left:${trip.socStart}%"></b>${known?`<b style="left:${end}%"></b>`:''}</div><div class="soc-scale"><span>0%</span><span>100%</span></div></section>`;
}
function consumptionBlock(trip){
  const future=state.scope==='future',sameRoute=future&&trip.from==='家'&&trip.to==='滨江园区',ref=sameRoute?156:154;
  return `<section class="consumption-block"><div class="section-line"><h3>这趟的电耗</h3>${button(icon('info',17),'reference-help','aria-label="电耗参考依据"','inline-icon')}</div><div class="consumption-main"><strong>${trip.ongoing?'—':number(trip.wh)}<small>Wh/km</small></strong><span>估算净电耗</span></div>${!trip.ongoing&&trip.wh!=null?`<div class="compare-row"><span class="legend-dot"></span><span>本次</span><div class="compare-track"><i style="width:${trip.wh/250*100}%"></i></div><b>${number(trip.wh)}</b></div><div class="compare-row reference"><span class="legend-line"></span><span>参考</span><div class="compare-track"><i style="width:${ref/250*100}%"></i></div><b>${ref}</b></div><p class="micro">${sameRoute?'同起终点 · 同方向 · 8次有效样本中位数':'同车此前30日 · '+referenceDates(trip)+' · 全部路线'}</p>${sameRoute?'<p class="micro capability-note">能力预览 · 历史范围 142 — 181 Wh/km</p>':''}`:`<p class="micro">${trip.ongoing?'行程结束后再看完整结果与参照。':'本次估算缺失，暂不显示对照。'}</p>`}</section>`;
}
const chartMeta={speed:{name:'速度',unit:'km/h',min:0,max:100},battery:{name:'电量',unit:'%',min:0,max:100},elevation:{name:'海拔',unit:'m',min:0,max:50},power:{name:'功率',unit:'kW',min:-40,max:120}};
function sampleChart(series,kind,small=false){
  const m=chartMeta[kind],selected=Math.min(state.point,series.length-1),p=series[selected],left=34,right=292,top=19,bottom=small?91:128,height=small?112:151;
  const x=p=>left+p.fraction*(right-left),y=v=>bottom-(v-m.min)/(m.max-m.min)*(bottom-top);
  const segments=[];let segment=[];
  for(const point of series){if(point[kind]==null){if(segment.length)segments.push(segment);segment=[];}else segment.push(`${x(point)},${y(point[kind])}`);}if(segment.length)segments.push(segment);
  const tickValues=kind==='power'?[m.max,40,0,m.min]:[m.max,(m.max+m.min)/2,m.min];
  return `<div class="sample-chart ${small?'secondary-chart':''}"><div class="section-line"><span class="chart-label">${m.name}</span><span class="micro">${m.unit}</span></div><svg data-chart="${kind}" viewBox="0 0 308 ${height}" role="slider" tabindex="0" aria-label="${m.name}采样读数，左右方向键选择" aria-valuemin="0" aria-valuemax="${series.length-1}" aria-valuenow="${selected}" aria-valuetext="${p.time}，${p[kind]==null?'缺失':p[kind]+' '+m.unit}">${tickValues.map(v=>`<line x1="${left}" x2="${right}" y1="${y(v)}" y2="${y(v)}" stroke="var(--line)" ${v===0&&m.min<0?'stroke-width="1.5"':''}/><text x="26" y="${y(v)+4}" text-anchor="end" class="axis">${v}</text>`).join('')}${segments.map(s=>s.length===1?'':`<polyline points="${s.join(' ')}" fill="none" stroke="var(--green)" stroke-width="2.5" stroke-linejoin="round"/>`).join('')}${series.map((point,i)=>point[kind]==null?'':`<circle cx="${x(point)}" cy="${y(point[kind])}" r="${i===selected?4.5:1.8}" fill="${i===selected?'var(--orange)':'var(--green)'}"/>`).join('')}<line x1="${x(p)}" x2="${x(p)}" y1="${top}" y2="${bottom}" stroke="var(--orange)" stroke-dasharray="3 3"/>${[series[0],series[Math.floor(series.length/2)],series[series.length-1]].map((point,i)=>`<text x="${x(point)}" y="${height-3}" text-anchor="${i===0?'start':i===2?'end':'middle'}" class="axis">${point.time}</text>`).join('')}</svg></div>`;
}
function processBlock(trip,series,variant){
  const future=state.scope==='future',selected=Math.min(state.point,series.length-1),p=series[selected],metricName=chartMeta[state.metric];
  return `<section class="process-block"><div class="section-line"><h2>沿途的变化</h2>${button(icon('info',16),'series-help','aria-label="采样说明"','inline-icon')}</div><div class="metric-tabs">${['speed','battery','elevation',...(future?['power']:[])].map(k=>button(chartMeta[k].name,'metric',`data-metric="${k}" aria-pressed="${state.metric===k}"`,state.metric===k?'selected':'')).join('')}</div>${sampleChart(series,state.metric)}${state.paired&&state.metric!=='battery'?sampleChart(series,'battery',true):''}<div class="sample-reader" aria-live="polite"><div><span class="eyebrow">${p.time}</span><strong>${number(p[state.metric])}<small>${metricName.unit}</small></strong></div><div class="reader-actions">${button('‹','point-prev',`aria-label="前一个采样" ${selected===0?'disabled':''}`,'reader-button')}${button('›','point-next',`aria-label="后一个采样" ${selected===series.length-1?'disabled':''}`,'reader-button')}</div></div><div class="process-bottom"><span class="micro">采样示意 · 缺失处断开</span>${state.metric!=='battery'?button(state.paired?'收起电量对照':'对照电量','pair','','text-button'):''}</div>${future&&!trip.ongoing&&state.metric==='power'?'<div class="recovery-summary"><span>回收能量 <b>0.84 kWh</b></span><span>回收峰值 <b>32 kW</b></span></div><p class="micro">能力预览 · 回收量为独立合成聚合，非图中采样积分</p>':''}</section>`;
}
function contextBlock(trip){return `<section class="context-block"><div class="section-line"><h2>驾驶与环境</h2><span class="micro">这一次的背景</span></div><div class="context-grid">${metric('平均速度',trip.ongoing?'—':number(trip.avg,1),'km/h')}${metric('最高速度',number(trip.max),'km/h')}${metric('最大功率',number(trip.peak),'kW')}${metric('车外均温',number(trip.outside),'°C')}${metric('车内均温',number(trip.inside),'°C')}${metric('电耗口径','额定','续航差估算')}</div><p class="micro">温度是全程均值，不能据此判断耗电原因。</p></section>`;}
function futureDetails(trip){
  const stop=Math.round(trip.min*.2),low=Math.round(trip.min*.39),rest=trip.min-stop-low;
  return `<section class="future-details"><span class="eyebrow">能力预览</span><h2>路上，时间花在哪里</h2><p class="micro">以原始时间间隔聚合 · 不是采样点占比</p><div class="time-stack"><i style="width:20%"></i><i style="width:39%"></i><i style="width:41%"></i></div><div class="time-legend"><span>静止 <b>${stop}分</b><small>0 km/h</small></span><span>低速 <b>${low}分</b><small>&gt;0 且 ≤40 km/h</small></span><span>其余行驶 <b>${rest}分</b><small>&gt;40 km/h</small></span></div><div class="terrain-preview">${metric('累计爬升','148','m')}${metric('累计下降','132','m')}</div><p class="micro">静止并不等于拥堵，地形不代表能耗归因。</p></section>`;
}
function detailPage(variant){
  const records=recordsFor(state),trip=records.find(r=>r.id===state.id)||records[0];
  if(!trip)return `${header(true)}<main class="page-content">${emptyList()}</main>`;
  const series=seriesFor(trip,state.scene),map=routeMap(trip,series),results=tripResults(trip),battery=batteryBlock(trip),consumption=consumptionBlock(trip),process=processBlock(trip,series,variant),context=contextBlock(trip);
  const body=variant==='B'?consumption+results+battery+process+map+context:variant==='C'?map+`<div class="endpoint-times"><span>${trip.from} <b>${trip.start}</b></span><span>${trip.ongoing?'进行中':trip.to+' '+trip.end}</span></div>`+results+battery+consumption+process+context:map+results+battery+consumption+process+context;
  return `${header(true)}<main class="page-content detail-page detail-${variant}">${staleBanner()}<div class="detail-heading"><div class="eyebrow">${dateLabel(trip.date)} · ${trip.start}${trip.ongoing?' 起':' — '+trip.end}</div><h1>${trip.from}<span> → </span>${trip.to}</h1>${trip.ongoing?pill('进行中 · 最终结果待记录'):''}</div>${body}${state.scope==='future'&&!trip.ongoing?futureDetails(trip):''}<details class="raw-details"><summary>时间、地点与指标口径</summary><p>2026年${dateLabel(trip.date)} ${trip.start} — ${trip.ongoing?'进行中':trip.end}（Asia/Shanghai）</p><p>${trip.from} → ${trip.to}；合成地点，不是真实用户位置。</p><p>能量与净电耗依据额定续航差估算，不是电表计量。原始极值来自明细，图上为抽样读数。示意底图与坐标不作为地图验收。</p></details></main>`;
}
function device(screen,variant,label=''){
  return `<div class="device-column"><div class="device-label">${label||`${variant} · ${variants[variant].name}`}<span>${screen==='list'?'行程列表':'单次详情'}</span></div><div class="phone ${state.font==='200'?'large-type':''}" data-screen="${screen}"><div class="screen-scroll" data-scroll="${screen}-${variant}">${screen==='list'?listPage(variant):detailPage(variant)}</div>${screen==='detail'?'<div class="detail-home-indicator"></div>':''}</div></div>`;
}
function selectControl(label,name,values){return `<label class="control"><span>${label}</span><select data-control="${name}">${values.map(([v,t])=>`<option value="${v}" ${state[name]===v?'selected':''}>${t}</option>`).join('')}</select></label>`;}
function reviewPanel(){return `<aside class="review-panel"><a class="review-brand" href="?">${icon('leaf',28)}<b>行笺 <small>MILEAF</small></b></a><p class="review-kicker">PRODUCT STUDY / 2026.10.27</p><h1>让每一段路，<br>都读得明白。</h1><p class="review-intro">行程列表与详情再设计。<br>先确定车主的问题，再安排数据。</p><div class="direction-list">${Object.entries(variants).map(([key,v])=>button(`<span>${key}</span><div><b>${v.name}${key==='A'?'<em>推荐</em>':''}</b><small>${v.lead}</small></div>`,'variant',`data-variant="${key}" aria-pressed="${state.variant===key}"`,state.variant===key?'selected':'')).join('')}</div><p class="direction-reason">${variants[state.variant].reason}</p><div class="review-controls">${selectControl('能力范围','scope',[['current','现有接口可支持'],['future','扩展能力预览']])}${selectControl('数据状态','scene',[['normal','正常记录'],['missing','部分指标缺失'],['empty','本期无记录'],['ongoing','最新一趟进行中'],['stale','保留旧快照'],['mapfail','地图加载失败']])}<div class="control-pair">${selectControl('外观','theme',[['light','湖畔 · 浅'],['dark','湖畔 · 深']])}${selectControl('字号','font',[['100','100%'],['200','200%']])}</div></div><div class="review-boundary"><b>${state.scope==='current'?'现有 API 模式':'扩展能力预览'}</b><p>${state.scope==='current'?'输入可由冻结契约提供。新增页面、联动与统计查询仍是方案；原型没有接通服务。':'额外展示同路线样本、完整查询、功率/回收与速度时长分布；需要新增契约，不是已交付功能。'}</p><p>所有数字、路线与底图为合成示意。无真实站点、位置或外部地图请求。</p></div><div class="review-links"><a href="?compare=1">三个首屏并排 ↗</a><a href="?export=1&screen=list">单独打开手机页 ↗</a><a href="?export=1&screen=detail">单独打开行程详情 ↗</a></div></aside>`;}
function sheet(){
  if(!state.sheet)return '';
  const trip=recordsFor(state).find(r=>r.id===state.id),hasRoute=state.scope==='future'&&trip?.from==='家'&&trip?.to==='滨江园区';
  const content={
    definitions:['指标怎样读','kWh表示这趟的估算净能量，Wh/km表示单位里程的估算净电耗。电量端点差用百分点表达；两者不用于反推电池容量。最高速度与最大功率取明细值，不从图中找极值。'],
    'reference-help':['这个参考来自哪里',hasRoute?'同起终点组的8次同向有效历史样本中位数为156 Wh/km，范围142–181。仅为扩展能力示意；它不能证明路径、交通和气温相同。':'参考154 Wh/km为独立合成统计。正式建议取行程开始日前30个完整本地日的同车整体净电耗，包含全部路线，不含本次。路线、温度和估算覆盖不同，因此不评价驾驶好坏，也不推断原因。'],
    'period-help':['期间与记录','摘要与日图只统计已完成行程，按开始时间归期；列表保留进行中记录。原型统计来自完整合成数据集，独立于可见6条。正式实现必须请求stats，不从列表分页汇总。'],
    'series-help':['按时间查看采样','点按或拖动图中位置，地图会标出同一采样的坐标。左右按钮或图上方向键逐点读取。图中连线只为采样示意，缺失处断开；没有坐标的点不在地图上定位。温度现在只有均值。'],
    dates:['选择一个日期范围',`原型提供两组固定合成区间。正式页面保留现有自定义日期选择和本地日历转换。${button('近7日 · 10/21—10/27','period','data-period="7"','solid-button')}${button('近30日 · 9/28—10/27','period','data-period="30"','more-button')}`],
    nav:['本轮评审聚焦「行程」','概览、充电与统计沿用现有正式页面。本原型只演示行程的查找、结果、过程与下钻，不修改其他导航功能。']
  }[state.sheet]||['方案说明','这里是待评审的交互示意。'];
  return `<div class="sheet-backdrop"><section class="help-sheet" role="dialog" aria-modal="true" aria-labelledby="sheet-title"><div class="section-line"><h2 id="sheet-title">${content[0]}</h2>${button(icon('close'),'close','aria-label="关闭说明"','icon-button')}</div><div class="sheet-copy">${content[1]}</div>${button('明白了','close','','text-button')}</section></div>`;
}
function render(){
  const available=recordsFor(state);if(available.length&&!available.some(r=>r.id===state.id))state.id=available[0].id;
  const scrolls=Array.from(document.querySelectorAll('[data-scroll]')).map(el=>[el.dataset.scroll,el.scrollTop]);
  document.body.className=[state.theme==='dark'?'dark':'',state.capture?'capture':'',state.full?'full-page':'',state.compare?'compare-page':''].join(' ');
  if(state.capture){app.innerHTML=device(state.screen,state.variant)+sheet();}
  else app.innerHTML=`<div class="studio">${reviewPanel()}<section class="review-canvas"><header class="canvas-header"><div><span class="review-kicker">${state.compare?'THREE DIRECTIONS':'DESIGN REVIEW'}</span><h2>${state.compare?'相同的数据，三种阅读顺序':state.variant+' · '+variants[state.variant].name}</h2></div><span class="prototype-badge">方案原型 · 非正式 App</span></header><div class="devices ${state.compare?'three-devices':''}">${state.compare?Object.keys(variants).map(v=>device('list',v)).join(''):device('list',state.variant)+device('detail',state.variant)}</div><p class="canvas-footnote">${state.scope==='future'?'当前为扩展能力预览 · 需要后端新能力':'当前为现有接口模式 · 页面交互仍待实施'} · 湖畔视觉 · 固定合成数据 · 可滚动手机区域</p></section></div><div class="prototype-switcher" aria-label="原型方向切换">${button('←','previous-variant','aria-label="上一个方案"')}<span>${state.variant} <b>${variants[state.variant].name}</b></span>${button('→','next-variant','aria-label="下一个方案"')}</div>${sheet()}`;
  for(const [key,value] of scrolls){for(const el of document.querySelectorAll('[data-scroll]')){if(el.dataset.scroll===key)el.scrollTop=value;}}
}
function updateUrl(){const p=new URLSearchParams();for(const key of ['variant','scope','scene','theme','font','period','screen','id'])p.set(key,state[key]);if(state.capture)p.set('export','1');if(state.full)p.set('full','1');if(state.compare)p.set('compare','1');history.replaceState(null,'','?'+p.toString());}
function selectVariant(key){state.variant=key;state.metric='speed';state.sheet='';updateUrl();render();}
function cycleVariant(delta){const keys=Object.keys(variants);selectVariant(keys[(keys.indexOf(state.variant)+delta+3)%3]);}
function scrollToScreen(screen){for(const el of document.querySelectorAll(`[data-screen="${screen}"] .screen-scroll`))el.scrollTop=0;}
app.addEventListener('click',e=>{
  const target=e.target.closest('[data-action]');if(!target)return;
  const action=target.dataset.action,records=recordsFor(state),trip=records.find(r=>r.id===state.id)||records[0];
  if(action==='variant'){selectVariant(target.dataset.variant);return;}
  if(action==='previous-variant'||action==='next-variant'){cycleVariant(action==='previous-variant'?-1:1);return;}
  if(action==='trip'){state.id=Number(target.dataset.id);state.screen='detail';state.compare=false;state.point=7;state.sheet='';updateUrl();render();scrollToScreen('detail');return;}
  if(action==='list'){state.screen='list';state.sheet='';updateUrl();render();scrollToScreen('list');return;}
  if(action==='period'){state.period=target.dataset.period;state.day='';state.route='';state.search='';state.loaded=6;state.chartDay=state.period==='7'?6:29;state.sheet='';}
  else if(action==='clear'){state.day='';state.route='';state.search='';state.loaded=6;}
  else if(action==='open-day'){state.day=target.dataset.date;state.loaded=6;}
  else if(action==='more')state.loaded+=6;
  else if(action==='route'){state.route='家 → 滨江园区';state.day='';state.loaded=6;}
  else if(action==='metric')state.metric=target.dataset.metric;
  else if(action==='pair')state.paired=!state.paired;
  else if(action==='point-prev')state.point=Math.max(0,state.point-1);
  else if(action==='point-next')state.point=Math.min(seriesFor(trip,state.scene).length-1,state.point+1);
  else if(action==='day-prev')state.chartDay=Math.max(0,Math.min(state.period==='7'?6:29,state.chartDay)-1);
  else if(action==='day-next')state.chartDay=Math.min(state.period==='7'?6:29,state.chartDay+1);
  else if(action==='retry'||action==='retry-map')state.scene='normal';
  else if(action==='close')state.sheet='';
  else state.sheet=action;
  updateUrl();render();
});
app.addEventListener('change',e=>{
  if(e.target.dataset.control){const key=e.target.dataset.control;state[key]=e.target.value;state.sheet='';if(key==='scope'){state.metric='speed';state.route='';state.search='';}if(key==='scene'){state.day='';state.loaded=6;state.id=1;state.point=7;}updateUrl();render();}
});
app.addEventListener('submit',e=>{if(e.target.id==='search-form'){e.preventDefault();state.search=document.getElementById('location-search').value.trim();state.day='';state.loaded=6;render();}});
function selectChartPoint(e){
  const chart=e.target.closest('[data-chart],[data-day-chart]');if(!chart)return;
  const rect=chart.getBoundingClientRect(),fraction=(e.clientX-rect.left)/rect.width;
  if(chart.dataset.dayChart){const length=state.period==='7'?7:30;state.chartDay=Math.max(0,Math.min(length-1,Math.floor((fraction*300-7)/(284-7)*length)));}
  else {const records=recordsFor(state),trip=records.find(r=>r.id===state.id)||records[0];if(!trip)return;const series=seriesFor(trip,state.scene),f=(fraction*308-34)/(292-34);state.point=series.reduce((best,p,i)=>Math.abs(p.fraction-f)<Math.abs(series[best].fraction-f)?i:best,0);}
  render();
}
app.addEventListener('pointerdown',selectChartPoint);
app.addEventListener('pointermove',e=>{if(e.buttons===1)selectChartPoint(e);});
document.addEventListener('keydown',e=>{
  if(['Enter',' '].includes(e.key)){const marker=e.target.closest('[data-map-trip]');if(marker){e.preventDefault();marker.dispatchEvent(new MouseEvent('click',{bubbles:true}));return;}}
  if(e.key==='Escape'&&state.sheet){state.sheet='';render();return;}
  if(!['ArrowLeft','ArrowRight'].includes(e.key))return;
  if(e.target.closest('input,textarea,select,[contenteditable]'))return;
  if(e.target.closest('[data-chart]')){
    const records=recordsFor(state),trip=records.find(r=>r.id===state.id)||records[0];if(!trip)return;
    e.preventDefault();state.point=Math.max(0,Math.min(seriesFor(trip,state.scene).length-1,state.point+(e.key==='ArrowLeft'?-1:1)));render();
    for(const el of document.querySelectorAll(`[data-chart="${state.metric}"]`))el.focus();return;
  }
  e.preventDefault();cycleVariant(e.key==='ArrowLeft'?-1:1);
});
render();

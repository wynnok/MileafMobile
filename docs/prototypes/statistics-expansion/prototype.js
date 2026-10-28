// Three throwaway statistics layouts, ?variant=A|B|C. Synthetic data only.
// The question: which hierarchy helps an owner understand a period at first glance?
const Q=new URLSearchParams(location.search);
const S={variant:['A','B','C'].includes(Q.get('variant'))?Q.get('variant'):'A',
  mode:Q.get('mode')==='existing'?'existing':'vision',theme:Q.get('theme')==='dark'?'dark':'light',
  size:Q.get('size')==='200'?'200':'100',data:Q.get('data')||'normal',period:Q.get('period')==='week'?'week':'month',
  currency:Q.get('currency')==='none'?'none':'CNY',screen:Q.get('screen')||'home',
  metric:'km',point:0,temp:2,rangePoint:5,day:28,sheet:null,compare:Q.get('compare')==='1',
  export:Q.get('export')==='1',full:Q.get('full')==='1',reference:true};
const VARIANTS={A:{name:'用车洞察',tag:'结果 → 节奏 → 原因线索',why:'先理解一段时间的用车，再决定要深入看什么。推荐作为统计默认入口。'},
  B:{name:'效率透镜',tag:'电耗 → 条件 → 行程证据',why:'用电耗作为主线，适合关心效率变化的车主；也适合作为A的能耗专题。'},
  C:{name:'用车年历',tag:'时间 → 一天 → 一段回忆',why:'从日历认出生活节奏，适合回顾与找记录；完整年度入口在正式方案中保留。'}};
const esc=v=>String(v).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
const f=(v,d=1)=>v===null||v===undefined||!Number.isFinite(v)?'—':v.toLocaleString('en-US',{minimumFractionDigits:0,maximumFractionDigits:d});
const vision=()=>S.mode==='vision';
const typeLabel=type=>({ac:'AC',dc:'DC',unknown:'未知'})[type];
const unit=()=>S.currency==='CNY'?'CNY':'币种未知';
const money=v=>`${f(v,2)} <small>${unit()}</small>`;
const duration=m=>m===null?'—':`${Math.floor(m/60)}小时${Math.round(m%60)}分`;
const F=()=>fixture(S.period,S.data);
const net=d=>vision()?d.net:d.legacyNet;
const canCompare=d=>S.reference&&d.referenceDistance>0&&d.net!==null&&!['referencefail','insufficient','missing'].includes(S.data)&&vision();
const icon=(name,size=19)=>{
  const paths={leaf:'M12 2c4 4 4 7 0 10-4-3-4-6 0-10ZM3 10c6 0 9 3 9 10-6-1-9-4-9-10Zm18 0c0 6-3 9-9 10 0-7 3-10 9-10Z',
    home:'m3 11 9-8 9 8M5 10v11h5v-7h4v7h5V10',car:'M5 6 3 13v6h3v-3h12v3h3v-6l-2-7H5Zm-1 7h16M6 15h1m10 0h1',
    bolt:'m13 2-8 12h6l-1 8 9-13h-7l1-7Z',chart:'M4 20V10h3v10M10 20V4h3v16m3 0V8h3v12',
    back:'m14 5-7 7 7 7M7 12h13',info:'M12 11v6m0-11v1M22 12a10 10 0 1 1-20 0 10 10 0 0 1 20 0Z',
    refresh:'M20 8V3l-4 4a8 8 0 1 0 3 10M20 8h-6',clock:'M12 7v5l4 2M22 12a10 10 0 1 1-20 0 10 10 0 0 1 20 0Z',
    calendar:'M4 5h16v16H4V5Zm0 5h16M8 2v6m8-6v6M8 14h2m4 0h2M8 18h2'};
  return `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="${paths[name]||paths.chart}"/></svg>`;
};
function btn(label,action,value='',cls='text-button',extra=''){return `<button class="${cls}" data-action="${action}" data-value="${esc(value)}" ${extra}>${label}</button>`;}
function head(title,side=''){return `<div class="section-head"><h2>${title}</h2>${side}</div>`;}
function help(key,label='口径'){return btn(label,'help',key);}
function topic(value,label){return btn(label,'topic',value);}
function appHeader(){return `<header class="app-head"><div class="brand">${icon('leaf',22)}行笺</div><button class="vehicle" data-action="help" data-value="vehicle">湖畔测试车 ⌄</button>${btn(icon('refresh'),'retry','','icon-button','aria-label="刷新统计"')}</header>`;}
function nav(){return `<nav class="nav" aria-label="主导航">${[['home','概览'],['car','行程'],['bolt','充电'],['chart','统计']].map(([i,label])=>btn(`${icon(i)}${label}`,label==='统计'?'topic':'help',label==='统计'?'home':'nav',label==='统计'?'active':'')).join('')}</nav>`;}
function pageHead(screen){return `<div class="page-title"><h1>统计</h1><span>Asia/Shanghai</span></div><div class="period">${btn('本周','period','week',S.period==='week'?'active':'')}${btn('本月','period','month',S.period==='month'?'active':'')}${btn('其他区间','help','dates')}<span class="date">${S.period==='week'?'10.26':'10.01'}—10.28</span></div><nav class="tabs" aria-label="统计专题">${[['home','总览'],['energy','能耗'],['charging','补能'],...(vision()?[['long','长期']]:[])].map(([k,t])=>btn(t,'topic',k,k===screen?'active':'')).join('')}</nav>`;}
function stateNotice(){
  const notes={missing:'部分耗能和费用缺失，暂不生成跨期结论。',baselinezero:'参照期无已完成行程，保留原值，不计算增幅。',referencefail:'上期参照暂不可用，本期数据已保留。',chargefail:'补能统计暂不可用，驾驶统计已保留。',stale:'当前为上次成功快照 · 18:40校验',insufficient:'新记录不足，先看原值，继续积累可比较样本。'};
  return notes[S.data]?`<div class="status">${notes[S.data]}${['referencefail','chargefail','stale'].includes(S.data)?btn('重试','retry'):''}</div>`:'';
}
const METRICS={km:['里程','km'],net:['净电耗','Wh/km'],energy:['估算能量','kWh'],drives:['行程数','次'],speed:['最高速度','km/h'],added:['入电量','kWh'],cost:['已知支出',''],price:['有效入电均价',''],sessions:['充电次数','次']};
function plot(items,series,{key='main',unitText='',line=false,selected=S.point,band=null}={}){
  const width=290,height=S.size==='200'?190:146,left=S.size==='200'?48:32,right=8,top=S.size==='200'?24:17,bottom=S.size==='200'?36:24,w=width-left-right,h=height-top-bottom;
  const raw=series.flatMap(s=>s.values).filter(v=>v!==null&&Number.isFinite(v));
  if(band)raw.push(...band.flat());
  const max=raw.length?Math.max(...raw):1,min=raw.length?Math.min(...raw):0;
  let low=line&&min>0?Math.floor(min*.88/5)*5:Math.min(0,min),high=line?Math.ceil(max*1.06/5)*5:Math.ceil(Math.max(max,1)/4)*4;
  if(high<=low)high=low+1;
  const y=v=>top+h-(v-low)/(high-low)*h;
  const x=i=>left+(i+.5)*w/items.length;
  const grid=[0,.5,1].map(t=>{const v=low+(high-low)*t;return `<line class="grid" x1="${left}" y1="${y(v)}" x2="${width-right}" y2="${y(v)}"/><text x="${left-5}" y="${y(v)+3}" text-anchor="end">${f(v,max<5?1:0)}</text>`;}).join('');
  const labels=items.map((p,i)=>items.length<=7||i===0||i===items.length-1||(items.length>10&&i===Math.floor(items.length/2))?`<text x="${x(i)}" y="${height-5}" text-anchor="${i===0?'start':i===items.length-1?'end':'middle'}">${esc(p.label)}</text>`:'').join('');
  let shapes='';
  if(band){const points=items.map((_,i)=>`${x(i)},${y(band[i][1])}`).concat(items.map((_,i)=>`${x(i)},${y(band[i][0])}`).reverse()).join(' ');shapes+=`<polygon points="${points}" fill="var(--pale)" opacity=".8"/>`;}
  series.forEach((s,j)=>{
    const isLine=line||s.reference;
    if(isLine){let path='',open=false;s.values.forEach((v,i)=>{if(v===null||!Number.isFinite(v)){open=false;return;}path+=`${open?'L':'M'}${x(i)} ${y(v)} `;open=true;});if(!s.pointsOnly)shapes+=`<path class="${s.reference?'reference':'line'}" d="${path}"/>`;
      shapes+=s.values.map((v,i)=>v===null?'':`<circle class="dot ${i===selected?'selected':''}" cx="${x(i)}" cy="${y(v)}" r="${i===selected?4:2.4}" ${s.reference?'style="stroke:var(--amber);fill:var(--card)"':''}/>`).join('');
    }else{const bw=Math.min(19,w/items.length*.65);shapes+=s.values.map((v,i)=>v===null?'':`<rect class="bar ${selected!==i?'faint':''}" x="${x(i)-bw/2}" y="${Math.min(y(v),y(0))}" width="${bw}" height="${Math.max(v===0?1:2,Math.abs(y(v)-y(0)))}" rx="2"/>`).join('');}
  });
  const hit=items.map((p,i)=>`<rect class="hit" data-action="point" data-value="${i}" data-chart="${key}" x="${left+i*w/items.length}" y="${top}" width="${w/items.length}" height="${h}" aria-label="${esc(p.label)}"/>`).join('');
  return `<svg class="chart" role="img" aria-label="${esc(unitText)}时间或分组图，使用下方前后按钮读取数值" viewBox="0 0 ${width} ${height}"><text x="0" y="9">${esc(unitText)}</text>${grid}${labels}${shapes}${hit}</svg>`;
}
function pointControls(chart,index,max){return `<span class="readout-controls">${btn('‹','step',-1,'',`data-chart="${chart}" aria-label="前一个数据点" ${index===0?'disabled':''}`)}${btn('›','step',1,'',`data-chart="${chart}" aria-label="后一个数据点" ${index>=max?'disabled':''}`)}</span>`;}
function trend(d,charging=false){
  const allowed=charging?['added','cost','price','sessions']:['km','net','energy','drives'];
  const metric=allowed.includes(S.metric)?S.metric:allowed[0], [title,u]=METRICS[metric];
  const unitText=metric==='cost'?unit():metric==='price'?`${unit()}/kWh`:u;
  const index=Math.min(S.point,d.days.length-1),p=d.days[index];
  const reference=S.reference&&d.referenceDistance>0&&!['referencefail','insufficient'].includes(S.data)&&['km','net'].includes(metric);
  const value=p=>metric==='net'&&!vision()?p.legacyNet:p[metric];
  const series=[{values:d.days.map(value)}];
  if(reference)series.push({reference:true,values:d.days.map(p=>value(p)===null?null:metric==='net'?value(p)+6.2:p.km/1.164)});
  return `<section class="card">${head(`${title}走势`,help('compare',S.reference?'参照已开':'开启参照'))}<div class="chart-tabs">${allowed.map(k=>btn(METRICS[k][0],'metric',k,k===metric?'active':'')).join('')}</div><div class="legend"><span><i></i>本期</span>${reference?`<span><i class="ref"></i>${S.period==='week'?'上周':'上月'}同进度</span>`:''}</div>${plot(d.days,series,{unitText,line:['net','price'].includes(metric),selected:index})}<div class="readout"><span>${p.label} <b class="value">${f(value(p),metric==='cost'||metric==='price'?2:1)} ${unitText}</b>${reference?` · 参照 <b style="color:var(--amber)">${f(metric==='net'?(value(p)===null?null:value(p)+6.2):p.km/1.164)}</b>`:''}</span>${pointControls('main',index,d.days.length-1)}${btn('看当天','day',p.day)}</div>${metric==='net'?'<p class="note">行程续航差估算 · 缺失日断线</p>':''}</section>`;
}
function hero(d){return `<section class="hero"><div class="overline">${S.period==='week'?'THIS WEEK / 本周回顾':'OCTOBER / 本月回顾'}</div><h2>${canCompare(d)?'开得更多，电耗更低':'这段时间的用车回顾'}</h2><div class="hero-line"><div class="hero-number">${f(d.distance,0)}<small>km</small></div><div class="change">${canCompare(d)?`<b>↗ ${f((d.distance/d.referenceDistance-1)*100)}%</b><br>${S.period==='week'?'上周':'上月'}同进度`:`${d.trips.length} 趟已完成<br>截至19:10`}</div></div><div class="hero-note">${canCompare(d)?`净电耗较参照低 ${f(d.referenceNet-d.net)} Wh/km`:'行程按开始日 · 只读已完成记录'}</div><div class="mini-metrics"><div><div class="label">${vision()?'行驶净电耗（估算）':'估算净电耗'}</div><div class="num">${f(net(d),0)} <small>Wh/km</small></div><small>${S.data==='missing'?`能量有效里程 ${f(d.coverage*100,0)}%`:'续航差估算 · 非电网侧'}</small></div><div><div class="label">已知充电支出</div><div class="num">${S.data==='chargefail'?'—':money(d.cost)}</div><small>${S.data==='chargefail'?'补能统计待重试':`费用有记录 ${d.costKnown}/${d.charges.length} 次`}</small></div></div></section>`;}
function calendar(d){
  const first=4; // 2026-10-01 is Thursday, Monday is column zero.
  const cells=[...Array(first-1)].map(()=>'<span class="day empty"></span>');
  for(let day=1;day<=31;day++){
    const p=d.days.find(x=>x.day===day),future=day>28,km=p?.km??0,level=km===0?0:km<50?1:km<100?2:km<200?3:4;
    cells.push(`<button class="day ${future?'future':''} ${day===S.day?'picked':''}" data-level="${level}" data-action="day" data-value="${day}" ${future||!p?'disabled':''} aria-label="10月${day}日 ${future?'尚未到来':!p?'当前查询范围外':f(km)+'公里'}">${day}</button>`);
  }
  return `<div class="calendar">${['一','二','三','四','五','六','日'].map(x=>`<span class="weekday">${x}</span>`).join('')}${cells.join('')}</div><div class="calendar-key">km <i></i>0 <i></i>50 <i></i>100 <i></i>200+ <span style="margin-left:auto">10月 · 点一天看记录</span></div>`;
}
function usage(d,calendarOnly=false){return `<section class="chapter">${head('01 / 用车节奏',help('usage'))}<p class="lead">${vision()?`<b>${d.active}</b>天，有它陪你出发`:'把每一天的里程，连成回顾'}</p>${calendar(d)}${vision()?`<div class="row-stats"><div><b>${d.trips.length}<small> 趟</small></b><span>已完成行程</span></div><div><b>${f(d.duration/60,1)}<small> h</small></b><span>驾驶记录时长</span></div><div><b>${f(d.medianKm)}<small> km</small></b><span>单程中位数</span></div></div>`:`<p class="note">每日颜色来自服务端日桶；空白未来日期不补0。</p>`}${calendarOnly?'':vision()?distanceGroups(d):''}</section>`;}
function distanceGroups(d){return `<div class="distribution" aria-hidden="true">${d.groups.map(g=>`<span style="flex:${g.km||.1}"></span>`).join('')}</div><div class="stat-list">${d.groups.map((g,i)=>`<button class="stat-row ${i===1?'amber':i===2?'grey':''}" data-action="group" data-value="${i}"><div>${g.label} <span>${g.range}</span></div><div>${g.drives} 趟 <span>· ${f(g.value,0)} Wh/km</span></div></button>`).join('')}</div><p class="note" style="margin-top:9px">色带按里程占比 · 分组电耗按有效里程加权</p>`;}
function temperature(d,full=false){
  const ix=Math.min(S.temp,d.temps.length-1),t=d.temps[ix];
  const adequate=t=>t.drives>=5&&t.km>=50;
  return `<section class="${full?'card':'chapter'}">${head(full?'温度与电耗':'02 / 电耗与条件',help('temperature'))}${!full?'<p class="lead">不同温度下，记录有何不同？</p>':''}<div class="legend"><span><i></i>行驶净电耗（估算）</span></div>${plot(d.temps,[{values:d.temps.map(t=>adequate(t)?t.value:null)},{values:d.temps.map(t=>adequate(t)?null:t.value),pointsOnly:true}],{key:'temp',unitText:'Wh/km',line:true,selected:ix})}<div class="readout"><span>${t.label}C <b class="value">${f(t.value,0)} Wh/km</b></span>${pointControls('temp',ix,d.temps.length-1)}${btn('看样本','temperature',ix)}</div><p class="note">${t.drives}趟 · ${f(t.km,0)}km · 单程中位 ${f(t.median)}km${adequate(t)?'':' · 样本较少'}<br>室外均温分组；存在路况、行程长度等差别，仅表关联。</p></section>`;
}
function classBars(d){
  const types=[['ac','AC',''],['dc','DC','amber'],['unknown','未知','grey']];
  const values=types.map(([type])=>sum(d.charges.filter(c=>c.type===type),c=>c.added)),max=Math.max(...values,1);
  return `<div class="stat-list">${types.map(([type,label,cls],i)=>`<button class="stat-row ${cls}" data-action="charge-type" data-value="${type}"><div>${label}</div><div>${f(values[i])} <span>kWh</span></div><div class="bar-track"><i style="width:${values[i]/max*100}%"></i></div></button>`).join('')}</div><p class="note" style="margin-top:9px">相同尺度的绝对入电量，未知分类单列</p>`;
}
function chargeSummary(d,home=true){
  if(S.data==='chargefail')return `<section class="chapter">${head('补能账目')}<div class="status">补能统计暂不可用 ${btn('重试','retry')}</div><p class="note">驾驶数据保持可读。</p></section>`;
  return `<section class="chapter">${head(home?'03 / 补能账目':'入电结构',topic('charging','展开补能 ›'))}${home?`<p class="lead">这段时间，补进 ${f(d.added)} kWh</p>`:''}${classBars(d)}<div class="row-stats"><div><b>${f(d.price,2)}</b><span>有效入电均价 ${unit()}/kWh</span></div><div><b>${f(d.chargeDuration/60,1)}<small> h</small></b><span>充电记录时长</span></div></div><div class="check-note">费用有记录 <strong>${d.costKnown}/${d.charges.length}次</strong>，对应入电 <strong>${f(d.costEnergy)}kWh</strong>。${d.costKnown<d.charges.length?'支出未覆盖全部充电。':'已知0费用也参与统计。'}</div></section>`;
}
function places(d){const names=[...new Set(d.charges.map(c=>c.place))];return `<section class="chapter">${head('自己的地点账目',help('places'))}<div>${names.sort((a,b)=>sum(d.charges.filter(c=>c.place===b),c=>c.added)-sum(d.charges.filter(c=>c.place===a),c=>c.added)).map(name=>{const records=d.charges.filter(c=>c.place===name),known=records.filter(c=>c.cost!==null);return `<button class="list-button" data-action="place" data-value="${esc(name)}"><div class="line1"><span>${name}</span><span>${f(sum(records,c=>c.added))} <small>kWh ›</small></span></div><div class="line2">${records.length}次 · 已知支出 ${known.length?f(sum(known,c=>c.cost),2):'—'} ${unit()} · 费用${known.length}/${records.length}次</div></button>`;}).join('')}</div></section>`;}
function longLinks(d){return `<section class="chapter">${head('04 / 长期观察',topic('long','看完整专题 ›'))}<button class="topic-link" data-action="topic" data-value="long"><h3>满电等效额定续航 <span>↗</span></h3><p>6个月记录 · 月中位数与波动范围</p><span class="topic-value">${S.data==='insufficient'?'—':f(LONG_RANGE[5].value,0)} <small>km</small></span><p>是记录估计，非电池健康检测</p></button><button class="topic-link" data-action="topic" data-value="parking"><h3>可观测停放窗口 <span>↗</span></h3><p>${!d.parking.length?'尚无足够闭合窗口':`${d.parking.length}个窗口 · ${f(d.parkedHours,0)}h观测`}</p><span class="topic-value">${!d.parking.length?'—':f(d.parkedChange/d.parkedHours*24,2)} <small>百分点/24h</small></span><p>电量变化率，不能归因为哨兵或空调</p></button></section>`;}
function whole(d){return `<details class="details"><summary>全部指标与口径</summary><div class="stat-list">${[['行程数',`${d.trips.length}次`],['估算净能量',`${f(d.energy,2)}kWh`],['区间净电耗',`${f(d.legacyNet)}Wh/km`],['期间入电折算电耗（毛）',`${f(d.gross)}Wh/km`],['最高速度',`${f(Math.max(...d.days.map(p=>p.speed??0)),0)}km/h`],['充电次数',S.data==='chargefail'?'—（补能统计待重试）':`${d.charges.length}次`],['充入电池能量',S.data==='chargefail'?'—（补能统计待重试）':`${f(d.added)}kWh`]].map(([k,v])=>`<div class="stat-row"><span>${k}</span><b>${v}</b></div>`).join('')}</div><div class="vertical-space"></div>${btn('查看每日净/毛比较','help','netgross')}<p class="note">毛电耗是期间充入量/里程；不是停放耗电，不等同Efficiency面板算法。最高速度不作成绩评价。</p>${btn('原始时间桶明细','help','buckets')}</details><p class="footnote">行程按开始日，充电按结束日 · 已完成记录<br>截至10/28 19:10 · ${S.data==='stale'?'18:40':'19:10'}查询校验，不是车辆采样时间</p>`;}
function VariantA(d){return `${hero(d)}${trend(d)}${usage(d)}${vision()?temperature(d):`<section class="chapter">${head('02 / 能耗走势',topic('energy','展开 ›'))}<p class="note">本期净/毛电耗与完整指标均可阅读。</p></section>`}${chargeSummary(d)}${vision()?longLinks(d):''}${whole(d)}`;}
function VariantB(d){return `<section class="topic-title"><div class="overline">EFFICIENCY / 效率透镜</div><h2>每公里，<br>电用得怎样？</h2><div class="editorial-number">${f(net(d),0)} <small>Wh/km</small></div><p>行程续航差估算${canCompare(d)?` · 较上期低${f(d.referenceNet-d.net)}Wh/km`:''}</p></section>${vision()?temperature(d,true):trend(d)}${vision()?`<section class="chapter">${head('先区分短途与长途',help('temperature'))}${distanceGroups(d)}</section>`:''}<section class="insight">${vision()&&d.groups.every(g=>g.value!==null)&&!['missing','insufficient'].includes(S.data)?'短途的记录电耗较高。':'把同一口径放在一起比较。'}<p>${vision()?'先看样本长度与条件，再判断是否值得关注。不能从相关图推断原因。':'净电耗与毛电耗来自不同能量口径，差额不等于损耗。'}</p></section>${netGross(d)}${chargeSummary(d)}${whole(d)}`;}
function VariantC(d){return `<section class="topic-title"><div class="overline">YOUR DAYS / 用车年历</div><h2>十月，行驶的日子</h2><p>${vision()?`${d.active}个活跃日`:`${d.trips.length}趟已完成行程`} · ${f(d.distance,0)}km · 点一天重温</p></section><section class="card">${head('2026 / 10',help('calendar'))}${calendar(d)}<div class="vertical-space"></div><div class="readout"><span>10/${S.day} <b class="value">${f(d.days.find(p=>p.day===S.day)?.km??0)}km</b></span>${btn('当天记录 ›','day',S.day)}</div></section>${vision()?`<section class="chapter">${head('一趟的尺度',help('usage'))}<div class="hero-number">${f(d.medianKm)}<small>km / 单程中位</small></div><p class="note">全期间行程分位数，不平均每日中位数</p>${distanceGroups(d)}</section>`:''}${trend(d)}${chargeSummary(d)}${vision()?longLinks(d):''}${whole(d)}`;}
function netGross(d){const index=Math.min(S.point,d.days.length-1),p=d.days[index];return `<section class="card">${head('净 / 毛电耗',help('netgross'))}<div class="legend"><span><i></i>净：行程续航差估算</span><span><i class="ref"></i>毛：期间入电/里程</span></div>${plot(d.days,[{values:d.days.map(p=>p.legacyNet)},{values:d.days.map(p=>p.gross),reference:true}],{key:'gross',unitText:'Wh/km',line:true,selected:index})}<div class="readout"><span>${p.label} · 净 <b class="value">${f(p.legacyNet)}</b> / 毛 <b style="color:var(--amber)">${f(p.gross)}</b><br><small>Wh/km · 原区间口径</small></span>${pointControls('gross',index,d.days.length-1)}</div><p class="note">两种归期与能量口径，不能用差额推算停放耗电。${btn('读数明细','help','buckets')}</p></section>`;}
function energyScreen(d){return `<section class="topic-title"><div class="overline">EFFICIENCY / 能耗观察</div><h2>理解电耗，<br>先把条件放在一起。</h2><div class="editorial-number">${f(net(d),0)} <small>Wh/km</small></div><p>${vision()?'估算有效里程':'区间净电耗'} · ${vision()?f(d.pairedDistance,0)+'km':'续航差估算'}</p></section>${vision()?temperature(d,true):trend(d)}${vision()?`<section class="chapter">${head('不同长度的行程',help('temperature'))}${distanceGroups(d)}</section>`:''}${netGross(d)}${whole(d)}`;}
function chargingScreen(d){if(S.data==='chargefail')return chargeSummary(d,false);return `<section class="topic-title"><div class="overline">CHARGING / 补能账目</div><h2>补进多少电，<br>花在什么地方。</h2><div class="editorial-number">${money(d.cost)}</div><p>已知充电支出 · 费用有记录${d.costKnown}/${d.charges.length}次</p></section>${trend(d,true)}${chargeSummary(d,false)}${places(d)}<div class="check-note">入电均价的有效配对分母 ${f(d.costEnergy)}kWh；零费用记录参与，未知费用不补0。</div>${whole(d)}`;}
function rangeScreen(){const selected=LONG_RANGE[S.rangePoint];return `<section class="topic-title"><div class="overline">LONG VIEW / 长期观察</div><h2>看长期变化，<br>给波动留出空间。</h2><p>额定续航的记录估计，不能等同电池健康检测。</p></section><div class="long-period"><span>独立观察窗口</span><strong>2026.05—10 · 6个月</strong></div>${S.data==='insufficient'?`<section class="card"><h2>还需要更多有效日</h2><p class="note">当前不足3个有效日，暂不绘制连续趋势。已有记录仍可核查。</p></section>`:`<section class="card">${head('满电等效额定续航',help('range'))}<div class="legend"><span><i></i>月中位数</span><span>色带：有效日P10–P90</span></div>${plot(LONG_RANGE,[{values:LONG_RANGE.map(p=>p.value)}],{key:'range',unitText:'km',line:true,selected:S.rangePoint,band:LONG_RANGE.map(p=>[p.low,p.high])})}<div class="readout"><span>${selected.label} <b class="value">${selected.value}km</b></span>${pointControls('range',S.rangePoint,5)}</div><p class="note">${selected.days}个有效日 · 日值范围${selected.low}–${selected.high}km<br>固定rated + battery_level；先按会话、日降权。</p></section>`}<section class="insight">先观察趋势，不急着给健康分。<p>记录开始不等于新车交付。温度、SOC范围和估算偏差都可能影响结果，没有新车基线不计算衰减。</p></section>${btn('查看样本方法','help','range')}${longLinks(F())}<p class="footnote">长期窗口独立于本月筛选 · 合成模型示意<br>查看样本方法，了解哪些记录参与估计</p>`;}
function parkingScreen(d){const adequate=S.data!=='insufficient'&&d.parking.length>0;return `<section class="topic-title"><div class="overline">BETWEEN TRIPS / 停放观察</div><h2>两次出发之间，<br>电量怎样变化。</h2><p>仅统计可观测、闭合的停放窗口</p></section><div class="editorial-number">${adequate?f(d.parkedChange/d.parkedHours*24,2):'—'} <small>百分点/24h</small></div><p class="note">负值表示下降 · 是标准化变化率，不是全天预测</p><div class="row-stats"><div><b>${adequate?d.parking.length:'—'}</b><span>有效窗口</span></div><div><b>${adequate?d.parkedHours:'—'} h</b><span>累计观测时间</span></div></div><section class="card">${head('可观测时间的状态',help('parking'))}${[['睡眠',70,''],['在线',24,'amber'],['离线',4,'grey'],['未知',2,'grey']].map(([label,value,cls])=>`<div class="stat-row ${cls}" style="margin:11px 0"><span>${label}</span><div>${adequate?value+'%':'—'}</div><div class="bar-track"><i style="width:${adequate?value:0}%"></i></div></div>`).join('')}<p class="note">离线不当睡眠，在线不等于哨兵/空调</p></section><section class="chapter">${head('窗口证据',help('parking'))}${adequate?d.parking.slice(0,4).map(p=>`<button class="list-button" data-action="parking" data-value="${p.id}"><div class="line1"><span>10/${p.day} 停放${p.hours}h</span><span>${p.change} <small>百分点 ›</small></span></div><div class="line2">里程无变化 · 结束于下一次驾驶/充电</div></button>`).join(''):'<p class="note">尚无足够有效闭合窗口，不显示0损耗。</p>'}</section><div class="check-note">只代表这些窗口，不代表全月停放；端点SOC有量化误差与回弹，不归因为具体功能。</div>`;}
function empty(){return `<section class="empty-state">${icon('calendar',36)}<h2>这段时间，还没有记录</h2><p>里程0km · 已完成行程0次<br>未知电耗不显示为0，未来日期留空。</p>${btn('查看本月样例','retry','','')}</section>`;}
function renderScreen(screen,variant,d){if(S.data==='empty')return empty();if(screen==='energy')return energyScreen(d);if(screen==='charging')return chargingScreen(d);if(screen==='long'||screen==='parking')return vision()?screen==='long'?rangeScreen():parkingScreen(d):'<p class="note">现有接口没有长期观察能力。</p>';return {A:VariantA,B:VariantB,C:VariantC}[variant](d);}
function phone(variant,screen,d,preview=false){return `<div class="phone ${S.theme==='dark'?'dark':''} ${S.size==='200'?'large':''}" data-phone="${preview?'preview':variant}">${appHeader()}<main class="screen" data-scroll="${preview?'preview':variant}">${pageHead(screen==='parking'?'long':screen)}${stateNotice()}${renderScreen(screen,variant,d)}</main>${nav()}${S.sheet&&S.sheetPhone===(preview?'preview':variant)?sheet(d):''}</div>`;}
const HELP={
  vehicle:['车辆上下文','本原型只使用一辆合成测试车。正式页面继续复用现有车辆切换、缓存与迟到响应隔离，不跨车比较。'],
  nav:['统计页设计评审','本轮只设计统计页。正式行程与充电入口继续使用现有页面；本原型的下钻展示合成记录，不连接业务API。'],
  dates:['日历与同进度','原型实现本周、本月，固定截止10/28 19:10 Asia/Shanghai。正式方案保留本年和自定义、730天上限、IANA/DST规则。本月参照为9/1–9/28 19:10；本周参照为10/19–10/21 19:10。月长无法对齐时不强算增减。'],
  usage:['用车节奏的分母','活跃日按已完成行程开始日去重；驾驶时长是记录时长；单程中位数在完整查询集计算。色带按各距离组里程，分组电耗使用同批有效能量/距离；不平均每趟电耗或每日中位数。'],
  calendar:['日历读法','从周一到周日，颜色表示当天里程；0km为真实无记录，未来日期留空。月历只显示当前10月；本年/自定义正式规则保留，原型没有实现任意日期选择。'],
  temperature:['关联，不是原因','使用行程室外均温分组，电耗=sum有效估算能量/sum同批里程。每组附趟数、里程和单程距离中位数；不足5趟或50km为小样本。路况、速度、地形等仍可能不同，不能推断某个温度让车辆更省电。'],
  fees:['钱与电的分母','已知充电支出只合计非null费用，0费用参与；不代表全部用车成本。有效入电均价使用费用和入电量同批有效会话。期间充电与驾驶存在库存及归期差，不把支出/里程直接叫真实百公里成本。'],
  places:['地点身份','正式0.2接口已有稳定地点键、全匹配集聚合和结束日下钻。本原型地点名都是合成。不能把AC都当家充、用地点名称猜运营商，或从第一页补算地点排行。'],
  range:['长期估计方法（待验证）','同一charges采样点使用额定续航×100/battery_level；只用20–90%SOC候选，先会话中位、再日中位、再月度日值中位与P10–P90。固定rated，不混ideal/usable SOC。少于3个有效日不作连续结论。这是建议模型，待Server验证，不是BMS SOH或出厂容量；记录起点不能当新车基线。'],
  parking:['停放窗口（待验证）','前一已完成行程/充电结束至下一事件开始，排除重叠、进行中、缺端点、里程变化和不足1小时窗口。SOC变化=结束-开始，负数表示下降；按总变化/总观测小时标准化为24小时，不平均窗口速率。online/asleep/offline分别统计，不诊断哨兵或空调，也不代表全月。'],
  netgross:['净与毛不能相减当损耗','净电耗是行程续航差与车辆效率的估算。当前API毛电耗是期间充入电池量/期间驾驶里程，充电按结束日、行程按开始日。它与TeslaMate Efficiency事件法gross不同；充入量减行驶量也不等于停放或充电损耗。'],
};
function sheet(d){
  const k=S.sheet.kind,v=S.sheet.value;let title='',content='';
  const tripRows=trips=>trips.length?trips.map(t=>`<button class="list-button" data-action="trip" data-value="${t.id}"><div class="line1"><span>${t.start} → ${t.end}</span><span>${f(t.km)} km ›</span></div><div class="line2">10/${t.day} ${t.at} · ${t.duration}分钟 · ${t.energy===null?'能量缺失':f(t.energy/t.km*1000,0)+'Wh/km'}</div></button>`).join(''):'<p>没有匹配的已完成行程。</p>';
  const chargeRows=charges=>charges.length?charges.map(c=>`<div class="list-button"><div class="line1"><span>${c.place} · ${typeLabel(c.type)}</span><span>${f(c.added)} kWh</span></div><div class="line2">10/${c.day}结束 · ${c.cost===null?'费用未知':f(c.cost,2)+' '+unit()} · ${duration(c.duration)}</div></div>`).join(''):'<p>没有匹配的已完成充电。</p>';
  if(k==='help'){
    if(v==='compare'){title='同进度参照';content=`<p>本期${S.period==='week'?'10/26':'10/1'}—10/28 19:10；参照${S.period==='week'?'10/19—10/21':'9/1—9/28'} 19:10，均为Asia/Shanghai。图中只在里程/净电耗视图显示参照。</p><div class="vertical-space"></div>${btn(S.reference?'关闭参照曲线':'开启参照曲线','toggle-reference')}<h3>什么时候不写比较结论？</h3><p>基期0、没有历史、质量不足或参照失败时，只显示可用原值。现有接口模式可以看参照原值，缺完整度元数据时不输出强结论。</p>`;
    }else if(v==='buckets'){title='时间桶原值';content=`<p>原区间净/毛口径；行程开始日、充电结束日；null保留—。</p><table><thead><tr><th>日期</th><th>km</th><th>净Wh/km</th><th>毛Wh/km</th><th>入电kWh</th></tr></thead><tbody>${d.days.map(p=>`<tr><td>${p.label}</td><td>${f(p.km)}</td><td>${f(p.legacyNet)}</td><td>${f(p.gross)}</td><td>${S.data==='chargefail'?'—':f(p.added)}</td></tr>`).join('')}</tbody></table>`;
    }else{const text=HELP[v]||HELP.nav;title=text[0];content=`<p>${text[1]}</p>`;}
  }else if(k==='day'){S.day=Number(v);const day=d.days.find(p=>p.day===S.day);title=`10月${S.day}日`;content=day?`<p class="fact">${f(day.km)} <small>km · ${day.drives}趟</small></p><p>行程开始日，充电结束日 · Asia/Shanghai</p><h3>行程记录</h3>${tripRows(d.trips.filter(t=>t.day===S.day))}<h3>完成充电</h3>${S.data==='chargefail'?'<p>当天记录独立可用，期间补能汇总仍待重试。</p>':''}${chargeRows(d.charges.filter(c=>c.day===S.day))}`:'<p>当前周期不包含这一天。</p>';
  }else if(k==='group'){const group=d.groups[Number(v)];title=group.label+' · '+group.range;content=`<p class="fact">${group.drives} <small>趟 · ${f(group.value,0)} Wh/km</small></p><p>该分组的全部匹配记录，按行程开始日归期。</p>${tripRows(d.trips.filter(t=>t.km>=group.min&&t.km<group.max))}`;
  }else if(k==='temperature'){const t=d.temps[Number(v)];title=t.label+'C 的样本';content=`<p class="fact">${t.drives} <small>趟 · ${f(t.km)}km</small></p><p>有效估算能量与里程配对；${t.drives<5||t.km<50?'样本较少，不作趋势结论。':'只表达关联，不控制其他条件。'}</p>${tripRows(d.trips.filter(p=>p.temp>=t.lower&&p.temp<t.lower+5&&p.energy!==null))}`;
  }else if(k==='place'||k==='charge-type'){const records=d.charges.filter(c=>k==='place'?c.place===v:c.type===v);title=k==='place'?v:typeLabel(v)+'补能';content=`<p class="fact">${f(sum(records,c=>c.added))} <small>kWh · ${records.length}次</small></p><p>相同结束日、车辆与筛选条件；按结束日查询的补能记录。</p>${chargeRows(records)}`;
  }else if(k==='parking'){const p=d.parking.find(p=>p.id===Number(v));title=`10/${p.day} 停放窗口`;content=`<p class="fact">${p.change} <small>百分点 / ${p.hours}h</small></p><p>起点电量72%，结束${72+p.change}%，里程变化0km。前次结束至下次事件开始；不是全月总损耗。</p><h3>观测状态时长</h3><p>睡眠${f(p.sleep)}h / 在线${f(p.online)}h / 离线${f(p.offline)}h / 未知${f(p.unknown)}h。端点SOC存在量化误差。</p>`;
  }else if(k==='trip'){const t=d.trips.find(t=>t.id===Number(v));title='行程证据';content=`<p class="fact">${t.start} → ${t.end}</p><p>10/${t.day} ${t.at}开始 · ${f(t.km)}km · ${t.duration}分钟</p><h3>记录与口径</h3><p>室外均温${t.temp}°C；估算能量${f(t.energy,2)}kWh；净电耗${t.energy===null?'—':f(t.energy/t.km*1000,0)}Wh/km。</p><p>正式产品由此进入已有地图/过程详情；本轮原型只演示统计到匹配证据，不仿造真实路线。</p>`;}
  return `<div class="overlay"><section class="sheet" role="dialog" aria-modal="true" aria-label="${esc(title)}"><div class="sheet-head"><h2>${esc(title)}</h2>${btn('×','close','','icon-button','aria-label="关闭详情"')}</div>${content}</section></div>`;
}
function toolbar(){const select=(label,key,values)=>`<label>${label}<select data-setting="${key}" aria-label="${label}">${values.map(([value,label])=>`<option value="${value}" ${String(S[key])===value?'selected':''}>${label}</option>`).join('')}</select></label>`;return `<div class="toolbar">${select('能力','mode',[['vision','完整方案（含待建）'],['existing','仅现有0.2接口']])}${select('外观','theme',[['light','浅色'],['dark','深色']])}${select('字号','size',[['100','100%'],['200','200%']])}${select('样例','data',[['normal','正常记录'],['missing','字段缺失'],['empty','无记录'],['baselinezero','基期零'],['referencefail','参照失败'],['chargefail','补能失败'],['insufficient','样本不足'],['stale','旧快照']])}${select('币种','currency',[['CNY','示例CNY'],['none','未配置']])}<a href="?compare=${S.compare?'0':'1'}">${S.compare?'回到交互评审':'三个方向并排 ↗'}</a><a href="renders/index.html">静态图册 ↗</a></div>`;}
function aside(){return `<aside class="aside"><p class="eyebrow">DESIGN INTENT / ${S.variant}</p><h2>${VARIANTS[S.variant].name}</h2><p>${VARIANTS[S.variant].why}</p><div class="annotation"><div class="counter">01 / 五秒内有主线</div><h3>结果先行，证据紧随。</h3><p>只突出一个主数字。比较是自己的同进度，副读数交代电耗与已知支出；主图在首屏完整出现。</p></div><div class="annotation"><div class="counter">02 / 内容有层级</div><h3>不是把更多卡片摆进来。</h3><p>节奏、条件、账目、长期分章。手机内可以切专题、选点、点日、点分组和地点；右侧预览展示能耗专题。</p></div><div class="annotation"><div class="counter">03 / 结论有边界</div><h3>看见数据，也看见可信程度。</h3><p>覆盖贴近数值，温度只谈关联，续航估计不叫健康分。失败、基期0、小样本时退回原值。</p></div><div class="capability">${vision()?'<strong>完整方案 ≠ 当前已支持</strong><br>配对驾驶覆盖、分位数、条件分组、长期和停放待补接口。充电覆盖/均价/地点已具备。':'<strong>仅现有0.2接口</strong><br>显示日桶与参照原值、完整驾驶指标、费用覆盖、分类及地点。隐藏条件分布与长期模型，不输出强比较结论。'}<br>所有数字、地点均为合成，非真实站点。</div><a class="spec-link" href="../../product/statistics-expansion-proposal.md">完整产品方案 ↗</a></aside>`;}
function render(){const scroll={};document.querySelectorAll('[data-scroll]').forEach(el=>scroll[el.dataset.scroll]=el.scrollTop);const d=F();document.body.className=S.export?`export ${S.full?'full':''}`:'';document.getElementById('app').innerHTML=`<div class="studio"><header class="studio-head"><div><p class="eyebrow">MILEAF / 湖畔 / STATISTICS / 2026.10.28</p><h1>让一段时间的用车，有结论。</h1><p>三个内容方向，共用一份合成记录。先评审产品表达与层级，再决定正式实施范围。手机内可真实滚动和操作。</p></div><span class="badge">设计原型 · 待评审 · 非Flutter</span></header>${toolbar()}<div class="workspace ${S.compare?'comparison':''}">${S.compare?Object.keys(VARIANTS).map(k=>`<div><div class="caption">${k} / ${VARIANTS[k].name}<br>${VARIANTS[k].tag}</div>${phone(k,'home',d)}</div>`).join(''):`<div><div class="caption"><span>${S.variant} / ${VARIANTS[S.variant].name} · 可操作整页</span><span>360 × 800</span></div>${phone(S.variant,S.screen,d)}</div><div class="preview"><div class="caption"><span>同一份数据 / 能耗专题预览</span><span>可滚动</span></div>${phone(S.variant,'energy',d,true)}</div>${aside()}`}</div><div class="switcher" aria-label="原型方向切换">${btn('←','variant',-1,'','aria-label="上一个方向"')}<span class="current">${S.variant} · ${VARIANTS[S.variant].name}<small>${S.variant==='A'?'推荐':''}</small></span>${btn('→','variant',1,'','aria-label="下一个方向"')}</div></div>`;document.querySelectorAll('[data-scroll]').forEach(el=>{el.scrollTop=scroll[el.dataset.scroll]||0;});}
function sync(){const q=new URLSearchParams(location.search);for(const k of ['variant','mode','theme','size','data','period','currency','screen'])q.set(k,S[k]);history.replaceState(null,'','?'+q.toString());}
function act(action,value,el){
  const d=F();
  S.sheetPhone=el.closest('[data-phone]')?.dataset.phone||S.variant;
  if(action==='variant'){const a=Object.keys(VARIANTS);S.variant=a[(a.indexOf(S.variant)+Number(value)+a.length)%a.length];S.screen='home';S.sheet=null;}
  else if(action==='topic'){S.screen=value;S.sheet=null;S.point=0;}
  else if(action==='period'){S.period=value;S.point=0;S.day=F().days.at(-1).day;S.sheet=null;}
  else if(action==='metric'){S.metric=value;}
  else if(action==='point'||action==='step'){
    const key=el.dataset.chart,prop=key==='range'?'rangePoint':key==='temp'?'temp':'point',max=key==='range'?5:key==='temp'?3:d.days.length-1;
    S[prop]=Math.max(0,Math.min(max,action==='step'?S[prop]+Number(value):Number(value)));
  }else if(action==='retry'){S.data='normal';S.sheet=null;}
  else if(action==='close'){S.sheet=null;}
  else if(action==='toggle-reference'){S.reference=!S.reference;S.sheet=null;}
  else {S.sheet={kind:action,value};if(action==='day')S.day=Number(value);}
  sync();render();
  if(['topic','period','variant','retry'].includes(action))document.querySelectorAll('[data-scroll]').forEach(el=>el.scrollTop=0);
}
document.addEventListener('click',e=>{const el=e.target.closest('[data-action]');if(!el||el.disabled)return;act(el.dataset.action,el.dataset.value,el);});
document.addEventListener('change',e=>{const key=e.target.dataset.setting;if(!key)return;S[key]=e.target.value;if(key==='mode'&&!vision())S.screen='home';S.sheet=null;sync();render();});
document.addEventListener('keydown',e=>{if(e.key==='Escape'){S.sheet=null;render();return;}if(!['ArrowLeft','ArrowRight'].includes(e.key)||e.target.closest('input,textarea,select,[contenteditable],.chart,.readout-controls'))return;e.preventDefault();act('variant',e.key==='ArrowLeft'?-1:1,e.target);});
render();

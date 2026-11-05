/* THROWAWAY: three information architectures within the approved Lake theme.
 * Synthetic fixtures only. No API, persistence, production code or inference model.
 */
(() => {
  const q = new URLSearchParams(location.search);
  const allowed = (key, values, fallback) => values.includes(q.get(key)) ? q.get(key) : fallback;
  const state = {
    variant: allowed('variant', ['A','B','C'], 'A'),
    theme: allowed('theme', ['light','dark'], 'light'),
    capability: allowed('capability', ['available','vision'], 'available'),
    sample: allowed('sample', ['normal','missing','empty','stale'], 'normal'),
    period: allowed('period', ['month','week'], 'month'),
    metric: allowed('metric', ['distance','net','energy','charge','cost'], 'distance'),
    scale: allowed('scale', ['100','200'], '100'),
    page: 'overview', point: null, points: {}, modal: null,
  };
  const names = {A:'用车简报', B:'沿途手账', C:'能量账本'};
  const captions = {A:'车况、使用、补能，一眼看全',B:'围绕最近发生的用车生活',C:'先理解驾驶消耗与补能花费'};
  const raw = [32.4,48.6,0,62.5,54.8,35.2,108.3,0,42.6,38.9,55.4,96.7,31.2,0,64.8,47.5,39.6,82.4,25.8,0,52.6,44.3,57.8,69.5,32.9,74.8];
  const net = [155,148,null,162,158,147,168,null,151,145,158,174,150,null,159,155,148,165,150,null,153,152,161,162,145,154];
  const charging = {2:22.5,5:28,8:24,11:30,14:13,17:25,20:20.7,23:43.5,25:28};
  const modes = {2:'AC',5:'AC',8:'AC',11:'DC',14:'DC',17:'DC',20:'unknown',23:'AC',25:'DC'};
  const costs = {2:18,5:22.4,8:null,11:24,14:0,17:20,20:23,23:56.6,25:22.4};
  const rows = raw.map((distance,i) => ({day:i+1,distance,net:net[i],energy:distance===0?0:net[i]===null?null:distance*net[i]/1000,charge:charging[i+1]??0,mode:modes[i+1],cost:Object.hasOwn(costs,i+1)?costs[i+1]:0}));
  const sum = values => values.reduce((a,b)=>a+(b??0),0);
  const num = (n, digits=1) => n===null ? '—' : n.toLocaleString('en-US',{minimumFractionDigits:digits,maximumFractionDigits:digits});
  const iconPaths = {
    leaf:'<path d="M12 3c-3 3-3 6 0 8 3-2 3-5 0-8Z"/><path d="M3 10c1 7 4 10 9 11-1-7-4-10-9-11Zm18 0c-1 7-4 10-9 11 1-7 4-10 9-11Z"/>',
    home:'<path d="m3 11 9-8 9 8M6 9v12h12V9M10 21v-7h4v7"/>',
    car:'<path d="m5 5-2 8v7h3v-3h12v3h3v-7l-2-8Zm-2 8h18M7 9h10"/><path d="M6 14h2m8 0h2"/>',
    bolt:'<path d="m13 2-8 12h6l-1 8 9-13h-6l1-7Z"/>',
    chart:'<path d="M4 21V12h4v9m3 0V4h4v17m3 0V8h4v13"/>',
    chevron:'<path d="m8 10 4 4 4-4"/>',
    settings:'<path d="m10 3-1 3-3 1-3 3 2 3v4l4 1 2 3 3-2 4-1 1-4 2-3-3-3-4-1-1-2Z"/><circle cx="12" cy="12" r="3"/>',
    refresh:'<path d="M20 7v5h-5M20 12a8 8 0 1 0-2 6"/>',
    spark:'<path d="m12 3 2.4 6.6L21 12l-6.6 2.4L12 21l-2.4-6.6L3 12l6.6-2.4Z"/>',
  };
  const icon = name => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${iconPaths[name]||iconPaths.chart}</svg>`;
  const action = (type,value='') => `data-action="${type}" data-value="${value}"`;
  const vision = () => state.capability==='vision';
  const empty = () => state.sample==='empty';
  const selectedRows = () => state.period==='month' ? rows : rows.slice(-7);
  function totals() {
    if (empty()) return {distance:0,energy:0,net:null,charge:0,cost:0,sessions:0,drives:0,ac:0,dc:0,share:null,price:null};
    const data = selectedRows(), distance=sum(data.map(x=>x.distance)), energy=sum(data.map(x=>x.energy));
    const ac=sum(data.filter(x=>x.mode==='AC').map(x=>x.charge)),dc=sum(data.filter(x=>x.mode==='DC').map(x=>x.charge));
    const cost=sum(data.map(x=>x.cost)),knownEnergy=sum(data.filter(x=>x.cost!==null).map(x=>x.charge));
    return {distance,energy:state.sample==='missing'?null:energy,net:state.sample==='missing'?null:1000*energy/distance,charge:sum(data.map(x=>x.charge)),cost:state.sample==='missing'?null:cost,sessions:state.period==='month'?9:3,drives:state.period==='month'?46:12,ac,dc,share:100*dc/(ac+dc),price:state.sample==='missing'?null:cost/knownEnergy};
  }
  const periodTitle = () => state.period==='month'?'本月':'近 7 天';
  const periodDates = () => state.period==='month'?'10月1日—26日 18:40':'10月20日—26日 18:40';
  function periodSwitch() {return `<div class="period-switch" aria-label="统计区间">${['month','week'].map(p=>`<button ${action('period',p)} class="${state.period===p?'active':''}" aria-pressed="${state.period===p}">${p==='month'?'本月':'近7天'}</button>`).join('')}</div>`;}
  function ring() {
    return `<div class="ring" role="img" aria-label="最近采样电量68%"><svg viewBox="0 0 74 74"><circle cx="37" cy="37" r="31" fill="none" stroke="var(--line)" stroke-width="5"/><circle cx="37" cy="37" r="31" fill="none" stroke="var(--accent)" stroke-width="5" stroke-linecap="round" stroke-dasharray="132.45 194.78"/></svg><strong>68<span style="font-size:.65em">%</span></strong><small>电量</small></div>`;
  }
  function statusCard() {return `<section class="card compact-status"><div><p class="status-title"><i class="dot"></i>${state.sample==='stale'?'最近状态 · 休眠':'最近状态 · 在线'}</p><div class="status-main"><strong>320</strong><span>km · 额定续航</span></div><p class="status-note">${state.sample==='stale'?'采样 10月25日 21:10':'采样 10月26日 18:38'} · 非实时车况</p></div>${ring()}<p class="status-note" style="grid-column:1/-1;border-top:1px solid var(--line);padding-top:6px">今日 ${empty()?"0.0":"74.8"} km · ${empty()?"0":"2"} 次行程 · 估算消耗 ${empty()?"0.0":"11.5"} kWh</p></section>`;}
  const sectionHead = (title,button='') => `<div class="section-head"><h2>${title}</h2>${button}</div>`;
  const link = (text,page) => `<button class="quiet-button" ${action('page',page)}>${text} ↗</button>`;
  function metric(label,value,unit,foot,key) {return `<button class="metric ${state.metric===key?'active':''}" ${action('metric',key)} aria-pressed="${state.metric===key}"><span class="metric-label">${label}</span><span class="metric-value">${value}<span class="unit">${unit}</span></span><span class="metric-foot" style="display:block">${foot}</span></button>`;}
  function metrics() {
    const t=totals();
    return `<section class="metric-grid">${metric('驾驶里程',num(t.distance),'km',`${t.drives} 次行程`,'distance')}${metric('驾驶净电耗 · 估算',num(t.net,0),'Wh/km','点按查看电耗变化','net')}${metric('充入电池',num(t.charge),'kWh',`${t.sessions} 次充电`,'charge')}${metric('已知充电费用',num(t.cost),'CNY','仅含费用已知记录','cost')}</section>`;
  }
  const chartInfo = {distance:['每日里程','km','distance','bar'],net:['净电耗变化 · 估算','Wh/km','net','line'],energy:['每日驾驶消耗 · 估算','kWh','energy','bar'],charge:['每日充入电池','kWh','charge','bar'],cost:['每日已知充电费用','CNY','cost','bar']};
  function plot(id,values,labels,unit,type='bar',second=null,customTicks=null) {
    if(empty()) return `<div class="empty"><strong>这个区间还没有记录</strong><span>电耗、均价保持未知；有记录后再显示趋势。</span></div>`;
    if(values.every(v=>v===null)) return '<div class="empty"><strong>还没有可用的电耗采样</strong><span>驾驶里程仍可查看；缺失值不补为零。</span></div>';
    const arr=values;
    const index=Math.min(state.points[id]??arr.length-1,arr.length-1), W=298,H=140,L=28,R=9,T=10,B=24;
    const valid=[...arr,...(second||[])].filter(v=>v!==null), lo=Math.min(0,...valid), hi=unit==='%'?100:Math.max(1,...valid)*1.12;
    const x=i=>L+6+i*(W-L-R-12)/Math.max(1,arr.length-1),y=v=>T+(hi-v)/(hi-lo)*(H-T-B),z=y(0);
    const tickVal=[hi,(hi+lo)/2,lo];
    const grid=tickVal.map(v=>`<line x1="${L}" x2="${W-R}" y1="${y(v)}" y2="${y(v)}" class="grid-line"/><text x="${L-5}" y="${y(v)+3}" text-anchor="end">${num(v,Math.abs(v)<5?1:0)}</text>`).join('');
    const ticks=customTicks??[0,Math.floor((arr.length-1)/2),arr.length-1];
    const axis=ticks.map((i,k)=>`<text x="${x(i)}" y="${H-6}" text-anchor="${k===0?'start':k===ticks.length-1?'end':'middle'}">${labels[i]}</text>`).join('');
    function line(series,secondary=false){let p='',start=true;series.forEach((v,i)=>{if(v===null){start=true;return;}p+=`${start?'M':'L'}${x(i)},${y(v)} `;start=false;});return `<path class="series-line ${secondary?'secondary':''}" d="${p}"/>${series.map((v,i)=>v===null?'':`<circle cx="${x(i)}" cy="${y(v)}" r="1.7" fill="var(--${secondary?'amber':'accent'})"/>`).join('')}`;}
    const bw=Math.min(15,(W-L-R)/arr.length*.66);
    const bars=arr.map((v,i)=>v===null?'':v===0?`<circle cx="${x(i)}" cy="${z}" r="1.5" fill="var(--sub)"/>`:`<rect class="bar ${i===index?'selected':''}" x="${x(i)-bw/2}" y="${Math.min(z,y(v))}" width="${bw}" height="${Math.abs(z-y(v))}" rx="2"/>`).join('');
    const v=arr[index];
    return `<svg class="chart" viewBox="0 0 ${W} ${H}" role="img" aria-label="${id}，${labels[index]}，${v===null?'缺失':num(v)+' '+unit}">${grid}${type==='line'?line(arr):bars}${second?line(second,true):''}<line x1="${x(index)}" x2="${x(index)}" y1="${T}" y2="${H-B}" stroke="var(--sub)" stroke-dasharray="2 3" stroke-width=".7"/>${axis}${arr.map((v,i)=>`<rect ${action('point',id+':'+i)} x="${x(i)-(W-L-R)/arr.length/2}" y="${T}" width="${(W-L-R)/arr.length}" height="${H-T-B}" fill="transparent"><title>${labels[i]}：${v===null?'缺失':num(v)+' '+unit}</title></rect>`).join('')}</svg><div class="readout" aria-live="polite"><span>${labels[index]} <strong>${v===null?'—（缺失）':num(v)+' '+unit}${second?` / ${second[index]===null?'—':num(second[index])} ${unit}`:''}</strong></span><div class="steps"><button ${action('step',id+':-1:'+arr.length)} aria-label="前一个读数" ${index===0?'disabled':''}>‹</button><button ${action('step',id+':1:'+arr.length)} aria-label="后一个读数" ${index===arr.length-1?'disabled':''}>›</button></div></div>`;
  }
  function trend(key=state.metric,cls='') {
    const [title,unit,field,type]=chartInfo[key],data=selectedRows();
    const values=data.map(r=>state.sample==='missing'&&['net','energy','cost'].includes(field)?(field==='net'?null:field==='energy'?(r.distance===0?0:null):(r.charge>0?null:0)):r[field]);
    return `<section class="card chart-card ${cls}"><div class="chart-heading"><div><h3>${title}</h3><p>${periodDates()} · 按日</p></div><span class="chart-unit">${unit}</span></div>${plot(title,values,data.map(r=>`10/${r.day}`),unit,type)}${key==='cost'?'<p class="footnote">缺失费用留空，已知零费用保留为 0。</p>':''}</section>`;
  }
  function insights() {
    if(empty())return '';
    const t=totals(),baseline=166,reference=state.period==='month'?'9月1日—26日 18:40':'10月13日—19日 18:40';
    if(t.net===null)return '<section class="insight"><h3>电耗样本不足，暂不作区间比较</h3><p>里程与补能记录仍可分别查看。</p></section>';
    return `<section class="insight"><div class="insight-top">${icon('spark')} 一条有参照的变化</div><h3>估算净电耗比前一同长区间低 ${num(baseline-t.net,0)} Wh/km</h3><p>本期 ${num(t.net,0)}，基期 ${baseline} Wh/km。<br>基期 ${reference}，同一归期时区。</p><p>样本覆盖率尚不可核验，不直接判断驾驶更省电。</p><button class="text-link" ${action('help','comparison')}>查看比较依据 →</button></section>`;
  }
  function energyCard(){const t=totals();return `<section class="card"><div class="topline"><h3>驾驶消耗</h3>${link('驾驶统计','driving')}</div><div class="two-numbers"><div><p>估算消耗</p><strong class="metric-value">${num(t.energy)}<span class="unit">kWh</span></strong></div><div><p>净电耗 · 估算</p><strong class="metric-value">${num(t.net,0)}<span class="unit">Wh/km</span></strong></div></div><button class="text-link" ${action('metric','energy')}>查看每日驾驶消耗 →</button><details class="data-details"><summary>毛电耗与计算口径</summary><p class="footnote">区间毛电耗 ${num(empty()?null:1000*t.charge/t.distance,0)} Wh/km：充入电池能量 ÷ 驾驶里程。受补能时点影响，不等同于网侧电耗；与净电耗的差不能解释为停车损耗。</p><p class="footnote">净电耗由续航差和车辆效率估算；缺少有效能量样本覆盖率，暂不作“比别人更省电”的评价。</p></details></section>`;}
  function chargingCard() {
    const t=totals(),max=Math.max(1,t.ac,t.dc);
    return `<section class="card"><div class="topline"><h3>补能账本</h3>${link('充电统计','charging')}</div><div class="two-numbers"><div><p>${periodTitle()}充入电池</p><strong class="metric-value">${num(t.charge)}<span class="unit">kWh</span></strong><p>${t.sessions} 次充电</p></div><div><p>已知费用均价</p><strong class="metric-value">${num(t.price,2)}<span class="unit">CNY/kWh</span></strong><p>仅费用已知的会话</p></div></div><div class="energy-bars"><div class="energy-row"><span>AC</span><div class="energy-track"><div class="energy-fill" style="width:${100*t.ac/max}%"></div></div><strong>${num(t.ac)} kWh</strong></div><div class="energy-row"><span>DC</span><div class="energy-track"><div class="energy-fill secondary" style="width:${100*t.dc/max}%"></div></div><strong>${num(t.dc)} kWh</strong></div></div><p class="footnote">DC 占已知分类能量 ${num(t.share)}%。<br>AC/DC 仅含已知分类，不能代表全部补能。</p>${vision()&&!empty()?`<p class="footnote"><span class="tag">愿景示例</span> 费用已记录 ${state.period==="month"?"8 / 9":"3 / 3"} 次；完整度需新增统计字段。</p>`:''}<button class="text-link" ${action('page','charging')}>查看补能与费用变化 →</button></section>`;
  }
  function records(){return `<section>${sectionHead('最近记录',link('全部记录','records'))}<div class="card records">${empty()?'<div class="empty"><strong>尚无行程或充电记录</strong><span>同步到记录后，这里会显示最近活动。</span></div>':`<button class="record" ${action('page','drive')}><span class="time">最近行程 · 10月26日 17:52</span><p class="record-title">最近一次行程 ↗</p><div class="record-bottom"><span><strong>32.9</strong> km</span><span>净电耗 <strong>145</strong> Wh/km</span></div></button><button class="record" ${action('page','charge')}><span class="time">最近充电 · 10月25日 20:12</span><p class="record-title">充入 <strong>28.0 kWh</strong> ↗</p><div class="soc-track"></div><div class="soc-labels"><span>24%</span><span>80% · 结束电量</span></div></button>`}</div></section>`;}
  function visionCards(){
    if(!vision()) return '';
    if(empty()) return '<section class="card"><span class="tag">愿景 · 待接数据</span><div class="empty"><strong>还没有可回看的历史记录</strong><span>有有效采样后，再展示电量历史与停放变化。</span></div></section>';
    return `<section>${sectionHead('不只是驾驶，还想看懂停放','<span class="tag">愿景 · 待接数据</span>')}<div class="card chart-card"><div class="chart-heading"><div><h3>最近 24 小时电量</h3><p>行程与补能，放在同一条时间线上</p></div><span class="chart-unit">%</span></div>${plot('电量历史',[24,80,79,null,79,74,74,73,68],['昨18:40','21:40','00:40','03:40','06:40','09:40','12:40','15:40','18:40'],'%','line')}<p class="footnote">昨20:12 补能 ↑ · 今07:50 行程 ↓ · 17:52 行程 ↓。<br>合成事件与采样；缺口断开，需跨记录历史接口。</p></div></section><section class="card"><div class="topline"><h3>最近一次完整停放</h3><span class="tag">愿景示例</span></div><div class="two-numbers"><div><p>8小时20分</p><strong class="metric-value">−1<span class="unit">百分点</span></strong></div><div><p>采样电量变化</p><strong class="metric-value">80→79<span class="unit">%</span></strong></div></div><p class="footnote">这是停放前后的采样变化，不能归因为哨兵、空调或电池故障。缺有效边界采样时不出结论。</p><button class="text-link" ${action('page','parking')}>了解停放期间的电量变化 →</button></section><section class="card"><div class="topline"><h3>长期续航观察</h3><span class="tag">愿景示例</span></div><p class="footnote">优先看多周投影续航与样本覆盖，不用单次续航给电池打分。</p><button class="text-link" ${action('page','battery')}>查看长期趋势与估算依据 →</button></section>`;
  }
  function metadata(){return `<details class="data-details"><summary>车辆资料与数据时间</summary><dl><dt>里程表</dt><dd>32,418 km</dd><dt>当前固件</dt><dd>2026.32.6</dd><dt>归期时区</dt><dd>Asia/Shanghai</dd><dt>原型基准时间</dt><dd>10月26日 18:40</dd></dl><p>所有数值为固定合成样例；币种示例显式选 CNY。采样旧不直接判定车辆异常。</p></details>`;}
  function notices(){return state.sample==='stale'?`<div class="inline-notice">刷新未成功，保留上次快照。<button ${action('retry')}>重试示例</button></div>`:state.sample==='missing'?'<div class="inline-notice">部分数据缺失；能量和费用保留未知。</div>':'';}
  function variantA(){return `${statusCard()}${sectionHead('这段时间的用车',periodSwitch())}<p class="period-note">${periodDates()} · 点按指标看趋势</p>${metrics()}${trend()}${insights()}${sectionHead('看懂消耗与补能')}${energyCard()}${chargingCard()}${visionCards()}${records()}${metadata()}`;}
  function variantB(){const t=totals();return `<section class="journal-head"><p class="journal-date">2026 / 10 / 26 · 星期一</p><h2>每一段路，<br>都留下了一点故事。</h2><div class="journal-stats"><div><strong>${empty()?'0.0':'74.8'}<span class="unit">km</span></strong><small>今日里程 · ${empty()?0:2} 次行程</small></div><div><strong>${empty()?'0.0':'11.5'}<span class="unit">kWh</span></strong><small>今日驾驶消耗 · 估算</small></div></div><div class="journal-status"><span>最近采样 · ${state.sample==='stale'?'休眠':'在线'} · 68%</span><span>额定续航 320 km</span></div><p class="period-note" style="margin-top:8px">车况采样 ${state.sample==='stale'?'10月25日 21:10':'10月26日 18:38'} · 非实时车况</p></section>${sectionHead('用车节奏',periodSwitch())}${trend('distance')}${sectionHead('最近的两段记录',link('全部记录','records'))}<section>${empty()?'<div class="empty"><strong>还没有可回看的记录</strong></div>':`<div class="timeline-row"><div class="time">今天<br>17:52</div><div class="timeline-body"><h3>一次行程，32.9 km</h3><p>净电耗 145 Wh/km · 估算</p><button class="text-link" ${action('page','drive')}>回看这次行程 →</button></div></div><div class="timeline-row"><div class="time">昨天<br>20:12</div><div class="timeline-body"><h3>一次补能，充入 28.0 kWh</h3><p>结束电量 80%</p><button class="text-link" ${action('page','charge')}>回看充电过程 →</button></div></div><p class="footnote">只展示最近记录，完整历史进入记录页。</p>`}</section>${sectionHead('把这段时间连起来')}<section class="metric-grid">${metric('驾驶净电耗 · 估算',num(t.net,0),'Wh/km','点按看趋势','net')}${metric('已知充电费用',num(t.cost),'CNY','仅含费用已知记录','cost')}</section>${state.metric!=='distance'?trend():''}${chargingCard()}${visionCards()}${metadata()}`;}
  function variantC(){const t=totals();return `${statusCard()}<section class="ledger-hero"><div class="section-head"><h2>能量与花费</h2>${periodSwitch()}</div><p class="ledger-title">${periodTitle()}已知充电费用 · CNY</p><p class="big-figure">${num(t.cost)}</p><p class="footnote">${periodDates()} · 仅含费用已知记录</p><div class="ledger-strip"><div><strong>${num(t.energy)}</strong><p>驾驶消耗 kWh · 估算</p></div><div><strong>${num(t.charge)}</strong><p>充入电池 kWh</p></div><div><strong>${num(t.net,0)}</strong><p>净电耗 Wh/km</p></div></div></section>${trend('net','ledger-chart')}<section class="insight"><h3>驾驶消耗和补能，分别看才清楚</h3><p>补能可能在行程之前或之后；本期补入与本期消耗的差额，不代表停车损耗。</p><button class="text-link" ${action('help','energy')}>了解能量口径 →</button></section>${chargingCard()}${sectionHead('驾驶的另一面',link('驾驶统计','driving'))}<section class="metric-grid">${metric('驾驶里程',num(t.distance),'km',`${t.drives} 次行程`,'distance')}${metric('驾驶消耗 · 估算',num(t.energy),'kWh','点按看每日消耗','energy')}</section>${trend(state.metric==='distance'?'distance':'energy')}${visionCards()}${records()}${metadata()}`;}
  function detailPage() {
    const p=state.page,t=totals();
    const heading={driving:'驾驶记录与效率',charging:'补能与已知费用',records:'最近记录',drive:'10月26日 · 最近行程',charge:'10月25日 · 最近充电',parking:'停放期间，电量怎样变化',battery:'长期续航观察'}[p];
    const back=`<button class="back" ${action('page','overview')}>‹ 返回概览</button><h2 class="page-title">${heading}</h2><p class="period-note">下钻路径演示 · 固定合成样例</p>`;
    if(p==='drive')return `${back}<section class="card"><p class="footnote">行程详情预览</p><p class="big-figure">32.9<span class="unit">km</span></p><p class="footnote">17:52 开始 · 净电耗145 Wh/km（估算）</p></section><section class="card"><h3>地图与速度曲线</h3><p class="footnote">正式 App 已有该入口；本次仅评审概览如何引导至详情，不伪造地点或地图。</p></section>`;
    if(p==='charge')return `${back}<section class="card"><h3>充入电池 28.0 kWh</h3><div class="soc-track"></div><div class="soc-labels"><span>24%</span><span>80%</span></div><p class="footnote">起止电量区间，不表示连续采样过程。正式详情已有功率曲线与记录明细。</p></section>`;
    if(p==='parking'||p==='battery')return `${back}<section class="card"><span class="tag">愿景 · 需要新数据契约</span><h3 style="margin-top:15px">${p==='parking'?'先有完整边界，再解释停放':'先观察趋势，再讨论估算'}</h3><p class="footnote">${p==='parking'?'需要停放起止、相邻驾驶/充电边界、有效SOC采样、低温与缺口规则。不从净毛电耗差推导。':'需要跨记录续航/电量样本、同口径参考线、估算模型版本与覆盖情况。不以历史最高估计值直接代表新车状态。'}</p></section>`;
    if(p==='records')return `${back}${records()}`;
    return `${back}${periodSwitch()}<p class="period-note" style="margin-top:10px">${periodDates()}</p>${p==='charging'?`${chargingCard()}${trend('charge')}${trend('cost')}`:`${energyCard()}${trend(['net','energy'].includes(state.metric)?state.metric:'distance')}<section class="card"><p class="footnote">总里程 ${num(t.distance)} km · ${t.drives} 次行程；使用服务端 totals，不平均每日电耗。</p></section>`}`;
  }
  function sheet(){if(!state.modal)return '';const content=state.modal==='comparison'?'比较使用同一车辆、同一Asia/Shanghai归期时区、同长日历窗口及当地截止时刻。本原型基期电耗166Wh/km为固定合成样例；真实产品需额外stats查询。费用未知、分母为零或样本不足时不输出百分比，也不推断变化原因。':state.modal==='energy'?'驾驶消耗按续航差与车辆效率估算；充入电池来自充电会话。两者归期与覆盖不同，不能相减得到停车损耗。':state.modal==='vehicle'?'当前为固定的「行笺测试车」合成数据。正式 App 已支持车辆切换；本次仅评审概览的信息结构，不连接真实车辆。':'本次原型不演示设置变更。沿用正式 App 的连接、车辆和本地币种设置。';return `<div class="modal-cover"><section class="sheet" role="dialog" aria-modal="true" aria-label="原型说明"><button class="quiet-button" ${action('close')}>关闭 ×</button><h2>${state.modal==='energy'?'驾驶与补能的口径':'原型入口说明'}</h2><p>${content}</p></section></div>`;}
  function phone(variant) {return `<div class="device-wrap"><div class="device-label"><span>${variant} · ${names[variant]}${variant==='A'?' · 推荐':''}</span><span>360 × 800 · ${state.theme==='light'?'浅色':'深色'}</span></div><article class="phone ${state.theme==='dark'?'dark':''} ${state.scale==='200'?'large':''}" data-variant="${variant}"><div class="statusbar"><span>18:40</span><span>●●● ▰</span></div><div class="screen"><header class="app-header"><div class="app-brand">${icon('leaf')}行笺</div><button class="quiet-button vehicle" ${action('help','vehicle')}>行笺测试车 ${icon('chevron')}</button><div class="header-actions"><button class="quiet-button" ${action('retry')} aria-label="刷新原型示例">${icon('refresh')}</button><button class="quiet-button" ${action('help','settings')} aria-label="设置入口说明">${icon('settings')}</button></div></header><main class="content">${notices()}${state.page==='overview'?({A:variantA,B:variantB,C:variantC}[variant])():detailPage()}</main></div><nav class="app-nav" aria-label="应用导航">${[['home','概览','overview'],['car','行程','driving'],['bolt','充电','charging'],['chart','统计','driving']].map(([i,label,page])=>`<button class="nav-item ${state.page===page&&label!=='统计'?'active':''}" ${action('page',page)}><span class="nav-icon">${icon(i)}</span><span>${label}</span></button>`).join('')}</nav>${sheet()}</article></div>`;}
  const options = (id,label,values) => `<div class="control"><label for="${id}">${label}</label><select id="${id}" data-control="${id}">${values.map(([v,n])=>`<option value="${v}" ${state[id]===v?'selected':''}>${n}</option>`).join('')}</select></div>`;
  function sidebar(){return `<aside class="sidebar"><div class="brand">${icon('leaf')}行笺 · 设计室</div><p class="eyebrow">Overview / Product study</p><p class="intro">沿用已选的「湖畔」视觉。<br>这次比较的是信息层级与用户价值，<br>所有数字均为合成样例。</p><div class="variants">${['A','B','C'].map(v=>`<button class="variant ${state.variant===v?'active':''}" ${action('variant',v)}><b>${v}</b><span><strong>${names[v]}${v==='A'?' · 推荐':''}</strong><small>${captions[v]}</small></span></button>`).join('')}</div><div class="controls">${options('capability','能力范围',[['available','现有接口能支持的方案'],['vision','完整愿景 · 含待建能力']])}${options('theme','外观',[['light','湖畔 · 浅色'],['dark','湖畔 · 深色']])}${options('sample','数据状态',[['normal','正常样例'],['missing','部分缺失'],['empty','本期无记录'],['stale','旧快照 / 刷新失败']])}${options('scale','文字大小',[['100','100%'],['200','200% 排版检查']])}</div><p class="scope-note">只做方案与原型，不改 Flutter、不访问真实站点。<br><br><a href="?compare=1">并排看三个结构 ↗</a><br><a href="?variant=A&full=1">查看推荐方案完整长页 ↗</a><br><a href="?variant=A&capture=1">360×800 首屏 ↗</a></p></aside>`;}
  function reviewer(){return `<aside class="reviewer"><p class="eyebrow">Review the idea</p><h2>${state.variant==='A'?'让首页能回答：<br>这段时间，车用得怎样？':state.variant==='B'?'从一条条记录，<br>读懂自己的用车生活。':'把消耗和补能看清，<br>让费用有上下文。'}</h2><p>${captions[state.variant]}。仍以图表、关键数字和下钻为主，减少大车况卡占用。</p><hr><h3>这一屏新增的价值</h3><ul><li>驾驶净电耗与消耗能量</li><li>充入电量、次数、已知费用与均价</li><li>AC/DC 的绝对能量比较</li><li>所有结果都能回到趋势或记录</li></ul><h3>${vision()?'愿景视图的边界':'当前接口视图的边界'}</h3><p>${vision()?'停车变化、跨记录电量历史、费用记录完整度和长期续航均为待建能力。示例不构成后端已支持的承诺。':'已有 summary + driving stats；新增 charging stats 请求即可覆盖主要增量。同期对比可复用stats另查基期；此处基期166Wh/km是固定合成样例，并非真实车况结论。'}</p><hr><h3>可操作</h3><p>点四个主数切换趋势；切区间、更换状态；手机内滚动看补能、记录；点入口体验下钻。← → 切换结构。</p><hr><h3>当前评审状态</h3><pre class="state-output">${JSON.stringify({...state,source:'fixed synthetic data',asOf:'2026-10-26T18:40+08:00'},null,2)}</pre></aside>`;}
  function syncUrl(){const url=new URL(location.href);for(const k of ['variant','theme','capability','sample','period','metric','scale'])url.searchParams.set(k,state[k]);history.replaceState(null,'',url);}
  function render(preserve=false){
    const scrolls=preserve?Array.from(document.querySelectorAll('.screen')).map(x=>x.scrollTop):[];
    document.body.className=[q.get('compare')==='1'?'compare':'',q.get('capture')==='1'?'capture':'',q.get('full')==='1'?'full':'',q.get('export')==='1'?'export':''].join(' ');
    document.getElementById('app').innerHTML=`<div class="studio">${sidebar()}<section class="stage"><header class="stage-head"><div><p class="eyebrow">Mileaf / Overview expansion / Proposal</p><h1>概览，应该更懂你的用车生活。</h1><p>三个信息结构，同一套湖畔视觉 · 固定合成样例 · 仅设计评审，尚未实施</p></div><span class="review-tag">${vision()?'完整愿景 · 待建能力有标注':'现有接口范围 · 推荐先做'}</span></header><div class="stage-body">${(q.get('compare')==='1'?['A','B','C']:[state.variant]).map(phone).join('')}${reviewer()}</div></section></div><div class="switcher"><button ${action('cycle',-1)} aria-label="上一个信息结构">←</button><span>${state.variant} · ${names[state.variant]}</span><button ${action('cycle',1)} aria-label="下一个信息结构">→</button></div>`;
    if(preserve)document.querySelectorAll('.screen').forEach((x,i)=>{x.scrollTop=scrolls[i]??0;});
  }
  function cycle(delta){const variants=['A','B','C'];state.variant=variants[(variants.indexOf(state.variant)+delta+3)%3];state.page='overview';state.modal=null;syncUrl();render();}
  document.addEventListener('click',event=>{
    const target=event.target.closest('[data-action]');if(!target)return;
    const {action:type,value}=target.dataset;
    if(type==='cycle'){cycle(Number(value));return;}
    if(type==='variant'){state.variant=value;state.page='overview';state.modal=null;}
    if(type==='period'){state.period=value;state.point=null;state.points={};}
    if(type==='metric'){state.metric=value;state.point=null;state.points={};}
    if(type==='page'){state.page=value;state.point=null;state.points={};state.modal=null;}
    if(type==='point'){const [id,index]=value.split(':');state.points[id]=Number(index);}
    if(type==='step'){const [id,delta,count]=value.split(':');state.points[id]=Math.max(0,Math.min(Number(count)-1,(state.points[id]??Number(count)-1)+Number(delta)));}
    if(type==='help')state.modal=value;
    if(type==='close')state.modal=null;
    if(type==='retry'){state.sample='normal';state.modal=null;}
    syncUrl();render(!['variant','page'].includes(type));
  });
  document.addEventListener('change',event=>{const key=event.target.dataset.control;if(!key)return;state[key]=event.target.value;state.modal=null;state.point=null;state.points={};syncUrl();render();});
  document.addEventListener('keydown',event=>{if(['INPUT','TEXTAREA','SELECT'].includes(event.target.tagName)||event.target.isContentEditable)return;if(event.key==='Escape'){state.modal=null;render(true);}if(event.key==='ArrowLeft'||event.key==='ArrowRight'){event.preventDefault();cycle(event.key==='ArrowLeft'?-1:1);}});
  render();
})();

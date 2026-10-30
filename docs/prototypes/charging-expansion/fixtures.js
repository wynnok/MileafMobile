// PROTOTYPE ONLY. Complete synthetic fixtures; never aggregate a real API's loaded pages.
const CHARGE_CLOCK = '2026-10-27T19:10:00+08:00';
const CHARGE_PLACES = [
  {id:'geofence:1',name:'家 · 地库',short:'家',kind:'AC',x:91,y:174},
  {id:'geofence:2',name:'滨江园区',short:'园区',kind:'AC',x:252,y:99},
  {id:'address:3',name:'湖畔超级充电站',short:'湖畔超充',kind:'DC',x:212,y:215},
  {id:'unlocated',name:'地点未记录',short:'未知地点',kind:'未知',x:null,y:null},
];
const chargeRows = [
  [301,'10-27T13:12',34,46.8,49.5,18,82,71.28,'DC',2],
  [300,'10-25T23:10',260,28.6,32.1,41,80,14.30,'AC',0],
  [299,'10-23T09:10',310,34.2,37.1,33,80,20.52,'AC',1],
  [298,'10-21T23:20',240,24.8,27.9,46,80,12.40,'AC',0],
  [297,'10-18T16:40',31,41.5,43.8,22,79,62.25,'DC',2],
  [296,'10-16T22:40',270,29.4,33.0,40,80,14.70,'AC',0],
  [295,'10-13T23:00',280,25.6,28.8,45,80,0,'AC',0],
  [294,'10-11T09:15',300,32.8,35.6,35,80,19.68,'AC',1],
  [293,'10-08T23:15',250,26.3,29.6,44,80,13.15,'AC',0],
  [292,'10-05T14:10',30,38.2,40.5,27,79,57.30,'DC',2],
  [291,'10-03T22:50',180,17.8,20.4,55,79,null,'AC',0],
  [290,'10-01T12:10',65,12.6,null,40,58,null,'未知',3],
];
const CHARGE_RECORDS = chargeRows.map(([id,start,duration,added,used,socStart,socEnd,cost,type,place])=>({
  id,start:new Date('2026-'+start+':00+08:00'),end:new Date(Date.parse('2026-'+start+':00+08:00')+duration*60000),
  duration,added,used,socStart,socEnd,cost,type,place:CHARGE_PLACES[place],active:false,
  outsideTemp:23.4,phases:type==='AC'?(place===1?3:1):null,
}));
const CHARGE_ACTIVE = {id:302,start:new Date('2026-10-27T18:50:00+08:00'),end:null,duration:null,added:2.2,used:null,
  socStart:60,socEnd:null,cost:null,type:'AC',place:CHARGE_PLACES[0],active:true,outsideTemp:21.8,phases:1};
// Independent examples of a future raw-charge aggregation response. Grid energy
// uses TeslaMate's separate estimator; it is not the time-weighted charger_power.
const CHARGE_PROCESS_FIXTURES = Object.fromEntries(CHARGE_RECORDS.map(r=>[r.id,{
  powerMax:r.type==='未知'?null:r.id===301?175:r.type==='DC'?151:r.phases===3?11:7,
  powerTimeWeighted:r.type==='未知'?null:r.id===301?87.4:r.type==='DC'?85.5:r.phases===3?7.2:6.3,
}]));
const CHARGE_MAIN_POINTS = [
  [0,8,18],[1,164,20],[3,166,27],[5,150,34],[8,132,43],[11,115,51],[14,96,58],
  [17,79,64],[20,65,69],[23,54,73],[26,42,77],[29,32,80],[32,22,81],[34,0,82],
];
function chargeSamples(record,missing=false){
  if(record.type==='未知') return [];
  const active=record.active;
  const minutes=active?20:record.duration;
  const base=record.id===301?CHARGE_MAIN_POINTS:Array.from({length:14},(_,i)=>{
    const f=i/13;return [Math.round(minutes*f),i===0||i===13?0:record.type==='DC'?145*(1-f*.75):record.phases===3?11:7,
      Math.round(record.socStart+((record.socEnd??63)-record.socStart)*f)];
  });
  return base.map(([minute,power,soc],i)=>({minute,t:new Date(record.start.getTime()+minute*60000),
    power:missing&&(i===5||i===6)?null:power,soc:missing&&i===6?null:soc,
    voltage:record.type==='DC'?Math.round(365+soc*.5):i%4===0?221:220,
    current:record.type==='DC'?Math.round(power*1000/(365+soc*.5)):record.phases===3?16:32,
    temp:Math.round((22.3+Math.sin(i/5)*1.8)*10)/10,
    range:Math.round(soc*4.56),
  }));
}
function chargeFixtureTotals(records){
  const sum=(field,rows=records)=>Math.round(rows.reduce((s,r)=>s+(r[field]??0),0)*100)/100;
  const known=records.filter(r=>r.cost!==null),knownEnergy=sum('added',known);
  const ac=records.filter(r=>r.type==='AC'),dc=records.filter(r=>r.type==='DC');
  return {sessions:records.length,energy:sum('added'),cost:records.length?(known.length?sum('cost'):null):0,
    price:knownEnergy>0?sum('cost')/knownEnergy:null,knownCount:known.length,knownEnergy,
    duration:sum('duration'),ac:sum('added',ac),dc:sum('added',dc),unknown:sum('added',records.filter(r=>r.type==='未知')),
    acDuration:sum('duration',ac),dcDuration:sum('duration',dc)};
}

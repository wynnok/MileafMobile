// Throwaway design fixtures. No real vehicle, API, database or client aggregation.
// Aggregation here manufactures synthetic server responses; it is not a Flutter design.
const CLOCK = '2026-10-28T19:10:00+08:00';
const DISTANCES = [48,76,0,35,246,138,52,24,42,0,62,38,29,44,56,0,168,94,36,48,27,52,45,0,83,51,61,24];
const TRIPS = DISTANCES.flatMap((distance, i) => {
  if (!distance) return [];
  const count = distance > 130 ? 3 : distance > 40 ? 4 : 2;
  const shares = count === 4 ? [.1,.22,.28,.4] : count === 3 ? [.12,.32,.56] : [.42,.58];
  return shares.map((share, j) => {
    const km = distance * share;
    const temp = 11 + (i + j * 3) % 18;
    const consumption = .132 + (km < 10 ? .044 : km < 50 ? .016 : 0) + (temp < 15 ? .015 : 0);
    const duration = Math.round(km / (km > 50 ? 76 : km > 10 ? 43 : 24) * 60);
    return {id:1000+i*10+j, day:i+1, km, energy:km*consumption, duration, temp,
      at:`${j===0?'08':j===1?'12':j===2?'17':'19'}:${String(10+i%4*10).padStart(2,'0')}`,
      start:j%2?'湖畔工作室':'家', end:j%2?'家':km>50?'郊外回程点':'湖畔工作室'};
  });
});
const CHARGES = [
  [2,31.6,21.8,'ac','家',310], [4,27.4,18.91,'ac','家',280],
  [6,48.2,73.26,'dc','途中补能',38], [8,26.8,18.49,'ac','家',270],
  [11,24.6,0,'ac','工作室',240], [13,29.5,20.36,'ac','家',300],
  [16,35.4,null,'unknown','未分类地点',170], [18,51.8,78.74,'dc','途中补能',41],
  [21,28.6,19.73,'ac','家',290], [24,26.3,null,'ac','工作室',260],
  [26,32.2,22.22,'ac','家',330], [28,23.8,16.42,'ac','家',240],
].map(([day,added,cost,type,place,duration],i)=>({id:300+i,day,added,cost,type,place,duration,
  startSoc:20+i%4*5,endSoc:75+i%3*5}));
const PARKING = [18,25,36,48,21,16,30,24,28,40].map((hours,i)=>({
  id:i+1,hours,change:[-1,-1,-1,-2,0,0,-1,-1,-1,-1][i],day:2+i*2,
  sleep:hours*.7,online:hours*.24,offline:hours*.04,unknown:hours*.02,
}));
const LONG_RANGE = [
  {label:'5月',value:438,low:430,high:447,days:8},
  {label:'6月',value:441,low:433,high:449,days:9},
  {label:'7月',value:437,low:428,high:445,days:11},
  {label:'8月',value:440,low:432,high:447,days:9},
  {label:'9月',value:435,low:425,high:444,days:10},
  {label:'10月',value:432,low:422,high:442,days:8},
];
const sum = (items,fn) => items.reduce((n,x)=>n+(fn(x)??0),0);
const median = values => {const a=[...values].sort((a,b)=>a-b);return a.length?(a[(a.length-1)>>1]+a[a.length>>1])/2:null;};
function fixture(period='month',state='normal') {
  const first=period==='week'?26:1;
  const empty=state==='empty';
  const trips=empty?[]:TRIPS.filter(t=>t.day>=first).filter((t,i)=>state!=='insufficient'||i<3).map(t=>state==='missing'&&t.day%4===0?{...t,energy:null}:t);
  const charges=empty?[]:CHARGES.filter(t=>t.day>=first).map(t=>state==='missing'?{...t,cost:null}:t);
  const distance=sum(trips,t=>t.km), valid=trips.filter(t=>t.energy!==null),energy=sum(valid,t=>t.energy);
  const pairedDistance=sum(valid,t=>t.km), net=pairedDistance?energy/pairedDistance*1000:null;
  const costKnown=charges.filter(t=>t.cost!==null),cost=costKnown.length?sum(costKnown,t=>t.cost):charges.length?null:0;
  const added=sum(charges,t=>t.added),costEnergy=sum(costKnown,t=>t.added);
  const days=Array.from({length:29-first},(_,i)=>{
    const day=first+i, ds=trips.filter(t=>t.day===day),cs=charges.filter(t=>t.day===day),vs=ds.filter(t=>t.energy!==null);
    const km=sum(ds,t=>t.km),kmValid=sum(vs,t=>t.km),en=sum(vs,t=>t.energy),known=cs.filter(t=>t.cost!==null);
    return {label:`10/${day}`,day,km,drives:ds.length,energy:ds.length&&!vs.length?null:en,
      net:kmValid?en/kmValid*1000:null, legacyNet:km?en/km*1000:null,
      gross:km?sum(cs,t=>t.added)/km*1000:null,
      added:sum(cs,t=>t.added),cost:known.length?sum(known,t=>t.cost):cs.length?null:0,
      price:sum(known,t=>t.added)?sum(known,t=>t.cost)/sum(known,t=>t.added):null,
      sessions:cs.length,speed:ds.length?Math.max(...ds.map(t=>Math.round(t.km/t.duration*60+18))):null};
  });
  const temps=[10,15,20,25].map(lower=>{
    const group=valid.filter(t=>t.temp>=lower&&t.temp<lower+5),km=sum(group,t=>t.km);
    return {label:`${lower}–${lower+5}°`,lower,drives:group.length,km,energy:sum(group,t=>t.energy),
      value:km?sum(group,t=>t.energy)/km*1000:null,median:median(group.map(t=>t.km))};
  });
  const groups=[[0,10,'短途','<10 km'],[10,50,'中途','10–50 km'],[50,Infinity,'长途','≥50 km']].map(([min,max,label,range])=>{
    const group=trips.filter(t=>t.km>=min&&t.km<max),good=group.filter(t=>t.energy!==null),km=sum(good,t=>t.km);
    return {min,max,label,range,drives:group.length,km:sum(group,t=>t.km),value:km?sum(good,t=>t.energy)/km*1000:null};
  });
  const parking=empty||state==='insufficient'?[]:PARKING.filter(p=>p.day>=first);
  return {trips,charges,days,temps,groups,distance,energy,net,pairedDistance,
    // Legacy API divides estimated energy by all known distance, not paired distance.
    legacyNet:distance?energy/distance*1000:null,
    duration:sum(trips,t=>t.duration),active:new Set(trips.map(t=>t.day)).size,medianKm:median(trips.map(t=>t.km)),
    cost,added,costEnergy,costKnown:costKnown.length,price:costEnergy?cost/costEnergy:null,
    chargeDuration:sum(charges,t=>t.duration),gross:distance?added/distance*1000:null,
    referenceDistance:state==='baselinezero'?0:distance/1.164,
    referenceNet:state==='baselinezero'?null:net===null?null:net+6.2,
    coverage:distance?pairedDistance/distance:null,
    parking,parkedHours:sum(parking,p=>p.hours),parkedChange:parking.length?sum(parking,p=>p.change):null};
}

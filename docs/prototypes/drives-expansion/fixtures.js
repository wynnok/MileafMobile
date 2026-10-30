// THROWAWAY PROTOTYPE. Fixed synthetic data, never a service/database adapter.
// Aggregation here constructs a COMPLETE synthetic stats fixture, independently
// of the visible/paginated list. Production must consume server totals/buckets.
const anchor = new Date('2026-10-27T19:10:00+08:00');
const baseTrips = [
  ['27','08:06','08:52','家','滨江园区',32.6,46,5.22,76,68],
  ['26','18:03','18:48','滨江园区','家',32.1,45,5.01,73,65],
  ['26','07:58','08:41','家','滨江园区',32.4,43,4.92,81,73],
  ['25','14:10','15:36','湖畔营地','家',86.4,86,13.82,57,36],
  ['25','09:30','10:55','家','湖畔营地',84.7,85,12.28,80,61],
  ['24','19:20','19:38','家','运动公园',8.2,18,1.62,70,67],
  ['24','18:36','18:55','运动公园','家',8.0,19,1.51,73,70],
  ['23','17:42','18:26','滨江园区','家',31.9,44,5.10,73,65],
  ['23','08:02','08:46','家','滨江园区',32.3,44,4.91,81,73],
  ['22','18:14','18:59','滨江园区','家',32.1,45,5.20,73,65],
  ['22','08:10','08:58','家','滨江园区',32.6,48,5.38,81,73],
  ['21','18:04','18:50','滨江园区','家',32.5,46,5.13,73,65],
  ['21','08:00','08:42','家','滨江园区',32.4,42,4.86,81,73],
];
const round=(n,d=1)=>Number(n.toFixed(d));
const endpointLocations={'家':[38,146],'滨江园区':[282,28],'湖畔营地':[134,45],'运动公园':[93,103]};
const record=(row,id,month='10')=>{
  const [day,start,end,from,to,km,min,kwh,socStart,socEnd]=row;
  return {id,date:`2026-${month}-${day}`,start,end,from,to,km,min,kwh,
    wh:round(kwh/km*1000),socStart,socEnd,avg:round(km/min*60,1),
    max:88,peak:112,outside:18,inside:22,startPoint:endpointLocations[from],endPoint:endpointLocations[to]};
};
const allTrips=baseTrips.map((row,i)=>record(row,i+1));
for(let day=20;day>=1;day--){
  if([3,4,10,11,17,18].includes(day))continue;
  const km=round(31.8+day%5*.2), kwh=round(km*(150+day%7*2)/1000,2);
  allTrips.push(record([String(day).padStart(2,'0'),'18:03','18:48','滨江园区','家',km,45,kwh,73,65],allTrips.length+1));
  allTrips.push(record([String(day).padStart(2,'0'),'08:06','08:52','家','滨江园区',km,46,kwh,81,73],allTrips.length+1));
}
for(const day of ['30','29','28']){
  allTrips.push(record([day,'18:03','18:48','滨江园区','家',32,45,4.99,73,65],allTrips.length+1,'09'));
  allTrips.push(record([day,'08:06','08:52','家','滨江园区',32,46,4.93,81,73],allTrips.length+1,'09'));
}
const dayDates=Array.from({length:30},(_,i)=>new Date(Date.UTC(2026,8,28+i)).toISOString().slice(0,10));
const minuteOffsets=[0,2,5,8,11,14,17,20,23,26,28,30,33,36,40,44,46];
const speedValues=[0,18,35,52,64,44,68,82,70,58,0,26,54,65,42,16,0];
const elevationValues=[12,14,18,24,28,23,32,40,37,36,24,18,22,20,15,13,12];
const powerValues=[0,18,35,58,72,-18,84,112,36,-32,0,32,57,49,-21,-9,0];
const mapPoints=[[38,146],[49,136],[62,130],[72,115],[86,110],[98,100],[118,95],[139,91],[156,82],[172,78],[184,69],[195,61],[216,59],[236,51],[259,44],[275,39],[282,28]];
const clock=(trip,fraction)=>{
  const [h,m]=trip.start.split(':').map(Number),total=h*60+m+Math.round(trip.min*fraction);
  return `${String(Math.floor(total/60)).padStart(2,'0')}:${String(total%60).padStart(2,'0')}`;
};
function seriesFor(trip,scene){
  const end=trip.socEnd??allTrips.find(r=>r.id===trip.id).socEnd;
  const route=trip.from==='家'&&trip.to==='滨江园区'?mapPoints:trip.from==='滨江园区'&&trip.to==='家'?[...mapPoints].reverse():mapPoints.map((_,i)=>{
    const f=i/(mapPoints.length-1),[sx,sy]=trip.startPoint,[ex,ey]=trip.endPoint;
    return [sx+(ex-sx)*f+Math.sin(f*Math.PI*3)*7,sy+(ey-sy)*f+Math.sin(f*Math.PI*2)*5];
  });
  return minuteOffsets.map((min,i)=>({
    time:clock(trip,min/46),fraction:min/46,
    speed:scene==='missing'&&i===6?null:speedValues[i],
    battery:scene==='missing'&&i>=10?null:Math.round(trip.socStart-(trip.socStart-end)*min/46),
    elevation:elevationValues[i],power:powerValues[i],
    coord:scene==='missing'&&i===10?null:route[i]
  })).filter(p=>!trip.ongoing||p.fraction<=.55);
}
function recordsFor(state){
  if(state.scene==='empty')return [];
  return allTrips.filter(r=>state.period!=='7'||r.date>='2026-10-21')
    .filter(r=>!state.route||r.from+' → '+r.to===state.route)
    .filter(r=>!state.search||(r.from+r.to).includes(state.search))
    .map(r=>state.scene==='missing'&&r.id===1?{...r,kwh:null,wh:null,socEnd:null}:r)
    .map(r=>state.scene==='ongoing'&&r.id===1?{...r,ongoing:true}:r);
}
function statsFixture(state,records){
  const dates=dayDates.slice(state.period==='7'?-7:0),completed=records.filter(r=>!r.ongoing);
  const buckets=dates.map(date=>{
    const rs=completed.filter(r=>r.date===date),km=rs.reduce((a,r)=>a+r.km,0),energy=rs.reduce((a,r)=>a+(r.kwh??0),0);
    return {date,km:round(km),count:rs.length,energy:round(energy,2),wh:km?round(energy/km*1000):null};
  });
  const km=round(completed.reduce((a,r)=>a+r.km,0)),energy=round(completed.reduce((a,r)=>a+(r.kwh??0),0),2);
  if(state.scene==='missing')buckets[buckets.length-1].wh=null;
  return {buckets,km,count:completed.length,energy:state.scene==='missing'?null:energy,
    wh:state.scene==='missing'?null:km?round(energy/km*1000):null};
}

import {imagePlacement} from './geometry.js';

const clamp=(value,min,max)=>Math.max(min,Math.min(max,value));
const midpoint=(a,b)=>({x:(a.x+b.x)/2,y:(a.y+b.y)/2});
const distance=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y);

// Keep the image point under the cursor/fingers fixed while scaling and panning.
function transform(photo,box,start,anchor,destination,zoom){
 const before=imagePlacement(photo.image,box,start);
 photo.zoom=clamp(zoom,1,4);
 const after=imagePlacement(photo.image,box,photo);
 const left=destination.x-(anchor.x-before.x)*after.w/before.w;
 const top=destination.y-(anchor.y-before.y)*after.h/before.h;
 photo.x=after.overflowX>0?clamp((box.x-left)/after.overflowX,0,1):.5;
 photo.y=after.overflowY>0?clamp((box.y-top)/after.overflowY,0,1):.5;
}

export function installCropGestures(canvas,{point,targetAt,selectedTarget,select,changed,enabled}){
 const pointers=new Map();
 let gesture=null;
 function cancel(){
  gesture=null;
  const ids=[...pointers.keys()];pointers.clear();
  for(const id of ids)if(canvas.hasPointerCapture(id))canvas.releasePointerCapture(id);
 }
 function rebase(target){
  const points=[...pointers.values()];
  if(!points.length){gesture=null;return;}
  gesture={...target,start:{zoom:target.photo.zoom,x:target.photo.x,y:target.photo.y},
   anchor:points.length===2?midpoint(...points):points[0],
   distance:points.length===2?distance(...points):0};
 }
 function valid(){
  const current=selectedTarget();
  return enabled()&&gesture&&current?.photo===gesture.photo&&
   ['x','y','w','h'].every(key=>current.box[key]===gesture.box[key]);
 }
 canvas.addEventListener('pointerdown',event=>{
  if(!enabled()||event.button!==0||pointers.size>=2)return;
  const p=point(event);
  if(pointers.size){if(!valid()){cancel();return;}}
  else{
   const target=targetAt(p);if(!target)return;
   select(target.index);gesture=target;
  }
  pointers.set(event.pointerId,p);canvas.setPointerCapture(event.pointerId);
  rebase(gesture);canvas.focus({preventScroll:true});event.preventDefault();
 });
 canvas.addEventListener('pointermove',event=>{
  if(!pointers.has(event.pointerId))return;
  if(!valid()){cancel();return;}
  pointers.set(event.pointerId,point(event));
  const points=[...pointers.values()],g=gesture;
  const anchor=points.length===2?midpoint(...points):points[0];
  const zoom=points.length===2&&g.distance>0?g.start.zoom*distance(...points)/g.distance:g.start.zoom;
  transform(g.photo,g.box,g.start,g.anchor,anchor,zoom);changed();event.preventDefault();
 });
 function finish(event){
  if(!pointers.has(event.pointerId))return;
  if(event.type==='pointercancel'||!valid()){cancel();return;}
  pointers.delete(event.pointerId);
  rebase(gesture);
 }
 for(const type of ['pointerup','pointercancel','lostpointercapture'])canvas.addEventListener(type,finish);
 canvas.addEventListener('wheel',event=>{
  if(!enabled()||pointers.size)return;
  const anchor=point(event),target=targetAt(anchor);if(!target)return;
  event.preventDefault();select(target.index);
  const delta=event.deltaY*(event.deltaMode===1?16:event.deltaMode===2?canvas.clientHeight:1);
  const start={zoom:target.photo.zoom,x:target.photo.x,y:target.photo.y};
  transform(target.photo,target.box,start,anchor,anchor,start.zoom*Math.exp(-clamp(delta,-300,300)*.002));
  changed();
 },{passive:false});
 return cancel;
}

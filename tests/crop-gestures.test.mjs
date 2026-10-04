import test from 'node:test';
import assert from 'node:assert/strict';
import {installCropGestures} from '../dist/crop-gestures.js';
import {imagePlacement} from '../dist/geometry.js';

function editor(){
 const photos=Array.from({length:2},()=>({image:{width:600,height:600},x:.5,y:.5,zoom:1}));
 const boxes=[{x:0,y:0,w:200,h:200},{x:210,y:0,w:200,h:200}];
 const listeners=new Map(),captured=new Set();let selected=0,enabled=true,changes=0;
 const canvas={clientHeight:200,addEventListener(type,fn){listeners.set(type,fn);},focus(){},
  setPointerCapture(id){captured.add(id);},hasPointerCapture:id=>captured.has(id),releasePointerCapture(id){captured.delete(id);}};
 const target=index=>({index,photo:photos[index],box:boxes[index]});
 const cancel=installCropGestures(canvas,{point:e=>({x:e.x,y:e.y}),targetAt:p=>{
  const i=boxes.findIndex(b=>p.x>=b.x&&p.x<=b.x+b.w&&p.y>=b.y&&p.y<=b.y+b.h);return i>=0?target(i):null;
 },selectedTarget:()=>target(selected),select:i=>selected=i,changed:()=>changes++,enabled:()=>enabled});
 return {photos,boxes,cancel,captured,get selected(){return selected;},get changes(){return changes;},
  disable(){enabled=false;},send(type,props={}){const event={type,pointerId:1,button:0,x:100,y:100,deltaY:0,deltaMode:0,preventDefault(){this.prevented=true;},...props};listeners.get(type)(event);return event;}};
}
function contained(photo,box){const p=imagePlacement(photo.image,box,photo);assert.ok(p.x<=box.x+1e-8&&p.y<=box.y+1e-8&&p.x+p.w>=box.x+box.w-1e-8&&p.y+p.h>=box.y+box.h-1e-8);}
const close=(a,b)=>assert.ok(Math.abs(a-b)<1e-8,`${a} != ${b}`);

test('wheel zoom targets only the hovered photo and keeps the cursor anchored',()=>{
 const e=editor(),anchor={x:260,y:70},before=imagePlacement(e.photos[1].image,e.boxes[1],e.photos[1]);
 assert.ok(e.send('wheel',{...anchor,deltaY:-200}).prevented);assert.equal(e.selected,1);assert.equal(e.photos[0].zoom,1);assert.ok(e.photos[1].zoom>1);
 const after=imagePlacement(e.photos[1].image,e.boxes[1],e.photos[1]);
 close((anchor.x-before.x)/before.w,(anchor.x-after.x)/after.w);close((anchor.y-before.y)/before.h,(anchor.y-after.y)/after.h);
 for(let i=0;i<30;i++)e.send('wheel',{...anchor,deltaY:-300});assert.equal(e.photos[1].zoom,4);
 for(let i=0;i<30;i++)e.send('wheel',{...anchor,deltaY:300});assert.equal(e.photos[1].zoom,1);contained(e.photos[1],e.boxes[1]);
 assert.equal(e.send('wheel',{x:205,deltaY:-100}).prevented,undefined);
});
test('pinch stays on the first photo, then transitions back to drag without a jump',()=>{
 const e=editor();e.send('pointerdown',{x:50});e.send('pointerdown',{pointerId:2,x:150});
 e.send('pointermove',{pointerId:2,x:250});assert.equal(e.photos[0].zoom,2);assert.equal(e.photos[1].zoom,1);
 e.send('pointerup',{pointerId:2,x:250});const crop={...e.photos[0]};
 e.send('pointermove',{x:50});assert.deepEqual(e.photos[0],crop);
 e.send('pointermove',{x:30,y:80});assert.notEqual(e.photos[0].x,crop.x);contained(e.photos[0],e.boxes[0]);
 e.send('pointerup');e.send('pointermove',{x:180});assert.equal(e.photos[0].zoom,2);
});
test('cancel, export and geometry changes stop active gestures safely',()=>{
 const e=editor();e.send('pointerdown');e.send('pointerdown',{pointerId:2,x:150});e.send('pointercancel',{pointerId:2});
 e.send('pointermove',{x:0});assert.equal(e.photos[0].zoom,1);assert.equal(e.captured.size,0);
 e.send('pointerdown');e.boxes[0]={x:0,y:0,w:100,h:200};e.send('pointermove',{x:80});assert.equal(e.changes,0);
 e.send('pointerdown',{x:50});e.disable();e.send('pointermove',{x:30});e.send('wheel',{deltaY:-100});assert.equal(e.changes,0);
});
test('pinch at the limits and large pans cannot expose the frame',()=>{
 const e=editor();e.send('pointerdown',{x:60,y:70});e.send('pointerdown',{pointerId:2,x:140,y:130});
 e.send('pointermove',{pointerId:2,x:1500,y:2000});assert.equal(e.photos[0].zoom,4);contained(e.photos[0],e.boxes[0]);
 e.send('pointermove',{pointerId:2,x:61,y:71});assert.equal(e.photos[0].zoom,1);contained(e.photos[0],e.boxes[0]);
 e.cancel();assert.equal(e.captured.size,0);
});

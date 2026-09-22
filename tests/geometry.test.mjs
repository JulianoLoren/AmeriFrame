import test from 'node:test';
import assert from 'node:assert/strict';
import {layouts,polygons,area,frameGeometry,bounds,imagePlacement,outputSize,hit} from '../dist/geometry.js';
test('36 layout families include 12 classic and 24 creative designs with distinct geometry',()=>{
 assert.equal(layouts.length,36);assert.equal(new Set(layouts.map(l=>l[0])).size,36);
 assert.equal(layouts.filter(l=>l[1]==='classic').length,12);assert.equal(layouts.filter(l=>l[1]==='creative').length,24);
 const shapes=layouts.map(([id])=>JSON.stringify(polygons(id,7).map(p=>p.map(v=>v.map(n=>Number(n.toFixed(6)))))));
 assert.equal(new Set(shapes).size,36);
});
test('every layout partitions the canvas into exactly 1–24 non-overlapping convex photo cells',()=>{
 for(const [id] of layouts)for(let n=1;n<=24;n++)for(const ratio of [.2,9/16,1,16/9,5]){
  const cells=polygons(id,n,ratio);assert.equal(cells.length,n,`${id}/${n}`);assert.ok(Math.abs(cells.reduce((s,p)=>s+area(p),0)-1)<1e-8,`${id}/${n} coverage`);
  for(const p of cells){assert.ok(area(p)>0);for(let i=0;i<p.length;i++){const a=p[i],b=p[(i+1)%p.length],c=p[(i+2)%p.length];assert.ok((b[0]-a[0])*(c[1]-b[1])-(b[1]-a[1])*(c[0]-b[0])>=-1e-8,`${id}/${n} convex`);}}
  for(let y=.01371177;y<1;y+=.091)for(let x=.02314159;x<1;x+=.083)assert.equal(cells.filter(p=>hit(p,x,y)).length,1,`${id}/${n} overlap`);
 }
});
test('4K output, safe border insets, and matching preview/export geometry',()=>{
 for(const [id] of layouts)for(const n of [1,2,5,13,24])for(const ratio of [.2,9/16,1,16/9,5])for(const gap of [0,24,120]){
  const {w,h}=outputSize(ratio);assert.equal(Math.max(w,h),3840);const full=frameGeometry(id,n,w,h,gap),preview=frameGeometry(id,n,w/8,h/8,gap/8);
  assert.equal(full.cells.length,n);assert.ok(Math.abs(full.gap-preview.gap*8)<1e-6);
  full.cells.forEach((p,i)=>{assert.ok(area(p)>0,`${id}/${n}/${gap}`);assert.equal(p.length,preview.cells[i].length);p.forEach((v,j)=>v.forEach((z,k)=>assert.ok(Math.abs(z-preview.cells[i][j][k]*8)<1e-5)));});
 }
});
test('zoomed and panned photos always cover each frame without exposed blank areas',()=>{
 for(const image of [{width:400,height:1200},{width:1800,height:500}])for(const [id] of layouts)for(const poly of polygons(id,7))for(const zoom of [1,2,4])for(const x of [0,.5,1])for(const y of [0,.5,1]){
  const b=bounds(poly),p=imagePlacement(image,b,{zoom,x,y});assert.ok(p.x<=b.x+1e-8&&p.y<=b.y+1e-8);assert.ok(p.x+p.w>=b.x+b.w-1e-8&&p.y+p.h>=b.y+b.h-1e-8);
 }
});

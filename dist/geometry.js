export const layouts=[['grid','classic','Lưới','Grid'],['columns','classic','Dọc','Columns'],['rows','classic','Ngang','Rows'],['hero','classic','Tiêu điểm','Spotlight'],['editorial','classic','Tạp chí','Editorial'],['film','classic','Điện ảnh','Cinema'],['brick','creative','Lát gạch','Brickwork'],['mosaic','creative','Khảm','Mosaic'],['diagonal','creative','Đường chéo','Diagonal'],['chevron','creative','Zigzag','Zigzag'],['shards','creative','Pha lê','Prism'],['fan','creative','Cánh quạt','Sunburst']];
const rect=(x,y,w,h)=>[[x,y],[x+w,y],[x+w,y+h],[x,y+h]];
layouts.push(
 ['gallery','classic','Triển lãm','Gallery'],['triptych','classic','Tam liên','Triptych'],
 ['panorama','classic','Toàn cảnh','Panorama'],['shelves','classic','Tầng ảnh','Shelves'],
 ['window','classic','Cửa sổ','Window'],['ribbon','classic','Dải phim','Filmstrip'],
 ['spiral','creative','Xoắn ốc','Spiral'],['pinwheel','creative','Chong chóng','Pinwheel'],
 ['diamond','creative','Kim cương','Diamond'],['facets','creative','Đá quý','Gemstone'],
 ['honeycomb','creative','Tổ ong','Honeycomb'],['constellation','creative','Chòm sao','Constellation'],
 ['origami','creative','Gấp giấy','Origami'],['lightning','creative','Tia chớp','Lightning'],
 ['wave','creative','Sóng','Wave'],['rays','creative','Tia nắng','Sunrays'],
 ['canyon','creative','Hẻm núi','Canyon'],['terraces','creative','Bậc thang','Terraces'],
 ['cross','creative','Giao điểm','Crossroads'],['orbit','creative','Quỹ đạo','Orbit'],
 ['dunes','creative','Cồn cát','Dunes'],['sail','creative','Cánh buồm','Sails'],
 ['burst','creative','Bùng nổ','Supernova'],['weave','creative','Đan lát','Woven']
);

// Bisect convex cells by area so narrow ratios and large photo counts remain usable.
function splitCell(poly,angle,fraction=.5){
 const nx=Math.cos(angle),ny=Math.sin(angle),values=poly.map(([x,y])=>x*nx+y*ny);
 let low=Math.min(...values),high=Math.max(...values);const target=area(poly)*fraction;
 for(let i=0;i<38;i++){const mid=(low+high)/2;if(area(clip(poly,-nx,-ny,-mid))<target)low=mid;else high=mid;}
 const d=(low+high)/2;return [clip(poly,-nx,-ny,-d),clip(poly,nx,ny,d)];
}
function growCells(initial,n,angleFor,fraction=.5){
 const out=[...initial];while(out.length<n){const i=out.reduce((best,p,j)=>area(p)>area(out[best])?j:best,0),b=bounds(out[i]);out.splice(i,1,...splitCell(out[i],angleFor(out.length,b),fraction));}return out;
}
function weightedRows(n,weights,offset=0){
 const rows=Math.min(n,weights.length),total=weights.slice(0,rows).reduce((a,b)=>a+b,0),out=[];let y=0;
 for(let r=0;r<rows;r++){const count=Math.floor(n/rows)+(r<n%rows?1:0),h=weights[r]/total;let x=0;const widths=Array.from({length:count},(_,i)=>1+offset*Math.sin((i+1)*(r+1)*1.8)),sum=widths.reduce((a,b)=>a+b,0);for(const width of widths){const w=width/sum;out.push(rect(x,y,w,h));x+=w;}y+=h;}return out;
}
function spiralCells(n,alternate=false){
 const out=[];let x=0,y=0,w=1,h=1;
 for(let i=0;i<n-1;i++){const f=Math.max(.16,Math.min(.44,1/(Math.sqrt(n-i)+.4))),dir=alternate?(i%2?3:0):i%4;
  if(dir===0){out.push(rect(x,y,w*f,h));x+=w*f;w*=1-f;}
  if(dir===1){out.push(rect(x,y,w,h*f));y+=h*f;h*=1-f;}
  if(dir===2){out.push(rect(x+w*(1-f),y,w*f,h));w*=1-f;}
  if(dir===3){out.push(rect(x,y+h*(1-f),w,h*f));h*=1-f;}
 }out.push(rect(x,y,w,h));return out;
}
function rays(n,cx,cy,rotation){
 if(n===2)return splitCell(rect(0,0,1,1),rotation,.46);
 return Array.from({length:n},(_,i)=>{const a=rotation+i*Math.PI*2/n,b=a+Math.PI*2/n;return clip(clip(rect(0,0,1,1),-Math.sin(a),Math.cos(a),-Math.sin(a)*cx+Math.cos(a)*cy),Math.sin(b),-Math.cos(b),Math.sin(b)*cx-Math.cos(b)*cy);});
}
function voronoi(seeds){return seeds.map((a,i)=>{let p=rect(0,0,1,1);seeds.forEach((b,j)=>{if(i!==j){const nx=a[0]-b[0],ny=a[1]-b[1];p=clip(p,nx,ny,(a[0]**2+a[1]**2-b[0]**2-b[1]**2)/2);}});return p;});}
function seededCells(n,kind){
 const cols=Math.ceil(Math.sqrt(n)),rows=Math.ceil(n/cols);
 const seeds=Array.from({length:n},(_,i)=>{const row=Math.floor(i/cols),col=i%cols;
  if(kind==='honeycomb')return [(.5+col+(row%2)*.45)/(cols+.45),(.5+row)/rows];
  if(kind==='constellation'){const a=i*2.399963229728653,r=.44*Math.sqrt((i+.5)/n);return [.5+r*Math.cos(a),.5+r*Math.sin(a)];}
  if(kind==='dunes')return [(col+.5+.22*Math.sin(i*3.1))/cols,(row+.5+.22*Math.cos(i*2.7))/rows];
  if(kind==='orbit'){if(i===0)return [.5,.5];const a=(i-1)*Math.PI*2/(n-1)+.2;return [.5+.43*Math.cos(a),.5+.43*Math.sin(a)];}
  const a=i*Math.PI*2/n+.31,r=i%2?.46:.24;return [.5+r*Math.cos(a),.5+r*Math.sin(a)];
 });return voronoi(seeds);
}
function newLayout(id,n,ratio){
 switch(id){
  case 'gallery':return weightedRows(n,[1.65,1,1.2]);
  case 'triptych':return weightedRows(n,[1,1.8,1]).map(p=>p.map(([x,y])=>[y,1-x]));
  case 'panorama':return weightedRows(n,[1,2.8,1],.15);
  case 'shelves':return weightedRows(n,[1.4,1,.7,1.1],.4);
  case 'window':return growCells([rect(0,0,1,1)],n,(_,b)=>b.w*ratio>b.h?0:Math.PI/2,.38);
  case 'ribbon':return weightedRows(n,[2.8,1],.25);
  case 'spiral':return spiralCells(n);
  case 'terraces':return spiralCells(n,true);
  case 'weave':return spiralCells(n).map(p=>p.map(([x,y])=>[y,1-x]));
  case 'pinwheel':return growCells([rect(0,0,1,1)],n,i=>i*Math.PI/3+.2,.42);
  case 'origami':return growCells([rect(0,0,1,1)],n,(i,b)=>(b.w>b.h?0:Math.PI/2)+(i%2?.72:-.72),.5);
  case 'facets':return growCells([rect(0,0,1,1)],n,i=>i*2.399963+.35,.38);
  case 'sail':return growCells([rect(0,0,1,1)],n,i=>i%2?Math.PI/4:Math.PI*3/4,.5);
  case 'lightning':return growCells([rect(0,0,1,1)],n,i=>i%2?-.9:.9,.36);
  case 'wave':return growCells([rect(0,0,1,1)],n,(i,b)=>(b.w>b.h?0:Math.PI/2)+Math.sin(i*1.4)*.28,.44);
  case 'canyon':return growCells([rect(0,0,1,1)],n,i=>Math.sin(i*2)*.18,.55);
  case 'rays':return rays(n,.24,.72,-.38);
  case 'honeycomb':case 'constellation':case 'dunes':case 'orbit':case 'burst':return seededCells(n,id);
  case 'diamond':{
   if(n<5)return rays(n,.5,.5,.1);
   const initial=[[[.5,0],[1,.5],[.5,1],[0,.5]],[[0,0],[.5,0],[0,.5]],[[.5,0],[1,0],[1,.5]],[[1,.5],[1,1],[.5,1]],[[0,.5],[.5,1],[0,1]]];
   return growCells(initial,n,(_,b)=>b.w>b.h?0:Math.PI/2);
  }
  case 'cross':{
   if(n<5)return weightedRows(n,[1,2],.55);
   return growCells([rect(.25,.25,.5,.5),rect(0,0,.75,.25),rect(.75,0,.25,.75),rect(.25,.75,.75,.25),rect(0,.25,.25,.75)],n,(_,b)=>b.w>b.h?0:Math.PI/2);
  }
 }
 return null;
}
const lerp=(a,b,t)=>[a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t];
export function clip(poly,nx,ny,d){
 const out=[],epsilon=1e-11*Math.max(Math.abs(d),...poly.map(([x,y])=>Math.abs(x*nx)+Math.abs(y*ny)),Number.EPSILON);
 for(let i=0;i<poly.length;i++){const a=poly[i],b=poly[(i+1)%poly.length];let da=a[0]*nx+a[1]*ny-d,db=b[0]*nx+b[1]*ny-d;if(Math.abs(da)<epsilon)da=0;if(Math.abs(db)<epsilon)db=0;if(da>=0)out.push(a);if((da>0&&db<0)||(da<0&&db>0))out.push(lerp(a,b,da/(da-db)));}
 return out.filter((p,i)=>{const q=out[(i+out.length-1)%out.length];return Math.hypot(p[0]-q[0],p[1]-q[1])>1e-11*Math.max(...out.flat().map(Math.abs),Number.EPSILON);});
}
export function bounds(p){const xs=p.map(v=>v[0]),ys=p.map(v=>v[1]);return {x:Math.min(...xs),y:Math.min(...ys),w:Math.max(...xs)-Math.min(...xs),h:Math.max(...ys)-Math.min(...ys)};}
export function area(p){return Math.abs(p.reduce((s,a,i)=>{const b=p[(i+1)%p.length];return s+a[0]*b[1]-b[0]*a[1];},0)/2);}
function tiles(n,rows,stagger=false){const out=[];for(let r=0;r<rows;r++){const count=Math.floor(n/rows)+(r<n%rows?1:0);const widths=Array.from({length:count},(_,i)=>stagger&&count>1?(i===0?(r%2?.6:1.4):i===count-1?(r%2?1.4:.6):1):1);let x=0;for(let c=0;c<count;c++){out.push(rect(x,r/rows,widths[c]/count,1/rows));x+=widths[c]/count;}}return out;}
function subdivide(n,angled=false){const out=[rect(0,0,1,1)];while(out.length<n){const idx=out.reduce((best,p,i)=>area(p)>area(out[best])?i:best,0),p=out[idx],b=bounds(p),vertical=b.w>b.h*.95;let nx=vertical?1:0,ny=vertical?0:1;if(angled){if(vertical)ny=(out.length%2?.42:-.42);else nx=(out.length%2?.38:-.38);}const values=p.map(a=>a[0]*nx+a[1]*ny),d=(Math.min(...values)+Math.max(...values))/2;out.splice(idx,1,clip(p,nx,ny,d),clip(p,-nx,-ny,-d));}return out;}
const polygonCache=new Map();
export function polygons(id,n,ratio=1){
 const key=`${id}/${n}/${ratio}`;if(polygonCache.has(key))return polygonCache.get(key);
 const value=buildPolygons(id,n,ratio);if(polygonCache.size>=128)polygonCache.delete(polygonCache.keys().next().value);polygonCache.set(key,value);return value;
}
function buildPolygons(id,n,ratio=1){
 if(n===1)return [rect(0,0,1,1)];
 const expanded=newLayout(id,n,ratio);if(expanded)return expanded;
 if(id==='columns')return Array.from({length:n},(_,i)=>rect(i/n,0,1/n,1));
 if(id==='rows')return Array.from({length:n},(_,i)=>rect(0,i/n,1,1/n));
 if(id==='hero'||id==='editorial'||id==='film'){const horizontal=id==='film',large=id==='editorial'?.62:.58;const rest=tiles(n-1,Math.min(n-1,Math.max(1,Math.round(Math.sqrt(n-1)*(horizontal?.55:1.5)))));return horizontal?[rect(0,0,1,large),...rest.map(p=>p.map(([x,y])=>[x,large+y*(1-large)]))]:[rect(0,0,large,1),...rest.map(p=>p.map(([x,y])=>[large+x*(1-large),y]))];}
 if(id==='mosaic'||id==='shards')return subdivide(n,id==='shards');
 if(id==='diagonal')return Array.from({length:n},(_,i)=>clip(clip(rect(0,0,1,1),1,.5,1.5*i/n),-1,-.5,-1.5*(i+1)/n));
 if(id==='chevron'){if(n<5)return subdivide(n,true);const left=Math.ceil((n-2)/2),right=n-2-left,out=[];for(let i=0;i<left;i++)out.push([[0,i/left],[.5,.2+i*.6/left],[.5,.2+(i+1)*.6/left],[0,(i+1)/left]]);out.push([[0,0],[1,0],[.5,.2]],[[0,1],[.5,.8],[1,1]]);for(let i=0;i<right;i++)out.push([[.5,.2+i*.6/right],[1,i/right],[1,(i+1)/right],[.5,.2+(i+1)*.6/right]]);return out;}
 if(id==='fan'){if(n===2)return subdivide(n,true);return Array.from({length:n},(_,i)=>{const a=-Math.PI/4+i*Math.PI*2/n,b=a+Math.PI*2/n;return clip(clip(rect(0,0,1,1),-Math.sin(a),Math.cos(a),(-Math.sin(a)+Math.cos(a))*.5),Math.sin(b),-Math.cos(b),(Math.sin(b)-Math.cos(b))*.5);});}
 return tiles(n,Math.min(n,Math.max(1,Math.round(Math.sqrt(n/ratio)))),id==='brick');
}
export function inset(poly,distance){let result=poly;for(let i=0;i<poly.length;i++){const a=poly[i],b=poly[(i+1)%poly.length],dx=b[0]-a[0],dy=b[1]-a[1],len=Math.hypot(dx,dy);if(len<1e-8)continue;const nx=-dy/len,ny=dx/len;result=clip(result,nx,ny,nx*a[0]+ny*a[1]+distance);}return result;}
export function frameGeometry(id,n,w,h,requestedGap){const base=polygons(id,n,w/h);let gap=requestedGap;for(let i=0;i<30;i++){const pad=gap/2,scaled=base.map(p=>p.map(([x,y])=>[pad+x*(w-2*pad),pad+y*(h-2*pad)])),inner=scaled.map(p=>inset(p,gap/2));if(inner.every((p,i)=>p.length>=3&&area(p)>area(scaled[i])*.25))return {cells:inner,gap};gap*=.8;}return {cells:base.map(p=>p.map(([x,y])=>[x*w,y*h])),gap:0};}
export function hit(poly,x,y){let inside=false;for(let i=0,j=poly.length-1;i<poly.length;j=i++){const [xi,yi]=poly[i],[xj,yj]=poly[j];if(((yi>y)!==(yj>y))&&(x<(xj-xi)*(y-yi)/(yj-yi)+xi))inside=!inside;}return inside;}
export function imagePlacement(image,box,photo){const scale=Math.max(box.w/image.width,box.h/image.height)*photo.zoom,iw=image.width*scale,ih=image.height*scale;return {x:box.x-(iw-box.w)*photo.x,y:box.y-(ih-box.h)*photo.y,w:iw,h:ih,overflowX:iw-box.w,overflowY:ih-box.h};}
export function outputSize(ratio){return ratio>=1?{w:3840,h:Math.round(3840/ratio)}:{w:Math.round(3840*ratio),h:3840};}

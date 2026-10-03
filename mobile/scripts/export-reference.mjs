import {layouts, frameGeometry} from '../../dist/geometry.js';
for (const [id] of layouts) for (let n=1;n<=24;n++) for (const ratio of [.2,.5625,.8,1,1.5,16/9,5]) for (const gap of [0,24,120]) {
  const w=ratio>=1?3840:3840*ratio,h=ratio>=1?3840/ratio:3840;
  const f=frameGeometry(id,n,w,h,gap);
  console.log(JSON.stringify({id,n,w,h,gap,expected:[f.gap,...f.cells.flatMap(p=>[p.length,...p.flat()])]}));
}

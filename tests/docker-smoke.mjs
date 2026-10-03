// Real runtime verification, intentionally separate from daemon-free contract tests.
// Starts only a unique test project, publishes no ports and requires no tunnel token.
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
const cwd=fileURLToPath(new URL('../',import.meta.url));
const project=`mosaic-smoke-${process.pid}-${Date.now()}`;
const env={...process.env,MOSAIC_IMAGE:`${project}:test`};
function docker(args,timeout=30000){
 const result=spawnSync('docker',args,{cwd,env,encoding:'utf8',timeout,maxBuffer:4*1024*1024});
 if(result.error||result.status!==0)throw Error(`docker ${args.join(' ')} failed: ${result.error?.message||result.stderr||result.stdout}`);
 return result.stdout.trim();
}
const compose=(args,timeout)=>docker(['compose','-p',project,...args],timeout);
assert.equal(docker(['info','--format','{{.OSType}}'],15000),'linux','Docker must be running in Linux containers mode.');
const config=JSON.parse(compose(['config','--format','json']));
let started=false;
try{
 console.log('Building static image and starting isolated origin without published ports…');
 started=true;compose(['up','-d','--build','--wait','--wait-timeout','90','web'],300000);
 const id=compose(['ps','-q','web']);
 const [container]=JSON.parse(docker(['inspect',id]));
 assert.equal(container.State.Health.Status,'healthy');
 assert.equal(container.Config.User,'101:101');
 assert.equal(container.HostConfig.ReadonlyRootfs,true);
 assert.equal(Object.keys(container.HostConfig.PortBindings??{}).length,0);
 compose(['exec','-T','web','nginx','-t']);
 assert.equal(compose(['exec','-T','web','wget','-qO-','http://127.0.0.1:8080/healthz']),'ok');
 for(const file of ['index.html','app.js','geometry.js','theme.js','style.css','themes.css']){
  assert.equal(compose(['exec','-T','web','wget','-qO-',`http://127.0.0.1:8080/${file}`]),readFileSync(new URL(`../dist/${file}`,import.meta.url),'utf8').trim(),`${file} must match the checked-out source`);
 }
 assert.equal(compose(['run','--rm','--no-deps','--entrypoint','wget','web','-qO-','http://web:8080/healthz']),'ok','Compose DNS and origin network must work');
 const image=config.services.cloudflared.image;
 const isolated=['run','--rm','--network','none','--read-only','--cap-drop','ALL','--security-opt','no-new-privileges',image];
 assert.match(docker([...isolated,'tunnel','run','--help'],120000),/--token-file/);
 assert.match(docker([...isolated,'tunnel','--metrics','127.0.0.1:2000','ready','--help']),/ready/);
 console.log('PASS: healthy read-only non-root origin; all assets; internal Docker DNS/HTTP; no host ports; cloudflared token-file and readiness commands.');
 console.log('Live Cloudflare authentication and hostname routing require the real token and configured hostname.');
}finally{
 if(started)compose(['down','--remove-orphans'],60000);
}

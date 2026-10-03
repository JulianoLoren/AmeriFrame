import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {readFileSync} from 'node:fs';

const cwd=fileURLToPath(new URL('../',import.meta.url));
const config=JSON.parse(execFileSync('docker',['compose','config','--format','json'],{cwd,encoding:'utf8',timeout:15000}));
test('no service publishes host ports; only the tunnel can leave the origin network',()=>{
 for(const service of Object.values(config.services)){
  assert.equal(service.ports?.length??0,0);assert.notEqual(service.network_mode,'host');
  assert.equal(service.privileged??false,false);assert.equal(service.read_only,true);
 }
 assert.equal(config.networks.origin.internal,true);
 assert.deepEqual(Object.keys(config.services.web.networks),['origin']);
 assert.deepEqual(Object.keys(config.services.cloudflared.networks).sort(),['edge','origin']);
 assert.notEqual(config.networks.edge.internal,true);
});
test('only the tunnel receives a file secret; it waits for the origin and checks readiness',()=>{
 assert.equal(config.services.web.secrets?.length??0,0);
 const tunnel=config.services.cloudflared;
 assert.deepEqual(tunnel.secrets.map(s=>s.source),['cloudflare_tunnel_token']);
 assert.ok(config.secrets.cloudflare_tunnel_token.file);
 assert.equal(tunnel.environment?.TUNNEL_TOKEN,undefined);
 assert.equal(tunnel.depends_on.web.condition,'service_healthy');
 assert.ok(tunnel.command.includes('--token-file'));
 assert.ok(tunnel.healthcheck.test.includes('ready'));
});
test('registry images are pinned and build copies only public application assets',()=>{
 assert.match(config.services.web.build.args.NGINX_IMAGE,/@sha256:[a-f0-9]{64}$/);
 assert.match(config.services.cloudflared.image,/@sha256:[a-f0-9]{64}$/);
 const dockerfile=readFileSync(new URL('../Dockerfile',import.meta.url),'utf8');
 assert.match(dockerfile,/USER 101:101/);
 const copies=dockerfile.split('\n').filter(s=>s.startsWith('COPY '));
 assert.equal(copies.length,2);
 assert.ok(copies.every(s=>!s.includes('secrets')&&!s.includes('.env')&&!s.includes('.git')));
 assert.match(readFileSync(new URL('../.dockerignore',import.meta.url),'utf8'),/^\*\*/);
});

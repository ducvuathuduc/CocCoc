import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const action=process.argv[2];
let raw=''; for await(const chunk of process.stdin)raw+=chunk;
let input={}; try {input=JSON.parse(raw||'{}');} catch {console.error('Invalid hook JSON');process.exit(2);}
const run=(command,args,options={})=>{
 const r=spawnSync(command,args,{cwd:root,encoding:'utf8',shell:false,...options});
 if(r.stdout)process.stdout.write(r.stdout);
 if(r.stderr)process.stderr.write(r.stderr);
 if(r.error){console.error(r.error.message);return 2;}
 return r.status??2;
};
function executable(name){
 if(process.platform!=='win32')return name;
 const found=spawnSync('where.exe',[name],{encoding:'utf8',shell:false});
 const candidates=(found.stdout||'').trim().split(/\r?\n/);
 const native=candidates.find(x=>/\.exe$/i.test(x)&&fs.existsSync(x));
 if(native)return native;
 if(name==='dart'){
  const shim=candidates.find(x=>/dart\.bat$/i.test(x));
  const binary=shim?path.join(path.dirname(shim),'cache/dart-sdk/bin/dart.exe'):null;
  if(binary&&fs.existsSync(binary))return binary;
 }
 return null;
}
if(action==='format'){
 const candidate=input.tool_input?.file_path;
 if(!candidate || !candidate.endsWith('.dart'))process.exit(0);
 const resolved=path.resolve(root,candidate);
 const relative=path.relative(root,resolved);
 if(relative.startsWith('..')||path.isAbsolute(relative)||!fs.existsSync(resolved))process.exit(0);
 const dart=executable('dart');
 if(!dart){console.error('Dart formatter unavailable; record required manual format check.');process.exit(0);}
 process.exit(run(dart,['format',resolved],{timeout:10000}));
}
if(action==='secrets'){
 const command=input.tool_input?.command||'';
 if(!/\bgit\s+commit\b/.test(command))process.exit(0);
 const scanner=executable('gitleaks');
 if(!scanner){console.error('Commit blocked: pinned gitleaks is missing. Install it in P1 and run staged secret scan.');process.exit(2);}
 const git=executable('git');
 if(!git){console.error('Commit blocked: Git executable unavailable.');process.exit(2);}
 const probe=spawnSync(git,['rev-parse','--show-toplevel'],{cwd:root,encoding:'utf8',shell:false,timeout:5000});
 const normalize=p=>path.resolve(p).toLowerCase();
 if(probe.status!==0||!probe.stdout?.trim()||normalize(probe.stdout.trim())!==normalize(root)){
  console.error('Commit blocked: this workspace is not its own initialized Git repository.');process.exit(2);
 }
 const scan=spawnSync(scanner,['git','--staged','--redact'],{cwd:root,encoding:'utf8',shell:false,timeout:25000});
 if(scan.stdout)process.stdout.write(scan.stdout);
 if(scan.stderr)process.stderr.write(scan.stderr);
 // Some scanner versions report a Git failure but return0. Never accept an error log as a clean scan.
 const loggedError=/\b(ERR|FATAL)\b/.test((scan.stderr||'').replace(/\x1b\[[0-9;]*m/g,''));
 if(scan.error||scan.status!==0||loggedError){console.error('Commit blocked: staged secret scan failed or reported an error.');process.exit(2);}
 process.exit(0);
}
if(action==='stop'){
 if(input.stop_hook_active)process.exit(0);
 const code=run(process.execPath,['tools/blueprint/validate.mjs'],{timeout:30000});
 if(code)process.exit(2);
 if(!fs.existsSync(path.join(root,'package.json'))){
  console.log('Phase0: blueprint checked; application build/device tests are not present.');
  process.exit(0);
 }
 // Constant command only; no hook/user text enters shell source.
 const status=process.platform==='win32'
  ?run('cmd.exe',['/d','/s','/c','pnpm verify'],{timeout:150000})
  :run('pnpm',['verify'],{timeout:150000});
 process.exit(status===0?0:2);
}
console.error('Unknown hook action');process.exit(2);

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const errors=[];
const check=(ok,message)=>{if(!ok)errors.push(message);};
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
function files(dir=''){
 return fs.readdirSync(path.join(root,dir),{withFileTypes:true}).flatMap(e=>{
  if(['.git','node_modules','build','.dart_tool'].includes(e.name))return [];
  const p=path.posix.join(dir,e.name);
  return e.isDirectory()?files(p):[p];
 });
}
const inventory=files();
const markdown=inventory.filter(p=>p.endsWith('.md'));
let links=0;
for(const file of markdown){
 const body=read(file);
 for(const m of body.matchAll(/!?\[[^\]\n]*\]\(([^)\n]+)\)/g)){
  let target=m[1].trim().replace(/^<|>$/g,'');
  if(/^(https?:|app:|codex:|mailto:)/.test(target))continue;
  target=target.split('#')[0];
  if(!target)continue;
  target=decodeURIComponent(target);
  const full=path.resolve(root,path.dirname(file),target);
  check(!path.relative(root,full).startsWith('..'),file+': reference leaves project '+target);
  check(fs.existsSync(full),file+': broken reference '+target);
  links++;
 }
}
const required=['docs/ARCHITECTURE_BLUEPRINT_V1.md','docs/FREEZE_REVIEW.md','docs/quality/TRACEABILITY.md','docs/agent/REPOSITORY_TREE.md','docs/api/openapi.yaml','AGENTS.md','CLAUDE.md','tools/agent/hooks.mjs','tools/blueprint/validate-schemas.mjs'];
for(const file of required)check(inventory.includes(file),'Missing required file: '+file);
const ids=(file,re)=>[...read(file).matchAll(re)].map(m=>m[1]);
const requirements=ids('docs/product/SRS.md',/^\| (FR-[A-Z]+-\d+) /gm);
const nfr=ids('docs/architecture/NFR.md',/^\| (NFR-[A-Z]+-\d+) /gm);
const screens=ids('docs/product/SCREEN_INVENTORY.md',/^\| (SC\d+) /gm);
const tasks=ids('docs/agent/IMPLEMENTATION_PLAN.md',/^\| (P\d+-[A-Z]+-\d+) /gm);
const edges=ids('docs/product/EDGE_CASE_MATRIX.md',/^\| (EC\d+) /gm);
for(const [name,list] of Object.entries({requirements,nfr,screens,tasks,edges}))check(new Set(list).size===list.length,'Duplicate '+name+' ID');
check(requirements.length===39,'Functional requirement baseline changed; review traceability/freeze');
check(screens.length===42,'Screen baseline changed; review fixture gate');
const tables=new Map([...read('docs/data/DATA_MODEL.md').matchAll(/^\| ([lpa]_[a-z_]+) \/ (Learning|Progress|AI) \|/gm)].map(m=>[m[1],m[2].toLowerCase()]));
check(tables.size>30,'Data ownership inventory is incomplete');
const api=JSON.parse(read('docs/api/openapi.yaml'));
check(api.openapi==='3.1.0','Expected OpenAPI3.1');
function pointer(ref){
 if(!ref.startsWith('#/'))return undefined;
 return ref.slice(2).split('/').reduce((v,k)=>v?.[k.replace(/~1/g,'/').replace(/~0/g,'~')],api);
}
let refs=0;
function walk(value,location){
 if(!value||typeof value!=='object')return;
 if(value.$ref){check(pointer(value.$ref)!==undefined,'Unresolved ref '+location+' '+value.$ref);refs++;}
 if(value.type==='object'&&value.required)for(const key of value.required)check(!value.properties||key in value.properties,'Undefined required property '+location+'.'+key);
 if(value.minimum!==undefined&&value.maximum!==undefined)check(value.minimum<=value.maximum,'Invalid numeric bounds '+location);
 if(value.discriminator?.mapping)for(const ref of Object.values(value.discriminator.mapping))check(pointer(ref)!==undefined,'Unresolved discriminator '+ref);
 for(const [k,v] of Object.entries(value))walk(v,location+'/'+k);
}
walk(api,'api');
const operations=[];
for(const [route,item] of Object.entries(api.paths))for(const [method,op] of Object.entries(item)){
 if(!['get','post','patch','put','delete'].includes(method))continue;
 operations.push(op);
 const label=method.toUpperCase()+' '+route;
 check(['learning','progress','ai'].includes(op['x-owner']),label+' missing owner');
 check(Array.isArray(op['x-tables'])&&Array.isArray(op['x-requirements']),label+' missing contract trace');
 for(const req of op['x-requirements']??[])check(requirements.includes(req),label+' unknown requirement '+req);
 for(const table of op['x-tables']??[]){
  check(tables.has(table),label+' unknown table '+table);
  check(tables.get(table)===op['x-owner'],label+' cross-owner table '+table);
 }
 const params=(op.parameters??[]).map(p=>p.$ref?pointer(p.$ref):p);
 for(const m of route.matchAll(/\{([^}]+)\}/g))check(params.some(p=>p?.name===m[1]&&p.in==='path'&&p.required===true),label+' undefined path param '+m[1]);
 if(['post','patch','delete'].includes(method)&&!route.startsWith('/internal/')&&!/\/(heartbeat|close)$/.test(route))check(params.some(p=>p?.name==='Idempotency-Key'&&p.required),label+' missing idempotency key');
 check(route==='/health'||(op.security?.length??0)>0,label+' unexpectedly public');
 for(const requirement of op.security??[])for(const scheme of Object.keys(requirement))check(scheme in api.components.securitySchemes,label+' unknown security scheme '+scheme);
}
check(new Set(operations.map(op=>op.operationId)).size===operations.length,'Duplicate operationId');
const traceRows=[...read('docs/quality/TRACEABILITY.md').matchAll(/^\| ((?:FR|NFR)-[A-Z]+-\d+) \| ([^\n]+)$/gm)].map(m=>({id:m[1],cells:m[2].split('|').map(x=>x.trim())}));
check(new Set(traceRows.map(r=>r.id)).size===traceRows.length,'Duplicate traceability row');
for(const id of [...requirements,...nfr])check(traceRows.some(r=>r.id===id),'No task/test trace for '+id);
for(const row of traceRows){
 check([...requirements,...nfr].includes(row.id),'Unknown traceability ID '+row.id);
 const expected=operations.filter(op=>op['x-requirements'].includes(row.id)).map(op=>op.operationId).sort();
 const actual=(row.cells[0]||'').split(',').map(s=>s.trim()).filter(s=>s&&!s.startsWith('LOCAL:'));
 check(JSON.stringify(actual.sort())===JSON.stringify(expected),'API trace drift '+row.id);
 for(const screen of (row.cells[1]||'').match(/SC\d+/g)??[])check(screens.includes(screen),'Unknown trace screen '+screen);
 const targetTasks=(row.cells[2]||'').match(/P\d+-[A-Z]+-\d+/g)??[];
 check(targetTasks.length>0,'No implementation task '+row.id);
 for(const task of targetTasks)check(tasks.includes(task),'Unknown trace task '+task);
 check((row.cells[3]||'').length>10,'Missing meaningful acceptance evidence '+row.id);
}
for(let phase=0;phase<=11;phase++)check(new RegExp('^\\| '+phase+' ','m').test(read('docs/agent/IMPLEMENTATION_PLAN.md')),'Missing phase gate '+phase);
const parts=ids('docs/ARCHITECTURE_BLUEPRINT_V1.md',/^## PART ([A-L]) —/gm);
check(parts.join('')==='ABCDEFGHIJKL','Blueprint A–L order incomplete');
const adrs=inventory.filter(p=>/^docs\/architecture\/adr\/\d{4}-.+\.md$/.test(p));
check(adrs.length===17,'Expected17ADR decisions');
for(const file of adrs)for(const field of ['Status','Context','Decision','Alternatives','Rationale','Consequences','Revisit triggers'])check(read(file).includes('## '+field),file+' missing '+field);
const skills=inventory.filter(p=>p.endsWith('/SKILL.md'));
check(skills.length===8,'Four canonical skills plus four discovery wrappers required');
for(const file of skills){
 const header=read(file).match(/^---\r?\n([\s\S]*?)\r?\n---/);
 check(!!header,file+' missing frontmatter');
 if(header)for(const key of ['name','description'])check(new RegExp('^'+key+': .+','m').test(header[1]),file+' missing '+key);
}
for(const module of ['apps/mobile','services/learning','services/progress','services/ai'])check(inventory.includes(module+'/AGENTS.md'),'Missing nested instructions '+module);
for(const file of ['.claude/settings.json','.mcp.example.json'])JSON.parse(read(file));
const s=api.components.schemas;
check(s.Session.required.includes('answerHistory')&&s.Session.required.includes('lastFeedback'),'Session resume must contain answer state');
check(s.PairAnswer.properties.matches?.items?.properties?.leftId&&s.PairAnswer.properties.matches?.items?.properties?.rightId,'PairAnswer loses chosen connection');
check(s.VoiceLease.oneOf?.length===2,'Voice lease mode constraints missing');
check(s.LiveVoiceLease.properties.ephemeralToken.type==='string'&&s.TurnVoiceLease.properties.ephemeralToken.type==='null','Invalid voice credential mode');
check(s.Assessment.allOf?.[0]?.else?.properties?.accuracy?.type==='null','Unscored assessment permits fabricated metric');
check(api.paths['/v1/voice-sessions'].post['x-tables'].includes('a_active_slots'),'Voice active slot omitted');
check(api.paths['/v1/assessment-jobs'].post['x-tables'].includes('a_usage'),'Assessment quota omitted');
check(api.paths['/v1/me/initialize'].post['x-tables'].includes('p_reward_ledger'),'Initial wallet lacks ledger');
if(errors.length){console.error(errors.join('\n'));process.exit(1);}
console.log(JSON.stringify({status:'PASS',files:inventory.length,markdown:markdown.length,localLinks:links,requirements:requirements.length,nfr:nfr.length,screens:screens.length,edgeCases:edges.length,tasks:tasks.length,tables:tables.size,schemas:Object.keys(s).length,paths:Object.keys(api.paths).length,operations:operations.length,refs,adrs:adrs.length,skills:skills.length,scope:'Phase0 structural consistency; no app build, account or device proof'},null,2));

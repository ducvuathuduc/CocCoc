// Full JSON Schema2020-12 fixture checks. P1 pins these tools; Phase0 can use an isolated temporary install.
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const require=createRequire(process.argv[2]?path.resolve(process.argv[2],'package.json'):import.meta.url);
const Ajv=require('ajv/dist/2020').default;
const formats=require('ajv-formats');
const api=JSON.parse(fs.readFileSync(path.join(root,'docs/api/openapi.yaml'),'utf8'));
const ajv=new Ajv({strict:false,allErrors:true,validateFormats:true});
formats(ajv);
ajv.addSchema({$id:'https://cocenglish.example.invalid/schema',components:api.components});
const validators=new Map();
for(const name of Object.keys(api.components.schemas))validators.set(name,ajv.compile({$ref:'https://cocenglish.example.invalid/schema#/components/schemas/'+name}));
const cases=[];
function expect(name,value,valid,label){
 const validate=validators.get(name);
 const result=validate(value);
 if(result!==valid)throw new Error(label+': expected '+valid+'; '+JSON.stringify(validate.errors));
 cases.push(label);
}
// Fixture cases live in packages/api_contracts/fixtures/schema-cases.json so the Dart DTO round-trip tests consume the same data.
function expand(value){
 if(Array.isArray(value))return value.map(expand);
 if(value&&typeof value==='object'){
  if(value.$repeat)return String(value.$repeat.text).repeat(value.$repeat.count);
  if(value.$file)return JSON.parse(fs.readFileSync(path.join(root,value.$file),'utf8'));
  return Object.fromEntries(Object.entries(value).map(([k,v])=>[k,expand(v)]));
 }
 return value;
}
const fixtures=JSON.parse(fs.readFileSync(path.join(root,'packages/api_contracts/fixtures/schema-cases.json'),'utf8'));
for(const c of fixtures.cases){
 if(!validators.has(c.schema))throw new Error(c.label+': unknown schema '+c.schema);
 expect(c.schema,expand(c.value),c.valid,c.label);
}
console.log(JSON.stringify({status:'PASS',compiledSchemas:validators.size,fixtureCases:cases.length,scope:'Contract validation only; no provider/device benchmark'},null,2));

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
const lease={sessionId:'c7081304-39d3-48a4-a411-e737da8a2479',mode:'LIVE',providerAlias:'gemini-live',model:'gemini-2.5-flash-native-audio-preview-12-2025',ephemeralToken:'ephemeral.fixture',connectExpiresAt:'2026-10-04T00:01:00Z',sessionExpiresAt:'2026-10-04T00:03:00Z',epoch:0,inputSampleRate:16000,outputSampleRate:24000,configVersion:'v1'};
expect('VoiceLease',lease,true,'LIVE complete');
expect('VoiceLease',{...lease,ephemeralToken:null},false,'LIVE missing token');
expect('VoiceLease',{...lease,mode:'TURN',ephemeralToken:null,connectExpiresAt:null},true,'TURN no credential');
expect('VoiceLease',{...lease,mode:'TURN'},false,'TURN credential rejected');
expect('VoiceLease',{...lease,inputSampleRate:44100},false,'wrong native sample rate');
const assessment={jobId:lease.sessionId,status:'SUCCEEDED',transcript:'Hello',accuracy:null,fluency:null,completeness:null,prosody:null,words:[],scorer:null,scoreVersion:null,unavailableReason:'scorer_disabled',expiresAt:'2026-10-11T00:00:00Z',scoreState:'NULL_UNAVAILABLE',locale:'en-US',referenceHash:'a'.repeat(64),provider:null,modelVersion:null,miscues:[]};
expect('Assessment',assessment,true,'honest unscored response');
expect('Assessment',{...assessment,accuracy:99},false,'unscored numeric accuracy rejected');
expect('Assessment',{...assessment,scoreState:'VALID'},false,'VALID without dedicated provenance rejected');
expect('Assessment',{...assessment,scoreState:'VALID',accuracy:80,completeness:85,scorer:'azure',scoreVersion:'v1',provider:'azure-speech',modelVersion:'recorded-config'},true,'dedicated valid response with null prosody');
expect('Assessment',{...assessment,accuracy:101,scoreState:'VALID'},false,'invalid score range');
expect('Answer',{kind:'pairs',matches:[{leftId:'left-a',rightId:'right-b'}]},true,'matching connections retained');
expect('Answer',{kind:'pairs',pairIds:['known-pair']},false,'ID-only fabricated pair answer rejected');
expect('Answer',{kind:'choice',choiceId:'a',correct:true},false,'client correctness injection rejected');
expect('VoiceHeartbeat',{epoch:0,elapsedSeconds:181,turnCount:1},false,'heartbeat duration bounded');
expect('AssessmentRequest',{jobId:lease.sessionId,referenceExerciseId:'ex1',lessonVersion:'v1',locale:'en-US',wavBase64:'A'.repeat(640068),audioSha256:'b'.repeat(64)},false,'oversized base64 rejected');
const base={id:'ex1',prompt:{text:'Hello',locale:'en-US'},gradingRule:{caseSensitive:false,ignorePunctuation:true,ignoreDiacritics:false},hint:'Think',explanation:'A greeting',skillIds:['greet'],vocabularyIds:['hello']};
const payloads={textTranslation:{placeholder:'Type',maxChars:512},choice:{choices:[{id:'a',text:'hello'}]},wordBank:{tokens:[{id:'t1',text:'hello'}]},sentenceOrder:{tokens:[{id:'t1',text:'hello'}]},fillBlank:{placeholder:'Type',maxChars:512},matchPairs:{pairs:[{id:'p1',left:{id:'l1',text:'hello'},right:{id:'r1',text:'xin chao'}}]},imageChoice:{choices:[{id:'a',text:'hello'}]},listenChoice:{choices:[{id:'a',text:'hello'}]},dictation:{placeholder:'Type',maxChars:512},speakRepeat:{referenceText:'Hello',locale:'en-US',maxSeconds:15},dialogueTurn:{referenceText:'Hello',locale:'en-US',maxSeconds:15},storyQuestion:{passage:'Hello',question:'What?',choices:[{id:'a',text:'hello'}]}};
for(const [type,content] of Object.entries(payloads)){
 const rules=['choice','imageChoice','listenChoice','storyQuestion'].includes(type)?{correctChoiceId:'a'}:['wordBank','sentenceOrder'].includes(type)?{correctTokenIds:['t1']}:type==='matchPairs'?{correctPairIds:['p1']}:{acceptedText:['Hello']};
 expect('Exercise',{...base,type,content,gradingRule:{...base.gradingRule,...rules}},true,'exercise '+type);
}
expect('Exercise',{...base,type:'choice',content:payloads.choice},false,'missing authored correct choice rejected');
expect('Exercise',{...base,type:'remoteWidget',content:{}},false,'unknown exercise renderer rejected');
expect('Exercise',{...base,type:'choice',content:payloads.wordBank},false,'wrong typed payload rejected');
console.log(JSON.stringify({status:'PASS',compiledSchemas:validators.size,fixtureCases:cases.length,scope:'Contract validation only; no provider/device benchmark'},null,2));

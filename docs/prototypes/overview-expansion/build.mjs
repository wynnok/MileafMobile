// Pre-render the default review page so opening the HTML never depends on JS
// merely to see the proposal. Browser interaction remains in prototype.js.
import {readFile, writeFile} from 'node:fs/promises';
import {dirname, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {runInNewContext} from 'node:vm';
const root=dirname(fileURLToPath(import.meta.url));
const [css,js]=await Promise.all(['style.css','prototype.js'].map(file=>readFile(resolve(root,file),'utf8')));
const app={innerHTML:''};
const document={body:{className:''},getElementById:()=>app,querySelectorAll:()=>[],addEventListener:()=>{}};
runInNewContext(js,{URLSearchParams,location:{search:'',href:'http://127.0.0.1:8766/'},document});
const head=`<!doctype html>\n<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>行笺 · 概览再设计评审</title><style>${css}</style>`;
const body=`</head><body><div id="app">${app.innerHTML}</div>`;
await writeFile(resolve(root,'index.html'),head+'<script src="prototype.js" defer></script>'+body+'</body></html>\n');
await writeFile(resolve(root,'overview-static.html'),head+body+'</body></html>\n');
console.log('已生成有静态正文的交互入口，以及不依赖脚本的单文件静态评审页。');

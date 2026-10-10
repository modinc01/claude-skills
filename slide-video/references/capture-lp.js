const puppeteer=require('puppeteer-core');
const sels={hero:'.lp-hero',stats:'.lp-stats',pains:'.lp-pains',why:'#why',features:'#features',mechanism:'#mechanism',flow:'#flow',pricing:'#pricing',final:'.lp-final'};
(async()=>{const b=await puppeteer.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:'new',args:['--no-sandbox']});const p=await b.newPage();await p.setViewport({width:1920,height:1080,deviceScaleFactor:1});await p.goto('https://ebaybridge.luxroute.net/lp',{waitUntil:'networkidle0',timeout:60000});await p.evaluate(()=>document.fonts.ready);
// lazy 画像を全部読ませる
await p.evaluate(async()=>{document.querySelectorAll('img[loading=lazy]').forEach(i=>i.loading='eager');window.scrollTo(0,document.body.scrollHeight);await new Promise(r=>setTimeout(r,800));window.scrollTo(0,0);await new Promise(r=>setTimeout(r,400));});
// 固定ヘッダー/CTAバー/ヘルプボットを隠す
await p.addStyleTag({content:'.lp-header,.lp-cta-bar,.lp-mobile-cta,#helpbot,.helpbot,[class*=helpbot]{display:none!important} html{scroll-behavior:auto}'});
for(const [k,s] of Object.entries(sels)){const el=await p.$(s);if(!el){console.log('missing',k,s);continue;}await el.evaluate(e=>e.scrollIntoView({block:'start'}));await new Promise(r=>setTimeout(r,500));const box=await el.boundingBox();await el.screenshot({path:`lp/${k}.png`});console.log(k,Math.round(box.width),Math.round(box.height));}
await b.close();})();

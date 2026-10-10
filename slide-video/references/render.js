const puppeteer = require('puppeteer-core');
const path = require('path'); const fs = require('fs');
(async () => {
  const fps = 30;
  const browser = await puppeteer.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless:'new', args:['--no-sandbox','--hide-scrollbars','--force-device-scale-factor=1']});
  const page = await browser.newPage();
  await page.setViewport({width:1920,height:1080,deviceScaleFactor:1});
  await page.goto('file://' + path.join(__dirname, process.env.FILE||'index.html'), {waitUntil:'networkidle0'});
  await page.evaluate(() => window.ready);
  await new Promise(r=>setTimeout(r,500));
  const total = await page.evaluate(() => window.totalSeconds);
  const frames = Math.ceil(total*fps);
  const only = process.argv[2] ? parseFloat(process.argv[2]) : null; // preview at second
  if (only !== null) { await page.evaluate(t=>window.seek(t), only); await page.screenshot({path:`preview-${only}.jpg`, type:'jpeg', quality:90}); await browser.close(); return; }
  fs.mkdirSync('frames',{recursive:true});
  for (let i=0;i<frames;i++){
    await page.evaluate(t=>window.seek(t), i/fps);
    await page.screenshot({path:`frames/${String(i).padStart(5,'0')}.jpg`, type:'jpeg', quality:92});
    if (i%150===0) console.log('frame', i, '/', frames);
  }
  await browser.close();
  console.log('done', frames);
})();

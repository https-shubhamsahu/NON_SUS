import puppeteer from "puppeteer-core";
const out = process.argv[2];
const b = await puppeteer.launch({ executablePath: "C:/Program Files/Google/Chrome/Application/chrome.exe", headless: true, args: ["--no-sandbox"] });
const p = await b.newPage();
await p.setViewport({ width: 360, height: 640, isMobile: true, hasTouch: true, deviceScaleFactor: 3 });
const wait = (ms) => new Promise(r => setTimeout(r, ms));
await p.goto("https://app.nosus.foo/", { waitUntil: "networkidle0", timeout: 90000 });
await wait(6000);
await p.mouse.click(180, 402); await wait(3000);          // Send a Burn Note
await p.mouse.click(180, 300); await wait(600);
await p.keyboard.type("Exam venue changed to Hall C, 9am. Don't forward this.", { delay: 15 });
await wait(800);
await p.mouse.click(180, 412); await wait(9000);          // Encrypt & generate link
await p.screenshot({ path: `${out}/04_share_ready.png` });
// back to the welcome screen, then the redeem tool
await p.goto("https://app.nosus.foo/", { waitUntil: "networkidle0", timeout: 90000 });
await wait(5000);
await p.mouse.click(180, 578); await wait(3000);          // Redeem a code
await p.screenshot({ path: `${out}/05_redeem.png` });
await b.close();

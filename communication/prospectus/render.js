// Produit le PDF A4 à imprimer et un aperçu PNG à partir de prospectus.html.
// Usage : node communication/prospectus/render.js   (Playwright et Chromium requis)
const path = require("path");
const { chromium } = require("playwright");

(async () => {
  const dir = __dirname;
  const browser = await chromium.launch();
  const page = await browser.newPage({
    viewport: { width: 794, height: 1123 }, // A4 à 96 dpi
    deviceScaleFactor: 2.5,
  });
  await page.goto("file://" + path.join(dir, "prospectus.html"), { waitUntil: "networkidle" });
  await page.evaluate(() => document.fonts.ready);
  await page.pdf({
    path: path.join(dir, "badge-creche-prospectus-a4.pdf"),
    format: "A4",
    printBackground: true,
    preferCSSPageSize: true,
  });
  await page.screenshot({ path: path.join(dir, "badge-creche-prospectus-a4.png"), fullPage: false });
  await browser.close();
  console.log("PDF et aperçu générés dans", dir);
})();

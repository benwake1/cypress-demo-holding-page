import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve('.');

const load = (path) => readFileSync(resolve(root, path), 'utf8');

const partials = {
  navHome: load('src/templates/partials/nav-home.html'),
  navPricing: load('src/templates/partials/nav-pricing.html'),
  navLegal: load('src/templates/partials/nav-legal.html'),
  footer: load('src/templates/partials/footer.html'),
};

const pages = [
  {
    path: 'public/index.html',
    nav: partials.navHome,
    footer: partials.footer.replace('{{privacy_class}}', '').replace('{{terms_class}}', ''),
  },
  {
    path: 'public/pricing.html',
    nav: partials.navPricing,
    footer: partials.footer.replace('{{privacy_class}}', '').replace('{{terms_class}}', ''),
  },
  {
    path: 'public/privacy.html',
    nav: partials.navLegal,
    footer: partials.footer.replace('{{privacy_class}}', ' text-cyber-green').replace('{{terms_class}}', ''),
  },
  {
    path: 'public/terms.html',
    nav: partials.navLegal,
    footer: partials.footer.replace('{{privacy_class}}', '').replace('{{terms_class}}', ' text-cyber-green'),
  },
];

const replaceFirst = (content, regex, replacement, label, path) => {
  if (!regex.test(content)) {
    throw new Error(`Could not find ${label} in ${path}`);
  }

  return content.replace(regex, `\n${replacement}`);
};

for (const page of pages) {
  const source = load(page.path);
  const withNav = replaceFirst(source, /\n\s*<nav[\s\S]*?<\/nav>/, page.nav, 'nav block', page.path);
  const withFooter = replaceFirst(withNav, /\n\s*<footer[\s\S]*?<\/footer>/, page.footer, 'footer block', page.path);
  writeFileSync(resolve(root, page.path), withFooter);
}

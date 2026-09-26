// src/ のテンプレート(index.html)と各言語の文言(lang/*.json)から、公開するファイルを dist/ に書き出す。
// npx wrangler deploy / npx wrangler dev のときに自動で実行される(wrangler.jsonc の build.command)
import { copyFileSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';

// 公開する場所(https://yota.co/DisplayColourFilter/)
const ORIGIN = 'https://yota.co';
const BASE = '/DisplayColourFilter/';

// ページを出す言語。先頭の英語は BASE 直下、ほかは BASE + path。name はその言語での言語名
const LANGS = [
  { code: 'en', path: '', name: 'English' },
  { code: 'ja', path: 'ja/', name: '日本語' },
  { code: 'zh-Hans', path: 'zh-hans/', name: '简体中文' },
  { code: 'zh-Hant', path: 'zh-hant/', name: '繁體中文' },
  { code: 'ko', path: 'ko/', name: '한국어' },
  { code: 'fr', path: 'fr/', name: 'Français' },
  { code: 'de', path: 'de/', name: 'Deutsch' },
  { code: 'es', path: 'es/', name: 'Español' },
];

// 英語のページに外から来たときだけ、ブラウザの第一言語に合うページへ移る(言語メニューから英語を選んだときは移らない)
const REDIRECT = `<script>
(function () {
  if (document.referrer.indexOf(location.origin) === 0) return;
  var lang = ((navigator.languages && navigator.languages[0]) || navigator.language || '').toLowerCase();
  var path = /^zh-(tw|hk|mo|hant)/.test(lang) ? 'zh-hant/' : /^zh/.test(lang) ? 'zh-hans/' : { ja: 'ja/', ko: 'ko/', fr: 'fr/', de: 'de/', es: 'es/' }[lang.split('-')[0]];
  if (path) location.replace(path);
})();
</script>`;

// ページに載せるバージョンはアプリの Info.plist から読む
const plist = readFileSync('../Resources/Info.plist', 'utf8');
const version = plist.match(/<key>CFBundleShortVersionString<\/key>\s*<string>([^<]+)<\/string>/)[1];

const template = readFileSync('src/index.html', 'utf8');
const out = 'dist' + BASE;
rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });

// アイコンと、アップデートの配信情報(scripts/make-appcast.sh が作る)はそのまま置く
copyFileSync('src/icon.png', out + 'icon.png');
copyFileSync('src/appcast.xml', out + 'appcast.xml');

const alternates = LANGS.map((l) => `<link rel="alternate" hreflang="${l.code}" href="${ORIGIN}${BASE}${l.path}">`)
  .concat(`<link rel="alternate" hreflang="x-default" href="${ORIGIN}${BASE}">`)
  .join('\n');
const languages = LANGS.map((l) => `<li><a href="${BASE}${l.path}" hreflang="${l.code}" lang="${l.code}">${l.name}</a></li>`).join('\n');

for (const lang of LANGS) {
  const text = JSON.parse(readFileSync(`src/lang/${lang.code}.json`, 'utf8'));
  const values = {
    lang: lang.code,
    url: ORIGIN + BASE + lang.path,
    alternates,
    languages,
    languageName: lang.name,
    redirect: lang.path === '' ? REDIRECT : '',
  };
  // 文言の配列は <li> の並びにする
  for (const [key, value] of Object.entries(text)) {
    values[key] = Array.isArray(value) ? value.map((item) => `<li>${item}</li>`).join('\n') : value;
  }
  const html = template
    .replace(/{{(\w+)}}/g, (_, key) => {
      if (!(key in values)) throw new Error(`src/lang/${lang.code}.json に "${key}" がありません`);
      return values[key];
    })
    .replaceAll('{version}', version);
  mkdirSync(out + lang.path, { recursive: true });
  writeFileSync(out + lang.path + 'index.html', html);
}

console.log(`Built: dist${BASE} (${LANGS.length} languages, version ${version})`);

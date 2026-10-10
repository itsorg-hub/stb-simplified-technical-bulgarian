# Страница на проекта (https://it-s.org/stb/)

Статична страница без скриптове, бисквитки, анализ и външни услуги. Само HTML, CSS, SVG и шрифт.

## Структура

```
site/
  index.html
  assets/
    css/style.css
    img/contours.svg      # генерира се от tools/make-contours.mjs
    img/favicon.svg
    fonts/                # шрифтът Adys (не е в хранилището), вж. fonts/README.md
  tools/make-contours.mjs
```

## Преглед на компютъра

```
cd site
node -e "require('http').createServer((q,r)=>require('fs').createReadStream('.'+(q.url==='/'?'/index.html':q.url.split('?')[0])).on('error',()=>{r.statusCode=404;r.end()}).pipe(r)).listen(4173)"
```

Отворете http://localhost:4173. Нужни са файловете на шрифта в `assets/fonts/`.

## Публикуване

1. Поставете шрифта в `site/assets/fonts/`.
2. Качете **съдържанието** на `site/` (без `tools/` и `README.md`) в папка `stb` в основата на сайта, така че адресът да е https://it-s.org/stb/.
3. Всички пътища са относителни, така че страницата работи и в подпапка.
4. Ако сайтът е на WordPress, проверете, че сървърът отдава папката директно и не я пренасочва през WordPress.

## Лого на компанията

Логото в долната част се зарежда от `https://it-s.org/wp-content/uploads/2025/04/Innovative-Technology-Solutions-Logo.png` на същия домейн. Ако файлът се премести, променете адреса в `index.html`.

## Лиценз

Кодът на страницата (HTML, CSS, скрипт за контури) е под MIT. Текстът е под CC BY-SA 4.0. Шрифтът Adys не е включен и е лицензиран отделно.

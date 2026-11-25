"""Render the caption layer frame by frame as transparent 1080x1920 PNGs.

Usage: python3 render_captions.py [--chrome /path/to/chrome] [--fps 24] [--dur 25] [--lang es|en|fr] [--only t1,t2] [--out build/captions]
Needs: pip install playwright (and either `playwright install chromium` or --chrome pointing to Google Chrome).
"""
import argparse, asyncio, pathlib
from playwright.async_api import async_playwright

ap = argparse.ArgumentParser()
ap.add_argument('--chrome', default=None)
ap.add_argument('--fps', type=int, default=24)
ap.add_argument('--dur', type=float, default=25.0)
ap.add_argument('--out', default='build/captions')
ap.add_argument('--lang', default='es')
ap.add_argument('--only', default=None, help='comma-separated seconds: render just these frames (for checks)')
a = ap.parse_args()
html = (pathlib.Path(__file__).resolve().parent.parent / 'captions' / 'captions.html').as_uri() + '?render&lang=' + a.lang
out = pathlib.Path(a.out); out.mkdir(parents=True, exist_ok=True)

async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(executable_path=a.chrome) if a.chrome else await p.chromium.launch()
        pg = await b.new_page(viewport={'width': 1080, 'height': 1920})
        await pg.goto(html); await pg.evaluate('window.captionsReady')
        n = round(a.dur * a.fps)
        frames = [round(float(s) * a.fps) for s in a.only.split(',')] if a.only else range(n)
        for i in frames:
            await pg.evaluate(f'window.renderAt({i / a.fps})')
            await pg.screenshot(path=str(out / f'cap_{i:04d}.png'), omit_background=True)
        await b.close()
        print(f'{n} frames -> {out}')
asyncio.run(main())

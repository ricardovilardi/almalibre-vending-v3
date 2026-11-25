# Almalibre v3 — screen-by-screen plan

Machine: NonStop vending (base theme "Onctuo"). We replace images; the provider's app draws
the dynamic UI (topping grid, prices, buttons, bowl selector, order text) on top.

Rules: design in Spanish once and copy it to the `_en` and `_fr` files. Keep the exact name, px size and format.
Note: the provider's "alpha" full screens are fully opaque, apart from a 1 px edge.

## Business rules
- Toppings: any number of different toppings, **max 1 of each** (toggle on/off).
- 6 toppings on screen (Figma node 46-255). Sólidos: granola, oreo, paçoca. Líquidos: frutos rojos,
  chocolate blanco y nocciola, + 1 per-machine slot: pistacho OR crema de cacahuete/cacao/avellana (assumed).
- 1, 2 or 3 bowls per order. Bowl base €4.50 + €1.00 per topping (placeholders).
- "Imagen ilustrativa" under topping photos. "Paçoca (Cacahuete dulce)".

## Flow
| # | Screen | Delivered files | Our image | App draws on top |
|---|---|---|---|---|
| 1 | Welcome | one MP4 per language: assets/video/attract_es.mp4 / attract_en.mp4 / attract_fr.mp4 — 1080x1920 H.264, 24 fps, 25.0 s seamless loop, WITH AUDIO (AAC 48 kHz stereo 192 kbps). Posters assets/attract-poster_{es,en,fr}.jpg. The old silent assets/video/attract.mp4 (ES, no button) is kept only for old links | claymation "Almita" loop v2 (assets/video/intro-source.mp4) with animated captions burned in: Filson Pro Heavy 88 px, white, soft purple shadow, centred, top-anchored block y 1474–1670 (above the tap button). 3.2–7.9 s "Del corazón / de la Amazonia." (kinetic-center-build) · 8.1–10.9 s "Cremoso. / Intenso." (focus-blur-resolve) · 11.1–15.0 s "Puro sabor / a tu ritmo." (short-slide-right) · 15.1–17.9 s "Elige tus toppings." (spring-scale-in) · 18.4–20.9 s "¡Listo!" (per-character-rise, completes on the clap ≈19.0 s) · 21.2–24.8 s "Tu açaí te espera." (blur-out-up). Every caption exits with blur-out-up (480 ms, 24 ms stagger). No caption 0–3.2 s or 24.8–25 s. White brand symbol (design/img/symbol-white.svg, 144 px) top-left for the whole video. Captions translated per language (design/video-v3/captions/captions.html `?lang=es|en|fr`). Tap button burned in (provider asked): design/video-v3/button/button.html, cream pill + hand at y≈1705, pulses every 2.5 s (10 pulses per loop): es "TOCA LA PANTALLA / PARA CONTINUAR", en "TOUCH THE SCREEN / TO CONTINUE", fr "TOUCHE L’ÉCRAN / POUR CONTINUER". Sound (approved 2026-11-25): soft tropical music bed (assets/audio/raw/music_a.mp3, RMS 0.03, ~8 dB below the first test) + effect set B with a soft Amazon bird at the start (lettered aracari, sfx14b_aracari_trim.wav at 0.35 s, level 0.24, replaces the whistle — client request 2026-11-25), a single clean clap (sfx08_single_clap.wav, cut from sfx08b) at 18.955 s and 19.33 s, and an Amazon bird call (sfx12b_bird_trim.wav) at 20.25 s instead of the chime. AAC leaves the audio 44 ms shorter than the video (tiny gap at the loop). Tap → 2 | whole screen is tappable; the prototype bar has Idioma (es/en/fr) and Sonido (browsers only allow sound after a tap); only this video has sound, the other screen videos stay muted |
| 2 | Personaliza | welcome_vanille_en/fr.jpg, welcome_mangues_en/fr.jpg (both identical, single design) | #FFFCF5, purple logo, no slot box (beige slot removed 2026-11-22: the machine plays the product video in a 16:9 strip 960x540 at x60 y510 straight on the cream), purple text below: "Tu bowl de açaí en segundos" + "Natural, fresco y a tu manera" | product slot: cup only, no text (assets/bowls-1.png, transparent); bottom button (colour + text configurable). The machine app plays a landscape product video in this slot: export/video/onctuo_welcome_cup_loop.mp4 (H.264 on #FFFCF5) / onctuo_welcome_cup_loop_alpha.mov (HEVC with alpha), 1920x1080, 24 fps, 8 s seamless 360° turntable, no audio, cup ~43% of the video width (default --lens 85; a 62% test was too small in the 960 px strip), MP4 tagged BT.709. Rendered in Blender 4.1 from scripts/cup_scene.py (cup wrap assets/cup_print_tex3_seam.png from the client's graphic-pack3.svg; 5-point star açaí piped from 60% fill) and encoded with scripts/png_seq_encode.swift |
| 3 | Toppings | book_en.jpg, book_fr.png | #FFFCF5 with Almita peeking from the right edge (design/img/book-final.png, from assets/higgsfield/book-final-L.png), purple text: "Personaliza tu açaí" (one line) + "Elige tus toppings". Preferred: video export/video/onctuo_book_loop.mp4, played ONCE per visit (no loop; ends on the same frame as the JPG) (H.264 1080x1920, 24 fps, 7.75 s, no audio, title burned in; Almita waves, presents the toppings palm-up with a red tongue tip, waves again; Kling v3.0 Pro segments assets/higgsfield/book-loop-part1/2.mp4 joined by scripts/loop_join.swift with a 6-frame crossfade; first frame = last frame = the JPG/PNG). The image is the fallback | Sólidos/Líquidos label images, topping cards, total, Volver/Siguiente |
| 3a | Section titles | book_topping_en 548x60, _fr 594x60 = "Sólidos"; book_sauce_en 211x45, _fr 608x60 = "Líquidos" | #4A1F6E, transparent, fixed height | – |
| 3b | Selected mark | bg_diy_selected_mark.png 256x256 | #FAB417 circle (172 px), #4A1F6E check | used on toppings and bowl quantity |
| 4 | Bowl quantity | order_en/fr.jpg | #FFFCF5, "¿Cuántos bowls quieres?" + "Elige 1, 2 o 3" | 1/2/3 bowl images (assets/bowls-1/2/3.png, 1000x1000 transparent; app data for the provider), selected mark, buttons |
| 5 | Summary | payment_en/fr.jpg | #FFFCF5, text only: "Resumen de tu pedido" + "Revisa que todo esté bien" | "Seleccionado: N bowls" + order text, buttons |
| 6 | Payment | – | **on hold, no clear path from the provider yet** | – |
| 7 | Preparing | outing_en.jpg, outing_fr.png + outing_process_1–4.png 485x74 | #FFFCF5, purple #4A1F6E text, light-beige #F5F1E8 panels; progress bar: purple outline, light-purple #8B2FC9 fill; texts centred | progress steps (loading state); cup = assets/bowls-1.png |
| 8 | Sold out | sold_out_en.png, sold_out_fr.png | full-bleed claymation image, no text: sad Almita showing an empty cup (design/img/sold-out-almita.png, from assets/higgsfield/soldout-B.png). Preferred: looping video, one per language: export/video/onctuo_sold_out_loop_{es,en,fr}.mp4 (H.264 1080x1920, 24 fps, 6.54 s, no audio; Almita peeks into the cup, then looks at the camera; base clip export/video/onctuo_sold_out_loop.mp4 from assets/higgsfield/soldout-loop-raw.mp4, MiniMax H3, first frame = last frame). Animated text (approved 2026-11-25, message B): layout = Figma "agotado" 225:1154 at 80 % placed like frame 165:37 (lockup over Almita's legs, x 212–810, y 1143–1778); motion like the kinetic "drop and stack" reference: headline words fall in one by one in reading order with a small bounce, subline pops in, everything drops out at 5.7 s so the loop starts empty. Source design/video-v3/soldout/soldout_text.html (?lang=es|en|fr). es HOY EL AÇAÍ HA VOLADO / LO SENTIMOS, VUELVE PRONTO, TE ESPERAMOS · en TODAY OUR AÇAÍ FLEW AWAY / SORRY! COME BACK SOON, WE'LL BE WAITING · fr AUJOURD'HUI, L'AÇAÍ S'EST ENVOLÉ / DÉSOLÉS. REVIENS VITE, ON T'ATTEND. The PNG fallback (design/sold_out.html) carries the Spanish text (design/img/sold-out-text-es.png = the final text frame). Back button maybe later | – |
| – | Common mark (hidden) | label_common_mark.png 308x344 | fully transparent | – |

## App colours to send to the provider
- Background of light screens: #FFFCF5
- Text (app and screen titles, incl. Sólidos/Líquidos labels): #4A1F6E (12:1 on #FFFCF5), switched from #FAB417 for legibility
- Topping card fill: #F5F1E8 · card text #4A1F6E · price smaller, regular weight · "Imagen ilustrativa" #8E8167
- Topping images: no background
- Primary button (Personaliza start, Siguiente, Pagar): fill #FAB417, text #24142E dark purple (9.6:1)
- Secondary button (Volver): fill #FFFFFF, text + border #4A1F6E

## Requests to the provider (not possible with images)
- Personaliza button text and colour.
- Separate colours for app text, primary button and secondary button.
- Topping card style above (fill, caption colour, smaller regular price, no image background).
- Limit each topping to 1 per order; Spanish copy ("Selected" → "Seleccionado", "cup" → "bowl").
- Payment flow details.
- Sold-out back button (if any).

## How to rebuild the assets
`./scripts/render.sh` renders design/*.html with headless Chrome → export/ (names, sizes and formats from scripts/manifest.txt).
Video captions (v3): design/video-v3/captions/captions.html is the source of truth (cue table + animations; open it to preview, `?render` for the transparent layer).
Fonts go in design/video-v3/captions/fonts/FilsonPro-{Medium,Bold,Heavy}.otf (not in the repo: commercial licence). Then:
`python3 design/video-v3/scripts/render_captions.py --chrome "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --out build/captions` (needs `pip install playwright`),
render design/video-v3/symbol.html to build/video/symbol.png, and
`swiftc -O scripts/overlay_sequence.swift -o build/overlay_sequence && build/overlay_sequence assets/video/intro-source.mp4 build/captions/cap_%04d.png assets/video/attract.mp4 build/video/symbol.png` (old silent ES version).
Intro v3 per language (L = es|en|fr): captions with `render_captions.py --lang L --out build/captions_L`, button layer from design/video-v3/button/button.html → build/button_L.png, then
`build/attract_compose assets/video/intro-source.mp4 build/captions_L build/button_L.png - build/attract_L_video.mp4 build/symbol_layer.png`,
`build/mix_soundtrack assets/audio/raw build/soundtrack_final.wav b` (defaults = approved mix), `afconvert -f m4af -d aac -b 192000 build/soundtrack_final.wav build/soundtrack_final.m4a`,
`build/mux_audio build/attract_L_video.mp4 build/soundtrack_final.m4a assets/video/attract_L.mp4` (build each tool with `swiftc -O scripts/<name>.swift -o build/<name>`).
Sold-out text: render 157 transparent frames of design/video-v3/soldout/soldout_text.html?lang=L&render (renderAt(i/24)) to build/soldout_text_L/cap_%04d.png, then
`build/attract_compose export/video/onctuo_sold_out_loop.mp4 build/soldout_text_L build/empty_1080x1920.png - export/video/onctuo_sold_out_loop_L.mp4` (empty_1080x1920.png = a fully transparent PNG in place of the button).
Add `?zones` to any design/*.html URL to see where the provider's app draws on top.

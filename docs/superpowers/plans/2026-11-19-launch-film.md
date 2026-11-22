# Film de lancement Modern Downloader — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** produire `modern-downloader-launch-1080p.mp4`, un film de 30 s en 16:9. Motion design composé en code sur les vraies captures Android, avec des plates lumineuses Seedance et un sound design calé au tempo.

**Architecture :** un moteur de rendu Python (numpy + OpenCV + PIL) dessine chaque image à 1920×1080, couche par couche : fond, plates Seedance en mode screen, téléphone, typo, finition. Chaque scène est envoyée à ffmpeg et donne un mp4. On les concatène ensuite sans réencodage, puis on ajoute le master audio : musique alignée à 120 BPM, plus des SFX numpy générés à partir de la même table de cues que l'image.

**Tech Stack :** Python 3 (numpy, scipy, opencv, Pillow, pytest), ffmpeg 6.1, polices Inter / Inter Display, Higgsfield MCP (Seedance 2.5 en illimité).

**Spec :** `docs/superpowers/specs/2026-11-19-launch-film-design.md`

## Global Constraints
- Sortie : 1920×1080, 30 fps, 900 images, H.264 `-crf 16 -pix_fmt yuv420p`, AAC 320 kb/s 48 kHz stéréo, durée 30,00 s ± 0,05.
- Tempo : 120 BPM. `BEAT = 15` images, `BAR = 60` images. Chaque cue tombe sur un multiple de 15, sauf `tick`.
- Scènes (fin exclue) : S1 0–120, S2 120–330, S3 330–570, S4 570–780, S5 780–900.
- Zone sûre : x ∈ [96, 1824], y ∈ [54, 1026].
- Palette : noir `#000000`, gris `#27272A` / `#A1A1AA`, blanc et rouge échantillonnés dans `assets/brand/logo-1024.png`. Une seule touche de rouge par plan.
- Textes exacts (`config.COPY`) : « Partage. Un tap. » · « 1 800+ sites. » (espace insécable U+00A0) · « Envoi local. Sans câble. » · « Ton archive TikTok. » · « Modern Downloader » · « Android · Open source · Zéro pub ».
- L'IA ne dessine jamais d'interface, de texte, de logo, de téléphone, de mains ou de visages. Les plates Seedance restent abstraites, sur fond noir.
- Higgsfield : seedance_2_5, `mode:"t2v"`, `resolution:"720p"`, `aspect_ratio:"16:9"`, `use_unlim:true` (accordé en validant ce plan). Aucune dépense de crédits sans accord explicite.
- Le film se rend sans aucune plate, grâce au repli procédural.
- Rendu vidéo (skill video-making) : un mp4 par scène, tous avec les mêmes réglages. On écrit dans `*.tmp.mp4` et on renomme quand ffmpeg sort en 0. On concatène avec `-c copy` et on ajoute le son avec `-c:v copy`.
- Workspace : `/home/claude/launch-film/` (git local pour les points de sauvegarde). Livraison sur l'appareil dans `Downloader-main/marketing/launch-film/` via `device_commit_files` (`device_bash` est indisponible : disque plein).

## Review Focus
1. **Plates absentes, illisibles ou bloquées au transfert** : le film doit se rendre quand même, avec des plates procédurales cohérentes. Test : `test_plate_fallback` (Task 3).
2. **Une plate contient du texte, un objet, un visage ou un dégradé générique** : elle est rejetée et régénérée, au plus 2 fois, puis on passe au repli. Contrôle visuel de 3 images par plate (Task 4, étape 4).
3. **Une capture garde la barre de navigation Android grise** : elle est rognée à 2395 px de haut, et les 20 dernières lignes doivent être sombres. Test : `test_screens_cropped_dark_bottom` (Task 2).
4. **Saturation, master trop fort ou SFX décalés de l'image** : I = −14 ± 1 LUFS, TP ≤ −1 dBTP, chaque impact à ± 1 image de sa cue. Tests `test_impact_aligned`, `test_master_loudness` (Task 8).
5. **Texte qui déborde ou « 1 800+ » coupé en deux** : chaque chaîne de `COPY`, rendue à sa taille réelle, tient dans la zone sûre sur une seule ligne. Test : `test_copy_fits_safe_area` (Task 3).

---

### Task 1 : Squelette, constantes, timeline, easing

**Files :**
- Create: `film/__init__.py`, `film/config.py`, `film/timeline.py`, `film/ease.py`
- Test: `tests/test_timeline.py`, `tests/test_ease.py`

**Interfaces :**
- Produces :
  - `config` : `W=1920, H=1080, FPS=30, BPM=120, BEAT=15, BAR=60, TOTAL=900, SAFE=(96,54,1824,1026)`, `ROOT: Path`, `ASSETS: Path`, `OUT: Path`, `FONTS: dict[str, Path]` (`black`, `bold`, `semibold`, `medium` → `/usr/share/fonts/opentype/inter/InterDisplay-Black.otf`, `InterDisplay-Bold.otf`, `Inter-SemiBold.otf`, `Inter-Medium.otf`), `COPY: dict[str,str]` (clés `share`, `sites`, `send`, `archive`, `name`, `tagline`), `LOGO_WHITE`, `LOGO_RED`, `LOGO_OFF: tuple[int,int,int]` (remplis en Task 2), `GREY_DARK=(39,39,42)`, `GREY=(161,161,170)`.
  - `timeline` : `Scene(name:str, start:int, end:int)`, `SCENES: tuple[Scene,...]`, `Cue(frame:int, kind:str, gain_db:float=0.0, length:int=0)`, `CUES: tuple[Cue,...]`, `beat(n: float) -> int`, `scene_at(frame:int) -> Scene`.
  - `ease` : `clamp01(x)`, `progress(f, a, b) -> float` (borné à 0..1), `out_expo(t)`, `in_out_cubic(t)`, `out_back(t, s=1.70158)`, `spring(t, freq=4.5, damping=0.35)`. Toutes de float vers float.

- [ ] **Step 1 : écrire les tests qui échouent**
```python
def test_scenes_contiguous():
    assert SCENES[0].start == 0 and SCENES[-1].end == 900
    assert all(a.end == b.start for a, b in zip(SCENES, SCENES[1:]))
    assert [s.name for s in SCENES] == ["s1", "s2", "s3", "s4", "s5"]
def test_cues_on_beat_grid():
    assert all(c.frame % 15 == 0 for c in CUES if c.kind != "tick")
    assert all(0 <= c.frame < 900 for c in CUES)
def test_tick_run():
    assert [c.frame for c in CUES if c.kind == "tick"] == list(range(330, 390, 3))
def test_ease_endpoints():
    for fn in (out_expo, in_out_cubic, out_back, spring):
        assert abs(fn(0)) < 1e-6 and abs(fn(1) - 1) < 1e-3
def test_out_back_overshoots():
    assert max(out_back(i / 100) for i in range(101)) > 1.0
def test_progress_clamped():
    assert progress(5, 10, 20) == 0 and progress(25, 10, 20) == 1 and progress(15, 10, 20) == 0.5
```
- [ ] **Step 2 :** `pytest tests/test_timeline.py tests/test_ease.py -q` → FAIL (ImportError).
- [ ] **Step 3 : implémenter.** `CUES` exactes : `riser@105 len 90`, `impact@105`, `whoosh@120`, `impact@165`, `tap@225`, `impact@285`, `tick@330..387 pas 3`, `impact@390`, `whoosh@480`, `glitch@480`, `whoosh@570`, `impact@585`, `swell@630 len 60`, `impact@690`, `tap@705`, `tap@720`, `tap@735`, `riser@780 len 60`, `impact@780 gain +2`, `swell@840 len 60`. Une cue désigne le pic : un riser ou un swell commence `length` images plus tôt. `spring` : `1 - exp(-damping·10·t)·cos(freq·2π·t)`, normalisé pour valoir 1 à t = 1.
- [ ] **Step 4 :** relancer → PASS.
- [ ] **Step 5 :** `git init` (premier passage), `git add -A && git commit -m "film: timeline, easing, config"`.

### Task 2 : Assets — logo en grille, captures, maquette téléphone

**Files :**
- Create: `film/assets.py`, `assets/screens/*.png` (8 captures copiées), `assets/brand/logo-1024.png`
- Modify: `film/config.py` (valeurs `LOGO_*` mesurées)
- Test: `tests/test_assets.py`

**Interfaces :**
- Consumes : `config.ASSETS`.
- Produces :
  - `Dot(col:int, row:int, state:str)`, où state vaut `"off"`, `"on"` ou `"red"`.
  - `logo_grid() -> list[Dot]` et `logo_layout(center:tuple[float,float], pitch:float) -> list[tuple[Dot,float,float]]` (position écran de chaque point ; grille de 7 colonnes, centre de la colonne 3).
  - `sample_logo_colors() -> tuple[rgb_white, rgb_red, rgb_off]`.
  - `SCREENS: dict[str,str]` = `{"share":"06_share.png","capture":"23_capture_to_add_sheet.png","done":"05_done.png","browser":"22_browser_capture_bar.png","library":"03_library.png","send":"12_send.png","archive":"14_archive.png","stats":"13_stats.png"}`.
  - `load_screen(key:str) -> np.ndarray` en RGB uint8, rogné à 1170×2395 et mis en cache.
  - `phone(screen: np.ndarray, height:int) -> np.ndarray` en RGBA uint8 : bezel `#0B0B0C` d'épaisseur 0,016·hauteur, rayon 0,13·largeur, liseré de 1 px `#2A2A2E`, écran incrusté au rayon 0,11·largeur.

- [ ] **Step 1 : placer les fichiers.** `device_stage_files` des 8 captures (`docs/verification/android/`) et du logo, puis copie dans `assets/`.
- [ ] **Step 2 : écrire les tests qui échouent**
```python
def test_logo_grid_counts():
    g = logo_grid()
    assert len(g) == 59
    assert sum(d.state == "on" for d in g) == 17
    assert [(d.col, d.row) for d in g if d.state == "red"] == [(3, 6)]
    assert {d.col for d in g if d.row in (0, 8)} == {1, 2, 3, 4, 5}
def test_logo_colors_plausible():
    w, r, o = sample_logo_colors()
    assert min(w) > 220 and r[0] > 200 and r[1] < 110 and max(o) < 40
@pytest.mark.parametrize("key", SCREENS)
def test_screens_cropped_dark_bottom(key):
    s = load_screen(key)
    assert s.shape == (2395, 1170, 3) and s[-20:].mean() < 60
def test_phone_alpha():
    p = phone(load_screen("send"), 900)
    assert p.shape[0] == 900 and p[0, 0, 3] == 0 and p[450, p.shape[1] // 2, 3] == 255
```
- [ ] **Step 3 :** `pytest tests/test_assets.py -q` → FAIL.
- [ ] **Step 4 : implémenter.** Grille : `cv2.connectedComponentsWithStats` sur max(RGB) > 12 dans le logo, puis classement des centroïdes en lignes et colonnes (pas d'environ 83 px). État selon la couleur moyenne du disque. `phone` : masque à coins arrondis, dessiné en sur-échantillonnage ×2 puis réduit (anticrénelage).
- [ ] **Step 5 :** relancer → PASS. Recopier les trois couleurs mesurées comme littéraux dans `config.py`.
- [ ] **Step 6 :** commit `"film: assets logo, screens, phone"`.

### Task 3 : FX, plates et typographie

**Files :**
- Create: `film/fx.py`, `film/typo.py`
- Test: `tests/test_fx.py`, `tests/test_typo.py`

**Interfaces :**
- Consumes : `config.*`, `ease.*`, `timeline.CUES`.
- Produces :
  - `fx.screen_blend(base: f32, layer: f32, opacity: float) -> f32` (images H×W×3 dans 0..1).
  - `fx.grain(img, f:int, amount=0.035)`, déterministe par `f`.
  - `fx.vignette(img, strength=0.25)`.
  - `fx.chroma_shift(img, px:int)`.
  - `fx.motion_blur(render: Callable[[float], f32], f:int, samples=4, shutter=0.5) -> f32`.
  - `fx.finish(img: f32, global_f:int) -> uint8` : grain et vignette toujours, chroma_shift(6→0) pendant les 2 images qui suivent chaque `impact`.
  - `fx.Plate(name: Literal["p1","p2","p3","p4","p5"])` avec `.frame(t: float) -> f32 (1080,1920,3)` : il lit `assets/plates/{name}.mp4` (redimensionné en bicubique, boucle), sinon il génère le repli procédural du même motif.
  - `typo.text_layer(text, size:int, weight="black", tracking=-0.02, color=(255,255,255)) -> RGBA uint8`.
  - `typo.paste(dst: f32, rgba, cx: float, cy: float, scale=1.0, alpha=1.0) -> f32`, avec positionnement sous-pixel via `cv2.warpAffine`.
  - `typo.kinetic(words: list[str], f_local:int, size:int, per_word:int=4, y=540) -> RGBA (1080,1920)` : chaque mot monte de 0,35·size derrière un masque, en `out_expo` sur 10 images, les mots décalés de `per_word` images.
  - `typo.COPY_SIZES = {"share":150, "sites":190, "send":120, "archive":120, "name":110, "tagline":34}`.

- [ ] **Step 1 : écrire les tests qui échouent**
```python
def test_plate_fallback(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "ASSETS", tmp_path)
    for n in ("p1", "p2", "p3", "p4", "p5"):
        p = Plate(n); a, b = p.frame(0.5), p.frame(1.5)
        assert a.shape == (1080, 1920, 3) and 0 <= a.min() and a.max() <= 1
        assert a.mean() < 0.35 and np.abs(a - b).mean() > 1e-3
def test_screen_blend_never_darkens():
    base = np.random.rand(8, 8, 3).astype(np.float32); lay = np.random.rand(8, 8, 3).astype(np.float32)
    assert (screen_blend(base, lay, 1.0) >= base - 1e-6).all()
def test_finish_uint8_and_deterministic():
    img = np.full((1080, 1920, 3), 0.5, np.float32)
    assert finish(img, 10).dtype == np.uint8 and (finish(img, 10) == finish(img, 10)).all()
@pytest.mark.parametrize("key", list(COPY))
def test_copy_fits_safe_area(key):
    t = text_layer(COPY[key], COPY_SIZES[key], "black" if key != "tagline" else "medium")
    h, w = t.shape[:2]
    assert w <= 1824 - 96 and h <= COPY_SIZES[key] * 1.6   # une seule ligne
def test_kinetic_end_state_inside_safe():
    a = kinetic(COPY["send"].split(), 60, COPY_SIZES["send"])[..., 3]
    ys, xs = np.nonzero(a)
    assert xs.min() >= 96 and xs.max() <= 1824 and ys.min() >= 54 and ys.max() <= 1026
```
- [ ] **Step 2 :** `pytest tests/test_fx.py tests/test_typo.py -q` → FAIL.
- [ ] **Step 3 : implémenter.** Replis procéduraux, tous en blanc monochrome sur noir et avec `t` comme seule horloge : p1 grille de points (pas 48 px) traversée par une vague gaussienne ; p2 traînées radiales issues du centre ; p3 flash puis anneau de choc et particules (graine fixe) ; p4 anneaux pointillés concentriques ; p5 poussière floue (σ variable). `text_layer` : PIL `ImageFont.truetype`, un glyphe à la fois pour appliquer le tracking, rendu ×2 puis réduit.
- [ ] **Step 4 :** relancer → PASS.
- [ ] **Step 5 :** commit `"film: fx, plates fallback, typo"`.

### Task 4 : Plates Seedance (génération, contrôle, transfert)

**Files :**
- Create: `assets/plates/p1.mp4` … `p5.mp4`, `assets/plates/QC.md` (job id, verdict, raison)

**Interfaces :**
- Produces : les fichiers lus par `fx.Plate`. Une plate absente signifie repli procédural ; aucun autre code ne dépend de cette tâche.

- [ ] **Step 1 : générer.** Appel `generate_video_batch` avec 5 éléments `{model:"seedance_2_5", mode:"t2v", duration:5, resolution:"720p", aspect_ratio:"16:9", generate_audio:false, use_unlim:true}`. Chaque prompt se termine par le suffixe commun : *"Pure black background. Monochrome white light only. Locked-off camera. No text, no letters, no numbers, no logos, no people, no faces, no hands, no phones, no devices, no objects, no planets, no gradients."*
  - **p1 :** *"Abstract motion graphics plate: a perfectly regular grid of small white dots; a smooth wave of brightness travels left to right across the grid, dots swelling and glowing as it passes, then dimming. Crisp, high contrast, orthographic."*
  - **p2 :** *"Thin white light streaks rush toward the camera through infinite black space, a few streaks with a faint warm red tint, hyperspeed tunnel, motion blur on streaks only."*
  - **p3 :** *"A single bright white flash at the center at 0.5 seconds, then a circular shockwave ring and thousands of fine white particles bursting outward and slowing down, a few tiny red sparks, embers fading over four seconds."*
  - **p4 :** *"Concentric dotted circles made of tiny white dots pulse outward from the center like a sonar signal, evenly spaced rings expanding and fading, rhythmic, crisp, orthographic."*
  - **p5 :** *"Very subtle fine white dust particles drifting slowly in deep black space, shallow depth of field, a few soft out-of-focus specks, extremely dark and minimal."*
- [ ] **Step 2 :** `jobs_wait` par groupe jusqu'à `all_terminal`, puis un seul `show_generation_by_ids`.
- [ ] **Step 3 : transférer.** Dans le navigateur intégré, ouvrir chaque URL de résultat. Exécuter `fetch(location.href).then(r=>r.blob()).then(b=>{const a=document.createElement('a');a.href=URL.createObjectURL(b);a.download='mdl-pN.mp4';a.click()})`. Puis `device_request_folder_access(["~/Downloads"])` et `device_stage_files` des 5 fichiers, renommés en `assets/plates/pN.mp4`. Si ça échoue : envoyer à l'utilisateur la liste des liens, avec la consigne de les déposer dans `Downloader-main/marketing/launch-film/plates/`, puis les stager depuis là.
- [ ] **Step 4 : contrôle qualité.** Pour chaque plate, extraire 3 images (0,5 s, 2,5 s, 4,5 s) avec `ffmpeg -ss T -frames:v 1` et les regarder. **Rejet** si l'image montre du texte, un objet reconnaissable, un visage, un dégradé coloré, ou si la luminance moyenne du fond est > 0,15. Une plate rejetée est régénérée avec le même prompt, au plus 2 fois, puis elle est supprimée (repli procédural). Consigner le tout dans `QC.md`.
- [ ] **Step 5 :** `pytest -q` → toujours PASS ; `Plate("pN").frame(1.0)` charge le mp4 quand il existe. Commit `"film: plates seedance"`.

### Task 5 : Moteur de rendu, puis S1 Accroche et S5 Final

**Files :**
- Create: `film/render.py`, `film/scenes/__init__.py`, `film/scenes/s1_hook.py`, `film/scenes/s5_end.py`, `film/scenes/logo_anim.py`
- Test: `tests/test_render.py`

**Interfaces :**
- Consumes : `assets.logo_layout`, `fx.*`, `typo.*`, `timeline.SCENES`, `ease.*`.
- Produces :
  - Chaque module de scène expose `render(f: int) -> np.ndarray (1080,1920,3) float32 0..1`, avec `f` local à la scène et la finition **non** appliquée. `scenes.REGISTRY: dict[str, Callable[[int], f32]]`.
  - `logo_anim.draw(img: f32, layout, lit: Callable[[Dot], float], glow: float=0.0) -> f32` : dessine les 59 disques (diamètre 0,72·pitch, anticrénelés). `lit` renvoie une intensité de 0 à 1 par point ; le halo est un flou gaussien du calque allumé.
  - CLI : `python -m film.render --scene s1|…|s5|all [--stills 0,60,105] [--frames A:B]`. La vidéo va dans `out/scenes/{name}.mp4` (temporaire `{name}.tmp.mp4`, renommé quand ffmpeg sort en 0), les images fixes dans `out/stills/{name}_f{N:03d}.jpg` (qualité 92).
  - Commande ffmpeg exacte : `ffmpeg -y -f rawvideo -pix_fmt rgb24 -s 1920x1080 -r 30 -i - -c:v libx264 -preset veryfast -crf 16 -pix_fmt yuv420p -g 30 -bf 2 OUT`.

- [ ] **Step 1 : écrire les tests qui échouent**
```python
@pytest.mark.parametrize("name,f", [("s1", 0), ("s1", 105), ("s5", 60)])
def test_scene_frame_shape(name, f):
    img = REGISTRY[name](f)
    assert img.shape == (1080, 1920, 3) and img.dtype == np.float32 and 0 <= img.min() and img.max() <= 1
def test_s1_starts_with_single_red_dot():
    img = REGISTRY["s1"](20)
    red = (img[..., 0] > 0.6) & (img[..., 1] < 0.4)
    assert red.any() and img[~red].mean() < 0.05
def test_render_cli_writes_scene(tmp_path):
    run_scene("s1", out_dir=tmp_path, frames=(0, 30))
    assert probe_frames(tmp_path / "s1.mp4") == 30 and not (tmp_path / "s1.tmp.mp4").exists()
```
- [ ] **Step 2 :** `pytest tests/test_render.py -q` → FAIL.
- [ ] **Step 3 : implémenter S1** (120 images). f0–29 : le point rouge apparaît seul au centre, en `out_expo`, avec une légère respiration d'échelle. f30–99 : il prend sa place en (3,6) ; les colonnes s'allument du centre vers les bords, une colonne toutes les 6 images, les points éteints apparaissent en `LOGO_OFF`. f60–104 : la caméra pousse de ×1,0 à ×1,15. f105 : impact, le halo monte à 1 puis redescend en 12 images, la plate p3 passe en screen à 0,6 et décroît, `fx.motion_blur` sur f100–110. f110–119 : le logo se rétracte en `in_out_cubic` vers ×0,4, sur le temps d'avant S2.
- [ ] **Step 4 : implémenter S5** (120 images). f0 : impact ; les 59 points arrivent depuis des positions éparpillées (graine fixe) vers la grille, en `spring`, avec motion blur sur f0–20. f24–45 : `kinetic` de « Modern Downloader » sous le logo (logo à gauche, wordmark à droite, le tout centré). f45–60 : la tagline apparaît en `GREY`, tracking +0,08. f60–105 : tenue, p5 à 0,25. f105–119 : noir en `in_out_cubic`.
- [ ] **Step 5 :** relancer → PASS. `python -m film.render --scene s1 --stills 0,20,60,90,105,112` et `--scene s5 --stills 0,12,40,70,110`. Regarder chaque image : alignement exact du logo, aucun crénelage, rouge unique.
- [ ] **Step 6 :** commit `"film: render engine, S1, S5"`.

### Task 6 : S2 Partage, S3 Navigateur & bibliothèque, S4 Envoi & archive

**Files :**
- Create: `film/scenes/s2_share.py`, `film/scenes/s3_browse.py`, `film/scenes/s4_send.py`, `film/scenes/stage.py`
- Test: `tests/test_scenes.py`

**Interfaces :**
- Consumes : `assets.phone`, `assets.load_screen`, `typo.kinetic`, `fx.Plate`, `fx.motion_blur`.
- Produces : `render(f)` pour s2, s3 et s4 (même contrat que la Task 5), plus `stage.place_phone(img, phone_rgba, cx, cy, scale, rot_y_deg=0.0, rot_z_deg=0.0, alpha=1.0) -> f32` : perspective 2,5D par `cv2.getPerspectiveTransform`, focale 2200 px, ombre portée en flou gaussien σ = 40 à 35 % d'opacité.

- [ ] **Step 1 : écrire les tests qui échouent**
```python
@pytest.mark.parametrize("name,f", [("s2", 0), ("s2", 105), ("s2", 209), ("s3", 0), ("s3", 150), ("s4", 30), ("s4", 180)])
def test_scene_frames_valid(name, f):
    img = REGISTRY[name](f)
    assert img.shape == (1080, 1920, 3) and np.isfinite(img).all()
def test_phone_visible_after_slam():
    img = REGISTRY["s2"](60)          # f global 180, après l'impact de 165
    assert img[300:800, 760:1160].mean() > 0.05
def test_counter_reaches_1800():
    assert counter_value(59) == 1800 and counter_value(0) == 0
```
- [ ] **Step 2 :** `pytest tests/test_scenes.py -q` → FAIL.
- [ ] **Step 3 : implémenter S2** (f local, global = +120). f0–44 : `kinetic("Partage. Un tap.")` avec p2 en fond à 0,3. f30–45 : le texte s'efface vers le haut. f45 (global 165) : le téléphone `share` tombe de y −600 jusqu'au centre en `spring`, avec rot_z de −6° à 0, motion blur, et p3 qui flashe. f45–104 : lente dérive en rot_y de 8° à −4°. f105 (225) : cercle de tap (rayon de 0 à 60 px, s'efface en 10 images) au point où l'on touche, puis l'écran passe à `capture` par un glissement de 120 px vers le haut, en `out_expo` sur 8 images. f165 (285) : l'écran passe à `done`, avec un anneau rouge unique qui s'étend autour du téléphone. f195–209 : le téléphone part en whip à gauche (x −2400, motion blur).
- [ ] **Step 4 : implémenter S3** (global +330). f0–59 : `counter_value(f)` monte de 0 à 1800 en `out_expo`, affiché « 1 800+ sites. » en chiffres tabulaires, avec p1 derrière. f60 (390) : impact ; le téléphone `browser` arrive en push caméra ×0,8 → ×1,1, pivoté de 12° en Y. f60–149 : dérive lente. f150 (480) : whip pan horizontal, flou directionnel de 120 px plus glitch : 3 images avec bandes horizontales décalées et chroma_shift 10. f150–239 : le téléphone `library` se déplace vers la gauche, la colonne de vignettes défile en parallaxe (l'écran est translaté de 0 à −160 px à l'intérieur du masque, le bas étant rempli par un miroir flou).
- [ ] **Step 5 : implémenter S4** (global +570). f0–14 : `kinetic("Envoi local. Sans câble.")` en haut (y = 170). f15 (585) : impact ; deux téléphones `send` apparaissent en (560, 600) et (1360, 600) à l'échelle 0,62, inclinés de ±10° en Y. f15–119 : 140 particules blanches (graine fixe) partent du téléphone gauche vers le droit sur une courbe de Bézier (contrôle y = 260), avec traînée de 6 images, et p4 est centré sur le téléphone de droite. f120 (690) : impact ; on passe aux cartes, et `kinetic("Ton archive TikTok.")` s'affiche. f135, f150, f165 (705/720/735) : les cartes `archive`, `stats`, `library` arrivent en éventail (rot_z −8°, 0°, +8°, x 620/960/1300), une par tap, en `out_back`. f180–209 : l'éventail se resserre et se réduit vers le centre (×0,9) pour préparer S5.
- [ ] **Step 6 :** relancer → PASS. Images fixes : s2 `0,45,50,105,112,165,200`, s3 `0,30,60,150,152,200`, s4 `10,15,60,120,140,165,200`. Regarder chacune : aucun débordement, aucun texte flou, téléphones nets, une seule touche de rouge par plan.
- [ ] **Step 7 :** commit `"film: S2, S3, S4"`.

### Task 7 : Lit musical

**Files :**
- Create: `film/music.py`, `assets/audio/music_raw.(mp4|mp3)`, `assets/audio/music_120.wav`
- Test: `tests/test_music.py`

**Interfaces :**
- Produces : `align_music(src: Path, dst: Path, bpm=120, duration=30.0) -> dict` (`tempo_in`, `offset_s`, `stretched: bool`). La sortie est un WAV 48 kHz stéréo de 30,00 s exactement, dont la grille des temps est calée sur t = 0, avec un fondu final de 0,3 s.

- [ ] **Step 1 : écrire le test qui échoue**
```python
def test_align_synthetic_click(tmp_path):
    src = make_click_track(tmp_path / "c.wav", bpm=118, offset=0.13, seconds=32)
    info = align_music(src, tmp_path / "o.wav")
    assert abs(info["tempo_in"] - 118) < 1.0
    sr, y = wavfile.read(tmp_path / "o.wav"); assert sr == 48000 and len(y) == 30 * 48000
    env = np.abs(y[:, 0]).astype(float)
    peaks = [np.argmax(env[int(k * 24000) - 2400 : int(k * 24000) + 2400]) - 2400 for k in range(2, 50)]
    assert np.median(np.abs(peaks)) < 480           # < 10 ms
```
- [ ] **Step 2 :** `pytest tests/test_music.py -q` → FAIL.
- [ ] **Step 3 : implémenter.** Enveloppe d'onsets (flux spectral, fenêtre 1024, pas 256), tempo estimé par autocorrélation sur 80–160 BPM, `atempo = 120 / tempo_in` si l'écart dépasse 1 BPM, phase choisie parmi 0–0,5 s pour maximiser l'énergie sur la grille, puis découpage ou complément de silence.
- [ ] **Step 4 :** relancer → PASS.
- [ ] **Step 5 : obtenir la musique.** Lancer `estimate_audio_cost` pour `elevenlabs_music_v2_5` avec `duration:30`, `force_instrumental:true`. **Demander à l'utilisateur** : soit ElevenLabs (coût annoncé, sur ses 10 crédits), soit l'option gratuite. Option gratuite : seedance_2_5 en t2v, 30 s, 720p, `generate_audio:true`, `use_unlim:true`, prompt *"A completely black empty screen for the full duration, nothing visible. Audio only: epic modern cinematic trailer music, instrumental, 120 BPM. 0–3.5 s low sub drone and rising tension; huge hit at 3.5 s; 4–26 s driving hybrid percussion, pulsing synth bass, staccato strings, building; brief stop at 25.5 s; final massive hit at 26 s with long reverb tail to 30 s. No voice, no vocals."* Prompt ElevenLabs : même structure, sans la phrase sur l'écran noir. Transfert comme en Task 4, étape 3. Pour l'option gratuite : `ffmpeg -i raw.mp4 -vn -ac 2 -ar 48000 music_raw.wav`.
- [ ] **Step 6 :** `python -m film.music assets/audio/music_raw.* assets/audio/music_120.wav`. Écouter les 10 premières secondes en regardant l'enveloppe autour de 3,5 s et 26 s. Si le gros hit tombe à plus de 3 images de f105 ou de f780, décaler la phase sur le temps le plus proche, ou régénérer une fois. Commit `"film: music bed"`.

### Task 8 : SFX procéduraux, mixage, master

**Files :**
- Create: `film/audio.py`
- Test: `tests/test_audio.py`

**Interfaces :**
- Consumes : `timeline.CUES`, `assets/audio/music_120.wav` (facultatif).
- Produces :
  - `sfx(kind:str, length:int=0, sr=48000) -> tuple[np.ndarray (n,2) f32, int peak_index]`, pour `riser`, `impact`, `whoosh`, `tap`, `tick`, `glitch`, `swell`.
  - `build_sfx_track(cues=CUES, sr=48000, total=900) -> np.ndarray (1_440_000, 2)`.
  - `duck_env(cues, sr=48000, depth_db=-6.0, release_s=0.35) -> np.ndarray (n,)`.
  - `master(out: Path, music: Path | None) -> dict` (`I`, `TP`) : mixage puis `loudnorm` de ffmpeg en deux passes, avec `I=-14:TP=-1.5:LRA=9`.

- [ ] **Step 1 : écrire les tests qui échouent**
```python
def test_track_length_and_finite():
    t = build_sfx_track(); assert t.shape == (30 * 48000, 2) and np.isfinite(t).all()
def test_impact_aligned():
    t = build_sfx_track([Cue(105, "impact")])
    assert abs(np.argmax(np.abs(t[:, 0])) - 105 * 1600) <= 1600
def test_riser_ends_at_cue():
    x, peak = sfx("riser", 90); assert abs(peak - len(x)) < 4800
def test_master_loudness(tmp_path):
    m = master(tmp_path / "m.wav", music=None)
    assert -15 <= m["I"] <= -13 and m["TP"] <= -1.0
```
- [ ] **Step 2 :** `pytest tests/test_audio.py -q` → FAIL.
- [ ] **Step 3 : implémenter les recettes.** **impact** : sinus dont la fréquence chute de 90 à 38 Hz sur 0,6 s, avec saturation tanh, plus un transitoire de bruit (passe-haut 2 kHz, 25 ms), plus une queue en bruit rose filtrée passe-bas à 800 Hz (1,2 s). **riser** : bruit filtré en passe-bande dont le centre glisse de 300 Hz à 6 kHz, plus une dent de scie qui monte d'une octave, avec un gain exponentiel jusqu'au pic, puis une coupe nette. **whoosh** : bruit passe-bande qui balaie de 400 Hz à 3 kHz puis redescend, avec un panoramique de gauche à droite, 0,45 s centrées sur le pic. **tap** : clic sinus à 2,2 kHz de 8 ms plus un corps à 180 Hz de 30 ms. **tick** : clic à 4 kHz de 4 ms, −12 dB. **glitch** : 3 rafales de bruit bitcrushé (4 bits, échantillonnage réduit à 6 kHz) de 30 ms. **swell** : nappe de bruit inversée et réverbérée (convolution exponentielle) qui monte jusqu'au pic. Mixage : `music × duck_env + sfx × 0,9`.
- [ ] **Step 4 :** relancer → PASS.
- [ ] **Step 5 :** `python -m film.audio` → `out/master.wav`, dont `I` et `TP` sont affichés. Commit `"film: sfx + master"`.

### Task 9 : Assemblage, contrôle final, livraison

**Files :**
- Create: `film/assemble.py`, `tests/test_final.py`, `out/modern-downloader-launch-1080p.mp4`, `out/contact_sheet.jpg`

**Interfaces :**
- Consumes : `out/scenes/s1..s5.mp4`, `out/master.wav`.
- Produces : `assemble() -> Path`. Un fichier de concat est écrit, puis `ffmpeg -f concat -safe 0 -i list.txt -c copy video.mp4`, puis `ffmpeg -i video.mp4 -i master.wav -map 0:v -map 1:a -c:v copy -c:a aac -b:a 320k -ar 48000 -shortest -movflags +faststart FINAL`.

- [ ] **Step 1 :** `python -m film.render --scene all`, en arrière-plan avec un timeout long, scène par scène. Une scène déjà rendue n'est pas refaite si son code n'a pas changé.
- [ ] **Step 2 : écrire le test**
```python
def test_final_specs():
    p = probe(FINAL)
    v, a = p["video"], p["audio"]
    assert (v["width"], v["height"], v["r_frame_rate"]) == (1920, 1080, "30/1")
    assert v["nb_frames"] == 900 and abs(p["duration"] - 30.0) <= 0.05
    assert a["sample_rate"] == 48000 and a["channels"] == 2
def test_final_loudness():
    I, TP = ebur128(FINAL); assert -15 <= I <= -13 and TP <= -1.0
```
- [ ] **Step 3 :** `python -m film.assemble && pytest tests/test_final.py -q` → PASS.
- [ ] **Step 4 : planche contact.** `ffmpeg -i FINAL -vf "select='not(mod(n,60))',scale=480:-1,tile=5x3" -frames:v 1 out/contact_sheet.jpg`. La regarder avec la grille anti-slop du spec (aucune interface ni texte générés par IA, rouge unique, pas de dégradé violet, texte net). Extraire aussi les images 105, 165, 390, 480, 585 et 780 en plein format, et vérifier que chaque impact visuel coïncide avec son pic audio.
- [ ] **Step 5 : livrer.** Copier `film/`, `tests/`, `README.md` (une commande pour tout rendre), le spec, le plan et le mp4 final dans `/mnt/user-data/outputs/…`. `device_commit_files` vers `Downloader-main/marketing/launch-film/` et `Downloader-main/docs/superpowers/{specs,plans}/`. `SendUserFile` du mp4 et de la planche contact.

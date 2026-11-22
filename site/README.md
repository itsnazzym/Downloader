# TapLoad website

This static Astro site introduces TapLoad and provides a searchable,
localized directory of its built-in modules, automations, and companion browser
extensions. The landing page includes a restrained product overview and a feature
showcase; the directory uses a three-part library layout on desktop and a
collapsible navigation on smaller screens. Search, category filters, and
alphabetical sorting all run locally in the page. The directory reads
`plugin-catalog.json`, which is also bundled into the Flutter application, so
both surfaces use the same feature IDs and descriptions. Each entry declares
its supported platforms; the website lists Windows entries only. Android-only
features such as the in-app X browser remain in the application catalog for
Android and do not get a Windows website page.

The catalog is a discovery and handoff layer, not a remote code loader. Selecting
an entry opens the app through its `moderndownloader://plugin/<id>` protocol;
the app then presents the relevant activation or installation flow. Core
downloads and the media library remain available, and no existing app feature is
removed by the catalog.

## Pages

- `/fr/`, `/en/`, `/ar/`: localized landing page and feature showcase.
- `/<lang>/sources/`: searchable feature directory with category filters and
  alphabetical sorting.
- `/<lang>/sources/<id>/`: individual feature details and app handoff.
- `/<lang>/guide/`: explains how to open and manage features in the app.
- `/`: redirects to the visitor's preferred supported language, or French.

## Local preview

From this directory:

```powershell
npm ci
npm run dev
```

Run `npm run check` for Astro and TypeScript diagnostics and `npm run build` to
create the static site. The GitHub Actions workflow builds and deploys `dist/`
to GitHub Pages when files under `site/` change. The first deployment requires
the repository Pages source to be set to **GitHub Actions**.

The Astro base path is derived from `GITHUB_REPOSITORY`, so a project site uses
`/<repository>/` while an `owner.github.io` site uses `/`.

## Interface and motion

The components in `src/components/ui/` are copied from the official shadcn/ui
Astro registry and styled through `src/styles/ui.css` plus the site's graphite
CSS. Astro renders cards and action links as static HTML. The mobile sheet,
showcase tabs, and guide accordion hydrate only on the pages and viewport sizes
where visitors use them. Motion handles the entrance sequence, section reveals,
gallery transitions, and catalog feedback. `SiteLayout.astro` enables Astro
page transitions; page scripts initialize on `astro:page-load` so navigation,
search, and release metadata continue working after an internal route change.
All nonessential movement respects `prefers-reduced-motion`.

## Real product captures without private data

On Windows, `--showcase` starts an isolated process before the normal profile,
services, downloads, or background tasks are initialized. It displays the real
desktop Library, Downloads, TikTok Archives, Statistics, Transfer, and Plugins
widgets with in-memory fixtures. Network clients are blocked, file imports and
device transfer are disabled or simulated, and the theme selector uses the
application's existing presets. Search, filters, selection, and plugin switches
only affect temporary demo state. The normal profile is never read.

From the repository root, rebuild and capture all six iOS-theme screens:

```powershell
flutter build windows --debug
./tool/capture_showcase_gallery.ps1
```

The gallery capture helper starts a separate `--showcase` process for each
screen, verifies that process before capture, and stops only that process.
The website serves the resulting real screenshots from `public/media/` and
labels them as demo data. The original freely licensed Blender film stills
are bundled in `assets/showcase/` for offline use, with source links and exact
licenses in `assets/showcase/ATTRIBUTION.md` and `public/media/ATTRIBUTION.md`.
No generated product images or personal library screenshots are used. Bundled
Space Grotesk and Noto Sans fonts include their OFL licenses under
`public/fonts/`.

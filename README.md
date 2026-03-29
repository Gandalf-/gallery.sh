# gallery.sh

Turns a folder of photos into a static web gallery. Run the script, serve the output folder — that's it.

The gallery is a single responsive HTML page with a masonry layout, lazy loading, and a lightbox viewer. Images are converted to WebP for efficient delivery.

Examples: [photos.anardil.net](https://photos.anardil.net), [art.anardil.net](https://art.anardil.net/)

## Requirements

- **ImageMagick** — `magick` and `identify`
- **rsync**
- **macOS only:** `findutils` — the script uses `gfind`

On macOS with [Homebrew](https://brew.sh):
```bash
brew install imagemagick findutils
```

On Linux, `rsync` and ImageMagick are typically available via your package manager. No `findutils` needed.

## Setup

1. **Clone the repo**
   ```bash
   git clone <repo-url>
   cd gallery
   ```

2. **Edit the config block** at the top of `gallery.sh`:
   ```bash
   PHOTOS="$HOME/Downloads/"     # where your source images live
   OUTPUT="$HOME/gallery-output" # where the generated site is written
   MAX_PHOTOS=500                 # how many recent photos to include
   ```

3. **Edit `web/index.html`** — replace every occurrence of `EXAMPLE` with your own values:
   - Page title and meta description
   - Canonical URL (`https://EXAMPLE.TLD`)
   - Footer link and copyright line

4. **Run it:**
   ```bash
   chmod +x gallery.sh
   ./gallery.sh
   ```

The script checks for missing tools and un-replaced `EXAMPLE` placeholders before doing anything, so it'll tell you if something needs fixing.

## Viewing the gallery

**Local preview:**
```bash
cd ~/gallery-output  # whatever you set OUTPUT to in gallery.sh
python3 -m http.server 8000
```
Then open `http://localhost:8000` in a browser. Don't open `index.html` directly as a file — it needs to be served over HTTP.

**Deployment:** The output directory is a self-contained static site. Copy it to any static host — Netlify, S3, GitHub Pages, a VPS with nginx, etc.

## How it works

1. The script scans `PHOTOS` for `.jpg` and `.png` files, picks the `MAX_PHOTOS` most recently modified, and computes an MD5 hash for each to use as a stable filename.
2. For each image, ImageMagick generates a 300px-wide WebP thumbnail and a full-size WebP version.
3. Image dimensions are extracted and written to `images.js`, a JavaScript file containing metadata for the whole gallery. The file is content-addressed (renamed to `images.<hash>.js`) so browsers always pick up updates.
4. The `web/` template files are copied to the output directory and `index.html` is updated to reference the versioned data file.
5. On subsequent runs, already-converted images are skipped. Old versioned metadata files are cleaned up after 7 days.

The gallery page builds the layout in the browser: images are distributed across columns (shortest-column-first), loaded lazily as they scroll into view, and opened full-screen with [FancyBox](https://fancyapps.com/fancybox/).

## License

MIT — Copyright (c) 2026 austin@anardil.net

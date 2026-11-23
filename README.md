# Quicklook Anything

Quick Look previews and Finder thumbnails for source code, Markdown notes and Jupyter notebooks on macOS. Select a file in Finder and press Space.

- **Code**: syntax-highlighted previews and thumbnails for more than 50 languages and data formats, with 100 themes and your choice of monospace font.
- **Markdown**: Obsidian-flavored notes with KaTeX math, GFM tables, highlighted code blocks, wikilinks, embedded images, callouts, `==highlights==`, `#tags`, task lists and frontmatter properties.
- **Jupyter notebooks** (`.ipynb`): Markdown cells, highlighted code cells and their outputs, including images.

Quicklook Anything is based on [PreviewCode](https://github.com/smittytone/PreviewCode) by Tony Smith; see [Credits](#credits).

## Install

Paste this into Terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/KehengZhu/QuicklookAnything/main/install.sh | zsh
```

Run the same command again to upgrade; your settings are kept.

It works from any shell (bash, fish, …): every Mac has zsh, and piping into `bash` or `sh` instead also works.

Requires macOS 13 (Ventura) or later, on Apple silicon or Intel. Nothing else (no Xcode, Homebrew or Obsidian) is needed.

### What the installer changes

- Copies **Quicklook Anything.app** to `/Applications` (or `~/Applications` if you cannot write to `/Applications`) and registers its Quick Look extensions.
- Turns off other Quick Look extensions for Markdown and Jupyter notebooks (Obsidian's, for example), and the App Store PreviewCode's, so they do not compete with these previews. Uninstalling turns them back on.
- Never changes which app opens a file: double-clicking a file opens it in the same app as before.

The app is signed but not notarized by Apple. macOS does not apply its download check (Gatekeeper) to files fetched by `curl`, so the installer runs without a warning; it checks the download's code signature itself before installing.

### Uninstall

```sh
curl -fsSL https://raw.githubusercontent.com/KehengZhu/QuicklookAnything/main/install.sh | zsh -s -- --uninstall
```

## Fast

Previews appear the moment you press Space. Quicklook Anything is tuned for speed:

- **Markdown and notebooks render in under 10 ms** once Quick Look is running. The renderer page is loaded ahead of time and kept warm, so a preview only has to parse and draw the file; the first preview after the extension starts takes about 0.1 s.
- **Code files preview in a few milliseconds.** Long files show their first screen highlighted at once and finish highlighting in the background.
- **Long notes and notebooks** draw the first screen first and the rest a chunk at a time, so even very large files open without a wait.
- **Math uses KaTeX**, which typesets in one synchronous pass, instead of MathJax, which Obsidian's own Quick Look extension loads for every preview.

Times measured with the extensions' own logging on an Apple silicon Mac, using the sample files in [`docs/samples`](docs/samples).

## Screenshots

**Code**: `primes.py` in Finder's Quick Look (select it and press Space)

![Quick Look preview of a Python file](docs/screenshots/code.png)

**Markdown**: `notes.md`, with frontmatter, math, a callout, a table, code and tasks

![Quick Look preview of a Markdown note](docs/screenshots/markdown.png)

**Jupyter notebook**: `damping.ipynb`, with Markdown, code cells and a plot

![Quick Look preview of a Jupyter notebook](docs/screenshots/notebook.png)

The **Open with** button still names each file's usual app: Quicklook Anything never changes default apps. The sample files are in [`docs/samples`](docs/samples), so you can try them yourself.

## Usage

Select a file in Finder and press Space, or use Finder's preview pane (**View > Show Preview**) or **Get Info**. Finder icons for code files show a thumbnail of their contents.

You can turn the extensions off and on in **System Settings > General > Login Items & Extensions > Quick Look**.

## Settings

Open **Quicklook Anything** from Applications. It has three tabs, and every change saves as you make it:

- **General**: the Quick Look window size, used by every preview; the text size in small previews (Finder's column and gallery views, and Get Info), 70% of the normal size by default; a shortcut to turn the extensions on or off; and **Check for Updates**, which installs a newer release by running the install command in Terminal (macOS asks once to let the app control Terminal).
- **Code**: text size (13 pt by default), font and style, line spacing, line numbers, the theme (one for light mode and one for dark, or a single theme for both), the preview margin, and whether thumbnails follow light or dark mode.
- **Markdown & Notebook**: the body text size (16 pt) and the code block size (13 pt), which also sets notebook code cells and outputs.

![The Code settings tab](docs/screenshots/settings-code.png)

Markdown notes and notebooks follow the system's light or dark mode. Images embedded in a note are found next to the note, in its Obsidian vault, or anywhere in the vault by name; for vaults outside iCloud Drive's Obsidian folder, only images next to the note can be shown.

## Supported Files

Markdown (`.md`, `.markdown`) and Jupyter notebooks (`.ipynb`), plus:

### Compiled Languages

- ActionScript (`.actionscript`)
- Ada (`.ads`, `.adb`)
- AppleScript (`.applescript`)
- Arduino (`.arduino`, `.ino`)
- Basic (`.basic`, `.bas`, `.lis`)
- Brainfuck (`.brainfuck`, `.b`, `.bf`)
- C (`.c`, `.h`)
- C++ (`.cpp`, `.hpp`)
- C# (`.csx`, `.cs`, `.c-sharp`, `.csharp`)
- Clojure (`.clojure`, `.clj`, `.cljc`, `.cljs`)
- CoffeeScript (`.coffee`, `.coffeescript`, `.litcoffee`)
- Dart (`.dart`)
- Elixir (`.elxir`, `.ex`, `.exs`)
- Elm (`.elm`)
- Erlang (`.erlang`, `.erl`, `.hrl`)
- Fortran (`.for`)
- F# (`.fsharp`, `.f-sharp`, `.fsi`, `.fsx`, `.fsscript`)
- Go (`.go`)
- GameMaker Language (`.gml`)
- IDL (`.pro`)
- Haskell (`.haskell`, `.hs`, `.lhs`)
- Java (`.java`)
- JavaScript (`.js`)
- Julia (`.julia`, `.jl`)
- Kotlin (`.kotlin`, `.kt`, `.ktm`, `.kts`)
- Lisp (`.lisp`, `.lsp`, `.fasl`)
- Lua (`.lua`)
- Objective-C (`.m`)
- OPL (`.opl`, `.opa`, `.tpl`)
- Pascal (`.pas`)
- Perl (`.perl`)
- PHP (`.php`)
- Python (`.py`)
- Ruby (`.rb`)
- Rust (`.rs`, `.rust`)
- Swift (`.swift`)
- TypeScript (`.typescript`, `.tsx`)
- Visual Basic Script (`.vbscript`, `.vbe`, `.vbs`, `.wsc`, `.wsf`)
- Vue.js (`.vue`)

### Shell Scripting

- Shell (`.sh`)
- Bash (`.bash`)
- C Shell (`.csh`)
- Korn Shell (`.ksh`)
- TCSH (`.tcsh`)
- Z Shell (`.zsh`)
- Executable scripts without an extension, such as `gitclone`, highlighted in the language of their `#!` line (Perl, Python, shell, Ruby and others)

### Assembly

- ARM Assembler (`.s`)
- x86-64 Assembler (`.asm`, `.nasm`)

### Others

- AsciiDoc (`.asciidoc`, `.adoc`, `.asc`)
- Config files (`.conf`, `.cf`, `.cfg`, `.ini`, `.rc`)
- Cmake files (`.cmake`)
- CSS (`.css`)
- DxO PhotoLab sidecar (`.dop`)
- Environment (`.env`)
- Extensible Markup Platform (`.xmp`)
- LaTex (`.latex`, `.tex`)
- Makefiles (`Makefile`, `GNUmakefile`, `Makefile.*`)
- Apple Property list files (`.plist`)
- Apple Entitlements files (`.entitlements`)
- Apple Xcode NIB files (`.xib`)
- Apple Xcode storyboard files (`.storyboard`)
- Apple Xcode strings files (`.strings`)
- Protobuf (`.proto`)
- SASS/SCSS (`.scss`, `.sass`)
- SQL script (`.sql`)
- Terraform source file (`.tf`, `.terraform`)
- Terraform variable file (`.tfvars`)
- Translation Memory eXchange (`.tmx`)
- Twig (`.twig`)
- XML Localization Interchange File Format (`.xlf`, `.xliff`)

## Known Issues

1. TypeScript `.ts` files are not previewed: macOS reserves `.ts` for MPEG-2 video. `.tsx` and `.typescript` work.
1. Clojure `.edn` files are not previewed: macOS reserves `.edn` for an Adobe format.
1. Elixir `.exs` files are not previewed when GarageBand or Logic Pro is installed, since those apps use `.exs` for instrument files.

## Building from Source

You need Xcode and an Apple Development certificate. Open `QuicklookAnything.xcodeproj`, or use the scripts:

- `Scripts/build-install.sh` builds the app and installs it on this Mac with `install.sh`.
- `Scripts/release.sh` builds it and publishes a GitHub release, which the install command then fetches. Set the version in the Xcode project (`MARKETING_VERSION`) first.

The source is laid out as:

| Folder | Contents |
|---|---|
| `App/` | The settings app, which hosts the extensions |
| `Extensions/CodePreviewer/` | Quick Look previews of source code |
| `Extensions/CodeThumbnailer/` | Finder thumbnails of source code |
| `Extensions/MarkdownPreviewer/` | Quick Look previews of Markdown notes and Jupyter notebooks (a web page in `Web/`) |
| `Shared/` | Settings and the code highlighting, used by the app and the extensions |
| `Vendor/HighlighterSwift/` | The highlighting library, with local changes |
| `Scripts/` | Build, install and release scripts; their output goes in `build/` |

## Credits

Quicklook Anything is a fork of [PreviewCode](https://github.com/smittytone/PreviewCode) by [Tony Smith](https://github.com/smittytone), which provides the code previews, thumbnails and settings app. Thank you, Tony, for building it and releasing it under the MIT License. If you only need code previews, consider the original [PreviewCode on the Mac App Store](https://apps.apple.com/app/previewcode/id1571797683).

It also builds on:

- [HighlighterSwift](https://github.com/smittytone/HighlighterSwift) by Tony Smith, derived from [Highlightr](https://github.com/raspu/Highlightr) by Juan Pablo Illanes (MIT)
- [Highlight.js](https://github.com/highlightjs/highlight.js) by Josh Goebel and contributors (BSD-3-Clause)
- [markdown-it](https://github.com/markdown-it/markdown-it) (MIT)
- [KaTeX](https://github.com/KaTeX/KaTeX) (MIT)

Their license texts ship with the app and are in [`Extensions/CodePreviewer/Licences.md`](Extensions/CodePreviewer/Licences.md) and [`Extensions/MarkdownPreviewer/Web/lib/LICENSES.txt`](Extensions/MarkdownPreviewer/Web/lib/LICENSES.txt).

## License

[MIT](LICENSE.md). Release notes are in the [CHANGELOG](CHANGELOG.md).

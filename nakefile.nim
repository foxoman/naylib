import nake, std/strformat

const
  RayLatestCommit = "4eb3d8857f1a8377f2cfa6e804183512cde5973e"

const
  srcDir = currentSourcePath().parentDir.quoteShell
  rayDir = srcDir / "dist/raylib"
  inclDir = srcDir / "cinclude"
  apiDir = srcDir / "api"
  docsDir = srcDir / "docs"

proc fetchLatestRaylib =
  if not dirExists(rayDir):
    direSilentShell "Cloning raysan/raylib...",
        "git clone --depth 50 https://github.com/raysan5/raylib.git " & rayDir
  withDir(rayDir):
    direSilentShell "Fetching latest commit...", "git fetch"
    direSilentShell "", "git checkout " & RayLatestCommit

proc buildLatestRaylib(platform: string) =
  fetchLatestRaylib()
  withDir(rayDir / "src"):
    const exe = when defined(windows): "mingw32-make" else: "make"
    direSilentShell "Building raylib static library...", exe & " clean"
    direSilentShell "", exe & &" PLATFORM={platform} -j4"
    echo "Copying to C include directory..."
    discard existsOrCreateDir(inclDir)
    copyFileToDir("libraylib.a", inclDir)
    copyFileToDir("raylib.h", inclDir)

task "buildDesktop", "Build the raylib library for the Desktop platform":
  buildLatestRaylib("PLATFORM_DESKTOP")

task "buildRPi", "Build the raylib library for the RPi platform":
  buildLatestRaylib("PLATFORM_RPI")

task "buildDRM", "Build the raylib library for the DRM platform":
  buildLatestRaylib("PLATFORM_DRM")

task "buildAndroid", "Build the raylib library for the Android platform":
  buildLatestRaylib("PLATFORM_ANDROID")

# The rest are meant for developers only!
proc generateWrapper =
  let script = "raylib_gen.nim"
  withDir(srcDir / "gen"):
    var exe = script.changeFileExt(ExeExt)
    direSilentShell "Building raylib2nim tool...",
        "nim c --mm:arc --panics:on -d:release -d:emiLenient " & script
    normalizeExe(exe)
    direSilentShell "Generating raylib Nim wrapper...", exe

task "wrap", "Produce the raylib nim wrapper":
  let parser = "raylib_parser.c"
  let header = rayDir / "src/raylib.h"
  fetchLatestRaylib()
  withDir(rayDir / "parser"):
    var exe = parser.changeFileExt(ExeExt)
    direSilentShell "Building raylib API parser...", &"cc {parser} -o {exe}"
    normalizeExe(exe)
    direSilentShell "Generating API JSON file...",
        &"{exe} -f JSON -d RLAPI -i {header} -o {apiDir / \"raylib_api.json\"}"
  generateWrapper()

task "docs", "Generate documentation":
  # https://nim-lang.github.io/Nim/docgen.html
  withDir(srcDir):
    for src in items(["raymath", "raylib"]):
      let doc = docsDir / src.addFileExt(".html")
      direSilentShell &"Generating the docs for {src}...",
        "nim doc --verbosity:0 --git.url:https://github.com/planetis-m/naylib " &
        &"--git.devel:main --git.commit:main --out:{doc} {src}"

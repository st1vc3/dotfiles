# wallpaper stub

CI stand-in for the private `wallpaper` flake input, which is fetched over
SSH and unreachable from GitHub Actions. The workflow substitutes this
directory with `--override-input wallpaper path:./.github/wallpaper-stub`.

`abstract/red.png` is a solid-colour placeholder at wallpaper dimensions.
The Simple Bar blur in `modules/home/desktop.nix` reads that file with
ImageMagick at build time, so the stub has to carry every path the
configuration resolves, not just a store path to interpolate.

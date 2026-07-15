# wallpaper stub

CI stand-in for the private `wallpaper` flake input, which is fetched over
SSH and unreachable from GitHub Actions. The workflow substitutes this
directory with `--override-input wallpaper path:./.github/wallpaper-stub`.

Evaluation only interpolates the input's store path into the activation
script, so no actual image files are needed here.

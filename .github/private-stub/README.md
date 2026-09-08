# private input stub

CI stand-in for the private `dotfiles-private` flake input, which is not
readable from GitHub Actions. The workflow substitutes this directory with
`--override-input private path:./.github/private-stub`.

It exposes the same `hosts` output as the real input, with placeholder account
names, so CI validates the structure of both host configurations rather than
the account names themselves.

`abstract/red.jpg` is a solid-colour placeholder at wallpaper dimensions. The
Simple Bar blur in `modules/home/desktop.nix` reads that file with ImageMagick
at build time, so the stub has to carry it.

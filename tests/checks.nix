{
  pkgs,
  mkNodeApp,
  mkNodeAppWithPkgs,
  mkNodeDeps,
  mkNodeDepsWithPkgs,
}:
let
  hashes = {
    npm = "sha256-aOCvF1XrI/iZBzc25nZ61y9nYOkaK3j1/vufrb2QlTk=";
    pnpm = "sha256-dxRkTJuqajSY8RrnMxDxzoTZ3Zv+1RmbIAS11XxZBbI=";
    yarn = "sha256-H7/cXzwldKTLmVfwprb6CE9FmEkydXC+I5FUPA3wE8Y=";
    yarnBerry = "sha256-NOacKi/kpP5kibLywwsC/TWeedma2BlsIkgx3DPVais=";
    yarnBerryMissingHashes = "sha256-2gkN3ChlDgr1qfbaTH5QgZjOwJHLxwWCmlnkS/GuTWc=";
  };
in
(import ./builders.nix {
  inherit
    pkgs
    mkNodeApp
    mkNodeAppWithPkgs
    mkNodeDeps
    hashes
    ;
})
// (import ./source.nix { inherit pkgs mkNodeApp; })
// (import ./package_manager.nix { inherit pkgs; })
// (import ./deps.nix {
  inherit
    pkgs
    mkNodeApp
    mkNodeDeps
    mkNodeDepsWithPkgs
    hashes
    ;
})

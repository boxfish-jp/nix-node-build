{ pkgs }:
{
  sharedArgs,
  depsHash,
  nodejs,
  buildScript,
  extra,
}:
let
  inherit (import ./build_phase.nix { inherit pkgs; }) mkBuildPhase;
in
pkgs.buildNpmPackage (
  sharedArgs
  // {
    inherit nodejs;
    npmDepsHash = depsHash;
    buildPhase = mkBuildPhase "npm run" buildScript;
  }
  // extra
)

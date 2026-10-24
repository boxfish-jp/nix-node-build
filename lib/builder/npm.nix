{ pkgs }:
{
  sharedArgs,
  deps,
  nodejs,
  npmDepsFetcherVersion,
  buildScript,
  extra,
}:
let
  inherit (import ./build_phase.nix { inherit pkgs; }) mkBuildPhase;
in
pkgs.buildNpmPackage (
  sharedArgs
  // {
    inherit nodejs npmDepsFetcherVersion;
    npmDeps = deps;
    buildPhase = mkBuildPhase "npm run" buildScript;
  }
  // extra
)

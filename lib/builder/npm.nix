{ pkgs }:
{
  sharedArgs,
  deps,
  nodejs,
  npmDepsFetcherVersion,
  buildScript,
  buildCommand,
  preBuild,
  postBuild,
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
    buildPhase = mkBuildPhase {
      command = "npm run";
      inherit
        buildScript
        buildCommand
        preBuild
        postBuild
        ;
    };
  }
  // extra
)

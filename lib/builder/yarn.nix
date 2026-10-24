{ pkgs }:
{
  sharedArgs,
  deps,
  nodejs,
  yarn,
  buildScript,
  buildCommand,
  preBuild,
  postBuild,
  extra,
}:
let
  inherit (import ./build_phase.nix { inherit pkgs; }) mkBuildPhase;
in
pkgs.stdenv.mkDerivation (
  sharedArgs
  // {
    yarnOfflineCache = deps;
    nativeBuildInputs = [
      nodejs
      yarn
      pkgs.yarnConfigHook
    ]
    ++ sharedArgs.nativeBuildInputs;
    buildPhase = mkBuildPhase {
      command = "yarn --offline run";
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

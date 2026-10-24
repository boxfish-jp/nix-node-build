{ pkgs }:
{
  sharedArgs,
  deps,
  nodejs,
  yarn,
  buildScript,
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
    buildPhase = mkBuildPhase "yarn --offline run" buildScript;
  }
  // extra
)

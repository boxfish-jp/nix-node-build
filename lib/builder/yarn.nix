{ pkgs }:
{
  sharedArgs,
  depsHash,
  nodejs,
  yarn,
  src,
  buildScript,
  extra,
}:
let
  inherit (import ./build_phase.nix { inherit pkgs; }) mkBuildPhase;
in
pkgs.stdenv.mkDerivation (
  sharedArgs
  // {
    yarnOfflineCache = pkgs.fetchYarnDeps {
      inherit src;
      hash = depsHash;
    };
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

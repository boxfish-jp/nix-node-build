{ pkgs }:
{
  sharedArgs,
  deps,
  nodejs,
  buildScript,
  extra,
  yarnBerryMissingHashes,
}:
let
  inherit (pkgs) lib;

  inherit (import ./build_phase.nix { inherit pkgs; }) mkBuildPhase;

  optionalMissingHashes = lib.optionalAttrs (yarnBerryMissingHashes != null) {
    missingHashes = yarnBerryMissingHashes;
  };
in
pkgs.stdenv.mkDerivation (
  sharedArgs
  // {
    offlineCache = deps;
    nativeBuildInputs = [
      nodejs
      pkgs."yarn-berry_4"
      pkgs."yarn-berry_4-fetcher".yarnBerryConfigHook
    ]
    ++ sharedArgs.nativeBuildInputs;
    buildPhase = mkBuildPhase "yarn run" buildScript;
    env = {
      YARN_IGNORE_PATH = "1";
    }
    // optionalMissingHashes
    // sharedArgs.env;
  }
  // extra
)

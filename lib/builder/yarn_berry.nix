{ pkgs }:
{
  sharedArgs,
  depsHash,
  nodejs,
  src,
  buildScript,
  extra,
  yarnBerryMissingHashes,
}:
let
  inherit (pkgs) lib;

  inherit (import ./build_phase.nix { inherit pkgs; }) mkBuildPhase;

  fetcher =
    pkgs."yarn-berry_4-fetcher"
      or (throw "mkNodeApp: Yarn Berry support requires nixpkgs >= 26.05 (pkgs.yarn-berry_4-fetcher is missing). Use a newer nixpkgs, or switch the project to yarn classic.");

  optionalMissingHashes = lib.optionalAttrs (yarnBerryMissingHashes != null) {
    missingHashes = yarnBerryMissingHashes;
  };
in
pkgs.stdenv.mkDerivation (
  sharedArgs
  // {
    offlineCache = fetcher.fetchYarnBerryDeps (
      {
        inherit src;
        hash = depsHash;
      }
      // optionalMissingHashes
    );
    nativeBuildInputs = [
      nodejs
      pkgs."yarn-berry_4"
      fetcher.yarnBerryConfigHook
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

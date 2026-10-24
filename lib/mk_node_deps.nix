{ pkgs }:
let
  inherit (pkgs) lib;

  inherit (import ./package_manager { inherit pkgs; }) resolvePackageManager;

  yarnBerryFetcher =
    pkgs."yarn-berry_4-fetcher"
      or (throw "Yarn Berry support requires nixpkgs >= 26.05 (pkgs.yarn-berry_4-fetcher is missing). Use a newer nixpkgs, or switch the project to yarn classic.");

  fetchName = "node-deps";

  fetchNpm =
    {
      src,
      depsHash,
      npmDepsFetcherVersion,
      ...
    }:
    pkgs.fetchNpmDeps {
      name = fetchName;
      inherit src;
      hash = depsHash;
      fetcherVersion = npmDepsFetcherVersion;
    };

  fetchPnpm =
    {
      src,
      depsHash,
      pnpm,
      pnpmWorkspaces,
      pnpmInstallFlags,
      ...
    }:
    let
      fetchArgs = {
        pname = fetchName;
        inherit src;
        hash = depsHash;
        inherit pnpmWorkspaces pnpmInstallFlags;
      };
    in
    if pkgs ? fetchPnpmDeps then
      pkgs.fetchPnpmDeps (
        fetchArgs
        // {
          inherit pnpm;
          # pnpm 11 needs fetcherVersion 4; older nixpkgs cap at 3. https://nixos.org/manual/nixpkgs/stable/#javascript-pnpm-fetcherVersion
          fetcherVersion = if lib.versionAtLeast pnpm.version "11.0.0" then 4 else 3;
        }
      )
    else
      pnpm.fetchDeps fetchArgs;

  fetchYarn =
    { src, depsHash, ... }:
    pkgs.fetchYarnDeps {
      inherit src;
      hash = depsHash;
    };

  fetchYarnBerry =
    {
      src,
      depsHash,
      yarnBerryMissingHashes,
      ...
    }:
    yarnBerryFetcher.fetchYarnBerryDeps (
      {
        inherit src;
        hash = depsHash;
      }
      // lib.optionalAttrs (yarnBerryMissingHashes != null) {
        missingHashes = yarnBerryMissingHashes;
      }
    );

  fetchers = {
    npm = fetchNpm;
    pnpm = fetchPnpm;
    yarn = fetchYarn;
    yarn-berry = fetchYarnBerry;
  };

  depsWithManager =
    manager: deps:
    deps
    // {
      passthru = (deps.passthru or { }) // {
        inherit manager;
      };
    };
in
{
  mkNodeDeps =
    {
      src,
      depsHash ? lib.fakeHash,
      packageManager ? null,
      pnpm ? pkgs.pnpm,
      npmDepsFetcherVersion ? 1,
      pnpmWorkspaces ? [ ],
      pnpmInstallFlags ? [ ],
      yarnBerryMissingHashes ? null,
    }:
    let
      manager = resolvePackageManager {
        inherit packageManager;
        source = src;
        caller = "mkNodeDeps";
      };
    in
    depsWithManager manager (
      fetchers.${manager} {
        inherit
          src
          depsHash
          pnpm
          npmDepsFetcherVersion
          pnpmWorkspaces
          pnpmInstallFlags
          yarnBerryMissingHashes
          ;
      }
    );
}

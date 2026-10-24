{ pkgs }:
{
  sharedArgs,
  depsHash,
  pnpm,
  pname,
  src,
  nodejs,
  buildScript,
  extra,
  extraAttrs,
}:
let
  inherit (pkgs) lib;

  inherit (import ./build_phase.nix { inherit pkgs; }) mkBuildPhase;

  fetchArgs = {
    inherit pname src;
    hash = depsHash;
    pnpmWorkspaces = extraAttrs.pnpmWorkspaces or [ ];
    pnpmInstallFlags = extraAttrs.pnpmInstallFlags or [ ];
  };

  pnpmDependencies =
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

  configHook = if pkgs ? pnpmConfigHook then pkgs.pnpmConfigHook else pnpm.configHook;
in
pkgs.stdenv.mkDerivation (
  sharedArgs
  // {
    pnpmDeps = pnpmDependencies;
    nativeBuildInputs = [
      nodejs
      pnpm
      configHook
    ]
    ++ sharedArgs.nativeBuildInputs;
    buildPhase = mkBuildPhase "pnpm run" buildScript;
  }
  // extra
)

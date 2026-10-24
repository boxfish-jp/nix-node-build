{ pkgs }:
{
  sharedArgs,
  deps,
  pnpm,
  nodejs,
  buildScript,
  extra,
}:
let
  inherit (pkgs) lib;

  inherit (import ./build_phase.nix { inherit pkgs; }) mkBuildPhase;

  configHook = if pkgs ? pnpmConfigHook then pkgs.pnpmConfigHook else pnpm.configHook;

  pnpmVolatileFiles = [
    "node_modules/.modules.yaml"
    "node_modules/.pnpm-workspace-state-v1.json"
  ];

  extra' = removeAttrs extra [ "postFixup" ];
in
pkgs.stdenv.mkDerivation (
  sharedArgs
  // {
    pnpmDeps = deps;
    nativeBuildInputs = [
      nodejs
      pnpm
      configHook
    ]
    ++ sharedArgs.nativeBuildInputs;
    buildPhase = mkBuildPhase "pnpm run" buildScript;
    postFixup = ''
      ${extra.postFixup or ""}
      rm -f ${lib.concatMapStringsSep " " (file: "$out/${file}") pnpmVolatileFiles}
    '';
  }
  // extra'
)

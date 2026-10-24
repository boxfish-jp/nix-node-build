{ pkgs }:
let
  inherit (pkgs) lib;
in
{
  mkBuildPhase =
    command: script:
    if script == null then
      ''
        runHook preBuild
        runHook postBuild
      ''
    else
      ''
        runHook preBuild

        ${command} ${lib.escapeShellArg script}

        runHook postBuild
      '';
}

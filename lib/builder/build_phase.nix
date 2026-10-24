{ pkgs }:
let
  inherit (pkgs) lib;
in
{
  mkBuildPhase =
    {
      command,
      buildScript,
      buildCommand,
      preBuild,
      postBuild,
    }:
    let
      buildLine =
        if buildCommand != null then
          buildCommand
        else if buildScript == null then
          null
        else
          "${command} ${lib.escapeShellArg buildScript}";

      sections = [
        "runHook preBuild"
      ]
      ++ lib.optional (preBuild != "") preBuild
      ++ lib.optional (buildLine != null) buildLine
      ++ lib.optional (postBuild != "") postBuild
      ++ [ "runHook postBuild" ];
    in
    lib.concatStringsSep "\n\n" sections + "\n";
}

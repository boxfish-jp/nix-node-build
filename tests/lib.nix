{ pkgs }:
let
  expectThrows = expr: !(builtins.tryEval (builtins.seq expr true)).success;

  check =
    name: condition:
    if condition then
      pkgs.runCommand "check-${name}" { } "touch $out"
    else
      throw "check failed: ${name}";

  outputCheck =
    name: body:
    pkgs.runCommand "check-${name}" { } ''
      set -eu
      ${body}
      touch $out
    '';
in
{
  inherit check expectThrows outputCheck;
}

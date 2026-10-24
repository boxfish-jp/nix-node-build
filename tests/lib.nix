{ pkgs }:
let
  expectThrows = expr: !(builtins.tryEval (builtins.seq expr true)).success;

  check =
    name: condition:
    if condition then
      pkgs.runCommand "check-${name}" { } "touch $out"
    else
      throw "check failed: ${name}";
in
{
  inherit check expectThrows;
}

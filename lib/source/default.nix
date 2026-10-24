{ pkgs }:
let
  inherit (pkgs) lib;

  isUrl = value: builtins.isString value && builtins.match "^(https?|file)://.*" value != null;

  invalidSourceError = throw "mkNodeApp: src must be a path, a derivation, or an http(s)/file URL string.";

  resolveSource =
    { src, srcHash }:
    let
      pinnedSourceError = throw "mkNodeApp: srcHash is only used for URL sources. Paths and derivations are already pinned by Nix (flake inputs are pinned in flake.lock).";
    in
    if builtins.isPath src || lib.isDerivation src then
      if srcHash != null then pinnedSourceError else src
    else if builtins.isString src && isUrl src then
      if srcHash == null then
        throw "mkNodeApp: srcHash is required when src is a URL. Set srcHash = lib.fakeHash and copy the hash Nix reports."
      else
        pkgs.fetchzip {
          url = src;
          hash = srcHash;
        }
    else
      invalidSourceError;
in
{
  inherit resolveSource;
}

{
  pkgs,
  mkNodeApp,
  mkNodeAppWithPkgs,
  mkNodeDeps,
  mkNodeDepsWithPkgs,
}:
let
  hashes = {
    npm = "sha256-zsbwE7tVlaNIQatR0go555QPd8uX++6vVIdQ/pnNStA=";
    pnpm = "sha256-lcmu8p7kTx915aNZO8dCQGATqpGlMqeUCndXtNFv+p4=";
    yarn = "sha256-2uMGM868iM8TZ/7fm30bgB1CYH9eVbl96LCOngfk6dw=";
    yarnBerry = "sha256-4e5F6Y8n/xQBTAQuuBF5nHtspET7jTGenv7ClRrRrTc=";
    yarnBerryMissingHashes = "sha256-8Br7aIVWLy/H4VcYE8L+Y9KmlQzhfdSZ0aJ76K2G18Y=";
  };
in
(import ./builders.nix {
  inherit
    pkgs
    mkNodeApp
    mkNodeAppWithPkgs
    hashes
    ;
})
// (import ./source.nix { inherit pkgs mkNodeApp; })
// (import ./package_manager.nix { inherit pkgs; })
// (import ./deps.nix {
  inherit
    pkgs
    mkNodeApp
    mkNodeDeps
    mkNodeDepsWithPkgs
    hashes
    ;
})

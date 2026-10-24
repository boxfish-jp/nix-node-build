{
  description = "Build Node.js projects with npm, pnpm, or yarn from a single flake input";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs { inherit system; }));

      libFor = pkgs: import ./lib/mk_node_app.nix { inherit pkgs; };

      mkNodeAppWithPkgs =
        { pkgs, ... }@args: (libFor pkgs).mkNodeApp (builtins.removeAttrs args [ "pkgs" ]);

      perSystem = forAllSystems libFor;
    in
    {
      lib = perSystem // {
        mkNodeApp = mkNodeAppWithPkgs;
      };

      checks = forAllSystems (
        pkgs:
        import ./tests/checks.nix {
          inherit pkgs mkNodeAppWithPkgs;
          mkNodeApp = (libFor pkgs).mkNodeApp;
        }
      );

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);
    };
}

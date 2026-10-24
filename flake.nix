{
  description = "Build Node.js projects with npm, pnpm, or yarn from a single flake input";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs { inherit system; }));

      libFor =
        pkgs:
        (import ./lib/mk_node_app.nix { inherit pkgs; })
        // (import ./lib/mk_node_deps.nix { inherit pkgs; });

      mkNodeAppWithPkgs =
        { pkgs, ... }@args: (libFor pkgs).mkNodeApp (builtins.removeAttrs args [ "pkgs" ]);

      mkNodeDepsWithPkgs =
        { pkgs, ... }@args: (libFor pkgs).mkNodeDeps (builtins.removeAttrs args [ "pkgs" ]);

      perSystem = forAllSystems libFor;
    in
    {
      lib = perSystem // {
        mkNodeApp = mkNodeAppWithPkgs;
        mkNodeDeps = mkNodeDepsWithPkgs;
      };

      checks = forAllSystems (
        pkgs:
        import ./tests/checks.nix {
          inherit pkgs;
          mkNodeApp = self.lib.${pkgs.stdenv.hostPlatform.system}.mkNodeApp;
          mkNodeAppWithPkgs = self.lib.mkNodeApp;
          mkNodeDeps = self.lib.${pkgs.stdenv.hostPlatform.system}.mkNodeDeps;
          mkNodeDepsWithPkgs = self.lib.mkNodeDeps;
        }
      );

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);
    };
}

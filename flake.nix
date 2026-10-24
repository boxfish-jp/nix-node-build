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

      libFor = pkgs: import ./lib/mk_node_app.nix { inherit pkgs; };

      mkNodeAppWithPkgs =
        { pkgs, ... }@args: (libFor pkgs).mkNodeApp (builtins.removeAttrs args [ "pkgs" ]);

      perSystem = nixpkgs.lib.genAttrs systems (system: libFor nixpkgs.legacyPackages.${system});
    in
    {
      lib = perSystem // {
        mkNodeApp = mkNodeAppWithPkgs;
      };

      checks = nixpkgs.lib.genAttrs systems (
        system:
        import ./tests/checks.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          inherit mkNodeAppWithPkgs;
          mkNodeApp = perSystem.${system}.mkNodeApp;
        }
      );
    };
}

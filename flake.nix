{
  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs";
    };
    cosmos-nix = {
      url = "github:informalsystems/cosmos.nix";
    };
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils = {
      url = "github:numtide/flake-utils";
    };
    devshell = {
      url = "github:numtide/devshell";
    };
  };

  outputs = {
    nixpkgs,
    cosmos-nix,
    pre-commit-hooks,
    flake-utils,
    devshell,
    self,
  }: let
    supportedSystems = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  in
    flake-utils.lib.eachSystem supportedSystems (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          devshell.overlay
        ];
      };
      pre-commit-check = pre-commit-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          alejandra.enable = true;
        };
      };
      tx-index-schema = cosmos-nix.packages.${system}.tx-database-migration;
    in {
      checks = {
        inherit
          pre-commit-check
          ;
      };
      devShells.default = pkgs.devshell.mkShell {
        env = [
        ];
        commands = import ./nix/commands {
          inherit pkgs tx-index-schema;
        };
        devshell = {
          name = "holdings-rs";
          startup.pre-commit.text = "${self.checks.${system}.pre-commit-check.shellHook}";
          packages = with pkgs; [];
        };
      };
    });
}

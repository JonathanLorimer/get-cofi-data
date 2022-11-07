{
  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    };
    cosmos-nix = {
      url = "github:informalsystems/cosmos.nix/osmosis-service";
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
    flake-utils.lib.eachSystem supportedSystems (
      system: let
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
        # tx-index-schema = cosmos-nix.packages.${system}.tx-database-migration;
        cosmos = cosmos-nix.packages.${system};
      in {
        checks = {
          inherit pre-commit-check;
        };

        packages = {
          osmosis-genesis-file = import ./osmosis-genesis.nix {inherit pkgs;};
        };

        devShells.default = pkgs.devshell.mkShell {
          env = [
            {
              name = "OVMF";
              value = "${pkgs.OVMF.fd}/FV";
            }
          ];
          commands = [
            {
              help = "Format nix files";
              name = "format";
              command = "alejandra ./*";
              category = "hygiene";
            }
            {
              help = "Emulate configuration in a vm";
              name = "emulate";
              command = ''
                rm -f cofiDataCollector
                nix build .#nixosConfigurations.cofiDataCollector.config.system.build.vm -o cofiDataCollector
                ./cofiDataCollector/bin/run-*-vm -nographic -display curses -no-reboot
              '';
              category = "hygiene";
            }
          ];
          devshell = {
            name = "cofi-data";
            startup.pre-commit.text = "${self.checks.${system}.pre-commit-check.shellHook}";
            packages = with pkgs; [
              alejandra
              coldsnap
              qemu
              netcat
              cosmos.osmosis1
            ];
          };
        };
      }
    )
    // (let
      system = "x86_64-linux";
      cosmos = cosmos-nix.packages.${system};
    in {
      nixosConfigurations.cofiDataCollector = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          #(nixpkgs + "/nixos/modules/virtualisation/amazon-image.nix")
          (nixpkgs + "/nixos/modules/virtualisation/qemu-vm.nix")

          cosmos-nix.nixosModules.osmosis

          ({pkgs, ...}: {
            nix = {
              extraOptions = ''
                experimental-features = nix-command flakes
              '';
            };

            # Let 'nixos-version --json' know about the Git revision
            # of this flake.
            system.configurationRevision = nixpkgs.lib.mkIf (self ? rev) self.rev;

            system.stateVersion = "22.11";

            environment.systemPackages = with pkgs; [
              cosmos.osmosis1
              vim
              htop
              lsof
            ];

            networking.firewall.enable = false;
            boot.loader.grub.extraConfig = "serial; terminal_input serial; terminal_output serial";
            services.getty.autologinUser = "root";

            services.postgresql = {
              package = pkgs.postgresql_15;
              enable = true;
              enableTCPIP = false;
              authentication = ''
                local all all trust
                host all all 127.0.0.1/32 trust
                host all all ::1/128 trust
              '';
              settings = {
                timezone = "UTC";
                shared_buffers = 128;
                fsync = false;
                synchronous_commit = false;
              };
            };

            services.osmosisd = {
              enable = true;
              node-name = "Cofi-data";
              snapshot-sync-url = "https://snapshots.polkachu.com/snapshots/osmosis/osmosis_6784048.tar.lz4";
              packages = with cosmos; {
                genesis = osmosis1;
                v2 = osmosis2;
                v3 = osmosis3;
                v4 = osmosis4;
                v5 = osmosis5;
                v6 = osmosis6;
                v7 = osmosis7;
                v8 = osmosis8;
                v9 = osmosis9;
                v10 = osmosis10;
                v11 = osmosis11;
                v12 = osmosis12;
              };

              persistent-peers = [
                ## Cosmostation
                "8f67a2fcdd7ade970b1983bf1697111d35dfdd6f@52.79.199.137:26656"
                "00c328a33578466c711874ec5ee7ada75951f99a@35.82.201.64:26656"
                "cfb6f2d686014135d4a6034aa6645abd0020cac6@52.79.88.57:26656"

                ## DiveCrypto
                "8d9967d5f865c68f6fe2630c0f725b0363554e77@134.255.252.173:26656"

                ## Forbole
                "785bc83577e3980545bac051de8f57a9fd82695f@194.233.164.146:26656"

                ## KalpaTech
                "778fdedf6effe996f039f22901a3360bc838b52e@161.97.187.189:36657"

                ## SolidStake
                "64d36f3a186a113c02db0cf7c588c7c85d946b5b@209.97.132.170:26656"

                ## StakeLab
                "4d9ac3510d9f5cfc975a28eb2a7b8da866f7bc47@37.187.38.191:26656"

                ## StakerSpace
                "2115945f074ddb038de5d835e287fa03e32f0628@95.217.43.85:26656"

                ## Stake-R-US
                "bf2c480eff178d2647ba1adfeee8ced568fe752c@91.65.128.44:26656"

                ## SyncNode
                "2f9c16151400d8516b0f58c030b3595be20b804c@37.120.245.167:26656"

                ## qf3l3k
                "bada684070727cb3dda430bcc79b329e93399665@173.212.240.91:26656"

                ## notional (seeds with state sync)
                "83adaa38d1c15450056050fd4c9763fcc7e02e2c@ec2-44-234-84-104.us-west-2.compute.amazonaws.com:26656"
                "23142ab5d94ad7fa3433a889dcd3c6bb6d5f247d@95.217.193.163:26656"
                "f82d1a360dc92d4e74fdc2c8e32f4239e59aebdf@95.217.121.243:26656"
                "e437756a853061cc6f1639c2ac997d9f7e84be67@144.76.183.180:26656"

                ## Witval
                "3fea02d121cb24503d5fbc53216a527257a9ab55@143.198.145.208:26656"

                ## artifact-staking.io
                "7de029fa5e9c1f39557c0e3523c1ae0b07c58be0@78.141.219.223:26656"

                ## Figment
                "7024d1ca024d5e33e7dc1dcb5ed08349768220b9@134.122.42.20:26656"
                "d326ad6dffa7763853982f334022944259b4e7f4@143.110.212.33:26656"

                ## Medusanode
                "e7916387e05acd53d1b8c0f842c13def365c7bb6@176.9.64.212:26666"

                ## Binary Holdings
                "55eea69c21b46000c1594d8b4a448563b075d9e3@34.107.19.235:26656"

                ## ChainFlow
                "9faf468b90a3b2b85ffd88645a15b3715f68bb0b@195.201.122.100:26656"

                ## Cephalopod Equipment
                "ffc82412c0261a94df122b9cc0ce1de81da5246b@15.222.240.16:26656"
                "5b90a530464885fd28c31f698c81694d0b4a1982@35.183.238.70:26656"

                ## mp20
                "7b6689cb18d625bbc069aa99d9d5521293db442c@51.158.97.192:26656"

                ## Stargaze.fi
                "fda06dcebe2acd17857a6c9e9a7b365da3771ceb@52.206.252.176:26656"

                ## Validatus
                "8d9fd90a009e4b6e9572bf9a84b532a366790a1d@193.26.156.221:26656"
              ];
              cosmovisor = cosmos.cosmovisor;
              genesis-file = "${self.packages.${system}.osmosis-genesis-file}/osmosis-1/genesis.json";
            };
          })
        ];
      };
    });
}

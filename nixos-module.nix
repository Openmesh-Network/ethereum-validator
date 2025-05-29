inputs:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.ethereum-validator;
in
{
  imports = [
    inputs.ethereum.nixosModules.default
  ];

  options = {
    services.ethereum-validator = {
      enable = lib.mkEnableOption "Enable the Ethereum validator.";

      network = lib.mkOption {
        type = lib.types.str;
        default = "mainnet";
        example = "sepolia";
        description = ''
          The name of the Ethereum-based network to run the validator on.
        '';
      };

      executionClient = {
        implementation = lib.mkOption {
          type = lib.types.enum [
            "geth"
            "nethermind"
            "erigon"
            "reth"
          ];
          default = "geth";
          example = "nethermind";
          description = ''
            Ethereum execution client implementation to use.
          '';
        };

        settings = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = ''
            Additional settings to pass to the execution client;
          '';
        };
      };

      consensusClient = {
        implementation = lib.mkOption {
          type = lib.types.enum [
            "lighthouse"
            "prysm"
            "nimbus"
          ];
          default = "lighthouse";
          example = "prysm";
          description = ''
            Ethereum consensus client implementation to use.
          '';
        };

        settings = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = ''
            Additional settings to pass to the consensus client;
          '';
        };
      };

      validatorClient = {
        implementation = lib.mkOption {
          type = lib.types.enum [
            "lighthouse"
            "prysm"
          ];
          default = "lighthouse";
          example = "prysm";
          description = ''
            Ethereum validator client implementation to use.
          '';
        };

        settings = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = ''
            Additional settings to pass to the validator client;
          '';
        };
      };

      mevBoost = {
        settings = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = ''
            Additional settings to pass to the MEV boost;
          '';
        };
      };
    };
  };

  config = lib.mkIf cfg.enable (
    let
      network = cfg.network;
      executionClient = cfg.executionClient.implementation;
      consensusClient = "${cfg.consensusClient.implementation}-beacon";
      validatorClient = "${cfg.validatorClient.implementation}-validator";
      jwt = "/tmp/ethereum-validator-jwt";

      # Some clients want no value passed if network is mainnet
      mapNetwork =
        network: client:
        lib.mkIf (
          network != "mainnet"
          || !(lib.elem client [
            "geth"
            "prysm"
          ])
        ) network;
    in
    (lib.mkMerge [
      {
        systemd.services."ethereum-validator-jwt" = {
          wantedBy = [ "network.target" ];
          description = "Generate Ethereum execution client JWT";
          serviceConfig = {
            Type = "oneshot";
          };
          script = ''
            ${lib.getExe pkgs.openssl} rand -hex 32 > ${jwt}
          '';
        };

        # https://github.com/nix-community/ethereum.nix/blob/main/modules/geth/args.nix
        services.ethereum.${executionClient}.${network} = lib.mkMerge [
          {
            enable = true;
            package = inputs.ethereum.packages.${pkgs.system}.${cfg.executionClient.implementation};
            openFirewall = true;
            args = {
              network = mapNetwork network cfg.executionClient.implementation;
              authrpc.jwtsecret = jwt;
            };
          }
          cfg.executionClient.settings
        ];

        # https://github.com/nix-community/ethereum.nix/blob/main/modules/lighthouse-beacon/args.nix
        services.ethereum.${consensusClient}.${network} = lib.mkMerge [
          {
            enable = true;
            package = inputs.ethereum.packages.${pkgs.system}.${cfg.consensusClient.implementation};
            openFirewall = true;
            args = {
              network = mapNetwork network cfg.consensusClient.implementation;
              execution-jwt = jwt;
            };
          }
          cfg.consensusClient.settings
        ];

        # https://github.com/nix-community/ethereum.nix/blob/main/modules/lighthouse-validator/args.nix
        services.ethereum.${validatorClient}.${network} = lib.mkMerge [
          {
            enable = true;
            package = inputs.ethereum.packages.${pkgs.system}.${cfg.validatorClient.implementation};
            openFirewall = true;
            args = {
              network = mapNetwork network cfg.validatorClient.implementation;
              graffiti = "Ethereum validator running on Xnode!";
            };
          }
          cfg.validatorClient.settings
        ];

        # https://github.com/nix-community/ethereum.nix/blob/main/modules/mev-boost/args.nix
        services.ethereum.mev-boost.${network} = lib.mkMerge [
          {
            enable = true;
            args = {
              network = network;
              relays = [ ];
            };
          }
          cfg.mevBoost.settings
        ];
      }

      # Register all users
      (lib.mkMerge (
        builtins.map
          (
            u:
            let
              id = "${u}-${network}";
            in
            {
              users = {
                users.${id} = {
                  isSystemUser = true;
                  group = id;
                };
                groups.${id} = { };
              };
            }
          )
          [
            cfg.executionClient.implementation
            cfg.consensusClient.implementation
            cfg.validatorClient.implementation
          ]
      ))

      # Disable dynamic user
      (lib.mkMerge (
        builtins.map
          (
            u:
            let
              id = "${u}-${network}";
            in
            {
              systemd.services.${id}.serviceConfig.DynamicUser = false;
            }
          )
          [
            executionClient
            consensusClient
            validatorClient
          ]
      ))
    ])
  );
}

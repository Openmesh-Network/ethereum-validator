{
  inputs = {
    xnode-manager.url = "github:Openmesh-Network/xnode-manager";
    ethereum-validator.url = "github:Openmesh-Network/ethereum-validator";
    nixpkgs.follows = "ethereum-validator/nixpkgs";
  };

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  outputs = inputs: {
    nixosConfigurations.container = inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit inputs;
      };
      modules = [
        inputs.xnode-manager.nixosModules.container
        inputs.ethereum-validator.nixosModules.default
        {
          # START USER CONFIG
          networking.hostName = "ethereum-validator";
          nixpkgs.hostPlatform = "x86_64-linux";
          system.stateVersion = "24.11";

          services.ethereum-validator.network = "mainnet";
          services.ethereum-validator.executionClient.implementation = "geth";
          services.ethereum-validator.consensusClient.implementation = "lighthouse";
          services.ethereum-validator.consensusClient.settings.args.checkpoint-sync-url =
            "https://sync-mainnet.beaconcha.in";
          services.ethereum-validator.validatorClient.implementation = "lighthouse";
          services.ethereum-validator.mevBoost.settings.args.relays = [
            "https://0xac6e77dfe25ecd6110b8e780608cce0dab71fdd5ebea22a16c0205200f2f8e2e3ad3b71d3499c54ad14d6c21b41a37ae@boost-relay.flashbots.net"
          ];
          # END USER CONFIG

          services.ethereum-validator.enable = true;
        }
      ];
    };
  };
}

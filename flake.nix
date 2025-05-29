{
  description = "Nix flake to run an Ethereum validator with minimal setup.";

  inputs = {
    ethereum.url = "github:nix-community/ethereum.nix";
    nixpkgs.follows = "ethereum/nixpkgs";
  };

  outputs = inputs: {
    nixosModules.default = import ./nixos-module.nix inputs;
  };
}

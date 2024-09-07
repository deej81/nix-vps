{
  description = "streamlit google auth example";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    hardware.url = "github:nixos/nixos-hardware";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, ... } @ inputs:
    let
      inherit (self) outputs;
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      nixpkgsFor = forAllSystems (system:
        import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
        }
      );
    in
    {

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixpkgs-fmt);

      packages = forAllSystems (system:
        let pkgs = nixpkgsFor.${system};
        in import ./shell.nix { inherit pkgs; }
      );

      devShells = forAllSystems (system:
        let pkgs = nixpkgsFor.${system};
        in import ./shell.nix { inherit pkgs; }
      );

      nixosConfigurations.digitalocean = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          { disko.devices.disk.main.device = "/dev/vda"; }
          {
            # do not use DHCP, as DigitalOcean provisions IPs using cloud-init
            networking.useDHCP = nixpkgs.lib.mkForce false;

            services.cloud-init = {
              enable = true;
              network.enable = true;
            };
          }
          ./server-config/configuration.nix
        ];
      };
    };
}

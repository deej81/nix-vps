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


      # configure the development shell loaded by direnv
      default = forAllSystems (system:
        let pkgs = nixpkgsFor.${system};
        in
        pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            nix
            git
            just
            go
          ];
        }
      );

      packages = forAllSystems (system:
        let pkgs = nixpkgsFor.${system};
        in {
          default = pkgs.buildGoModule rec {
            pname = "hello";
            version = "0.1.0";
            src = ./.;
            meta = with pkgs.lib; {
              description = "A simple hello world program";
              license = licenses.mit;
            };
            vendorHash = null;
          };
        }
      );

      init_script = forAllSystems (system:
        let pkgs = nixpkgsFor.${system};
        in {
          default =
            pkgs.writeScript "runit" ''
              #!/usr/bin/env sh
              ${pkgs.copier}/bin/copier copy https://github.com/deej81/nix-vps .
            '';
        }
      );

      # Add an app to directly run copier
      apps = forAllSystems (system:
        let pkgs = nixpkgsFor.${system};
        in {
          initialise = {
            type = "app";
            description = "Run Copier";
            # Define how copier will be run using nix run
            program = "${self.packages.${system}.default}/bin/nix-vps";
          };
        }
      );
    };
}

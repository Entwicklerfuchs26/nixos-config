{
  description = "Nexus Recovery-Install (kein sojus-core – nur für Erstinstall nach Crash)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    quickshell = {
      url = "github:quickshell-mirror/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    awww = {
      url = "git+https://codeberg.org/LGFae/awww";
    };
    skwd-daemon = {
      url = "github:liixini/skwd-daemon";
    };
    skwd-wall = {
      url = "github:liixini/skwd-wall";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs = { self, nixpkgs, home-manager, quickshell, awww, skwd-daemon, skwd-wall, agenix, ... }: {
    nixosConfigurations.nexus = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit quickshell awww skwd-daemon skwd-wall; };
      modules = [
        ./hardware-configuration.nix
        ./nexus/default-recovery.nix
        home-manager.nixosModules.home-manager
        skwd-wall.nixosModules.default
        agenix.nixosModules.default
      ];
    };
  };
}

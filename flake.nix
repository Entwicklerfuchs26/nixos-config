{
 description = "Nexus System Konfiguration";

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
 };

 outputs = {self, nixpkgs, home-manager,quickshell,awww, ... }: {
   nixosConfigurations.nexus = nixpkgs.lib.nixosSystem {
     system = "x86-64-linux";
     specialArgs = {inherit quickshell awww;};
     modules = [
       ./hardware-configuration.nix
       ./nexus/default.nix
       home-manager.nixosModules.home-manager
     ];
   };
 };
}

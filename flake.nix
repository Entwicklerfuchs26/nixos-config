{
 description = "Nexus System Konfiguration";

 inputs = {
   nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
   home-manager = {
     url = "github:nix-community/home-manager/release-25.11";
     inputs.nixpkgs.follows = "nixpkgs";
   };
 };

 outputs = {self, nixpkgs, home-manager, ... }: {
   nixosConfigurations.nexus = nixpkgs.lib.nixosSystem {
     system = "x86-64-linux";
     modules = [
       ./hardware-configuration.nix
       ./nexus/default.nix
       home-manager.nixosModules.home-manager
     ];
   };
 };
}

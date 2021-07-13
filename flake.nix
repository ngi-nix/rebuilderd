{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-21.05";
  };

  outputs = { nixpkgs, self }:
    let
      supportedSystems = [ "x86_64-linux" "i686-linux" "aarch64-linux" ];
      forAllSystems' = systems: fun: nixpkgs.lib.genAttrs systems fun;
      forAllSystems = forAllSystems' supportedSystems;
    in
    {
      overlays.rebuilderd = final: prev:
        {
          rebuilderd = final.callPackage ./rebuilderd.nix {};
          archlinux-repro = final.callPackage ./archlinux-repro.nix {};
        };

      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; overlays = [ self.overlays.rebuilderd ]; };
        in
          {
            inherit (pkgs)
              rebuilderd
              archlinux-repro;
          }
      );

      defaultPackage = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; overlays = [ self.overlays.rebuilderd ]; };
        in
          pkgs.rebuilderd
      );

      defaultApp = self.defaultPackage;
      apps = self.packages;
    };
}

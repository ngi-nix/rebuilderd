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

      overlay = self.overlays.rebuilderd;

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

      nixosModule = self.nixosModules.rebuilderd;

      nixosModules =
        {
          rebuilderd = import ./module.nix;
        };

      nixosConfigurations =
        {
          container = nixpkgs.lib.nixosSystem
            {
              system = "x86_64-linux";

              modules = [
                self.nixosModule
                ({ ... }:
                  {
                    boot.isContainer = true;

                    nixpkgs.overlays = [ self.overlay ];

                    services.rebuilderd =
                      {
                        enable = true;
                        daemon = 
                          {
                            http =
                              {
                                bind_addr = "0.0.0.0:8484";
                                endpoint = "http://127.0.0.1:8484";
                              };
                            auth =
                              {
                                cookie = "$(</var/secrets/auth_cookie)"; 
                              };
                            endpoints."https://rebuilder.example.com" =
                              {
                                cookie = "$(</var/secrets/endpoint_cookie)";
                              };
                            worker =
                              {
                                authorized_workers =
                                  [ "$(</var/secrets/comma_separated_workers)"
                                  ];
                                signup_secret = "$(</var/secrets/worker_signup_secret)"; 
                              };
                            schedule =
                              {
                                retry_delay_base = 24;
                              };
                          };
                        workers.main =
                          {
                            endpoint = "http://127.0.0.1:8484"; 
                            signup_secret = "$(</var/secrets/worker_signup_server)";

                            build =
                              {
                                timeout = 86400;
                                max_bytes = 10485760;
                              };
                            diffoscope =
                              {
                                enable = false;
                                args = [ "--max-container-depth" "2" "--fuzzy-threshold" "0" ];
                                timeout = 600;
                                max_bytes = 41943040;
                              };
                          };
                        sync =
                          {
                            profile."archlinux-core" =
                              {
                                distro = "archlinux";
                                suite = "core";
                                architectures = [ "x86_64" ];
                                source = "https://ftp.halifax.rwth-aachen.de/archlinux/\\$repo/os/\\$arch";
                              };
                          };
                      };
                  })
              ];
            };
        };
    };
}

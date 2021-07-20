{ pkgs, lib, config, ... }:
with lib;
let
  cfg = config.services.rebuilderd;

  runtimeDir = "/run/rebuilderd";
  stateDir = "/var/lib/rebuilderd";

  flattenAttrs = x:
    flatten
      (mapAttrsToList (n: v:
        (if !(isAttrs v) then
          { name = n; value = v; end = true; }
         else
           let
             recursed = flattenAttrs v;
           in
             let
               ends = (filter (x: x ? "end") recursed);
             in
               optional (ends != []) (singleton { name = n; value = listToAttrs ends; })
               ++
               map (x:
                 x // { name = n + "." + ''"${x.name}"''; }
               ) (filter (x: ! x ? "end") recursed)
        )
      ) x);

  toINIFlat = x:
    let
      toINIString = x:
        (if isBool x then
          if x then "true" else "false"
         else if isInt x then
           toString x
         else if isList x then
           "[ " +
           concatMapStringsSep ", "
             (x:
               if isBool x then
                 if x then "true" else "false"
               else if isInt x then
                 toString x
               else
                 "\"" + toString x + "\"") x
           +
           " ]"
         else
           "\"" + toString x + "\""
        );
    in
    (concatStringsSep "\n" (map
      ({ name, value, ... }:
        if isAttrs value then
          "[${name}]\n"
          +
          concatStringsSep "\n" (mapAttrsToList
            (n: v:
              "${n} = "
              +
              toINIString v
            ) value)
        else
          "${name} = " + toINIString value
      ) (sort (a: b: a ? "end" && ! b ? "end" ) (flattenAttrs x))));

  iniFlatType = with types;
    let
      values = [ str int bool (listOf (oneOf [ str int bool ])) ];
    in
      nullOr (attrsOf (oneOf (values ++ [ (attrsOf (oneOf (values ++ [ (attrsOf (oneOf values)) ]))) ])));
in
{
  options.services.rebuilderd = {
    enable = mkEnableOption "Enable rebuilderd.";

    user = mkOption {
      description = ''
        The user under which all the rebuilderd services are ran.
      '';
      type = types.str;
      default = "rebuilderd";
    };

    group = mkOption {
      description = ''
        The group under which all the rebuilderd services are ran.
      '';
      type = types.str;
      default = "rebuilderd";
    };

    package = mkOption {
      description = ''
        rebuilderd package.
      '';
      type = types.package;
      default = pkgs.rebuilderd;
    };

    daemon = mkOption {
      description = ''
        rebuilderd daemon configuration.

        The generated file is ran through bash's substitution, therefore
        <literal>"$(</some/file)"</literal> will expand to the contents of
        <literal>/some/file</literal> at runtime!
     '';
      type = iniFlatType;
      default = null;
      example = literalExample ''
        # for the generated config file, visit https://github.com/kpcyrd/rebuilderd/blob/a28e72/contrib/docs/rebuilderd.conf.5.scd
        {
          http =
            {
              bind_addr = "0.0.0.0:8484";
              real_ip_header = "X-Real-IP";
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
              authorized_workers = ''''[ "$(</var/secrets/comma_separated_workers)" ]'''';
              signup_secret = "$(</var/secrets/worker_signup_secret)"; 
            };
          schedule =
            {
              retry_delay_base = 24;
            };
        }
      '';
      apply = x: 
          pkgs.writeText "rebuilderd.conf" (toINIFlat x);
    };

    workers = mkOption {
      description = ''
        rebuilderd-worker configurations, you can run multiple workers.

        The generated files are ran through bash's substitution, therefore
        <literal>"$(</some/file)"</literal> will expand to the contents
        of <literal>/some/file</literal> at runtime!
      '';
      type = types.attrsOf iniFlatType;
      default = {};
      example = literalExample ''
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
              args = [ "--max-container-depth" 2 "--fuzzy-threshold" 0 ];
              timeout = 600;
              max_bytes = 41943040;
            };
        }
      '';
      apply = x:
        mapAttrs (n: v: pkgs.writeText "rebuilderd-worker-${n}.conf" (toINIFlat v)) x;
    };

    sync = mkOption {
      description = ''
        rebuilderd-sync configuration, for each profile a systemd unit and timer will
        be created. 

        The generated files are ran through bash's substitution, therefore
        <literal>"$(</some/file)"</literal> will expand to the contents
        of <literal>/some/file</literal> at runtime!
      '';
      type = iniFlatType;
      default = {};
      example = literalExample ''
        {
          profile."archlinux-core" =
          {
            distro = "archlinux";
            suite = "core";
            architectures = [ "x86_64" ];
            source = "https://ftp.halifax.rwth-aachen.de/archlinux/\\$repo/os/\\$arch";
          };

          profile."archlinux-community" = 
            {
              distro = "archlinux";
              suite = "community";
              architectures = [ "x86_64" ];
              source = "https://ftp.halifax.rwth-aachen.de/archlinux/\\$repo/os/\\$arch";
              maintainers = [ "somebody" ];
              pkgs = [ "some-pkg" "python-*" ];
              excludes = ["tensorflow*"];
            };

          profile."debian-main" =
            {
              distro = "debian";
              suite = "main";
              architectures = [ "amd64" ];
              releases = [ "buster" "sid" ];
              source = "http://deb.debian.org/debian";
            };
        }
      '';
    };
  };

  config = mkIf cfg.enable {
    users.users.rebuilderd = mkIf (cfg.user == "rebuilderd") {
      group = cfg.group;
      description = "rebuilderd user";
      uid = 98; # TODO put into config.ids.uids.rebuilderd
    };

    users.groups.rebuilderd = mkIf (cfg.group == "rebuilderd") {
      gid = 98; # TODO put into config.ids.gids.rebuilderd
    };

    environment.systemPackages = [
      cfg.package
    ];

    # systemd.tmpfiles.rules =
    #   [
    #     "d '${authDir}' 0755 ${cfg.user} ${cfg.group}"
    #     "Z '${authDir}' -    ${cfg.user} ${cfg.group}"
    #   ];

    systemd.services = listToAttrs
      ( (optional (cfg.daemon != null)
        (nameValuePair "rebuilderd"
          {
            description = "rebuilderd";
            wantedBy = [ "multi-user.target" ];
            path = [ cfg.package ];

            environment = {
              REBUILDERD_COOKIE_PATH = "${stateDir}/rebuilderd-auth-cookie";
            };

            preStart =
              ''
                eval "cat <<EOF
                $(<${cfg.daemon})
                EOF
                " 2> /dev/null > ${runtimeDir}/daemon/config.conf
              '';

            serviceConfig = {
              # rebuilderd writes its db to ./rebuilderd.db
              WorkingDirectory = "${stateDir}";
              ExecStart = "@${cfg.package}/bin/rebuilderd rebuilderd -v -c ${runtimeDir}/daemon/config.conf";
              User = cfg.user;
              Group = cfg.group;
              #Type = "???";
              Restart = "always";
              RestartSec = "5";
              StateDirectory = "rebuilderd";
              StateDirectoryMode = "0750";
              RuntimeDirectory = "rebuilderd/daemon";
              RuntimeDirectoryMode = "0755";
            };
          })
      )
      ++ (mapAttrsToList (n: v: nameValuePair "rebuilderd-worker-${n}"
        {
          description = "rebuilderd ${n} worker";
          wantedBy = [ "multi-user.target" ];
          requires = [ "rebuilderd.service" ];
          after = [ "rebuilderd.service" ];
          path = with pkgs;
            [ cfg.package
            ];

          environment = {
            REBUILDERD_COOKIE_PATH = "${stateDir}/rebuilderd-auth-cookie";
            SSL_CERT_FILE = "${pkgs.cacert.out}/etc/ssl/certs/ca-bundle.crt";
            NIX_SSL_CERT_FILE = "${pkgs.cacert.out}/etc/ssl/certs/ca-bundle.crt";
          };

          preStart =
            ''
              eval "cat <<EOF
              $(<${v})
              EOF
              " 2> /dev/null > ${runtimeDir}/worker-${n}/config.conf
            '';

          serviceConfig = {
            WorkingDirectory = "${stateDir}";
            ExecStart = "@${cfg.package}/bin/rebuilderd-worker rebuilderd-worker -c ${runtimeDir}/worker-${n}/config.conf connect";
            User = "root";
            Group = "root";
            #Type = "???";
            Restart = "always";
            RestartSec = "5";
            StateDirectory = "rebuilderd";
            StateDirectoryMode = "0750";
            RuntimeDirectory = "rebuilderd/worker-${n}";
            RuntimeDirectoryMode = "0755";
          };
        }) cfg.workers)
      ++ (mapAttrsToList (n: v: nameValuePair "rebuilderd-sync-${n}"
        {
          description = "rebuilderd ${n} sync";
          wantedBy = [ "multi-user.target" ];
          requires = [ "rebuilderd.service" ];
          after = [ "rebuilderd.service" "network.target" ];
          path = [ cfg.package ];

          environment = {
            # it looks for its cookie there
            XDG_DATA_HOME = "${stateDir}";
          };

          preStart =
            ''
              eval "cat <<EOF
              $(<${pkgs.writeText "rebuilderd-sync-${n}.conf" (toINIFlat cfg.sync)})
              EOF
              " 2> /dev/null > ${runtimeDir}/sync-${n}/config.conf
            '';

          serviceConfig = {
            WorkingDirectory = "${stateDir}";
            ExecStart = "@${cfg.package}/bin/rebuildctl rebuildctl pkgs sync-profile --sync-config ${runtimeDir}/sync-${n}/config.conf ${n}";
            User = cfg.user;
            Group = cfg.group;
            #Type = "???";
            Restart = "always";
            RestartSec = "5";
            StateDirectory = "rebuilderd";
            StateDirectoryMode = "0750";
            RuntimeDirectory = "rebuilderd/sync-${n}";
            RuntimeDirectoryMode = "0755";
          };
        }) (if cfg.sync ? "profile" then cfg.sync.profile else {}))
      );
  };
}

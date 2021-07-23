# rebuilderd

- upstream: https://github.com/kpcyrd/rebuilderd
- ngi-nix: https://github.com/ngi-nix/ngi/issues/83

a daemon and workers, which build things with backends, which test for reproducibility.

> :warning: Currently the NixOS module is broken, for some reason everything works when ran outside of systemd, but when `rebuilderd-worker` is ran in systemd, the backend `archlinux-repro` launches `curl` which exits with a TLS error.

## Using

In order to use this [flake](https://nixos.wiki/wiki/Flakes) you need to have the
[Nix](https://nixos.org/) package manager installed on your system. Then you can simply run this
with:

```
$ nix run github:ngi-nix/rebuilderd
```

You can also enter a development shell with:

```
$ nix develop github:ngi-nix/rebuilderd
```

For information on how to automate this process, please take a look at [direnv](https://direnv.net/).

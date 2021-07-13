{ lib
, rustPlatform 
, fetchFromGitHub

, pkgconfig, xz, libsodium, openssl, sqlite

, which, makeWrapper, runCommandNoCC
, archlinux-repro
, backends ? [ archlinux-repro ]
}:
with lib;
let
  pname = "rebuilderd";
  version = "0.12.0";

  githubSrc = fetchFromGitHub {
    owner = "kpcyrd";
    repo = "rebuilderd";
    rev = "v" + version;
    sha256 = "sha256-NUiJ0ltUoIUYnM+VloviaU9d9jVULIIAZcze+htlCHg=";
  };

  backendsBin = runCommandNoCC "rebuilderd-backends" {}
    ''
      export PATH=${makeBinPath (backends ++ [ which ])}:$PATH
      . ${makeWrapper}/nix-support/setup-hook
           
      if which repro ; then
        install -Dm 0775 ${githubSrc}/worker/rebuilder-archlinux.sh $out/bin/rebuilder-archlinux.sh
        wrapProgram $out/bin/rebuilder-archlinux.sh --prefix PATH : ${makeBinPath backends}
      fi
      if which debrebuild ; then
        install -Dm 0775 ${githubSrc}/worker/rebuilder-debian.sh $out/bin/rebuilder-debian.sh
        wrapProgram $out/bin/rebuilder-debian.sh --prefix PATH : ${makeBinPath backends}
      fi
    '';
in
rustPlatform.buildRustPackage {
  inherit pname version;

  src = githubSrc;

  buildInputs = [ xz.dev libsodium.dev openssl.dev sqlite.dev ];
  nativeBuildInputs = [ pkgconfig ];

  cargoSha256 = "sha256-IWV776MgzTp6brshd8W6pCoNkY1cZ0ibUJGKgUHIRvo=";

  patchPhase =
    let
      escapePath = path: builtins.replaceStrings ["/"] ["\\/"] (toString path);
    in
      optionalString (backends != []) ''
        sed -i 's/"\."/"${escapePath backendsBin}\/bin"/' ./worker/src/rebuild.rs
        sed -i 's/\(return Ok(bin\.to_path_buf());\)/println!("{:?}", bin); \1/' ./worker/src/rebuild.rs
        cat ./worker/src/rebuild.rs | head -n 40 | tail -n 1 ; sleep 5
      '';

  meta = with lib; {
    description = "";
    homepage = "";
    license = licenses.mit;
    maintainers = [ maintainers.magic_rb ];
    mainProgram = "rebuildctl";
  };

  # the units tests call /bin/echo and its hardcoded
  doCheck = false;
}

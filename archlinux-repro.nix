{ stdenv
, fetchFromGitHub
, lib

, makeWrapper
, curl, gnupg, systemd, asciidoc, git, gnum4, gettext, sudo, utillinux
}:
with lib;
let
  pname = "archlinux-repro";
  version = "20210602";
in
stdenv.mkDerivation {
  inherit pname version;

  doCheck = false;

  nativeBuildInputs = [ git gnum4 asciidoc makeWrapper ];

  installPhase = ''
    make install PREFIX=$out
  '';

  fixupPhase = ''
    patchShebangs --build $out/bin/
    # sed -i 's/curl -f --remote-name-all/cat \$SSL_CERT_FILE \&\& curl -f --remote-name-all/' $out/bin/repro
    wrapProgram $out/bin/repro --prefix PATH : ${makeBinPath [ sudo utillinux curl gnupg systemd gettext ]} 
  '';

  src = fetchFromGitHub {
    owner = "archlinux";
    repo = "archlinux-repro";
    sha256 = "sha256-EK7pLqD/yk3P2qeqwIGOib+f9L9MoidsDnzDsVspAK0="; 
    rev = version;
    leaveDotGit = true;
  };

  meta = with lib; {
    description = "Tools to reproduce arch linux packages";
    homepage = "https://github.com/archlinux/archlinux-repro";
    license = licenses.mit;
    platforms = platforms.unix;
    maintainers = [ maintainers.magic_rb ];
    mainProgram = "repro";
  };
}

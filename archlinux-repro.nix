{ stdenv
, fetchFromGitHub
, lib

, makeWrapper
, curl, gnupg, systemd, asciidoc, git, gnum4, gettext
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
    make install DESTDIR=$out PREFIX=""
  '';

  fixupPhase = ''
    patchShebangs --build $out/bin/
    wrapProgram $out/bin/repro --prefix PATH : ${makeBinPath [ curl gnupg systemd gettext ]} 
  '';

  src = fetchFromGitHub {
    owner = "archlinux";
    repo = "archlinux-repro";
    sha256 = "sha256-EK7pLqD/yk3P2qeqwIGOib+f9L9MoidsDnzDsVspAK0="; 
    rev = version;
    leaveDotGit = true;
  };

  meta = with lib; {
    mainProgram = "repro";
  };
}

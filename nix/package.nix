{
  lib,
  makeWrapper,
  runCommand,
  bash,
  ncurses,
  coreutils,
}:
let
  src = ../cetch.sh;
  binName = "cetch";
  deps = [
    bash
    ncurses
    coreutils
  ];
in
runCommand "${binName}"
  {
    nativeBuildInputs = [ makeWrapper ];
    buildInputs = [ bash ];
    meta = with lib; {
      mainProgram = "cetch";
      description = "A small terminal fastfetch-esque tool, in a single bash script, all horizontally centered.";
      homepage = "https://github.com/willcannotcode/cetch";
      license = licenses.mit;
      platforms = platforms.unix;
    };
  }
  ''
    install -Dm755 ${src} $out/bin/${binName}
    patchShebangs $out/bin/${binName}
    wrapProgram $out/bin/${binName} \
      --prefix PATH : ${lib.makeBinPath deps}
  ''

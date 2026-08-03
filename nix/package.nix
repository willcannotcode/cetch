{
  lib,
  makeWrapper,
  runCommand,
  bash,
  ncurses,
  coreutils,
  chafa,
}:

  let
   src = ../cetch.sh;
   logos = ../DistroLogos;
   binName = "cetch";
   deps = [
     bash
     ncurses
     coreutils
     chafa
    ];
  in
  runCommand "${binName}"
  {
    nativeBuildInputs = [ makeWrapper ];
    meta = with lib; {
      mainProgram = "cetch";
      description = "A small terminal fastfetch-esque tool, in a single bash script, all horizontally centered.";
      homepage = "https://github.com/willcannotcode/cetch";
      license = licenses.mit;
      platforms = platforms.linux;
    };
  }
  ''
    install -Dm755 ${src} $out/bin/${binName}
    mkdir -p $out/share/cetch
    cp -r ${logos} $out/share/cetch/DistroLogos

    wrapProgram $out/bin/${binName} \
      --prefix PATH : ${lib.makeBinPath deps} \
      --set CETCH_LOGOS_DIR $out/share/cetch/DistroLogos
  ''

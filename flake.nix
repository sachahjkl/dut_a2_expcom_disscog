{
  description = "Reproducible checks and static package for the cognitive dissonance website";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      perSystem =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          site = pkgs.runCommand "dut-a2-expcom-disscog-site" { } ''
            mkdir -p "$out/bootstrap"/{css,jquery,js,popper} "$out/pages"
            cp ${./index.html} "$out/index.html"
            cp -r ${./css} "$out/css"
            cp -r ${./img} "$out/img"
            cp ${./bootstrap/css/bootstrap.min.css} "$out/bootstrap/css/bootstrap.min.css"
            cp ${./bootstrap/jquery/jquery-3.3.1.min.js} "$out/bootstrap/jquery/jquery-3.3.1.min.js"
            cp ${./bootstrap/js/bootstrap.bundle.min.js} "$out/bootstrap/js/bootstrap.bundle.min.js"
            cp ${./bootstrap/popper/popper.min.js} "$out/bootstrap/popper/popper.min.js"
            for page in ${./pages}/*; do
              if [ -d "$page" ] && [ -f "$page/content.html" ]; then
                name="$(basename "$page")"
                mkdir "$out/pages/$name"
                cp "$page/content.html" "$out/pages/$name/"
              fi
            done
          '';
        in
        {
          inherit pkgs site;
        };
    in
    {
      packages = forAllSystems (system: {
        default = (perSystem system).site;
      });

      checks = forAllSystems (
        system:
        let
          inherit (perSystem system) pkgs site;
        in
        {
          actionlint = pkgs.runCommand "actionlint" { nativeBuildInputs = [ pkgs.actionlint ]; } ''
            actionlint -config-file ${./.github/actionlint.yaml} ${./.github/workflows/ci.yml}
            touch "$out"
          '';
          html = pkgs.runCommand "html-validation" { nativeBuildInputs = [ pkgs.html5validator ]; } ''
            html5validator --root ${site} --also-check-css --ignore-re 'bootstrap/'
            touch "$out"
          '';
          links = pkgs.runCommand "local-links" { nativeBuildInputs = [ pkgs.lychee ]; } ''
            SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt \
              lychee --offline --include-fragments '${site}/**/*.html'
            touch "$out"
          '';
          package = site;
        }
      );

      formatter = forAllSystems (system: (perSystem system).pkgs.nixfmt-tree);
    };
}

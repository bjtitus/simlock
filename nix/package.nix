{
  lib,
  buildNpmPackage,
  fetchurl,
  jq,
  nodejs_22,
  runtimeShell,
}:

let
  version = "0.4.0";
in
buildNpmPackage {
  pname = "simlock";
  inherit version;
  nodejs = nodejs_22;

  # why: the npm release holds the compiled daemon, the console and the two iOS capture programs,
  # which only Xcode builds (vendor/screen-capture links Xcode's SDK and a private framework the
  # Nix sandbox cannot see). Wrapping the release gives every platform the package npm users get;
  # a build of the checkout would ship no iOS streams.
  src = fetchurl {
    url = "https://registry.npmjs.org/simlock/-/simlock-${version}.tgz";
    hash = "sha256-fU36c5b8vhgGOC+xtek9TQRaOVvxyGrF10Naq3DD5Ag=";
  };

  sourceRoot = "package";

  # why: a release that ships npm-shrinkwrap.json needs no lockfile from this tree. 0.4.0 predates
  # it, so package-lock.json beside this file was generated from its manifest without `scripts`,
  # `devDependencies` and `devEngines`, the shape the release workflow publishes, with
  # `npm install --package-lock-only --ignore-scripts` on Node 22. Delete both the file and this
  # branch when `version` moves to a release that carries the shrinkwrap.
  postPatch = ''
    if [ ! -f npm-shrinkwrap.json ]; then
      cp ${./package-lock.json} package-lock.json
      ${lib.getExe jq} 'del(.scripts, .devDependencies, .devEngines)' package.json > package.json.tmp
      mv package.json.tmp package.json
    fi
  '';

  npmDepsHash = "sha256-7q5sdpjNQO6WOC8eKinbl80yCcyRCj0blhMgJ4/eo8I=";

  dontNpmBuild = true;
  # why: the capture programs are ad-hoc-signed Mach-O binaries; stripping would re-sign them.
  dontStrip = true;

  postInstall = ''
    # why: 0.4.0's tarball holds the capture programs without their executable bit (the release
    # workflow checks the bit since); the daemon spawns them from dist/bin beside itself.
    chmod 755 "$out/lib/node_modules/simlock/dist/bin/"* 2>/dev/null || true

    # why: a program that runs the daemon in the foreground, at a path a profile keeps across
    # upgrades (~/.nix-profile/bin/simlock-daemon), for a login service managed outside Simlock
    # or named to `simlock daemon install`.
    {
      echo '#!${runtimeShell}'
      echo "exec ${lib.getExe nodejs_22} \"$out/lib/node_modules/simlock/dist/daemon/main.js\" \"\$@\""
    } > "$out/bin/simlock-daemon"
    chmod 755 "$out/bin/simlock-daemon"
  '';

  meta = {
    description = "Leases iOS simulators, Android emulators and enrolled phones to coding agents";
    homepage = "https://github.com/callstackincubator/simlock";
    changelog = "https://github.com/callstackincubator/simlock/blob/v${version}/CHANGELOG.md";
    license = lib.licenses.mit;
    mainProgram = "simlock";
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryNativeCode
    ];
  };
}

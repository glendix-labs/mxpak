# AUR publishing

The `Publish AUR package` GitHub Actions workflow prepares and publishes the
`mxpak-bin` package from an existing GitHub release.

## Package model

- A GitHub release tag must be a `v`-prefixed semantic version such as
  `v1.0.0`.
- The release must contain an asset named `mxp`.
- `aur/PKGBUILD` is the maintained template. The updater replaces `pkgver`,
  resets `pkgrel` to `1` for a new upstream version (or increments it for a
  same-version packaging change), downloads `mxp`, records its SHA-256
  checksum, and regenerates `.SRCINFO`.
- The AUR package installs the escript as `/usr/bin/mxp`, depends on
  `erlang-core`, `erlang-inets`, and `erlang-ssl`, and includes the
  repository's MIT `LICENCE`.

## Repository setup

1. Create a dedicated Ed25519 SSH key for GitHub Actions.
2. Add the public key to the maintainer's AUR account.
3. Add the complete private key, including its header and footer, as the
   repository Actions secret `AUR_SSH_PRIVATE_KEY`.
4. Leave `AUR_PUBLISH_ENABLED` unset or set to `false` during AUR maintenance.
   Set it to `true` when automatic release publication should push to AUR.
5. Set `AUR_INITIALIZE_EMPTY` to `true` only for the first publication, then
   unset it or set it to `false` after the package exists in AUR.
6. Optionally set repository Actions variables:
   - `AUR_GIT_NAME`
   - `AUR_GIT_EMAIL`

The private key is exposed only to the SSH configuration step. Pull requests
do not run this workflow.

## First publication

The first SSH clone of a package name that does not yet exist returns an empty
AUR Git repository. Tagged releases call the AUR workflow with this initial
state enabled only when `AUR_INITIALIZE_EMPTY` is `true`. For the first
automatic publication, set both `AUR_PUBLISH_ENABLED` and
`AUR_INITIALIZE_EMPTY` to `true`. After it succeeds, disable
`AUR_INITIALIZE_EMPTY` while leaving `AUR_PUBLISH_ENABLED` enabled.

To publish an existing GitHub release manually, run the workflow with:

- `tag`: the existing GitHub release tag
- `publish`: `true`
- `initialize_empty`: `true`

After the initial commit exists, leave `initialize_empty` disabled.

## Normal publication

Pushing a version tag starts the release workflow. After it builds and uploads
the `mxp` release asset, that workflow calls the AUR workflow directly. This
direct call is intentional: GitHub does not start another workflow from most
events created with the repository `GITHUB_TOKEN`.

The AUR workflow:

1. installs `makepkg`, Git, SSH, cURL, and jq in an Arch Linux container;
2. downloads the tagged release metadata and `mxp` asset;
3. verifies the downloaded SHA-256 against GitHub's asset digest when one is
   available;
4. runs `makepkg` as an unprivileged user, clones the current AUR package, and
   refuses dirty, divergent, or unpushed local state;
5. writes `PKGBUILD`, regenerates `.SRCINFO`, and runs
   `makepkg --verifysource`; the package `check()` also verifies that
   `mxp --version` matches the release;
6. commits only `PKGBUILD`, `.SRCINFO`, and `LICENCE`;
7. pushes the commit to the AUR `master` branch over SSH.

## Maintenance or outage dry run

While `AUR_PUBLISH_ENABLED` is not `true`, tagged releases run an offline dry
run and upload `PKGBUILD`, `.SRCINFO`, and `LICENCE` as a workflow artifact.
The dry run does not contact AUR, so release validation still works during a
full AUR outage.

You can also start the workflow manually with `publish` set to `false`.

The same check can be run on an Arch Linux workstation:

```sh
bash scripts/update-mxpak-aur.sh \
  --tag v1.0.0 \
  --work-dir /tmp/mxpak-aur \
  --verify-source \
  --offline
```

Do not add `--push` during an AUR maintenance window. When maintenance ends,
set `AUR_PUBLISH_ENABLED` to `true`, or manually run the workflow with
`publish` and `initialize_empty` set to `true` for the first publication.

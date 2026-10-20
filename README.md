# desmume-docker
DeSmuME 0.9.11, the version of the course, in Docker, with HUD, GDB stub, sound, the controls of the course and the
graphical output on the host (X11 / Wayland) or through VNC. It is used by the `bmde run` and `bmde debug` commands of
[bmde](https://github.com/URV-teacher/bmde), but can be used on its own.

## Build and installation

DeSmuME 0.9.11 is built from the sources of its Ubuntu package (the upstream sources and the patches of the package),
with `--enable-hud` so the HUD (`View -> HUD`: FPS,
input, lag counter...) works and with the GDB stub. The distribution packages lack them, or do not provide this version
anymore.

`scripts/download_assets.sh` downloads those sources from Launchpad (and the ROM and the project used by the tests) into
`assets/`, checking them against their pinned SHA-256 (see [external
resources](https://github.com/URV-teacher/bmde/blob/master/docs/development/external-resources.md) of bmde). Then the
scripts in `src/` build and install DeSmuME into `/URV/bmde/DeSmuME_0.9.11`, with its environment (`DESMUME`, `PATH`) in
`/etc/profile.d/bmde-desmume.sh`, taking the files only from `src/`, `config/` and `assets/`. The image is built with
them, and they install it in an Ubuntu / Debian host too:

```shell
scripts/download_assets.sh
src/install_desmume.sh
src/install_wrapper.sh  # $DESMUME/DeSmuME.exe and DeSmuME_dev.exe, used by the Makefiles of the course
```

Test the installation with the `test/test_*.sh` scripts. To build the image:

```shell
scripts/download_assets.sh  # The image is built from the assets
docker build -t aleixmt/desmume .
```

## Configuration (controls, HUD)

DeSmuME is configured with a `desmume.ini` in the format written by DeSmuME for Windows, so the same file can be
shared between Windows and this image. On start, the entrypoint translates it (`desmume-ini2gtk`) into the config of
the Linux (GTK) frontend: key bindings from `[Controls]`, and HUD, screen gap, rotation and SPU interpolation
options. Other options are ignored.

* **Default config**: `config/desmume.ini` is installed at `$DESMUME/share/bmde/desmume.ini`. It is
  applied on the first run only (when no key bindings are saved yet in `~/.config/desmume`), so changes made from the
  emulator window persist if `~/.config/desmume` is a volume.
* **Custom config**: mount your own file at `/config/desmume.ini`. It is applied on every start, overriding saved
  changes:

```bash
docker run --rm -v "$PWD/desmume.ini:/config/desmume.ini:ro" ... aleixmt/desmume
```

| Variable              | Default                                 | Description                                     |
|-----------------------|-----------------------------------------|-------------------------------------------------|
| `DESMUME_INI`         | `/config/desmume.ini`                   | Custom config, applied on every start if found. |
| `DESMUME_DEFAULT_INI` | `$DESMUME/share/bmde/desmume.ini`       | Default config, applied on first run.           |

Unassigned keys (code `0`) keep the defaults of the Linux frontend (Debug: `p`, Boost: `o`, Lid: `Backspace`).

## Sound

DeSmuME's audio can be played on the host through its PulseAudio-compatible server (PulseAudio or PipeWire's
`pipewire-pulse`). Mount the host socket at `/run/pulse/native` and the entrypoint will use it automatically:

```bash
docker run --rm \
  -v "$XDG_RUNTIME_DIR/pulse/native:/run/pulse/native" \
  -v "$HOME/.config/pulse/cookie:/run/pulse/cookie:ro" \
  ... aleixmt/desmume
```

The cookie mount is only needed when the host server requires authentication (classic PulseAudio). Relevant
environment variables:

| Variable            | Default              | Description                                                   |
|---------------------|----------------------|---------------------------------------------------------------|
| `DESMUME_USE_SOUND` | `1`                  | `0` disables sound (`--disable-sound`).                       |
| `PULSE_SERVER`      | unset                | Standard libpulse server address; overrides `PULSE_SOCKET`.   |
| `PULSE_SOCKET`      | `/run/pulse/native`  | Where the host socket is mounted.                             |
| `PULSE_COOKIE_FILE` | `/run/pulse/cookie`  | Where the host cookie is mounted, if any.                     |

## FAT image (CompactFlash card)

The programs of the course that read and write files (with libfat) need a FAT image as the CompactFlash card of the
emulator. The entrypoint uses `/fs/fat.img` if it exists (`DESMUME_CFLASH_IMAGE` changes it). Create an empty one in
`fs/fat.img` (it needs `mkfs.fat`, of the package `dosfstools`) and mount it:

```bash
scripts/create_fat_image.sh
docker run --rm -v "$PWD/fs:/fs" ... aleixmt/desmume
```

`test/image/test_fat.sh` tests this mechanism from outside the image (it needs Docker, `mkfs.fat` and mtools): it runs
the ROM of [filesystem-nds](https://github.com/URV-teacher/filesystem-nds) (built by `scripts/download_assets.sh`) with
an empty FAT image, and checks the files that it writes into it:

```bash
scripts/download_assets.sh filesystem-nds.nds
test/image/test_fat.sh aleixmt/desmume
```

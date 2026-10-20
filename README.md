# desmume-docker
DeSmuME 0.9.11, the version of the course, in Docker, with HUD, GDB stub, sound, the controls of the course and the
graphical output on the host (X11 / Wayland) or through VNC. It is used by the `bmde run` and `bmde debug` commands of
[bmde](https://github.com/URV-teacher/bmde), but can be used on its own.

## Build and installation

DeSmuME 0.9.11 is built from the sources of its Ubuntu package (the upstream sources and the patches of the package,
downloaded from Launchpad and checked against pinned checksums), with `--enable-hud` so the HUD (`View -> HUD`: FPS,
input, lag counter...) works and with the GDB stub. The distribution packages lack them, or do not provide this version
anymore.

The scripts in `scripts/` build and install it into `/URV/bmde/DeSmuME_0.9.11`, with its environment (`DESMUME`,
`PATH`) in `/etc/profile.d/bmde-desmume.sh`. The image is built with them, and they install it in an Ubuntu / Debian
host too:

```shell
scripts/install_desmume.sh
scripts/install_wrapper.sh  # $DESMUME/DeSmuME.exe and DeSmuME_dev.exe, used by the Makefiles of the course
```

Test the installation with the `scripts/test_*.sh` scripts. To build the image:

```shell
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

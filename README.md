# desmume-cli
Docker for desmume-cli

Commit for desmume 0.9.11
git checkout 7c7fd242c221a8f722d39f9df5cdf40789cb31e3 && \
## Build

The image ships DeSmuME 0.9.11, rebuilt from the Ubuntu 22.04 source package (keeping its patches) with
`--enable-hud`, so the HUD (`View -> HUD`: FPS, input, lag counter...) works. The stock package is compiled
without it.

## Configuration (controls, HUD)

DeSmuME is configured with a `desmume.ini` in the format written by DeSmuME for Windows, so the same file can be
shared between Windows and this image. On start, the entrypoint translates it (`desmume-ini2gtk`) into the config of
the Linux (GTK) frontend: key bindings from `[Controls]`, and HUD, screen gap, rotation and SPU interpolation
options. Other options are ignored.

* **Default config**: `config/desmume.ini` is baked into the image at `/usr/share/desmume-docker/desmume.ini`. It is
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
| `DESMUME_DEFAULT_INI` | `/usr/share/desmume-docker/desmume.ini` | Default config, applied on first run.           |

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

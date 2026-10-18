# desmume-cli
Docker for desmume-cli

Commit for desmume 0.9.11
git checkout 7c7fd242c221a8f722d39f9df5cdf40789cb31e3 && \
## Build

The image ships DeSmuME 0.9.11, rebuilt from the Ubuntu 22.04 source package (keeping its patches) with
`--enable-hud`, so the HUD (`View -> HUD`: FPS, input, lag counter...) works. The stock package is compiled
without it.

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

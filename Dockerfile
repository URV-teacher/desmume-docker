# DeSmuME 0.9.11 (the version of the course) with HUD and GDB stub, with the graphical output, sound and configuration
# handled by entrypoint.sh. The installation is done by the scripts in scripts/, the same ones used to install it in a
# host (see README.md).

# STAGE 1: Build. install_desmume.sh builds DeSmuME into /URV/bmde/DeSmuME_0.9.11
# Base image of the BMDE images (docker-bake.hcl of bmde replaces this stage by the base image being built)
FROM aleixmt/bmde-base:latest AS bmde-base

FROM bmde-base AS build

RUN --mount=type=bind,target=/component /component/scripts/install_desmume.sh


# STAGE 2: Runtime. install_desmume.sh finds DeSmuME already built, and installs its runtime dependencies only
FROM bmde-base

RUN bmde-install-display

COPY --from=build /URV/bmde/DeSmuME_0.9.11 /URV/bmde/DeSmuME_0.9.11
RUN --mount=type=bind,target=/component \
    /component/scripts/install_desmume.sh \
    && /component/scripts/install_wrapper.sh \
    && apt-get install -y --no-install-recommends expect \
    && rm -rf /var/lib/apt/lists/*

COPY --chmod=755 entrypoint.sh /entrypoint.sh

RUN useradd --create-home --uid 1000 --shell /bin/bash desmume
USER desmume
# Configuration of DeSmuME (controls, HUD...) and recently used files
RUN mkdir -p /home/desmume/.config/desmume /home/desmume/.local/share

EXPOSE 1024

ENTRYPOINT ["/entrypoint.sh"]
CMD []

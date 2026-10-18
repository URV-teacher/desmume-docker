FROM ubuntu:22.04 AS build

ENV DEBIAN_FRONTEND=noninteractive

# Rebuild the distro DeSmuME 0.9.11 package (keeping its patches) with HUD support,
# which the stock package is compiled without
RUN sed -i 's/^# deb-src/deb-src/' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends dpkg-dev devscripts libagg-dev && \
    apt-get build-dep -y desmume && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build
RUN apt-get update && \
    apt-get source desmume && \
    rm -rf /var/lib/apt/lists/* && \
    cd desmume-* && \
    sed -i 's/--enable-gdb-stub \\/--enable-gdb-stub --enable-hud \\/' debian/rules && \
    grep -q -- '--enable-hud' debian/rules && \
    # libagg >= 2.6 dropped comp_op_minus/comp_op_contrast; DeSmuME's HUD code never uses them
    sed -i '/agg::comp_op_minus\|agg::comp_op_contrast/d' src/agg2d.h && \
    dpkg-buildpackage -b -uc -us -j"$(nproc)" && \
    mv ../desmume_*.deb /build/desmume.deb


FROM ubuntu:22.04 AS runtime

# Prevent interactive prompts during apt install
ENV DEBIAN_FRONTEND=noninteractive

# Runtime packages of desmume and x11 and VNC utilites
RUN apt-get update && apt-get install -y --no-install-recommends \
    libsdl2-dev \
    libpcap-dev \
    libgtk2.0-dev \
    libopenal-dev \
    libsoundtouch-dev \
    libagg-dev \
    libosmesa6-dev \
    x11vnc \
    xvfb \
    expect \
    python3 \
    less && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# DeSmuME built with HUD support (see build stage); apt pulls its runtime dependencies
COPY --from=build /build/desmume.deb /tmp/desmume.deb
RUN apt-get update && apt-get install --install-recommends -y \
    /tmp/desmume.deb && \
    rm /tmp/desmume.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p ~/.vnc && \
    touch ~/.vnc/passwd && \
    x11vnc -storepasswd "devopsil" ~/.vnc/passwd

# Change to use custom entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Default DeSmuME config (Windows desmume.ini format), translated to the GTK config by the entrypoint
COPY config/desmume.ini /usr/share/desmume-docker/desmume.ini
COPY scripts/desmume-ini2gtk.py /usr/local/bin/desmume-ini2gtk
RUN chmod +x /usr/local/bin/desmume-ini2gtk

RUN export uid=1000 gid=1000 username=desmume && \
    mkdir -p /home/${username} && \
    mkdir -p /etc/sudoers.d/ && \
    echo "${username}:x:${uid}:${gid}:${username},,,:/home/${username}:/bin/bash" >> /etc/passwd && \
    echo "${username}:x:${uid}:" >> /etc/group && \
    echo "${username} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${username} && \
    chmod 0440 /etc/sudoers.d/${username} && \
    chown ${uid}:${gid} -R /home/${username}

EXPOSE 1024

USER desmume
ENV HOME=/home/desmume
ENV PATH="${PATH}:/usr/games"
# To allow the save of recently used
RUN mkdir -p /home/desmume/.local/share
# Use config file
RUN mkdir -p /home/desmume/.config/desmume

ENTRYPOINT ["/entrypoint.sh"]
CMD []
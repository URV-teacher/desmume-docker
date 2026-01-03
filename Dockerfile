FROM ubuntu:24.04 AS runtime

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
    desmume-gtk && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*


RUN apt-get update && apt-get install -y --no-install-recommends \
    expect \
    less && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p ~/.vnc && \
    touch ~/.vnc/passwd && \
    x11vnc -storepasswd "devopsil" ~/.vnc/passwd

# Change to use custom entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

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
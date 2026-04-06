# Stage 1: Build jauto (Java UI automation agent)
FROM eclipse-temurin:22-jammy@sha256:51a01c283e948409830df6f9a7d16bff971a371eff75274c0941524803c8d445 AS jauto_build
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl cmake gcc g++ make libc-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
ENV JAUTO_VER=1.0.0
RUN curl -L https://github.com/heshiming/jauto/archive/refs/tags/v$JAUTO_VER.tar.gz -o /tmp/jauto.tar.gz
WORKDIR /tmp
RUN tar xfz jauto.tar.gz && \
    mkdir jauto_build && \
    cd jauto_build && \
    cmake ../jauto-$JAUTO_VER && \
    cmake --build .

# Stage 2: Build show_text utility
FROM debian:bookworm-slim@sha256:8af0e5095f9964007f5ebd11191dfe52dcb51bf3afa2c07f055fc5451b78ba0e AS util_build
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc libx11-dev libc-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
ADD utils /tmp/utils
WORKDIR /tmp/utils
RUN gcc show_text.c -O2 -lX11 -o show_text

# Stage 3: Download IB Gateway installer at build time (not runtime)
FROM debian:bookworm-slim@sha256:8af0e5095f9964007f5ebd11191dfe52dcb51bf3afa2c07f055fc5451b78ba0e AS ibg_download
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
ARG IBG_ARCH=x64
RUN curl -L "https://download2.interactivebrokers.com/installers/ibgateway/latest-standalone/ibgateway-latest-standalone-linux-${IBG_ARCH}.sh" \
    -o /tmp/ibgateway.sh && \
    chmod +x /tmp/ibgateway.sh

# Stage 4: Final image
FROM debian:bookworm-slim@sha256:8af0e5095f9964007f5ebd11191dfe52dcb51bf3afa2c07f055fc5451b78ba0e
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl ed xvfb x11vnc x11-utils xdotool python3-websockify procps xfonts-scalable tzdata oathtool && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
RUN useradd -ms /bin/bash -u 2000 ibg
WORKDIR /opt
RUN curl -L "https://github.com/novnc/noVNC/archive/refs/tags/v1.3.0.tar.gz" -o novnc.tar.gz && \
    tar xfz novnc.tar.gz && \
    rm novnc.tar.gz && \
    chown -R ibg:ibg /opt/noVNC-1.3.0
# Create pid/log directories writable by ibg
RUN mkdir -p /var/run /var/log && \
    chown ibg:ibg /var/run /var/log
# Set permissions before switching to ibg
COPY --from=util_build /tmp/utils/show_text /bin
COPY --from=jauto_build /tmp/jauto_build/jauto.so /opt
RUN chmod a+rx /bin/show_text && \
    chmod a+rx /opt/jauto.so
COPY --from=ibg_download /tmp/ibgateway.sh /tmp/ibgateway.sh
# Install IB Gateway at build time — no runtime download or install needed
RUN cd /home/ibg && \
    printf '/home/ibg/Jts/ibgateway\n\n' | DISPLAY="" /tmp/ibgateway.sh && \
    rm /tmp/ibgateway.sh
ADD scripts /opt/ibga/
RUN chmod a+rx /opt/ibga/* && \
    mkdir -p /home/ibg_settings && \
    chown -R ibg:ibg /home/ibg /home/ibg_settings
# Patch ibgateway.vmoptions for jauto
RUN echo "-agentpath:/opt/jauto.so=/tmp/ibg-jauto.in" >> /home/ibg/Jts/ibgateway/ibgateway.vmoptions
USER ibg
WORKDIR /home/ibg
# IB Gateway API port: 4001 for Live Trading, 4002 for Paper Trading
EXPOSE 4001/tcp 4002/tcp
ENTRYPOINT ["/opt/ibga/manager.sh"]

# Containerfile for RMS (Raspberry Pi Meteor Station)
# Build:  podman build -t rms -f Containerfile .
# Run:    podman run -it --rm \
#           -v ./RMS_data:/home/rms/RMS_data:Z \
#           -v ./.config:/home/rms/source/RMS/.config:Z \
#           --device /dev/video0 \
#           rms
#
# For IP cameras no --device flag is needed, just configure the RTSP URL
# in your .config file.
#
# To start capture:
#   podman run -d --name rms-capture \
#     -v ./RMS_data:/home/rms/RMS_data:Z \
#     -v ./.config:/home/rms/source/RMS/.config:Z \
#     rms python -m RMS.StartCapture
#
# To run interactively:
#   podman run -it --rm \
#     -v ./RMS_data:/home/rms/RMS_data:Z \
#     -v ./.config:/home/rms/source/RMS/.config:Z \
#     rms bash

FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=C.UTF-8

# System packages (mirrors RMS_Installer.sh)
RUN apt-get update && apt-get install -y --no-install-recommends \
        git wget zip ca-certificates \
        python3 python3-dev python3-pip python3-venv python3-tk python3-pil \
        mplayer socat chrony \
        imagemagick ffmpeg \
        python3-gi python3-gi-cairo \
        gir1.2-gstreamer-1.0 \
        gstreamer1.0-tools \
        gstreamer1.0-plugins-base \
        gstreamer1.0-plugins-good \
        gstreamer1.0-plugins-bad \
        gstreamer1.0-plugins-ugly \
        gstreamer1.0-libav \
        python3-opencv \
        python3-pyqt5 \
        build-essential g++ \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install gstreamer python plugin loader if available
RUN apt-get update \
    && apt-get install -y --no-install-recommends gstreamer1.0-python3-plugin-loader 2>/dev/null || true \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN ln -sf /usr/share/zoneinfo/UTC /etc/localtime \
    && echo "UTC" > /etc/timezone

RUN useradd -m -s /bin/bash rms
USER rms
WORKDIR /home/rms

RUN mkdir -p /home/rms/source
COPY --chown=rms:rms . /home/rms/source/RMS

# Set up Python virtual environment with system site-packages
RUN python3 -m venv --system-site-packages /home/rms/vRMS
ENV PATH="/home/rms/vRMS/bin:${PATH}"
ENV VIRTUAL_ENV="/home/rms/vRMS"

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip setuptools wheel \
    && pip install --no-cache-dir -r /home/rms/source/RMS/requirements.txt

# Install RMS as editable package
WORKDIR /home/rms/source/RMS
RUN pip install --no-cache-dir -e . --no-deps --no-build-isolation

RUN mkdir -p /home/rms/RMS_data

WORKDIR /home/rms/source/RMS


ENTRYPOINT ["python", "-m", "RMS.StartCapture"]

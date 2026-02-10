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

# ═══════════════════════════════════════════════════════════════════════════════
#  Stage 1: Builder — compile wheels for all Python dependencies
# ═══════════════════════════════════════════════════════════════════════════════
FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8

# Build-time system packages (compilers, headers, git for VCS deps)
RUN apt-get update && apt-get install -y --no-install-recommends \
        git ca-certificates \
        python3 python3-dev python3-pip python3-venv \
        build-essential g++ gfortran \
        libopenblas-dev liblapack-dev \
        pkg-config \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /tmp/requirements.txt

# Build all wheels into /tmp/wheels
RUN python3 -m pip wheel --no-cache-dir --wheel-dir /tmp/wheels \
        -r /tmp/requirements.txt

# Build a wheel for RMS itself
COPY . /tmp/RMS
RUN cd /tmp/RMS \
    && python3 -m pip wheel --no-cache-dir --no-deps --no-build-isolation \
        --wheel-dir /tmp/wheels .

# ═══════════════════════════════════════════════════════════════════════════════
#  Stage 2: Runtime — minimal image with only runtime dependencies
# ═══════════════════════════════════════════════════════════════════════════════
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=C.UTF-8

# Runtime-only system packages (no compilers, no -dev headers)
RUN apt-get update && apt-get install -y --no-install-recommends \
        git wget zip ca-certificates \
        python3 python3-pip python3-venv python3-tk python3-pil \
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
        libopenblas0 liblapack3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install gstreamer python plugin loader if available
RUN apt-get update \
    && apt-get install -y --no-install-recommends gstreamer1.0-python3-plugin-loader 2>/dev/null || true \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── Set timezone to UTC ─────────────────────────────────────────────────────
RUN ln -sf /usr/share/zoneinfo/UTC /etc/localtime \
    && echo "UTC" > /etc/timezone

# ── Create non-root user ────────────────────────────────────────────────────
RUN useradd -m -s /bin/bash rms
USER rms
WORKDIR /home/rms

# ── Copy source code ────────────────────────────────────────────────────────
RUN mkdir -p /home/rms/source
COPY --chown=rms:rms . /home/rms/source/RMS

# ── Set up Python virtual environment with system site-packages ──────────────
RUN python3 -m venv --system-site-packages /home/rms/vRMS
ENV PATH="/home/rms/vRMS/bin:$PATH" \
    VIRTUAL_ENV="/home/rms/vRMS"

# ── Install pre-built wheels from builder stage ─────────────────────────────
COPY --from=builder /tmp/wheels /tmp/wheels
RUN pip install --no-cache-dir --upgrade pip setuptools wheel \
    && pip install --no-cache-dir --no-deps /tmp/wheels/*.whl \
    && rm -rf /tmp/wheels

# ── Create data directory ───────────────────────────────────────────────────
RUN mkdir -p /home/rms/RMS_data

WORKDIR /home/rms/source/RMS

ENTRYPOINT ["python", "-m", "RMS.StartCapture"]


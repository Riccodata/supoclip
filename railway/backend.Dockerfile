# Railway build of the SupoClip backend: the FastAPI API and the arq worker run
# in one container because a Railway volume can only attach to one service, and
# both processes need the same uploads/clips storage.
# Build context is the repository root.
FROM python:3.11-slim

# Install system dependencies including ffmpeg and unzip (for deno).
# fonts-noto-color-emoji lets libass render colour emojis in burned captions.
RUN apt-get update && apt-get install -y \
    ffmpeg \
    curl \
    unzip \
    fonts-noto-color-emoji \
    fontconfig \
    && fc-cache -f \
    && rm -rf /var/lib/apt/lists/*

# Install deno (required by yt-dlp for YouTube JS challenge solving)
RUN curl -fsSL https://deno.land/install.sh | sh
ENV DENO_DIR=/root/.deno
ENV PATH="/root/.deno/bin:${PATH}"

RUN pip install uv

WORKDIR /app

COPY backend/pyproject.toml backend/uv.lock ./

# Railway has no GPUs, so default to CPU-only Torch wheels.
ARG BACKEND_CPU_ONLY=true
RUN uv venv .venv && \
    if [ "$BACKEND_CPU_ONLY" = "true" ]; then \
      uv sync --frozen --extra cpu; \
    else \
      uv sync --frozen --extra cuda; \
    fi

# Force update yt-dlp to the latest version to handle YouTube API changes
RUN uv pip install --upgrade --force-reinstall "yt-dlp[default]"

COPY backend/src/ ./src/
COPY backend/fonts/ ./fonts/
COPY backend/transitions/ ./transitions/

# Railway's managed Postgres can't run init.sql on first boot the way the
# docker-compose Postgres does, so the start script applies it instead.
COPY init.sql railway/bootstrap_db.py railway/backend-start.sh ./railway/

RUN mkdir -p /app/logs

ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1

EXPOSE 8000

CMD ["bash", "/app/railway/backend-start.sh"]

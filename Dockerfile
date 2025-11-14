# syntax=docker/dockerfile:1
FROM node:20-slim AS frontend-build
WORKDIR /build

# Increase memory for Node
ENV NODE_OPTIONS="--max-old-space-size=2048"

COPY frontend/package.json frontend/yarn.lock ./
RUN yarn install --pure-lockfile --network-timeout 300000 --ignore-engines
COPY frontend/ .
RUN yarn run build


FROM python:3.10-slim as django-build

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gettext \
    gcc \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app/

# Install Python dependencies with pip cache to speed up and reduce memory
COPY backend/requirements.txt /app/backend/requirements.txt
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r /app/backend/requirements.txt

# Copy application code
COPY . /app/

# Copy compiled frontend assets
COPY --from=frontend-build /build/dist /app/frontend/dist

# Collect static files and compile messages
RUN python manage.py collectstatic --noinput --ignore=node_modules && \
    python manage.py compilemessages

# Runtime configuration
ENV PORT=80 \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

CMD uwsgi --http=0.0.0.0:$PORT --module=backend.wsgi --master --workers=4 --max-requests=5000 --max-requests-delta=1000 --lazy-apps --need-app --http-keepalive --harakiri 65 --vacuum --strict --single-interpreter --die-on-term --disable-logging --log-4xx --log-5xx --cheaper=2 --enable-threads --ignore-sigpipe --ignore-write-errors
# Optimizations:
# --max-requests=5000 with delta=1000: Improved worker recycling to prevent memory leaks
# --ignore-sigpipe --ignore-write-errors: Better handling of client disconnections
# --lazy-apps: Load app after fork for better memory efficiency
# --cheaper=2: Dynamic worker spawning for resource optimization

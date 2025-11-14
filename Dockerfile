# syntax=docker/dockerfile:1
# Build from pre-compiled frontend assets
FROM python:3.10-slim as django-build

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gettext \
    gcc \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app/

# Install Python dependencies
COPY backend/requirements.txt /app/backend/requirements.txt
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r /app/backend/requirements.txt

# Copy application code
COPY . /app/

# Copy pre-built frontend assets (build locally first!)
# If frontend/dist doesn't exist, create empty dir
RUN mkdir -p /app/frontend/dist

# Collect static files and compile messages
RUN python manage.py collectstatic --noinput --ignore=node_modules && \
    python manage.py compilemessages

# Runtime configuration
ENV PORT=80 \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

CMD uwsgi --http=0.0.0.0:$PORT --module=backend.wsgi --master --workers=2 --max-requests=5000 --max-requests-delta=1000 --lazy-apps --need-app --http-keepalive --harakiri 65 --vacuum --strict --single-interpreter --die-on-term --disable-logging --log-4xx --log-5xx --cheaper=1 --enable-threads --ignore-sigpipe --ignore-write-errors

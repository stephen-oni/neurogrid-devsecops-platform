# using multi staging to reduce the image and remove unwanted OS 
FROM python:3.11-alpine AS builder

# Prevent bytecode generation & enable immediate log output
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Install minimal build dependencies to comlie the images.
RUN apk update && \
    apk add --no-cache gcc musl-dev libffi-dev

# Build Python in isolated place.
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt



# the second one

FROM python:3.11-alpine

# Python runtime optimization flags
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/usr/local/bin:$PATH"

WORKDIR /app

# Create unprivileged app user & group
RUN addgroup -g 1001 appgroup && \
    adduser -u 1001 -G appgroup -D -s /bin/sh appuser

# 3. Copy only compiled Python libraries from the first stage
COPY --from=builder /install /usr/local

# 4. Copy application source code with correct ownership
COPY --chown=appuser:appgroup . .

# 5. Drop root privileges
USER 1001:1001

# 6. Container networking
EXPOSE 5000

# 7. Run production WSGI server
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--threads", "2", "--timeout", "60", "app:app"]
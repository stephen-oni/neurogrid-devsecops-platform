# 1. Base Image i am uisng the slim version.
FROM python:3.10-slim

# 2. Set environment variables to optimize Python for Docker
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# 3. Working Directory
WORKDIR /app

# 4. Install dependencies first
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 5. Copy application source code to the host manchine
COPY . .

# 6. Create and switch to non root or remove it if not needed
RUN useradd -m -u 1001 appuser && chown -R appuser:appuser /app
USER appuser

# 7. Exposing Flask Port
EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--threads", "2", "--timeout", "60", "app:app"]
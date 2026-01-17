FROM python:3.12-slim

WORKDIR /app
COPY api/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY api/main.py .
COPY api/web.py .

# Copy frontend (served by FastAPI StaticFiles)
COPY web ./web

EXPOSE 8000
ENV APP_VERSION=dev
CMD ["uvicorn","main:app","--host","0.0.0.0","--port","8000"]

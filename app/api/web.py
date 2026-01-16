from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

def mount_web(app: FastAPI) -> None:
    """Serve the frontend at /"""
    app.mount("/", StaticFiles(directory="web", html=True), name="web")
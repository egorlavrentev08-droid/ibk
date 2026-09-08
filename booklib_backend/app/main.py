from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from app.database import engine, Base
import app.models
from app.routers import auth, books, chapters, rating, dev, uploads
import os

# Создаём таблицы
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Interactive BookLib API",
    description="Приватная библиотека для друзей",
    version="0.2.0"
)

# Настройка CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Папка для статических файлов (обложки, обои)
UPLOAD_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

# Подключаем роутеры
app.include_router(auth.router)
app.include_router(books.router)
app.include_router(chapters.router)
app.include_router(rating.router)
app.include_router(dev.router)
app.include_router(uploads.router)

# Монтируем статические файлы (доступ к обложкам и обоям)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

@app.get("/")
async def root():
    return {"message": "Interactive BookLib API работает!"}

@app.get("/health")
async def health():
    return {"status": "ok"}
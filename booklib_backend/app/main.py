from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.database import engine, Base
import app.models
from app.routers import auth, books, chapters, rating, dev

# Создаём таблицы
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Interactive BookLib API",
    description="Приватная библиотека для друзей",
    version="0.1.0"
)

# Настройка CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Разрешаем все источники для разработки
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Подключаем роутеры
app.include_router(auth.router)
app.include_router(books.router)
app.include_router(chapters.router)
app.include_router(rating.router)
app.include_router(dev.router)

@app.get("/")
async def root():
    return {"message": "Interactive BookLib API работает!"}

@app.get("/health")
async def health():
    return {"status": "ok"}
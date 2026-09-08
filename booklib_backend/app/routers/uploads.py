from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.user import User
from app.services.auth_dependencies import get_current_user
import os
import shutil
from datetime import datetime

router = APIRouter(prefix="/uploads", tags=["uploads"])

# Папка для хранения загруженных файлов
UPLOAD_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "uploads")

# Создаём папку, если её нет
os.makedirs(UPLOAD_DIR, exist_ok=True)

# Разрешённые расширения
ALLOWED_EXTENSIONS = {'.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp', '.svg'}

@router.post("/image")
async def upload_image(
    file: UploadFile = File(...),
    user: User = Depends(get_current_user)
):
    """Загрузка изображения (обложка книги или обои главы)"""
    
    # Получаем имя файла
    filename = file.filename or "image.png"
    
    # Получаем расширение файла
    file_extension = os.path.splitext(filename)[1].lower()
    
    # Если расширения нет — пробуем определить из content_type
    if not file_extension:
        if file.content_type == "image/png":
            file_extension = ".png"
        elif file.content_type == "image/jpeg":
            file_extension = ".jpg"
        elif file.content_type == "image/gif":
            file_extension = ".gif"
        elif file.content_type == "image/webp":
            file_extension = ".webp"
        elif file.content_type == "image/bmp":
            file_extension = ".bmp"
        elif file.content_type == "image/svg+xml":
            file_extension = ".svg"
        else:
            file_extension = ".png"  # По умолчанию
    
    # Проверяем расширение
    if file_extension not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Неподдерживаемый формат: {file_extension}. Разрешённые: {', '.join(ALLOWED_EXTENSIONS)}"
        )
    
    # Читаем содержимое
    content = await file.read()
    
    # Проверяем размер файла (максимум 10 МБ)
    if len(content) > 10 * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Файл слишком большой (максимум 10 МБ)"
        )
    
    # Проверяем, что файл не пустой
    if len(content) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Файл пустой"
        )
    
    # Создаём уникальное имя файла
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    unique_filename = f"{timestamp}_{user.id}{file_extension}"
    file_path = os.path.join(UPLOAD_DIR, unique_filename)
    
    # Сохраняем файл
    with open(file_path, "wb") as f:
        f.write(content)
    
    # Возвращаем URL для доступа к файлу
    return {
        "filename": unique_filename,
        "url": f"/uploads/{unique_filename}",
        "content_type": file.content_type or "image/png",
        "size": len(content)
    }
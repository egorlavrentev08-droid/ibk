from fastapi import APIRouter, Depends, HTTPException, status, Header
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime

from app.database import get_db
from app.models.user import User, UserRank
from app.models.book import Book
from app.models.chapter import Chapter
from app.services.auth_service import decode_access_token

router = APIRouter(prefix="/chapters", tags=["chapters"])

# Схемы
class ChapterCreate(BaseModel):
    book_id: int
    title: str
    content: str
    background_image: Optional[str] = None
    order_number: int

class ChapterResponse(BaseModel):
    id: int
    book_id: int
    title: str
    content: str
    background_image: Optional[str]
    order_number: int
    created_at: datetime
    
    class Config:
        from_attributes = True

# Функция для получения текущего пользователя
def get_current_user(authorization: str = Header(None), db: Session = Depends(get_db)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Требуется авторизация"
        )
    
    token = authorization.replace("Bearer ", "")
    payload = decode_access_token(token)
    
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Недействительный токен"
        )
    
    user_id = payload.get("user_id")
    user = db.query(User).filter(User.id == user_id).first()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Пользователь не найден"
        )
    
    return user

@router.post("/", response_model=ChapterResponse)
async def create_chapter(
    chapter_data: ChapterCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Создание новой главы (только автор книги)"""
    # Проверяем, существует ли книга
    book = db.query(Book).filter(Book.id == chapter_data.book_id).first()
    if not book:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Книга не найдена"
        )
    
    # Проверяем, является ли пользователь автором
    if book.author_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Только автор может добавлять главы"
        )
    
    # Проверяем, нет ли уже главы с таким порядковым номером
    existing_chapter = db.query(Chapter).filter(
        Chapter.book_id == chapter_data.book_id,
        Chapter.order_number == chapter_data.order_number
    ).first()
    
    if existing_chapter:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Глава с таким номером уже существует"
        )
    
    chapter = Chapter(
        book_id=chapter_data.book_id,
        title=chapter_data.title,
        content=chapter_data.content,
        background_image=chapter_data.background_image,
        order_number=chapter_data.order_number
    )
    
    db.add(chapter)
    db.commit()
    db.refresh(chapter)
    
    return chapter

@router.get("/book/{book_id}", response_model=List[ChapterResponse])
async def get_book_chapters(book_id: int, db: Session = Depends(get_db)):
    """Получение всех глав книги"""
    book = db.query(Book).filter(Book.id == book_id).first()
    if not book:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Книга не найдена"
        )
    
    chapters = db.query(Chapter).filter(Chapter.book_id == book_id).order_by(Chapter.order_number).all()
    return chapters

@router.get("/{chapter_id}", response_model=ChapterResponse)
async def get_chapter(chapter_id: int, db: Session = Depends(get_db)):
    """Получение конкретной главы по ID"""
    chapter = db.query(Chapter).filter(Chapter.id == chapter_id).first()
    if not chapter:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Глава не найдена"
        )
    return chapter

@router.put("/{chapter_id}", response_model=ChapterResponse)
async def update_chapter(
    chapter_id: int,
    chapter_data: ChapterCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Обновление главы (только автор книги)"""
    chapter = db.query(Chapter).filter(Chapter.id == chapter_id).first()
    if not chapter:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Глава не найдена"
        )
    
    book = db.query(Book).filter(Book.id == chapter.book_id).first()
    if book.author_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Только автор может редактировать главы"
        )
    
    chapter.title = chapter_data.title
    chapter.content = chapter_data.content
    chapter.background_image = chapter_data.background_image
    chapter.order_number = chapter_data.order_number
    
    db.commit()
    db.refresh(chapter)
    
    return chapter

@router.delete("/{chapter_id}")
async def delete_chapter(
    chapter_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Удаление главы (только автор книги)"""
    chapter = db.query(Chapter).filter(Chapter.id == chapter_id).first()
    if not chapter:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Глава не найдена"
        )
    
    book = db.query(Book).filter(Book.id == chapter.book_id).first()
    if book.author_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Только автор может удалять главы"
        )
    
    db.delete(chapter)
    db.commit()
    
    return {"message": "Глава удалена"}  

from fastapi import APIRouter, Depends, HTTPException, status, Header
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime

from app.database import get_db
from app.models.user import User, UserRank
from app.models.book import Book
from app.services.auth_dependencies import get_current_user

router = APIRouter(prefix="/books", tags=["books"])

# Схемы
class BookCreate(BaseModel):
    title: str
    description: str = ""
    cover_image: Optional[str] = None
    is_restricted: bool = False

class BookUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    cover_image: Optional[str] = None
    is_restricted: Optional[bool] = None

class BookResponse(BaseModel):
    id: int
    title: str
    description: str
    cover_image: Optional[str]
    is_restricted: bool
    author_id: int
    created_at: datetime
    
    class Config:
        from_attributes = True

@router.post("/", response_model=BookResponse)
async def create_book(
    book_data: BookCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Создание новой книги (только для писателей и выше)"""
    if user.rank not in [UserRank.WRITER, UserRank.CREATOR, UserRank.SUPREME]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Только писатели могут создавать книги"
        )
    
    book = Book(
        title=book_data.title,
        description=book_data.description,
        cover_image=book_data.cover_image,
        is_restricted=book_data.is_restricted,
        author_id=user.id
    )
    
    db.add(book)
    db.commit()
    db.refresh(book)
    
    return book

@router.get("/", response_model=List[BookResponse])
async def get_all_books(db: Session = Depends(get_db)):
    """Получение списка всех книг"""
    books = db.query(Book).all()
    return books

@router.get("/{book_id}", response_model=BookResponse)
async def get_book(book_id: int, db: Session = Depends(get_db)):
    """Получение конкретной книги по ID"""
    book = db.query(Book).filter(Book.id == book_id).first()
    if not book:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Книга не найдена"
        )
    return book

@router.put("/{book_id}", response_model=BookResponse)
async def update_book(
    book_id: int,
    book_data: BookUpdate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Обновление книги (только автор)"""
    book = db.query(Book).filter(Book.id == book_id).first()
    if not book:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Книга не найдена"
        )
    
    if book.author_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Только автор может редактировать книгу"
        )
    
    if book_data.title is not None:
        book.title = book_data.title
    if book_data.description is not None:
        book.description = book_data.description
    if book_data.cover_image is not None:
        book.cover_image = book_data.cover_image
    if book_data.is_restricted is not None:
        book.is_restricted = book_data.is_restricted
    
    db.commit()
    db.refresh(book)
    
    return book

@router.delete("/{book_id}")
async def delete_book(
    book_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Удаление книги (только автор)"""
    book = db.query(Book).filter(Book.id == book_id).first()
    if not book:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Книга не найдена"
        )
    
    if book.author_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Только автор может удалить книгу"
        )
    
    db.delete(book)
    db.commit()
    
    return {"message": "Книга удалена"}
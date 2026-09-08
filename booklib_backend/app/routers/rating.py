from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime, timedelta

from app.database import get_db
from app.models.user import User
from app.models.book import Book
from app.models.rating import Rating
from app.models.review_vote import ReviewVote
from app.services.auth_dependencies import get_current_user

router = APIRouter(prefix="/ratings", tags=["ratings"])

# Схемы
class RatingCreate(BaseModel):
    book_id: int
    stars: int
    review: Optional[str] = None
    is_anonymous: bool = False

class RatingUpdate(BaseModel):
    stars: Optional[int] = None
    review: Optional[str] = None
    is_anonymous: Optional[bool] = None

class RatingResponse(BaseModel):
    id: int
    book_id: int
    user_id: int
    stars: int
    review: Optional[str]
    is_anonymous: bool
    created_at: datetime
    updated_at: Optional[datetime]
    likes: int
    dislikes: int
    
    class Config:
        from_attributes = True

@router.post("/", response_model=RatingResponse)
async def create_rating(
    rating_data: RatingCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Создание оценки и отзыва"""
    if rating_data.stars < 1 or rating_data.stars > 5:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Оценка должна быть от 1 до 5"
        )
    
    if rating_data.review and len(rating_data.review) > 300:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Отзыв не может быть длиннее 300 символов"
        )
    
    book = db.query(Book).filter(Book.id == rating_data.book_id).first()
    if not book:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Книга не найдена"
        )
    
    existing_rating = db.query(Rating).filter(
        Rating.book_id == rating_data.book_id,
        Rating.user_id == user.id
    ).first()
    
    if existing_rating:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Вы уже оставляли оценку для этой книги"
        )
    
    rating = Rating(
        book_id=rating_data.book_id,
        user_id=user.id,
        stars=rating_data.stars,
        review=rating_data.review,
        is_anonymous=rating_data.is_anonymous,
        last_stars_change=datetime.utcnow(),
        last_review_change=datetime.utcnow(),
        likes=0,
        dislikes=0
    )
    
    db.add(rating)
    db.commit()
    db.refresh(rating)
    
    return rating

@router.put("/{rating_id}", response_model=RatingResponse)
async def update_rating(
    rating_id: int,
    rating_data: RatingUpdate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Обновление оценки или отзыва с ограничениями"""
    rating = db.query(Rating).filter(Rating.id == rating_id).first()
    if not rating:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Оценка не найдена"
        )
    
    if rating.user_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Вы можете редактировать только свои оценки"
        )
    
    now = datetime.utcnow()
    
    # Обновление звёзд
    if rating_data.stars is not None:
        if rating_data.stars < 1 or rating_data.stars > 5:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Оценка должна быть от 1 до 5"
            )
        
        # Проверяем, прошла ли неделя с последнего изменения звёзд
        if rating.last_stars_change:
            week_ago = now - timedelta(days=7)
            if rating.last_stars_change > week_ago:
                days_left = 7 - (now - rating.last_stars_change).days
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Менять звёзды можно раз в неделю. Осталось дней: {days_left}"
                )
        
        # Проверяем разницу в звёздах
        stars_diff = abs(rating_data.stars - rating.stars)
        if stars_diff > 2:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Нельзя изменить оценку более чем на 2 пункта"
            )
        
        rating.stars = rating_data.stars
        rating.last_stars_change = now
    
    # Обновление отзыва
    if rating_data.review is not None:
        if len(rating_data.review) > 300:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Отзыв не может быть длиннее 300 символов"
            )
        
        # Проверяем, прошла ли неделя с последнего изменения отзыва
        if rating.last_review_change:
            week_ago = now - timedelta(days=7)
            if rating.last_review_change > week_ago:
                days_left = 7 - (now - rating.last_review_change).days
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Менять отзыв можно раз в неделю. Осталось дней: {days_left}"
                )
        
        rating.review = rating_data.review
        rating.last_review_change = now
    
    # Обновление анонимности (без ограничений)
    if rating_data.is_anonymous is not None:
        rating.is_anonymous = rating_data.is_anonymous
    
    db.commit()
    db.refresh(rating)
    
    return rating

@router.get("/book/{book_id}", response_model=List[RatingResponse])
async def get_book_ratings(book_id: int, db: Session = Depends(get_db)):
    """Получение всех оценок книги"""
    book = db.query(Book).filter(Book.id == book_id).first()
    if not book:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Книга не найдена"
        )
    
    ratings = db.query(Rating).filter(Rating.book_id == book_id).all()
    return ratings

@router.get("/book/{book_id}/average")
async def get_book_average_rating(book_id: int, db: Session = Depends(get_db)):
    """Получение среднего рейтинга книги"""
    book = db.query(Book).filter(Book.id == book_id).first()
    if not book:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Книга не найдена"
        )
    
    ratings = db.query(Rating).filter(Rating.book_id == book_id).all()
    if not ratings:
        return {"average": 0, "count": 0}
    
    average = sum(r.stars for r in ratings) / len(ratings)
    return {"average": round(average, 1), "count": len(ratings)}

@router.get("/book/{book_id}/reviews")
async def get_book_reviews(book_id: int, db: Session = Depends(get_db)):
    """Получение всех отзывов книги с лайками"""
    book = db.query(Book).filter(Book.id == book_id).first()
    if not book:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Книга не найдена"
        )
    
    ratings = db.query(Rating).filter(
        Rating.book_id == book_id,
        Rating.review.isnot(None)
    ).all()
    
    reviews = []
    for rating in ratings:
        user = db.query(User).filter(User.id == rating.user_id).first()
        reviews.append({
            "id": rating.id,
            "book_id": rating.book_id,
            "stars": rating.stars,
            "review": rating.review,
            "is_anonymous": rating.is_anonymous,
            "username": "Аноним" if rating.is_anonymous else (user.username if user else "Пользователь"),
            "likes": rating.likes,
            "dislikes": rating.dislikes,
            "created_at": rating.created_at
        })
    
    return reviews

@router.post("/{rating_id}/vote")
async def vote_review(
    rating_id: int,
    vote_type: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Лайк или дизлайк отзыва"""
    if vote_type not in ["like", "dislike"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Тип голоса должен быть 'like' или 'dislike'"
        )
    
    rating = db.query(Rating).filter(Rating.id == rating_id).first()
    if not rating:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Отзыв не найден"
        )
    
    # Проверяем, голосовал ли пользователь
    existing_vote = db.query(ReviewVote).filter(
        ReviewVote.rating_id == rating_id,
        ReviewVote.user_id == user.id
    ).first()
    
    is_like = vote_type == "like"
    
    if existing_vote:
        # Пользователь уже голосовал
        if existing_vote.is_like == is_like:
            # Повторный голос — убираем
            if is_like:
                rating.likes -= 1
            else:
                rating.dislikes -= 1
            db.delete(existing_vote)
        else:
            # Меняем голос
            if existing_vote.is_like:
                rating.likes -= 1
                rating.dislikes += 1
            else:
                rating.dislikes -= 1
                rating.likes += 1
            existing_vote.is_like = is_like
    else:
        # Новый голос
        vote = ReviewVote(
            rating_id=rating_id,
            user_id=user.id,
            is_like=is_like
        )
        db.add(vote)
        if is_like:
            rating.likes += 1
        else:
            rating.dislikes += 1
    
    db.commit()
    
    return {
        "likes": rating.likes,
        "dislikes": rating.dislikes
    }

@router.delete("/{rating_id}")
async def delete_rating(
    rating_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Удаление своей оценки"""
    rating = db.query(Rating).filter(Rating.id == rating_id).first()
    if not rating:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Оценка не найдена"
        )
    
    if rating.user_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Вы можете удалять только свои оценки"
        )
    
    db.delete(rating)
    db.commit()
    
    return {"message": "Оценка удалена"}
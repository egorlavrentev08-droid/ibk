from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel

from app.database import get_db
from app.models.user import User, UserRank

router = APIRouter(prefix="/dev", tags=["dev"])

# Схема для запроса
class ChangeRankRequest(BaseModel):
    username: str
    rank: str

@router.post("/change-rank")
async def change_rank(request: ChangeRankRequest, db: Session = Depends(get_db)):
    """Изменение ранга пользователя по логину (режим разработчика)"""
    # Проверяем, что ранг валидный
    valid_ranks = [r.value for r in UserRank]
    if request.rank not in valid_ranks:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Неверный ранг. Доступные: {', '.join(valid_ranks)}"
        )
    
    # Ищем пользователя
    user = db.query(User).filter(User.username == request.username).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Пользователь не найден"
        )
    
    # Меняем ранг
    old_rank = user.rank.value
    user.rank = UserRank(request.rank)
    db.commit()
    db.refresh(user)
    
    return {
        "message": f"Ранг пользователя {user.username} изменён",
        "old_rank": old_rank,
        "new_rank": user.rank.value
    }

@router.get("/users")
async def get_all_users(db: Session = Depends(get_db)):
    """Получение списка всех пользователей с рангами"""
    users = db.query(User).all()
    return [
        {
            "id": user.id,
            "username": user.username,
            "rank": user.rank.value,
            "created_at": user.created_at
        }
        for user in users
    ] 

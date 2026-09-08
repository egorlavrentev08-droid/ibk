from sqlalchemy import Column, Integer, String, DateTime, Enum
from sqlalchemy.sql import func
from app.database import Base
import enum

# Ранги пользователей
class UserRank(str, enum.Enum):
    GUEST = "Гость"
    READER = "Читатель"
    WRITER = "Писатель"
    CREATOR = "Творец"
    SUPREME = "Высший"

# Модель пользователя
class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    rank = Column(Enum(UserRank), default=UserRank.READER)
    created_at = Column(DateTime, server_default=func.now())
    
    def __repr__(self):
        return f"<User {self.username} ({self.rank.value})>"  

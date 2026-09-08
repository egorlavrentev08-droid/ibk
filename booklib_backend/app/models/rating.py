from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Float, Boolean
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base

class Rating(Base):
    __tablename__ = "ratings"

    id = Column(Integer, primary_key=True, index=True)
    book_id = Column(Integer, ForeignKey("books.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    stars = Column(Integer, nullable=False)  # От 1 до 5
    review = Column(String(300), nullable=True)  # Отзыв до 300 символов
    is_anonymous = Column(Boolean, default=False)  # Анонимный отзыв
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, onupdate=func.now())
    last_stars_change = Column(DateTime, nullable=True)
    last_review_change = Column(DateTime, nullable=True)
    likes = Column(Integer, default=0)  # Количество лайков
    dislikes = Column(Integer, default=0)  # Количество дизлайков
    
    # Связи
    book = relationship("Book", back_populates="ratings")
    user = relationship("User", backref="ratings")
    
    def __repr__(self):
        return f"<Rating {self.stars}★ for book {self.book_id}>"
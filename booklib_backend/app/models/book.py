from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Float
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base

class Book(Base):
    __tablename__ = "books"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    description = Column(String, default="")
    cover_image = Column(String, nullable=True)  # Путь к обложке
    is_restricted = Column(Boolean, default=False)  # Ограниченная книга
    author_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, server_default=func.now())
    
    # Связи
    author = relationship("User", backref="books")
    chapters = relationship("Chapter", back_populates="book", cascade="all, delete-orphan")
    ratings = relationship("Rating", back_populates="book", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<Book {self.title} by user {self.author_id}>"  

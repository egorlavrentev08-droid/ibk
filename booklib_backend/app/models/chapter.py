from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base

class Chapter(Base):
    __tablename__ = "chapters"

    id = Column(Integer, primary_key=True, index=True)
    book_id = Column(Integer, ForeignKey("books.id"), nullable=False)
    title = Column(String, nullable=False)
    content = Column(Text, nullable=False)
    background_image = Column(String, nullable=True)  # Путь к обоям
    order_number = Column(Integer, nullable=False)  # Порядковый номер главы
    created_at = Column(DateTime, server_default=func.now())
    
    # Связь с книгой
    book = relationship("Book", back_populates="chapters")
    
    def __repr__(self):
        return f"<Chapter {self.title} (book {self.book_id})>"  

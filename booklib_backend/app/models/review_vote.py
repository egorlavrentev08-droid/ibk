from sqlalchemy import Column, Integer, DateTime, ForeignKey, Boolean
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base

class ReviewVote(Base):
    __tablename__ = "review_votes"

    id = Column(Integer, primary_key=True, index=True)
    rating_id = Column(Integer, ForeignKey("ratings.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    is_like = Column(Boolean, nullable=True)  # True = лайк, False = дизлайк, None = удалён
    created_at = Column(DateTime, server_default=func.now())
    
    # Связи
    rating = relationship("Rating", backref="votes")
    user = relationship("User", backref="review_votes")
    
    def __repr__(self):
        return f"<ReviewVote {self.is_like} for rating {self.rating_id}>"
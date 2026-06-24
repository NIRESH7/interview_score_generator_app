import os
import random
from typing import List, Dict, Any
from fastapi import FastAPI, HTTPException, Body
from fastapi.middleware.cors import CORSMiddleware
from pymongo import MongoClient
from pydantic import BaseModel
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

app = FastAPI(title="FAANG Behavioral Interview Evaluator API")

# Configure CORS securely using regex to support random Flutter web ports
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)

# Connect to MongoDB
MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017")
client = MongoClient(MONGO_URI)
db = client["interview_db"]

# Pydantic models
class AnswerSubmission(BaseModel):
    question_id: int
    question: str
    theme: str
    company: str
    role_family: str
    role_track: str
    role_level: str
    answer: str

class AssessmentRequest(BaseModel):
    answers: List[AnswerSubmission]

@app.get("/api/v1/onboarding/options")
def get_onboarding_options():
    try:
        col = db["questions"]
        companies = sorted([c for c in col.distinct("companyApplicable") if c])
        role_families = sorted([r for r in col.distinct("roleFamily") if r])
        role_tracks = sorted([t for t in col.distinct("roleTrack") if t])
        role_levels = sorted([l for l in col.distinct("roleLevel") if l])
        
        # Ensure we have defaults if DB is empty
        if not companies:
            companies = ["Google", "Meta", "Amazon", "Microsoft", "General"]
        if not role_families:
            role_families = ["Engineering", "ProductManager", "DataScience/ML"]
        if not role_tracks:
            role_tracks = ["IC", "Manager"]
        if not role_levels:
            role_levels = ["Entry", "Senior", "Staff / Manager", "Sr. Staff / Sr. Manager"]
            
        return {
            "companies": companies,
            "role_families": role_families,
            "role_tracks": role_tracks,
            "role_levels": role_levels
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/v1/questions/filter")
def get_filtered_questions(
    company: str,
    role_family: str,
    role_level: str,
    role_track: str
):
    try:
        col = db["questions"]
        # Build query
        query = {
            "companyApplicable": company,
            "roleFamily": role_family,
            "roleLevel": role_level,
            "roleTrack": role_track
        }
        
        cursor = list(col.find(query))
        
        # If not enough questions found, fall back to "General" for the company and other criteria
        if len(cursor) < 3:
            query["companyApplicable"] = "General"
            cursor = list(col.find(query))
            
        # If still not enough, return random questions from the same role family
        if len(cursor) < 3:
            cursor = list(col.find({"roleFamily": role_family}))
            
        # Last resort fallback: all questions
        if len(cursor) < 3:
            cursor = list(col.find({}))
            
        if not cursor:
            raise HTTPException(status_code=404, detail="No questions found in database.")
            
        # Sort by assessmentQuestionNumber ascending
        cursor.sort(key=lambda x: x.get("assessmentQuestionNumber", 1))
        selected = cursor[:3]
        
        # Format response
        result = []
        for q in selected:
            result.append({
                "questionID": q["questionID"],
                "question": q["question"],
                "companyApplicable": q["companyApplicable"],
                "roleFamily": q["roleFamily"],
                "roleLevel": q["roleLevel"],
                "roleTrack": q["roleTrack"],
                "prepMode": q["prepMode"],
                "questionCompetency": q["questionCompetency"],
                "assessmentQuestionNumber": q.get("assessmentQuestionNumber", 1)
            })
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/v1/assessment/evaluate")
def evaluate_assessment(payload: AssessmentRequest):
    try:
        from app.services.evaluator_service import evaluate_answers
        results = evaluate_answers(payload.answers)
        return results
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

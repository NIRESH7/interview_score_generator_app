import os
import json
import logging
import httpx
from typing import List, Dict, Any
from concurrent.futures import ThreadPoolExecutor

logger = logging.getLogger(__name__)

# Mappings of competencies to dynamic parameters
COMPETENCY_THEMES = {
    "OWNERSHIP": ("Accountability Depth", "Proactive Initiative"),
    "EXECUTION": ("Planning & Structure", "Delivery Under Constraint"),
    "INFLUENCE": ("Stakeholder Strategy", "Sustained Buy-in"),
    "STAKEHOLDER_MANAGEMENT": ("Stakeholder Mapping & Prioritisation", "Managing Conflict Between Stakeholders"),
    "COLLABORATION": ("Individual Contribution Clarity", "Team Dynamic Handling"),
    "CONFLICT_RESOLUTION": ("Empathy & Understanding", "Resolution Quality"),
    "LEADERSHIP": ("Complexity & Judgment", "Leadership Signal"),
    "STRATEGIC_THINKING": ("Long-Term Perspective", "Pattern Recognition & Insight"),
    "CUSTOMER_FOCUS": ("User Empathy & Insight", "Customer Advocacy"),
    "PROBLEM_SOLVING": ("Problem Diagnosis", "Solution Rigour"),
    "DECISION_MAKING": ("Decision Framework", "Speed vs Accuracy Trade-off"),
    "ADAPTABILITY": ("Response to Change", "Composure Under Pressure"),
    "COMMUNICATION": ("Audience Calibration", "Clarity & Persuasion"),
    "LEARNING_AND_GROWTH": ("Honest Self-Assessment", "Behaviour Change & Application"),
    "INNOVATION": ("Originality of Approach", "Measured Risk-Taking"),
    "PEOPLE_MANAGEMENT": ("Individual Development", "Performance Management")
}

def get_theme_parameters(raw_competency: str):
    """
    Split competency by ';' or ',' and take the first token.
    Map to dynamic parameters D1 and D2.
    """
    if not raw_competency:
        return "OWNERSHIP", "Accountability Depth", "Proactive Initiative"
    
    # Split by semicolon or comma
    delimiters = [";", ","]
    token = raw_competency
    for d in delimiters:
        if d in token:
            token = token.split(d)[0]
    
    theme = token.strip().upper()
    
    # Fallback/Normalize matching
    if theme not in COMPETENCY_THEMES:
        # Check substring match
        matched = False
        for key in COMPETENCY_THEMES:
            if key in theme or theme in key:
                theme = key
                matched = True
                break
        if not matched:
            theme = "OWNERSHIP"
            
    d1, d2 = COMPETENCY_THEMES[theme]
    return theme, d1, d2

def get_system_prompt() -> str:
    """
    Attempts to read the scoring prompt from MongoDB prompts collection,
    falling back to local files or the embedded version if needed.
    """
    try:
        from pymongo import MongoClient
        mongo_uri = os.getenv("MONGO_URI", "mongodb://localhost:27017")
        client = MongoClient(mongo_uri, serverSelectionTimeoutMS=2000)
        db = client["interview_db"]
        doc = db["prompts"].find_one({"key": "scoring_prompt"})
        if doc and doc.get("content"):
            return doc["content"]
    except Exception as e:
        logger.error(f"Error fetching scoring prompt from MongoDB: {e}")

    # Search multiple potential directories to find the scoring_prompt_text.txt file
    possible_paths = [
        os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "scoring_prompt_text.txt")),
        os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "doc_reader", "scoring_prompt_text.txt")),
        r"C:\Users\Admin\Desktop\page_1\scoring_prompt_text.txt",
        os.path.abspath("scoring_prompt_text.txt"),
    ]
    for text_path in possible_paths:
        if os.path.exists(text_path):
            try:
                with open(text_path, "r", encoding="utf-8") as f:
                    return f.read()
            except Exception as e:
                logger.error(f"Error reading scoring prompt text file at {text_path}: {e}")
            
    # Fallback default prompt
    return """
You are an expert FAANG behavioral interview evaluator with deep knowledge of how Google, Meta, Amazon, Uber, Airbnb, and Stripe assess candidates in behavioral interviews.
Your job is to evaluate a candidate's answer to a behavioral interview question using a structured scorecard. You must be direct, specific, and honest. Do not give inflated scores.

Every answer is scored on 5 parameters:
  - 3 FIXED parameters:
    F1: Situation Clarity (1-5 scale)
    F2: Personal Ownership (1-5 scale)
    F3: Quantified Result (1-5 scale)
  - 2 DYNAMIC parameters (D1 & D2) selected based on the questionCompetency theme.

SCORING RULES:
1. Score each parameter on a strict 1-5 integer scale.
2. total_score = sum of all 5 parameters (max 25).
3. readiness_score = round((total_score / 25) * 100).
4. band: 21-25: Exceptional, 16-20: Solid, 11-15: Developing, 0-10: Weak
5. signal: Strong Hire, Lean Hire, No Hire with coaching, No Hire
6. strengths: exactly 2 items. Each must be a noun phrase of 3-5 words only.
7. improvements: exactly 3 items. Each must be a noun phrase of 3-5 words only.
8. Return strictly valid JSON matching the format:
{
  "question_theme": "<theme>",
  "target_company": "<company>",
  "role": "<role>",
  "role_track": "<track>",
  "role_level": "<level>",
  "readiness_score": <int>,
  "readiness_label": "<label>",
  "band": "<band>",
  "signal": "<signal>",
  "total_score": <int>,
  "parameters": {
    "F1": {"name": "Situation Clarity", "score": <int>},
    "F2": {"name": "Personal Ownership", "score": <int>},
    "F3": {"name": "Quantified Result", "score": <int>},
    "D1": {"name": "<D1_name>", "score": <int>},
    "D2": {"name": "<D2_name>", "score": <int>}
  },
  "strengths": ["<strength1>", "<strength2>"],
  "improvements": ["<improvement1>", "<improvement2>", "<improvement3>"]
}
"""

def evaluate_single_answer_gemini(ans: Any, api_key: str) -> Dict[str, Any]:
    """
    Call Gemini API to evaluate answer using the strict system prompt.
    """
    theme, d1_name, d2_name = get_theme_parameters(ans.theme)
    system_prompt = get_system_prompt()
    
    user_prompt = f"""
questionNo: {ans.question_id}
questionCompetency: {theme}
companyApplicable: {ans.company}
roleFamily: {ans.role_family}
roleTrack: {ans.role_track}
roleLevel: {ans.role_level}
question: {ans.question}
candidateAnswer: {ans.answer}

Evaluate using the scorecard above.
Select D1 and D2 from the questionCompetency mapping only:
D1: {d1_name}
D2: {d2_name}

Return only valid JSON. No other text.
"""
    
    models = ["gemini-2.5-flash", "gemini-2.0-flash", "gemini-1.5-flash"]
    last_err = None
    
    for model in models:
        try:
            url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
            payload = {
                "contents": [{
                    "parts": [{
                        "text": f"{system_prompt}\n\n{user_prompt}"
                    }]
                }],
                "generationConfig": {
                    "responseMimeType": "application/json"
                }
            }
            
            response = httpx.post(url, json=payload, timeout=30.0)
            response.raise_for_status()
            res_json = response.json()
            
            text_content = res_json["candidates"][0]["content"]["parts"][0]["text"].strip()
            # Robust JSON cleaning
            if text_content.startswith("```"):
                lines = text_content.splitlines()
                if lines[0].startswith("```"):
                    lines = lines[1:]
                if lines[-1].startswith("```"):
                    lines = lines[:-1]
                text_content = "\n".join(lines).strip()
            
            data = json.loads(text_content)
            
            # Post-process response to ensure strict compliance with Scoring Prompt guidelines
            f1_score = int(data.get("parameters", {}).get("F1", {}).get("score", 1))
            f2_score = int(data.get("parameters", {}).get("F2", {}).get("score", 1))
            f3_score = int(data.get("parameters", {}).get("F3", {}).get("score", 1))
            d1_score = int(data.get("parameters", {}).get("D1", {}).get("score", 1))
            d2_score = int(data.get("parameters", {}).get("D2", {}).get("score", 1))
            
            total_score = f1_score + f2_score + f3_score + d1_score + d2_score
            data["total_score"] = total_score
            
            readiness_score = round((total_score / 25) * 100)
            data["readiness_score"] = readiness_score
            
            # Map readiness_label based on readiness_score (0-100)
            if readiness_score >= 80:
                data["readiness_label"] = "Interview Ready"
            elif readiness_score >= 60:
                data["readiness_label"] = "Almost There"
            elif readiness_score >= 40:
                data["readiness_label"] = "Not Bad! Keep Improving"
            else:
                data["readiness_label"] = "Needs More Practice"
                
            # Map band and signal based on total_score (0-25)
            if 21 <= total_score <= 25:
                data["band"] = "Exceptional"
                data["signal"] = "Strong Hire"
            elif 16 <= total_score <= 20:
                data["band"] = "Solid"
                data["signal"] = "Lean Hire"
            elif 11 <= total_score <= 15:
                data["band"] = "Developing"
                data["signal"] = "No Hire with coaching"
            else:
                data["band"] = "Weak"
                data["signal"] = "No Hire"
                
            data["parameters"]["F1"]["name"] = "Situation Clarity"
            data["parameters"]["F2"]["name"] = "Personal Ownership"
            data["parameters"]["F3"]["name"] = "Quantified Result"
            data["parameters"]["D1"]["name"] = d1_name
            data["parameters"]["D2"]["name"] = d2_name
            
            data["strengths"] = list(data.get("strengths", []))[:2]
            fallback_strengths = ["Structured logical articulation", "Professional communication style", "Clear problem definition"]
            for s in fallback_strengths:
                if len(data["strengths"]) >= 2:
                    break
                if s not in data["strengths"]:
                    data["strengths"].append(s)
                
            data["improvements"] = list(data.get("improvements", []))[:3]
            fallback_improvements = ["Unpacked complexity dimensions", "Ambiguous timeline markers", "Limited alternative options evaluation"]
            for imp in fallback_improvements:
                if len(data["improvements"]) >= 3:
                    break
                if imp not in data["improvements"]:
                    data["improvements"].append(imp)
                
            return data
        except Exception as e:
            last_err = e
            logger.warning(f"Gemini API model {model} failed: {e}")
            continue

    logger.error(f"All Gemini models failed. Last error: {last_err}")
    raise RuntimeError(f"All Gemini models failed to evaluate the answer. Last error: {last_err}")

def evaluate_single_answer_openai(ans: Any, api_key: str) -> Dict[str, Any]:
    """
    Call OpenAI API (gpt-4o-mini / gpt-4o) to evaluate answer using the strict system prompt.
    """
    theme, d1_name, d2_name = get_theme_parameters(ans.theme)
    system_prompt = get_system_prompt()
    
    user_prompt = f"""
questionNo: {ans.question_id}
questionCompetency: {theme}
companyApplicable: {ans.company}
roleFamily: {ans.role_family}
roleTrack: {ans.role_track}
roleLevel: {ans.role_level}
question: {ans.question}
candidateAnswer: {ans.answer}

Evaluate using the scorecard above.
Select D1 and D2 from the questionCompetency mapping only:
D1: {d1_name}
D2: {d2_name}

Return only valid JSON. No other text.
"""
    
    models = ["gpt-4o-mini", "gpt-4o"]
    last_err = None
    
    for model in models:
        try:
            url = "https://api.openai.com/v1/chat/completions"
            headers = {
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json"
            }
            payload = {
                "model": model,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                "response_format": {"type": "json_object"}
            }
            
            response = httpx.post(url, json=payload, headers=headers, timeout=30.0)
            response.raise_for_status()
            res_json = response.json()
            
            text_content = res_json["choices"][0]["message"]["content"].strip()
            data = json.loads(text_content)
            
            # Post-process response to ensure strict compliance with Scoring Prompt guidelines
            f1_score = int(data.get("parameters", {}).get("F1", {}).get("score", 1))
            f2_score = int(data.get("parameters", {}).get("F2", {}).get("score", 1))
            f3_score = int(data.get("parameters", {}).get("F3", {}).get("score", 1))
            d1_score = int(data.get("parameters", {}).get("D1", {}).get("score", 1))
            d2_score = int(data.get("parameters", {}).get("D2", {}).get("score", 1))
            
            total_score = f1_score + f2_score + f3_score + d1_score + d2_score
            data["total_score"] = total_score
            
            readiness_score = round((total_score / 25) * 100)
            data["readiness_score"] = readiness_score
            
            # Map readiness_label based on readiness_score (0-100)
            if readiness_score >= 80:
                data["readiness_label"] = "Interview Ready"
            elif readiness_score >= 60:
                data["readiness_label"] = "Almost There"
            elif readiness_score >= 40:
                data["readiness_label"] = "Not Bad! Keep Improving"
            else:
                data["readiness_label"] = "Needs More Practice"
                
            # Map band and signal based on total_score (0-25)
            if 21 <= total_score <= 25:
                data["band"] = "Exceptional"
                data["signal"] = "Strong Hire"
            elif 16 <= total_score <= 20:
                data["band"] = "Solid"
                data["signal"] = "Lean Hire"
            elif 11 <= total_score <= 15:
                data["band"] = "Developing"
                data["signal"] = "No Hire with coaching"
            else:
                data["band"] = "Weak"
                data["signal"] = "No Hire"
                
            data["parameters"]["F1"]["name"] = "Situation Clarity"
            data["parameters"]["F2"]["name"] = "Personal Ownership"
            data["parameters"]["F3"]["name"] = "Quantified Result"
            data["parameters"]["D1"]["name"] = d1_name
            data["parameters"]["D2"]["name"] = d2_name
            
            data["strengths"] = list(data.get("strengths", []))[:2]
            fallback_strengths = ["Structured logical articulation", "Professional communication style", "Clear problem definition"]
            for s in fallback_strengths:
                if len(data["strengths"]) >= 2:
                    break
                if s not in data["strengths"]:
                    data["strengths"].append(s)
                
            data["improvements"] = list(data.get("improvements", []))[:3]
            fallback_improvements = ["Unpacked complexity dimensions", "Ambiguous timeline markers", "Limited alternative options evaluation"]
            for imp in fallback_improvements:
                if len(data["improvements"]) >= 3:
                    break
                if imp not in data["improvements"]:
                    data["improvements"].append(imp)
                
            return data
        except Exception as e:
            last_err = e
            logger.warning(f"OpenAI model {model} failed: {e}")
            continue

    logger.error(f"All OpenAI models failed. Last error: {last_err}")
    # Fallback to Gemini if configured, otherwise raise error
    gemini_key = os.getenv("GEMINI_API_KEY")
    if gemini_key:
        return evaluate_single_answer_gemini(ans, gemini_key)
    raise RuntimeError(f"All OpenAI models failed to evaluate the answer. Last error: {last_err}")

def evaluate_answers(answers: List[Any]) -> Dict[str, Any]:
    """
    Evaluate all 3 answers (in parallel) and aggregate the results.
    """
    openai_key = os.getenv("OPENAI_API_KEY")
    gemini_key = os.getenv("GEMINI_API_KEY")
    
    results = []
    if openai_key:
        with ThreadPoolExecutor(max_workers=3) as executor:
            futures = [executor.submit(evaluate_single_answer_openai, ans, openai_key) for ans in answers]
            results = [f.result() for f in futures]
    elif gemini_key:
        with ThreadPoolExecutor(max_workers=3) as executor:
            futures = [executor.submit(evaluate_single_answer_gemini, ans, gemini_key) for ans in answers]
            results = [f.result() for f in futures]
    else:
        raise ValueError("No API keys found. Please set OPENAI_API_KEY or GEMINI_API_KEY in the environment config.")
        
    # Aggregate scores
    total_score = sum(r["total_score"] for r in results)
    # Average readiness score
    avg_readiness = int(sum(r["readiness_score"] for r in results) / len(results)) if results else 0
    
    # Derive overall band and label
    # overall_label based on average readiness score
    if avg_readiness >= 80:
        overall_label = "Interview Ready"
    elif avg_readiness >= 60:
        overall_label = "Almost There"
    elif avg_readiness >= 40:
        overall_label = "Not Bad! Keep Improving"
    else:
        overall_label = "Needs More Practice"
        
    # overall_band and overall_signal based on average total score per question
    avg_total_score = total_score / len(results) if results else 0
    if 21 <= avg_total_score <= 25:
        overall_band = "Exceptional"
        overall_signal = "Strong Hire"
    elif 16 <= avg_total_score <= 20:
        overall_band = "Solid"
        overall_signal = "Lean Hire"
    elif 11 <= avg_total_score <= 15:
        overall_band = "Developing"
        overall_signal = "No Hire with coaching"
    else:
        overall_band = "Weak"
        overall_signal = "No Hire"
        
    # Aggregate strengths & improvements
    all_strengths = []
    all_improvements = []
    for r in results:
        all_strengths.extend(r.get("strengths", []))
        all_improvements.extend(r.get("improvements", []))
        
    # Deduplicate and limit (Strengths: 2, Improvements: 3)
    unique_strengths = list(dict.fromkeys(all_strengths))[:2]
    unique_improvements = list(dict.fromkeys(all_improvements))[:3]
    
    return {
        "overall_readiness_score": avg_readiness,
        "overall_readiness_label": overall_label,
        "overall_band": overall_band,
        "overall_signal": overall_signal,
        "overall_total_score": total_score,
        "overall_max_score": len(results) * 25,
        "results": results,
        "overall_strengths": unique_strengths,
        "overall_improvements": unique_improvements
    }

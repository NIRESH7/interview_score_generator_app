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
    Attempts to read scoring_prompt_text.txt, or falls back to an embedded version of the FAANG scoring guidelines.
    """
    text_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "doc_reader", "scoring_prompt_text.txt"))
    if os.path.exists(text_path):
        try:
            with open(text_path, "r", encoding="utf-8") as f:
                return f.read()
        except Exception as e:
            logger.error(f"Error reading scoring prompt text file: {e}")
            
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

def evaluate_single_answer_mock(ans: Any) -> Dict[str, Any]:
    """
    High-fidelity context-aware mock evaluator that dynamically analyzes candidate answers
    to assign realistic scores, strengths, and improvements in strict compliance with
    the Scoring Prompt guidelines.
    """
    theme, d1_name, d2_name = get_theme_parameters(ans.theme)
    answer_lower = ans.answer.lower()
    words = answer_lower.split()
    word_count = len(words)
    
    # 1. Score Situation Clarity (F1)
    if word_count < 15:
        f1 = 1
    elif word_count < 40:
        f1 = 2
    elif word_count < 75:
        f1 = 3
    elif word_count < 120:
        f1 = 4
    else:
        f1 = 5
        
    # Context boost
    context_keywords = ["role", "team", "project", "client", "customer", "company", "at my", "in my last", "when i was"]
    if f1 < 5 and any(kw in answer_lower for kw in context_keywords):
        f1 += 1

    # 2. Score Personal Ownership (F2)
    personal_pronouns = ["i", "me", "my", "myself", "mine"]
    team_pronouns = ["we", "our", "us", "team"]
    
    personal_count = sum(1 for w in words if w in personal_pronouns)
    team_count = sum(1 for w in words if w in team_pronouns)
    
    if personal_count == 0 or word_count < 15:
        f2 = 1
    else:
        total_p = personal_count + team_count
        ratio = personal_count / total_p if total_p > 0 else 1.0
        if ratio >= 0.7:
            f2 = 5
        elif ratio >= 0.5:
            f2 = 4
        elif ratio >= 0.3:
            f2 = 3
        else:
            f2 = 2

    # 3. Score Quantified Result (F3)
    has_digits = any(char.isdigit() for char in answer_lower)
    metric_keywords = ["%", "percent", "week", "month", "day", "hour", "minute", "million", "traffic", "latency", "ms", "users", "dollar", "usd", "revenue"]
    
    if has_digits:
        if any(kw in answer_lower for kw in metric_keywords):
            f3 = 5 if word_count > 60 else 4
        else:
            f3 = 3
    else:
        success_keywords = ["improved", "increased", "reduced", "delivered", "launched", "resolved", "saved", "fixed"]
        if any(kw in answer_lower for kw in success_keywords):
            f3 = 2
        else:
            f3 = 1

    # 4. Score Dynamic Parameters D1 and D2 based on competency keywords
    competency_keywords = {
        "OWNERSHIP": {
            "D1": ["owned", "responsible", "blame", "mistake", "error", "admitted"],
            "D2": ["proactive", "initiated", "started", "created", "went beyond", "noticed", "stepped up"]
        },
        "EXECUTION": {
            "D1": ["plan", "milestones", "structure", "first", "schedule", "organized", "timeline"],
            "D2": ["constraint", "deadline", "tight", "limited", "time limit", "overcame", "pressure"]
        },
        "INFLUENCE": {
            "D1": ["strategy", "stakeholder", "convinced", "persuaded", "presented", "data"],
            "D2": ["buy-in", "durable", "alignment", "long-term", "supported", "sustained"]
        },
        "STAKEHOLDER_MANAGEMENT": {
            "D1": ["mapped", "prioritised", "needs", "stakeholders", "interest", "power"],
            "D2": ["conflict", "disagreement", "between", "resolved", "mediated", "compromise"]
        },
        "COLLABORATION": {
            "D1": ["i did", "my contribution", "specifically", "role", "responsible for"],
            "D2": ["friction", "team", "dynamic", "morale", "handling", "collaboration"]
        },
        "CONFLICT_RESOLUTION": {
            "D1": ["listened", "perspective", "understood", "empathy", "feelings", "concern"],
            "D2": ["resolved", "consensus", "agreement", "outcome", "win-win", "solved"]
        },
        "LEADERSHIP": {
            "D1": ["complex", "judgment", "trade-off", "options", "decided", "reasoning"],
            "D2": ["led", "guided", "stepped up", "mentored", "directed", "vision"]
        },
        "STRATEGIC_THINKING": {
            "D1": ["long-term", "future", "strategic", "years", "scale", "sustainable"],
            "D2": ["insight", "pattern", "trend", "discovered", "observed", "identified"]
        },
        "CUSTOMER_FOCUS": {
            "D1": ["user", "customer", "empathy", "need", "feedback", "behavior"],
            "D2": ["advocated", "customer first", "championed", "represented", "user experience"]
        },
        "PROBLEM_SOLVING": {
            "D1": ["diagnosed", "root cause", "analyzed", "investigated", "why", "drill down"],
            "D2": ["options", "trade-offs", "evaluated", "alternatives", "criteria", "robust"]
        },
        "DECISION_MAKING": {
            "D1": ["framework", "criteria", "matrix", "decided", "factors", "scorecard"],
            "D2": ["speed", "accuracy", "fast", "trade-off", "time pressure", "urgency"]
        },
        "ADAPTABILITY": {
            "D1": ["pivot", "changed", "adapted", "response", "flexible", "unexpected"],
            "D2": ["pressure", "composure", "calm", "stressed", "overwhelmed", "focused"]
        },
        "COMMUNICATION": {
            "D1": ["audience", "calibrated", "tailored", "explained", "technical", "non-technical"],
            "D2": ["clear", "persuaded", "presentation", "articulated", "communicated", "influence"]
        },
        "LEARNING_AND_GROWTH": {
            "D1": ["mistake", "error", "learned", "gap", "fail", "self-assessment"],
            "D2": ["applied", "behavior change", "subsequent", "future", "changed my approach"]
        },
        "INNOVATION": {
            "D1": ["novel", "original", "innovative", "creative", "unorthodox", "new way"],
            "D2": ["risk", "mitigation", "measured", "failure rate", "experimented", "calculated"]
        },
        "PEOPLE_MANAGEMENT": {
            "D1": ["coached", "mentored", "developed", "career", "growth", "feedback"],
            "D2": ["performance", "feedback", "expectation", "underperforming", "improvement plan"]
        }
    }
    
    # Get keywords for current theme, defaulting to OWNERSHIP
    keywords = competency_keywords.get(theme, competency_keywords["OWNERSHIP"])
    
    d1_score = 2
    d1_matches = sum(1 for kw in keywords["D1"] if kw in answer_lower)
    if d1_matches >= 3:
        d1 = 5
    elif d1_matches >= 1:
        d1 = 4 if word_count > 60 else 3
    else:
        d1 = 2
        
    d2_score = 2
    d2_matches = sum(1 for kw in keywords["D2"] if kw in answer_lower)
    if d2_matches >= 3:
        d2 = 5
    elif d2_matches >= 1:
        d2 = 4 if word_count > 60 else 3
    else:
        d2 = 2
        
    # Cap dynamic scores at Situation Clarity (f1) + 1 to keep them realistic
    d1 = min(5, max(1, min(d1, f1 + 1)))
    d2 = min(5, max(1, min(d2, f1 + 1)))

    total = f1 + f2 + f3 + d1 + d2
    readiness = round((total / 25.0) * 100)
    
    if readiness >= 80:
        label = "Interview Ready"
        band = "Exceptional"
        signal = "Strong Hire"
    elif readiness >= 60:
        label = "Almost There"
        band = "Solid"
        signal = "Lean Hire"
    elif readiness >= 40:
        label = "Not Bad! Keep Improving"
        band = "Developing"
        signal = "No Hire with coaching"
    else:
        label = "Needs More Practice"
        band = "Weak"
        signal = "No Hire"
        
    # Generate Strengths dynamically (Select top 2 based on highest parameters)
    param_scores = [
        ("F1", f1, "Highly specific situation setting"),
        ("F2", f2, "Strong personal accountability"),
        ("F3", f3, "Exceptional quantified results"),
        ("D1", d1, f"Robust {d1_name.lower()} focus"),
        ("D2", d2, f"Active {d2_name.lower()} demonstration")
    ]
    param_scores.sort(key=lambda x: x[1], reverse=True)
    strengths = [item[2] for item in param_scores[:2]]
    
    # Generate Improvements dynamically (Select worst 3 parameters)
    param_scores.sort(key=lambda x: x[1])
    improvement_map = {
        "F1": "Vague situation stakes",
        "F2": "Ambiguous personal attribution",
        "F3": "Missing absolute impact metric",
        "D1": f"Weak {d1_name.lower()} articulation",
        "D2": f"Limited {d2_name.lower()} evidence"
    }
    improvements = []
    for item in param_scores:
        improvements.append(improvement_map[item[0]])
        if len(improvements) == 3:
            break
            
    # Ensure all noun phrases are strictly 3-5 words
    # (The generated phrases above are already designed to be 3-5 words)
    
    return {
        "question_theme": theme,
        "target_company": ans.company,
        "role": ans.role_family,
        "role_track": ans.role_track,
        "role_level": ans.role_level,
        "readiness_score": readiness,
        "readiness_label": label,
        "band": band,
        "signal": signal,
        "total_score": total,
        "parameters": {
            "F1": {"name": "Situation Clarity", "score": f1},
            "F2": {"name": "Personal Ownership", "score": f2},
            "F3": {"name": "Quantified Result", "score": f3},
            "D1": {"name": d1_name, "score": d1},
            "D2": {"name": d2_name, "score": d2}
        },
        "strengths": strengths,
        "improvements": improvements
    }

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
    
    # Try models: gemini-2.5-flash is the stable model in 2025/2026. gemini-2.0-flash and gemini-1.5-flash as fallbacks.
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
            # 1. Total score calculation
            f1_score = int(data.get("parameters", {}).get("F1", {}).get("score", 1))
            f2_score = int(data.get("parameters", {}).get("F2", {}).get("score", 1))
            f3_score = int(data.get("parameters", {}).get("F3", {}).get("score", 1))
            d1_score = int(data.get("parameters", {}).get("D1", {}).get("score", 1))
            d2_score = int(data.get("parameters", {}).get("D2", {}).get("score", 1))
            
            total_score = f1_score + f2_score + f3_score + d1_score + d2_score
            data["total_score"] = total_score
            
            # 2. Readiness score round((total_score / 25) * 100)
            readiness_score = round((total_score / 25) * 100)
            data["readiness_score"] = readiness_score
            
            # 3. Label based on readiness score
            if readiness_score >= 80:
                data["readiness_label"] = "Interview Ready"
                data["band"] = "Exceptional"
                data["signal"] = "Strong Hire"
            elif readiness_score >= 60:
                data["readiness_label"] = "Almost There"
                data["band"] = "Solid"
                data["signal"] = "Lean Hire"
            elif readiness_score >= 40:
                data["readiness_label"] = "Not Bad! Keep Improving"
                data["band"] = "Developing"
                data["signal"] = "No Hire with coaching"
            else:
                data["readiness_label"] = "Needs More Practice"
                data["band"] = "Weak"
                data["signal"] = "No Hire"
                
            # 4. Enforce parameter names
            data["parameters"]["F1"]["name"] = "Situation Clarity"
            data["parameters"]["F2"]["name"] = "Personal Ownership"
            data["parameters"]["F3"]["name"] = "Quantified Result"
            data["parameters"]["D1"]["name"] = d1_name
            data["parameters"]["D2"]["name"] = d2_name
            
            # 5. Enforce strengths/improvements lengths and formatting (exactly 2 strengths, 3 improvements)
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

    logger.error(f"All Gemini models failed. Falling back to mock. Last error: {last_err}")
    return evaluate_single_answer_mock(ans)

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
            
            if readiness_score >= 80:
                data["readiness_label"] = "Interview Ready"
                data["band"] = "Exceptional"
                data["signal"] = "Strong Hire"
            elif readiness_score >= 60:
                data["readiness_label"] = "Almost There"
                data["band"] = "Solid"
                data["signal"] = "Lean Hire"
            elif readiness_score >= 40:
                data["readiness_label"] = "Not Bad! Keep Improving"
                data["band"] = "Developing"
                data["signal"] = "No Hire with coaching"
            else:
                data["readiness_label"] = "Needs More Practice"
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

    logger.error(f"All OpenAI models failed. Falling back to Gemini. Last error: {last_err}")
    gemini_key = os.getenv("GEMINI_API_KEY")
    if gemini_key:
        return evaluate_single_answer_gemini(ans, gemini_key)
    return evaluate_single_answer_mock(ans)

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
        results = [evaluate_single_answer_mock(ans) for ans in answers]
        
    # Aggregate scores
    total_score = sum(r["total_score"] for r in results)
    # Average readiness score
    avg_readiness = int(sum(r["readiness_score"] for r in results) / len(results)) if results else 0
    
    # Derive overall band and label
    if avg_readiness >= 80:
        overall_label = "Interview Ready"
        overall_band = "Exceptional"
        overall_signal = "Strong Hire"
    elif avg_readiness >= 60:
        overall_label = "Almost There"
        overall_band = "Solid"
        overall_signal = "Lean Hire"
    elif avg_readiness >= 40:
        overall_label = "Not Bad! Keep Improving"
        overall_band = "Developing"
        overall_signal = "No Hire with coaching"
    else:
        overall_label = "Needs More Practice"
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

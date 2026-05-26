import re
from datetime import datetime, date
import math

def calculate_spanish_severance(start_date: date, end_date: date, monthly_salary: float):
    daily_salary = (monthly_salary * 12) / 365.0
    reform_date = date(2012, 2, 12)
    
    days_p1 = 0
    days_p2 = 0
    
    if end_date < reform_date:
        days_p1 = (end_date - start_date).days + 1
        days_p2 = 0
    elif start_date >= reform_date:
        days_p1 = 0
        days_p2 = (end_date - start_date).days + 1
    else:
        days_p1 = (reform_date - start_date).days
        days_p2 = (end_date - reform_date).days + 1
        
    months_p1 = math.ceil(days_p1 / 30.4167) if days_p1 > 0 else 0
    months_p2 = math.ceil(days_p2 / 30.4167) if days_p2 > 0 else 0
    
    severance_improcedente_p1 = (months_p1 * (45.0 / 12.0)) * daily_salary
    severance_improcedente_p2 = (months_p2 * (33.0 / 12.0)) * daily_salary
    
    total_improcedente_uncapped = severance_improcedente_p1 + severance_improcedente_p2
    
    cap_720_days = daily_salary * 720
    cap_1260_days = daily_salary * 1260
    
    improcedente_cap = cap_720_days
    is_capped = False
    
    if start_date < reform_date:
        if severance_improcedente_p1 >= cap_720_days:
            improcedente_cap = min(severance_improcedente_p1, cap_1260_days)
        else:
            improcedente_cap = cap_720_days
            
    total_improcedente = total_improcedente_uncapped
    if total_improcedente > improcedente_cap:
        total_improcedente = improcedente_cap
        is_capped = True
        
    total_months = math.ceil(((end_date - start_date).days + 1) / 30.4167)
    total_objetivo_uncapped = (total_months * (20.0 / 12.0)) * daily_salary
    cap_360_days = daily_salary * 360
    
    total_objetivo = total_objetivo_uncapped
    is_objetivo_capped = False
    if total_objetivo > cap_360_days:
        total_objetivo = cap_360_days
        is_objetivo_capped = True
        
    return {
        "daily_salary": round(daily_salary, 2),
        "total_days_worked": (end_date - start_date).days + 1,
        "days_pre_reform": days_p1,
        "days_post_reform": days_p2,
        "months_pre_reform": months_p1,
        "months_post_reform": months_p2,
        "improcedente": {
            "uncapped": round(total_improcedente_uncapped, 2),
            "final": round(total_improcedente, 2),
            "cap_applied": round(improcedente_cap, 2),
            "is_capped": is_capped
        },
        "objetivo": {
            "uncapped": round(total_objetivo_uncapped, 2),
            "final": round(total_objetivo, 2),
            "cap_applied": round(cap_360_days, 2),
            "is_capped": is_objetivo_capped
        }
    }

def extract_case_parameters(text: str):
    text_lower = text.lower()
    
    months_es = {
        "enero": 1, "febrero": 2, "marzo": 3, "abril": 4, "mayo": 5, "junio": 6,
        "julio": 7, "agosto": 8, "septiembre": 9, "octubre": 10, "noviembre": 11, "diciembre": 12
    }
    
    dates_found = []
    
    slash_pattern = re.compile(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{4})\b')
    for m in slash_pattern.finditer(text):
        day, month, year = int(m.group(1)), int(m.group(2)), int(m.group(3))
        try:
            dates_found.append(date(year, month, day))
        except ValueError:
            pass
            
    text_pattern = re.compile(r'\b(\d{1,2})\s+de\s+(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)\s+de\s+(\d{4})\b', re.IGNORECASE)
    for m in text_pattern.finditer(text):
        day = int(m.group(1))
        month_str = m.group(2).lower()
        month = months_es[month_str]
        year = int(m.group(3))
        try:
            dates_found.append(date(year, month, day))
        except ValueError:
            pass
            
    dates_found = sorted(list(set(dates_found)))
    
    start_date = None
    end_date = None
    
    if len(dates_found) >= 2:
        start_date = dates_found[0]
        end_date = dates_found[-1]
    elif len(dates_found) == 1:
        today = date.today()
        if (today - dates_found[0]).days > 365:
            start_date = dates_found[0]
        else:
            end_date = dates_found[0]
            
    salary = None
    salary_patterns = [
        r'\b(\d+(?:\.\d{3})*(?:,\d{2})?)\s*(?:€|euros)(?!\w)',
        r'\bsalario\s+(?:de\s+)?(\d+(?:\.\d{3})*(?:,\d{2})?)\b',
        r'\bnómina\s+(?:de\s+)?(\d+(?:\.\d{3})*(?:,\d{2})?)\b'
    ]
    
    for pat in salary_patterns:
        match = re.search(pat, text_lower)
        if match:
            val_str = match.group(1).replace(".", "")
            val_str = val_str.replace(",", ".")
            try:
                salary = float(val_str)
                break
            except ValueError:
                pass
                
    return {
        "start_date": start_date,
        "end_date": end_date,
        "salary": salary
    }

sample_text = """
El trabajador fue contratado el 15/05/2015 con un salario mensual de 2.250 € bruto. 
La empresa le comunicó su despido el 20 de mayo de 2026 sin alegar causas válidas.
"""
params = extract_case_parameters(sample_text)
print("Extracted params:", params)
if params["start_date"] and params["end_date"] and params["salary"]:
    calc = calculate_spanish_severance(params["start_date"], params["end_date"], params["salary"])
    print("Calculated Severance:", calc)

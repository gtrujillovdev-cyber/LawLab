from datetime import date, timedelta
import calendar
import math

def calculate_seniority_months(start_date: date, end_date: date) -> int:
    """
    Calcula los meses de antigüedad laboral en España.
    En España, cualquier fracción de mes trabajado se redondea al mes completo superior
    a efectos de cálculo de indemnizaciones.
    """
    if start_date > end_date:
        return 0
        
    years = end_date.year - start_date.year
    months = end_date.month - start_date.month
    total_months = years * 12 + months
    
    def get_completion_date(start: date, m: int) -> date:
        if m == 0:
            return start - timedelta(days=1)
        month = start.month - 1 + m
        year = start.year + month // 12
        month = month % 12 + 1
        
        _, last_day = calendar.monthrange(year, month)
        
        target_day = start.day - 1
        if target_day == 0:
            target_day = last_day
        else:
            if target_day > last_day:
                target_day = last_day
            elif start.day > last_day:
                target_day = last_day
        return date(year, month, target_day)
        
    comp_date = get_completion_date(start_date, total_months)
    
    if end_date == comp_date:
        final_months = total_months
    elif end_date > comp_date:
        final_months = total_months + 1
    else:
        final_months = total_months
        
    return max(1, final_months)

def calculate_spanish_severance(start_date: date, end_date: date, monthly_salary: float):
    """
    Calcula la indemnización por despido improcedente y objetivo según la legislación española,
    teniendo en cuenta la reforma laboral del 12 de febrero de 2012.
    """
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
        
    # Calculamos meses de antigüedad para cada tramo (redondeando hacia arriba la fracción de mes)
    months_p1 = math.ceil(days_p1 / 30.4167) if days_p1 > 0 else 0
    months_p2 = math.ceil(days_p2 / 30.4167) if days_p2 > 0 else 0
    
    # Indemnización despido improcedente (45 días/año y 33 días/año)
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
        
    # Indemnización por despido objetivo (20 días/año, máximo 12 mensualidades = 360 días)
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

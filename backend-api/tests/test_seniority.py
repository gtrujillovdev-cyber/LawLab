from datetime import date, timedelta
import calendar

def calculate_seniority_months(start_date: date, end_date: date) -> int:
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

# Test cases
test_cases = [
    (date(2015, 5, 15), date(2016, 5, 14), 12, "Exactly 1 year"),
    (date(2015, 5, 15), date(2016, 5, 15), 13, "1 year and 1 day (rounds up to 13 months)"),
    (date(2015, 5, 15), date(2026, 5, 20), 133, "11 years and 5 days"),
    (date(2020, 8, 31), date(2020, 9, 30), 1, "Exactly 1 month (31st Aug to 30th Sept)"),
    (date(2020, 8, 31), date(2020, 9, 29), 1, "Fraction of 1 month (rounds up to 1)"),
    (date(2020, 1, 31), date(2020, 2, 28), 1, "Fraction of Feb (rounds up to 1)"),
    (date(2020, 1, 31), date(2020, 2, 29), 1, "Exactly 1 month in leap year"),
    (date(2020, 1, 31), date(2020, 3, 1), 2, "1 month and 1 day in leap year (rounds up to 2)")
]

print("=== SENIORITY CALCULATION TESTS ===")
for start, end, expected, desc in test_cases:
    actual = calculate_seniority_months(start, end)
    status = "PASS" if actual == expected else f"FAIL (expected {expected}, got {actual})"
    print(f"Start: {start}, End: {end} | Expected: {expected} | Actual: {actual} | Status: {status} ({desc})")

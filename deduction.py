from datetime import datetime

MEAL_HOURS = {'morning': 8, 'lunch': 12, 'snack': 15, 'dinner': 18}


def is_overdue(date_str, meal_time):
    hour = MEAL_HOURS[meal_time]
    meal_dt = datetime.strptime(date_str, '%Y-%m-%d').replace(hour=hour)
    return meal_dt < datetime.now()


def compute_deductions(meals, ingredients):
    """
    meals:       [{'id', 'date', 'meal_time', 'status', 'ingredients': [{'ingredient_id', 'grams'}]}]
    ingredients: [{'id', 'weight_per_cube'}]
    Returns:
      updates: {meal_id: 'auto-consumed'}
      deltas:  {ingredient_id: negative_int}
    """
    ing_map = {i['id']: i for i in ingredients}
    updates, deltas = {}, {}

    for meal in meals:
        if meal['status'] != 'upcoming':
            continue
        if not is_overdue(meal['date'], meal['meal_time']):
            continue
        updates[meal['id']] = 'auto-consumed'
        for mi in meal.get('ingredients', []):
            i = ing_map.get(mi['ingredient_id'])
            if not i:
                continue
            grams = mi['grams'] or 0
            wpc   = i['weight_per_cube'] or 1
            # grams < wpc 이면 큐브 수를 그대로 보낸 것으로 간주
            cubes = int(grams) if grams < wpc else round(grams / wpc)
            if cubes:
                deltas[mi['ingredient_id']] = deltas.get(mi['ingredient_id'], 0) - cubes

    return updates, deltas

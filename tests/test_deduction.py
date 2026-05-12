import pytest
from datetime import datetime
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from deduction import compute_deductions, MEAL_HOURS


def meal(mid, date, meal_time, status='upcoming', ingredients=None):
    return {'id': mid, 'date': date, 'meal_time': meal_time,
            'status': status, 'ingredients': ingredients or []}


def ing(iid, weight_per_cube=20):
    return {'id': iid, 'weight_per_cube': weight_per_cube}


def test_past_upcoming_meal_is_auto_consumed():
    m = meal(1, '2020-01-01', 'morning', ingredients=[{'ingredient_id': 10, 'grams': 20}])
    updates, deltas = compute_deductions([m], [ing(10)])
    assert updates[1] == 'auto-consumed'
    assert deltas[10] == -1


def test_future_meal_not_deducted():
    m = meal(2, '2099-01-01', 'morning', ingredients=[{'ingredient_id': 10, 'grams': 20}])
    updates, deltas = compute_deductions([m], [ing(10)])
    assert 2 not in updates
    assert 10 not in deltas


def test_already_consumed_skipped():
    m = meal(3, '2020-01-01', 'morning', status='auto-consumed',
             ingredients=[{'ingredient_id': 10, 'grams': 20}])
    updates, deltas = compute_deductions([m], [ing(10)])
    assert 3 not in updates


def test_grams_to_cubes_rounds():
    m = meal(4, '2020-01-01', 'morning', ingredients=[{'ingredient_id': 10, 'grams': 40}])
    updates, deltas = compute_deductions([m], [ing(10, weight_per_cube=20)])
    assert deltas[10] == -2


def test_multiple_meals_accumulate():
    m1 = meal(5, '2020-01-01', 'morning', ingredients=[{'ingredient_id': 10, 'grams': 20}])
    m2 = meal(6, '2020-01-02', 'lunch',   ingredients=[{'ingredient_id': 10, 'grams': 20}])
    updates, deltas = compute_deductions([m1, m2], [ing(10)])
    assert deltas[10] == -2


def test_skipped_not_deducted():
    m = meal(7, '2020-01-01', 'morning', status='skipped',
             ingredients=[{'ingredient_id': 10, 'grams': 20}])
    updates, deltas = compute_deductions([m], [ing(10)])
    assert 7 not in updates

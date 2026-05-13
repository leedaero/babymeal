ALTER TABLE ingredients ADD COLUMN user_id INT DEFAULT NULL;
UPDATE ingredients
  SET user_id = (SELECT id FROM users WHERE is_admin=1 ORDER BY id LIMIT 1)
  WHERE user_id IS NULL;
ALTER TABLE ingredients
  MODIFY COLUMN user_id INT NOT NULL,
  ADD CONSTRAINT fk_ing_user FOREIGN KEY (user_id) REFERENCES users(id);

ALTER TABLE meals ADD COLUMN user_id INT DEFAULT NULL;
UPDATE meals
  SET user_id = (SELECT id FROM users WHERE is_admin=1 ORDER BY id LIMIT 1)
  WHERE user_id IS NULL;
ALTER TABLE meals
  MODIFY COLUMN user_id INT NOT NULL,
  ADD CONSTRAINT fk_meal_user FOREIGN KEY (user_id) REFERENCES users(id);

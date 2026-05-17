CREATE TABLE IF NOT EXISTS ingredient_logs (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    ingredient_id INT NOT NULL,
    user_id       INT NOT NULL,
    event_type    ENUM('created','fed','replenished') NOT NULL,
    delta         INT NOT NULL,
    note          VARCHAR(255) DEFAULT NULL,
    logged_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_ing_id (ingredient_id),
    INDEX idx_user_id (user_id)
);

-- 기존 재료를 'created' 이벤트로 시딩 (이미 이력이 있는 재료는 건너뜀)
INSERT INTO ingredient_logs (ingredient_id, user_id, event_type, delta, note, logged_at)
SELECT id, user_id, 'created', total_cubes, '기존 데이터', created_at
FROM ingredients
WHERE id NOT IN (SELECT DISTINCT ingredient_id FROM ingredient_logs);

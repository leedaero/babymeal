"""
재고 부족 디스코드 알림 배치
NAS crontab: 0 8 * * * /bin/python3 /volume1/DR_DATA1/babyMeal/notify_low_stock.py
"""
import sys
import json
import urllib.request
import urllib.error
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import db as _db

LOW_STOCK_THRESHOLD = 3


def fetch_low_stock(conn):
    cur = conn.cursor()
    cur.execute(
        "SELECT name, emoji, current_cubes FROM ingredients WHERE current_cubes <= %s ORDER BY current_cubes",
        (LOW_STOCK_THRESHOLD,),
    )
    return cur.fetchall()


def build_message(items):
    lines = ["🚨 **재고 부족 알림** — 치밀한 이유식\n"]
    for item in items:
        bar = "▓" * item["current_cubes"] + "░" * (LOW_STOCK_THRESHOLD - item["current_cubes"])
        lines.append(f"{item['emoji']} **{item['name']}** — {item['current_cubes']}개 남음  `{bar}`")
    lines.append("\n> 재고 탭에서 큐브를 보충해주세요 🍼")
    return "\n".join(lines)


def send_discord(webhook_url, message):
    payload = json.dumps({"content": message}).encode("utf-8")
    req = urllib.request.Request(
        webhook_url,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    urllib.request.urlopen(req, timeout=10)


def main():
    cfg = _db.load_config()
    webhook = cfg.get("discord_webhook", "").strip()
    if not webhook:
        print("discord_webhook이 config.json에 설정되지 않았습니다.")
        sys.exit(0)

    conn = _db.get_connection(cfg)
    try:
        items = fetch_low_stock(conn)
    finally:
        conn.close()

    if not items:
        print("재고 부족 항목 없음 — 알림 생략")
        sys.exit(0)

    message = build_message(items)
    try:
        send_discord(webhook, message)
        print(f"디스코드 알림 전송 완료 ({len(items)}개 항목)")
    except urllib.error.URLError as e:
        print(f"디스코드 전송 실패: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

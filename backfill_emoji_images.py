#!/usr/bin/env python3
"""기존 재료의 이모지 이미지를 MinIO에 일괄 업로드한다."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

import db as _db
import minio_storage
from emoji_image import save_emoji_image


def main():
    cfg = _db.load_config()
    mc = minio_storage.get_minio_client(cfg)
    if not mc:
        print('MinIO 미설정 또는 연결 실패. config.json의 minio 섹션을 확인하세요.')
        sys.exit(1)

    bucket = cfg.get('minio', {}).get('bucket', 'babymeal')
    minio_storage.ensure_bucket(mc, bucket)
    print(f'버킷: {bucket}')

    conn = _db.get_connection(cfg)
    cur = conn.cursor()
    cur.execute('SELECT id, name, emoji FROM ingredients WHERE image_url IS NULL')
    rows = cur.fetchall()
    print(f'처리 대상: {len(rows)}건\n')

    ok = fail = 0
    for row in rows:
        img_url = save_emoji_image(mc, bucket, row['emoji'])
        if img_url:
            cur.execute('UPDATE ingredients SET image_url=%s WHERE id=%s', (img_url, row['id']))
            conn.commit()
            print(f'  ✓ {row["name"]} {row["emoji"]} → {img_url}')
            ok += 1
        else:
            print(f'  ✗ {row["name"]} {row["emoji"]} (Twemoji 미지원)')
            fail += 1

    print(f'\n완료: {ok}건 성공, {fail}건 실패')


if __name__ == '__main__':
    main()

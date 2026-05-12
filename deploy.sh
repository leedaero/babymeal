#!/bin/bash
set -e
cd /volume1/DR_DATA1/babyMeal
git pull origin main
pip3 install -r requirements.txt --quiet
sudo systemctl restart babymeal
echo "배포 완료: $(date)"

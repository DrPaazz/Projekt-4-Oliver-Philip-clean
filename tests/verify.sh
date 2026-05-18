#!/usr/bin/env bash
set -euo pipefail

echo "Rensar gamla testfiler..."
sudo rm -f /mnt/gemensam/anna.txt /mnt/gemensam/bert.txt /mnt/gemensam/clara.txt 2>/dev/null || true
sudo rm -f /mnt/avdelning-a/anna.txt /mnt/avdelning-a/bert-fel.txt /mnt/avdelning-a/clara.txt 2>/dev/null || true
sudo rm -f /mnt/avdelning-b/bert.txt /mnt/avdelning-b/anna-fel.txt /mnt/avdelning-b/clara.txt 2>/dev/null || true

echo "Testar gemensam katalog..."
sudo -u anna bash -lc 'echo "anna gemensam" > /mnt/gemensam/anna.txt'
sudo -u bert bash -lc 'echo "bert gemensam" > /mnt/gemensam/bert.txt'
sudo -u clara bash -lc 'echo "clara gemensam" > /mnt/gemensam/clara.txt'

echo "Testar att anna kan skriva till avdelning-a..."
sudo -u anna bash -lc 'echo "anna avd a" > /mnt/avdelning-a/anna.txt'

echo "Testar att anna INTE kan skriva till avdelning-b..."
if sudo -u anna bash -lc 'echo "ska inte fungera" > /mnt/avdelning-b/anna-fel.txt' 2>/dev/null; then
  echo "FEL: anna kunde skriva till avdelning-b"
  exit 1
else
  echo "OK: anna nekades till avdelning-b"
fi

echo "Testar att bert kan skriva till avdelning-b..."
sudo -u bert bash -lc 'echo "bert avd b" > /mnt/avdelning-b/bert.txt'

echo "Testar att bert INTE kan skriva till avdelning-a..."
if sudo -u bert bash -lc 'echo "ska inte fungera" > /mnt/avdelning-a/bert-fel.txt' 2>/dev/null; then
  echo "FEL: bert kunde skriva till avdelning-a"
  exit 1
else
  echo "OK: bert nekades till avdelning-a"
fi

echo "Testar att clara kan skriva till båda avdelningar..."
sudo -u clara bash -lc 'echo "clara avd a" > /mnt/avdelning-a/clara.txt'
sudo -u clara bash -lc 'echo "clara avd b" > /mnt/avdelning-b/clara.txt'

echo "Alla tester lyckades."
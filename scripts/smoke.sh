#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE:-http://localhost:3000}"

routes=(
  "/"
  "/faculties"
  "/students"
  "/teachers"
  "/sections"
  "/sections/1"
  "/competitions"
  "/competitions/1"
  "/students/new"
  "/teachers/new"
  "/sections/new"
  "/competitions/new"
  "/faculties/1/edit"
  "/students/1/edit"
  "/teachers/1/edit"
  "/sections/1/edit"
  "/competitions/1/edit"
  "/schedule/1/edit"
  "/memberships/1/edit"
  "/participants/1/edit"
  "/health"
)

for route in "${routes[@]}"; do
  code="$(/usr/bin/curl -sS -o /dev/null -w '%{http_code}' "$BASE$route")"
  if [[ "$code" != "200" ]]; then
    echo "FAIL $code $route"
    exit 1
  fi
  echo "OK   $code $route"
done

echo "Smoke test passed: ${#routes[@]} routes"

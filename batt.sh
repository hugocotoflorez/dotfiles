#!/bin/bash



upower --dump | awk '
BEGIN { RS=""; FS="\n" }
{
  model = ""; percent = "";
  for (i = 1; i <= NF; i++) {
    if ($i ~ /model:/) {
      sub(/^.*model:[[:space:]]*/, "", $i)
      model = $i
    }
    if ($i ~ /percentage:/) {
      sub(/^.*percentage:[[:space:]]*/, "", $i)
      percent = $i
    }
  }
  if (model && percent) {
    print model " - " percent
  }
}'


#!/usr/bin/env bash

# Check for username argument
if [ -z "$1" ]; then
  echo "Usage: $0 <username>"
  exit 1
fi
USERNAME="$1"

# Create user folder if it doesn't exist
mkdir -p "$USERNAME"
cd "$USERNAME"

# Set headers
AUTH="authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJhdXRoLXNlcnZpY2UiLCJpYXQiOjE3NTI1MDM3NTYsImF1ZCI6Imh0dHBzOi8vYXBpLnJlZGdpZnMuY29tIiwiYXpwIjoiMTgyM2MzMWY3ZDMtNzQ1YS02NTg5LTAwMDUtZDhlOGZlMGE0NGMyIiwiZXhwIjoxNzUyNTkwMTU2LCJzdWIiOiJjbGllbnQvMTgyM2MzMWY3ZDMtNzQ1YS02NTg5LTAwMDUtZDhlOGZlMGE0NGMyIiwic2NvcGVzIjoicmVhZCIsInZhbGlkX2FkZHIiOiI0OS4xNzcuMTMuMTEiLCJ2YWxpZF9hZ2VudCI6Ik1vemlsbGEvNS4wIChYMTE7IExpbnV4IHg4Nl82NCkgQXBwbGVXZWJLaXQvNTM3LjM2IChLSFRNTCwgbGlrZSBHZWNrbykgQ2hyb21lLzEzNy4wLjAuMCBTYWZhcmkvNTM3LjM2IiwicmF0ZSI6LTEsImh0dHBzOi8vcmVkZ2lmcy5jb20vc2Vzc2lvbi1pZCI6IjMwMDM3Nzc2MzMxODIwOTk5MiJ9.KKim9PkjoBeLM3NXwcwflnAClhwZ8elNt22egv6vhWXWXsMGYT_DOdUdJA9pCyTS84wTnvSIOgmM7nQBWi_lpLFNXQ3P55poIx2OE6gAD7SJ4oAmlvr5MYZzbRxWs2NbAokgZTizlqnN8pqjLJhCXIsQek5jOH2TkA__MZeWZg2atVTTahAef2eOEOEpFgmMrZqqL21s2AlyLIH_WwC-rgyod1k9Xa1c2nxDPwZZVuIrJzvCFNQFNPP8uqQwY6Sbc7SJQ9u5RjRd9zSlXeZw1kwCLb7WmqNXP0rgvajb2Swmnc8EkN-kWJgoe0FL9T1Y41lbE0bDD5fwBf0gfB8cuA"
REFERER="referer: http://localhost/"
USERAGENT="user-agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36"

# Download all pages
for i in {1..11}; do
  curl -s -H "$AUTH" -H "$REFERER" -H "$USERAGENT" "https://api.redgifs.com/v2/users/$USERNAME/search?order=recent&count=80&page=$i&type=g&search_text=&tags=" -o "page_$i.json"
done

# Extract URLs (prefer hd, fallback to sd)
> urls.list
for i in {1..11}; do
  jq -r '.gifs[] | .urls.hd // .urls.sd' "page_$i.json" >> urls.list
done

# Remove URLs from urls.list if the corresponding file is already present
TMP_LIST="urls.list.tmp"
> "$TMP_LIST"
while read -r url; do
  fname="$(basename "$url")"
  if [ ! -f "$fname" ]; then
    echo "$url" >> "$TMP_LIST"
  fi
done < urls.list
mv "$TMP_LIST" urls.list

# Remove temporary page JSON files
rm -f page_*.json

# Fetch videos

wget -i urls.list

# Remove videos list
rm urls.list


# Check for and remove duplicate video files by perceptual hash
# This will keep the first occurrence and remove subsequent duplicates
cd ..
echo "Checking for perceptually similar videos..."

# Create hash database file for this user
hash_db="$USERNAME/video_hashes.db"

# Generate hashes for new videos and compare all videos (including existing ones)
echo "Generating hashes and comparing videos..."
./phash_video_compare -wd 5 -s "$hash_db" ./$USERNAME/*.mp4 2>/dev/null | while read -r line; do
    # Parse the new format: "distance - file1 - file2"
    # Extract the second filename (the one to remove)
    dupfile=$(echo "$line" | awk -F' - ' '{print $3}')
    if [ -f "$dupfile" ]; then
        echo "Removing duplicate video: $dupfile"
        rm -- "$dupfile"
    fi
done

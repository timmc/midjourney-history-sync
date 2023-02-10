#!/bin/bash
# Synchronize your online Midjourney history with a local copy.
#
#
#
# /!\ This requires familiarity with HTTP and the command line. /!\
#
#
#
# - Creates a directory called `jobs` (in the current directory) with a
#   subdirectory for each prompt.
# - All generated images are downloaded to the subdirectory, along with a
#   JSON file containing information about the prompt.
# - Saves a jobs/last.json in case something fails and you need to do
#   manual backups.
# - Safe to re-run if interrupted.
#
# Prerequisities: bash, jq, curl
#
# - Go to https://www.midjourney.com/app
# - Get your user ID from the "view as visitor link (https://www.midjourney.com/app/users/.../)
#   and save it as a file called userid.txt
# - In your browser's dev tools, find the `__Secure-next-auth.session-token` cookie.
# - Run `./sync.sh` from the directory *containing* your jobs dir (or where
#   you want one to be added)

set -eu -o pipefail

UA='Midjourney-history-sync/1.0'

USER_ID=`cat userid.txt`

read -e -p "Enter your Midjourney session token (eyJ...): " SESSION_TOKEN

mkdir -p jobs

# Fetch 50 images per page, iterating through all the pages required until all images are downloaded.
for page in {1..100}
do
    jobs="$(
    curl -sS -A "$UA" -H "Cookie: __Secure-next-auth.session-token=$SESSION_TOKEN" \
       -H 'Content-Type: application/json' \
       -- "https://www.midjourney.com/api/app/recent-jobs/?orderBy=new&jobStatus=completed&userId=${USER_ID}&dedupe=true&refreshApi=0&page=$page"
    )"

    echo "$jobs" | jq > jobs/last_page_$page.json

    # Start from the oldest ones and process each job as a line of input.
    echo "$jobs" | jq 'sort_by(.enqueue_time)[]' -c | while IFS= read -r job; do
        # Get job ID and validate that it's safely usable on the
        # filesystem and that the format hasn't changed in a way that
        # might mean we have to rewrite part of the script.
        job_id="$(echo "$job" | jq .id -r)"
        # Specifically, check that it looks roughly like a UUID.
        if [[ ! "$job_id" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
            echo >&2 "Potentially unsafe job ID '$job_id' -- stopping!"
            exit 1
        fi

        # Ensure we're in a good state before proceeding.
        tdir="./jobs/${job_id}"
        if [[ -d "$tdir" ]]; then
            if [[ -f "$tdir/completed" ]]; then
                echo >&2 "Skipping $job_id -- already downloaded."
                continue
            else
                echo >&2 "Warning: $job_id did not finish syncing. Will try again!"
            fi
        else
            echo <&2 "Downloading $job_id"
            mkdir -- "$tdir"
        fi

        # Save off entire job object. Can read it later to find prompt
        # and other info.
        echo "$job" | jq . > "$tdir/job.json"

        # Download images
        echo "$job" | jq '.image_paths[]' -c -r | while IFS= read -r img_url; do
            # Get image filename and make sure it's safe to use on the filesystem.
            fname="$(echo "$img_url" | sed 's|[^?#]*/||')"
            if [[ ! "$fname" =~ ^[0-9_]+\.(png|jpg|jpeg|webp)$ ]]; then
                echo >&2 "Potentially unsafe image path '$img_url' ending in '$fname' -- stopping!"
                exit 1
            fi

            # Download!
            echo "  ${fname}"
            curl -sS -A "$UA" -o "$tdir/$fname" -- "$img_url"
        done

        # Mark job as completely downloaded.
        touch "$tdir/completed"
    done
done

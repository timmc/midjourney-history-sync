# Midjourney history sync

As of August 2022, Midjourney's multi-downloader did not include exact
prompts, flags, or other metadata. This is my attempt to provide a
stop-gap measure. It downloads any new images (since the last time you
ran it) along with their complete metadata.

**This requires familiarity with HTTP and the command line.** See
sync.sh for details.

I cannot provide support—I don't work for Midjourney and don't even
have access to documentation for their website's (internal) API. It
could break at any time, or do the wrong things because I didn't make
the right guess about the parameters I was seeing in the browser's
network tab.

If you want a supported option, please ask Midjourney.

**2023-02-10**: I've stopped playing with Midjourney and can't commit to
testing any improvements, so I'm archiving the repo. Check the list of
recently updated forks to see if there's a maintained version:
https://github.com/timmc/midjourney-history-sync/network

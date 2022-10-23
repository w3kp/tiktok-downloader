# TikTok Downloader

## Description

This bash script allows you to download TikTok videos both one by one and in batch mode. It uses [yt-dlp](https://github.com/yt-dlp/yt-dlp) for downloading, which is the only external dependency. If downloading fails, check if [yt-dlp](https://github.com/yt-dlp/yt-dlp) is installed and up-to-date.

The script is confirmed working on macOS[^1], but it should run on all plattforms with bash and yt-dlp installed.

## Features

- "single mode": Enter a TikTok video URL and download it to the chosen directory.
- "batch mode": Paste all video URLs you want to download inside a txt file (one video per line) and tell the script the path to that txt file. (Depending on the OS and other circumstances it may be a good idea to end the text file with an empty line to make sure the last URL gets read successfully.
- If you always want to downlaod the videos to the same directory, you can point the variable `default_folder` to it and the script will suggest that folder every time you launch it and all you need to do is to confirm with Enter.

## Installation

Windows users need to use Cygwin or WSL to run bash scripts. Most Linux distributions and macOS[^1] should have bash already installed.

Like all bash scripts, the file has to be marked as exectuable. To do this, open a terminal window and paste `chmod +x /path/to/tt-downloader.sh`. Once that is done, you can double-click it to run.

If you don't already have it installed you also need to install [yt-dlp](https://github.com/yt-dlp/yt-dlp).


# Acknowledgements

The user can select which mode they want to use via a fancy select menu I found on [StackExchange](https://unix.stackexchange.com/questions/146570/arrow-key-enter-menu).


[^1]: macOS now uses zsh as default, so the installed bash version is pretty outdated. It may or may not work (untested). You may want to update it via [Homebrew](https://formulae.brew.sh/formula/bash). 


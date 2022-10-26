# TikTok Downloader

![tiktok-downloader](https://raw.githubusercontent.com/anga83/tiktok-downloader/main/screenshot.png)

## Description

This Bash script allows you to download TikTok videos without watermarks — both one by one and in batch mode. You can also get the profile picture (avatar) of a given user in the highest resolution available.

Underneath the surface, my script uses [yt-dlp](https://github.com/yt-dlp/yt-dlp) for downloading, which is the only external dependency[^1]. If downloading fails, check if [yt-dlp](https://github.com/yt-dlp/yt-dlp) is installed and up-to-date.

The script is confirmed working on macOS[^1] and Ubuntu, but it should run on all platforms with Bash and yt-dlp installed.

## Features

- **Single Mode**: <br />Enter a TikTok video URL and download it to the chosen directory.
- **Batch Mode**: <br />Paste all video URLs you want to download inside a txt file (one video per line) and tell the script the path to that txt file. (Depending on the OS and other circumstances it may be a good idea to end the text file with an empty line to make sure the last URL gets read successfully. Lines should be in the following pattern: `https://www.tiktok.com/@<username>/video/<video id>`
- **Avatar Mode**: <br />Enter a TikTok username or the profile URL to download the profile picture of that channel in the highest resolution available.
- **Restore Mode** _(experimental)_: <br />Like Batch Mode this mode uses a txt file as input, but this time lines should be formatted like this: `<user name>_<video id>.mp4`. Use it to (re)download TikToks based on the file name, for example if you notice that previously downloaded files are corrupt. The script will translate the file names back to TikTok video URLs and will (re)download them (if still available). Existing files will be overwritten.
- In all modes the videos will be downloaded without watermarks and named as `<user name>_<video id>.mp4`.
- The video description will be integated in the file's metadata (`description` tag).
- If available, subtitles will be embedded into the file.
- If you always want to download the videos to the same directory, you can point the variable `default_folder` to it and the script will suggest that folder every time you launch it and all you need to do is to confirm with the enter key.

## Installation

Windows users need to use Cygwin or WSL to run Bash scripts. Most Linux distributions and macOS[^1] should already have Bash installed.

Simply download [tiktok-downloader.sh](https://raw.githubusercontent.com/anga83/tiktok-downloader/main/tiktok-downloader.sh) from the files above and save it in a convenient place. Like all Bash scripts, the file has to be marked as executable. To do this, open a terminal window and paste `chmod +x /path/to/tiktok-downloader.sh`. Once that is done, you can double-click it to run.

If you don't already have it installed you also need to install [yt-dlp](https://github.com/yt-dlp/yt-dlp).
Ubuntu users should note that Ubuntu 22.04 LTS has an old version of yt-dlp in its package repositories, which may cause the download process to fail. Check the link above to update to the latest version.

## Usage

Depending on your operating system, launching the script may differ, but in general there three ways:
- macOS: remove the `.sh` file extension, now you can simply double-click to launch
- Ubuntu: right click and choose "Run as a Program" (there are tutorials to make double-click work as well)
- any OS: open a Terminal window, navigate to the script directory and enter `./tiktok-downloader.sh`

Once launched, choose the mode you want to use and the script will assist you through the necessary steps to get your files.

In all prompts you can enter 'q', 'quit' or 'exit' to exit the program. Enter 'b' or 'back' to go back to the main menu.

## Acknowledgements

The user can select which mode they want to use via a fancy selection menu I found on [StackExchange](https://unix.stackexchange.com/questions/146570/arrow-key-enter-menu).
The sreenshot above was created with [Carbon](https://carbon.now.sh).


[^1]: macOS now uses zsh as default shell and hasn't updated Bash for ages. The script should automatically fallback to a "classic" selection menu, but other issues may still arise. You may update Bash via [Homebrew](https://formulae.brew.sh/formula/bash). <br />macOS users also need to install GNU grep (`ggrep`) via [Homebrew](https://formulae.brew.sh/formula/grep). Otherwise "Avatar Mode" won't work.

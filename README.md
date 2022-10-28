# TikTok Videos & Live Downloader
_Download any TikToks, profile pictures, sounds and ongoing livestreams_

![tiktok-downloader](https://raw.githubusercontent.com/anga83/tiktok-downloader/main/screenshot-v2.0.png)

## Description

This Bash script allows you to download TikTok videos without watermarks — both one by one and in batch mode. You can also get the profile picture (avatar) of a given user in the highest resolution available. The script is also capable of downloading TikTok Lives.

Underneath the surface, my script uses [yt-dlp](https://github.com/yt-dlp/yt-dlp) for downloading tiktok posts (TikToks) and [ffmpeg](https://ffmpeg.org/) for livestreams (Lives). If you get warnings or downloading fails, check if those tools are installed and up-to-date.

The script is confirmed working on macOS[^1] and Ubuntu, but it should run on all platforms with Bash, yt-dlp and/or ffmpeg installed.

## Features

#### Modes

- **Single Mode**: <br />Enter a TikTok video URL and download it to the chosen directory. <br />The URL should be in the following pattern: `https://www.tiktok.com/@<username>/video/<video id>`, but shortcut URLS `https://vm.tiktok.com/<xxxxxxxxx>` are also supported.
- **Batch Mode**: <br />Paste all video URLs you want to download inside a txt file (one video per line) and tell the script the path to that txt file. Bulk downloading is perfect for archiving and hoarding purposes. <br />Lines should be in the following pattern: `https://www.tiktok.com/@<username>/video/<video id>`, but shortcut URLS `https://vm.tiktok.com/<xxxxxxxxx>` are also supported. <br />_Note: Depending on the OS and other circumstances it may be a good idea to end the text file with an empty line to make sure the last URL gets read successfully. Also double-check to have actual line breaks between the URLs, otherwise they won't get recognized._
- **Live Mode**: <br />Live Mode allows you to download a TikTok livestream by any user. <br />Enter the host's username or profile URL and the script will handle the rest. Not that the script unfortuantely can't time travel, so the output file will only be from the point you started recording. You can end the recording by pressing ctrl+c, but have caution to only press the keyboard shortcut once, even when it takes some time for the recording to stop. _(Currently stopping a recording prematurely will cause the whole script to quit.)_ <br />Input can be: `username`, `https://www.tiktok.com/@<username>`, `https://www.tiktok.com/@<username>/live`, or `https://vm.tiktok.com/<xxxxxxxxx>`.
- **Avatar Mode**: <br />Enter a TikTok username or the profile URL to download the profile picture of that channel in the highest resolution available. <br />Input can be either `username` or `https://www.tiktok.com/@<username>`
- **Music Mode**: <br />Enter a TikTok music URL to download a TikTok sound / music snippet. <br />Input has to be in the following format `https://www.tiktok.com/music/<xxxxxxxxxxx>`. Optionally, this will also download the cover image. This mode will output a .m4a and .jpg file in `<artist> - <title>` pattern. The audio file has arist, title and album (if available) written in its metadata. 
- **Restore Mode**: <br />Like Batch Mode this mode uses a txt file as input, but this time lines should be formatted like this: `<user name>_<video id>.mp4` (the .mp4 suffix is optional). Use it to (re)download TikToks based on the file name, for example if you notice that previously downloaded files are corrupt. The script will translate the file names back to TikTok video URLs and will (re)download them (if still available). <br />_Note: Double-check to have actual line breaks between the file names, otherwise they won't get recognized._

#### Other features
- In all modes the TikToks will be downloaded without watermarks and named as `<user name>_<video id>.mp4`. Live recordings will be named as `<user name>_<recording start time in YYYY-MM-DD_HHMM>.mp4`.
- The video description or stream title, respectively, will be written to the file's metadata (`description` tag). In Live Mode the user can opt to write additional information (stream start time and host's device information) to the recording. <br />_If your video player can't display the `description` tag, you may want to take a look at [anga83/video-info](https://github.com/anga83/video-info), which is a metadata viewer for all kinds of video sources._
- If available, subtitles will be embedded into the file.
- If you always want to download the videos to the same directory, you can point the variable `default_folder` to it and the script will suggest that folder every time you launch it and all you need to do is to confirm with the enter key. If you want to save the files to the same directory as the script resides, set it to `default_folder="$BASEDIR"` — which is also the default behavior.
- At the top of the script, you can find settings, which you can switch between `true` and `false` depending on your needs. For example, if you never intend to use Live Mode, you may want to supress the "ffmpeg is not installed" warning when starting the script.

## Installation

Windows users need to use Cygwin or WSL to run Bash scripts. Most Linux distributions and macOS[^1] should already have Bash installed.

Simply download [tiktok-downloader.sh](https://raw.githubusercontent.com/anga83/tiktok-downloader/main/tiktok-downloader.sh) from the files above and save it in a convenient place. Like all Bash scripts, the file has to be marked as executable. To do this, open a terminal window and paste `chmod +x /path/to/tiktok-downloader.sh`. Once that is done, you can double-click it to run.

If you don't already have it installed you also need to install [yt-dlp](https://github.com/yt-dlp/yt-dlp).
Ubuntu users should note that Ubuntu 22.04 LTS has an old version of yt-dlp in its package repositories, which may cause the download process to fail. Check the link above to update to the latest version.

To record TikTok Lives and download sounds you also need [ffmpeg](https://ffmpeg.org/) to be installed. Optionally, [ffprobe](https://ffmpeg.org/) allows you to see the recording duration.

See the script's header for more information about dependenices.


## Usage

Depending on your operating system, launching the script may differ, but in general there are three ways:
- macOS: remove the `.sh` file extension, now you can simply double-click to launch
- Ubuntu: right click and choose "Run as a Program" (there are tutorials to make double-click work as well)
- any OS: open a Terminal window, navigate to the script directory and enter `./tiktok-downloader.sh`

Once launched, select the mode you want to use and the script will assist you through the necessary steps to get your files.

In all prompts you can enter 'q', 'quit' or 'exit' to exit the program. Enter 'b' or 'back' to go back to the main menu.

## Acknowledgements

The users can choose the mode they want to use via a fancy selection menu originally written by [Alexander Klimetschek](https://unix.stackexchange.com/users/219724/alexander-klimetschek) on [StackExchange](https://unix.stackexchange.com/questions/146570/arrow-key-enter-menu).
The visualization of the terminal window was created with [Carbon](https://carbon.now.sh).


[^1]: macOS now uses zsh as default shell and hasn't updated Bash for ages. The script should automatically fallback to a "classic" selection menu, but other issues may still arise. You may update Bash via [Homebrew](https://formulae.brew.sh/formula/bash). <br />macOS users also need to install GNU grep (`ggrep`) via [Homebrew](https://formulae.brew.sh/formula/grep). Otherwise "Avatar Mode" and "Music Mode" won't work. Linux users can skip that part, since they already have the correct version of `grep` installed.

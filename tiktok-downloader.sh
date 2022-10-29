
#!/usr/bin/env bash

# This script allows you to use yt-dlp to download a TikTok video.
# The script has both a mode for downloading a single video and a mode to download all videos passed to the script via a text file.
# "Live Mode" allows the user to download a running TikTok live stream. Note that the recording will only start after the script has been started.
# In "Avatar Mode" the script downloads the profile picture of a TikTok channel in the highest resolution available.
# In "Sound Mode" the script downloads the sound file of a TikTok sound / music snippet.
# In "Restore Mode" the script tries to (re)download videos based on the file name. The input is a text file with entries in the following format: <user name>_<video id>.mp4

version="2.4"

# Version 2.4 (2022-10-29) - Live Mode fixes, added success messages for Batch and Restore Mode
# Version 2.3 (2022-10-29) - updated the selection menu to the version by RobertMcReed (https://gist.github.com/RobertMcReed/05b2dad13e20bb5648e4d8ba356aa60e) which allows the user to select the desired option by pressing the corresponding number key, overwriting files in Restore Mode is now optional, renamed Music Mode to Sound Mode to match TikTok terminology, improved Windows support, several fixes and improvements
# Version 2.2 (2022-10-28) - added Music Mode to download sounds/music, script can now handle shortcut URLs (https://vm.tiktok.com/<xxxxxxxxx>), Live Mode writes additional metadata to the downloaded video file (if setting is enabled)
# Version 2.1 (2022-10-28) - default folder is now script folder by default, the stream title of TikToks lives gets now written into the description metadata field, Avatar Mode can now handle existing files, now showing recording duration if ffprobe is installed, several fixes to make the script more robust, clarified dependencies and settings description, added more settings
# Version 2.0 (2022-10-27) - added live mode, simplified the option to save files in the script's directory
# Version 1.8 (2022-10-26) - if user launches the script with the wrong shell the script will now try to launch itself with the correct shell instead of exiting, warning can be suppressed
# Version 1.7 (2022-10-26) - script now preserves the output folder when changing modes, improved visibility on dark terminal window backgrounds, added more environment checks, added debug information to help screen, improved legacy support (mainly for macOS with built-in bash 3.2)
# Version 1.6 (2022-10-26) - bugxfies, improved support for Ubuntu/Debian based distributions
# Version 1.5 (2022-10-25) - embedding video description and URL into the file's metadata, embedding subtitles (if available), check for yt-dlp updates is now optional
# Version 1.4 (2022-10-24) - bug fixes and compatibility improvements 
# Version 1.3 (2022-10-24) - added "Restore Mode" (experimental)
# Version 1.2 (2022-10-24) - legacy mode for Bash versions < 4.2, check if file already exists before downloading it, check for outdated yt-dlp version
# Version 1.1 (2022-10-23) - added "Avatar Mode"
# Version 1.0 (2022-10-23) - initial version


### Dependencies:
#   Required:
#   - yt-dlp (https://github.com/yt-dlp/yt-dlp)             # needed for downloading TikTok videos
#   - ffmpeg (https://ffmpeg.org)                           # needed for downloading TikTok lives and sounds
#
#   Other required tools that are already installed on most systems, but might have to be added on some (mainly Cygwin and other Bash on Windows layers):
#   - jq, curl, rev, sed, grep
#
#     on macOS hosts you have to install the GNU version of grep via Homebrew (https://brew.sh), since the built-in version is missing features:
#     - ggrep (https://formulae.brew.sh/formula/grep)       # needed for downloading TikTok lives, avatar images and sounds
#
#   Optional:
#   - ffprobe (https://ffmpeg.org)                          # needed for showing the recording duration of TikTok lives
#   - bash >= 4.2                                           # needed for interactive main menu


### Internal Variables:

BASEDIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )     # only edit this line if you know what you do
output_folder=""                                                                 # leave this empty, to set the default output folder use the setting below


### Paths
# macOS and Linux users usaually do not need to change these paths since those programs are installed in a PATH directory by default.
# Windows users using Cygwin, MinGW64 or Git Bash need to change these paths to the correct location of the programs including the .exe extension.
#   example: if yt-dlp.exe is in the same folder as this script, edit the following line like this: ytdlp_path="$BASEDIR/yt-dlp.exe"

ytdlp_path="yt-dlp"
ffmpeg_path="ffmpeg"
ffprobe_path="ffprobe"


### Settings

default_folder="$BASEDIR"                            # set default download folder, leave empty for empty prompt // default_folder="$BASEDIR" will save files in the script's folder
                                                     # on Cygwin you need to set default_folder="." to achieve this behavior

legacy_mode="false"                                  # set to "true" if script won't start, this will disable some features (namely the interactive main menu and output folder suggestions)

check_for_updates="true"                             # set to "false" if you don't want to check for yt-dlp updates at startup (if true, script may take a few seconds longer to start)
get_additional_metadata="true"                       # set to "false" if you don't want to download additional metadata in Live Mode (if true, recording may take a few seconds longer to start)
download_music_cover="true"                          # set to "false" if you don't want to download the music cover image in Music Mode
overwrite_existing_files_in_restore_mode="true"     # set to "fals" if you don't want to overwrite existing files in Restore Mode
show_warning_when_ffmpeg_is_not_installed="true"     # set to "false" if you don't want to see a warning when ffmpeg is not installed
show_warning_when_ggrep_is_not_installed="true"      # set to "false" if you don't want to see a warning when ggrep is not installed (only macOS)

disable_shell_rerouting="false"                      # set to "true" if you experience a error loop when starting the script (e.g. when using Bash on Windows layers)
show_warning_when_shell_is_not_bash="true"           # set to "false" if you don't want to see a warning when the script is not executed with Bash

user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36"      # usually you don't need to change this, but if TikTok will block "old" browsers in the future you can change this to a newer user agent string



### Traps

# ensures the temporary file gets deleted on exit; reference: https://unix.stackexchange.com/a/181939
trap 'if [ -f "$tempfile" ]; then rm "$tempfile"; fi; if [ -f "$metatempfile" ]; then rm "$metatempfile"; fi' 0 2 3 15


### Functions

## define select menu function
# originally written by Alexander Klimetschek: https://unix.stackexchange.com/questions/146570/arrow-key-enter-menu
# adated by RobertMcReed: https://gist.github.com/RobertMcReed/05b2dad13e20bb5648e4d8ba356aa60e
# some modifications by me

# shellcheck disable=SC1087,SC2059,SC2034,SC2162,SC2086,SC2162,SC2155,SC2006,SC2004,SC2053,SC2154
function select_option {
  #local header="\nAdd A Header\nWith\nAs Many\nLines as you want"      # uncommented
  #header+="\n\nPlease choose an option:\n\n"       # uncommented
  #printf "$header"     # uncommented
	options=("$@")

	# helpers for terminal print control and key input
	ESC=$(printf "\033")
	cursor_blink_on()	{ printf "$ESC[?25h"; }
	cursor_blink_off()	{ printf "$ESC[?25l"; }
	cursor_to()			{ printf "$ESC[$1;${2:-1}H"; }
    print_option()      { printf "  $1 "; }     # reverted to original code
    print_selected()    { printf " $ESC[7m $ESC[1;105m$1 $ESC[27m$ESC[0m"; }   # reverted to original code, changed font color from white to purple
	get_cursor_row()	{ IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
  key_input() {
    local key
    # read 3 chars, 1 at a time
    for ((i=0; i < 3; ++i)); do
      read -s -n1 input 2>/dev/null >&2
      # concatenate chars together
      key+="$input"
      # if a number is encountered, echo it back
      if [[ $input =~ ^[1-9]$ ]]; then
        echo $input; return;
      # if enter, early return
      elif [[ $input = "" ]]; then
        echo enter; return;
      # if we encounter something other than [1-9] or "" or the escape sequence
      # then consider it an invalid input and exit without echoing back
      elif [[ ! $input = $ESC && i -eq 0 ]]; then
        return
      fi
    done

    if [[ $key = $ESC[A ]]; then echo up; fi;
    if [[ $key = $ESC[B ]]; then echo down; fi;
  }
  function cursorUp() { printf "$ESC[A"; }
  function clearRow() { printf "$ESC[2K\r"; }
  function eraseMenu() {
    cursor_to $lastrow
    clearRow
    numHeaderRows=$(printf "$header" | wc -l)
    numOptions=${#options[@]}
    numRows=$(($numHeaderRows + $numOptions))
    for ((i=0; i<$numRows; ++i)); do
      cursorUp; clearRow;
    done
  }

	# initially print empty new lines (scroll down if at bottom of screen)
	for opt in "${options[@]}"; do printf "\n"; done

	# determine current screen position for overwriting the options
	local lastrow=`get_cursor_row`
	local startrow=$(($lastrow - $#))
    local selected=0

	# ensure cursor and input echoing back on upon a ctrl+c during read -s
	trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
	cursor_blink_off

	while true; do
    # print options by overwriting the last lines
		local idx=0
    for opt in "${options[@]}"; do
      cursor_to $(($startrow + $idx))
      # add an index to the option
      local label="$(($idx + 1)). $opt"
      if [ $idx -eq $selected ]; then
        print_selected "$label"
      else
        print_option "$label"
      fi
      ((idx++))
    done

		# user key control
    input=$(key_input)

		case $input in
			enter) break;;
      [1-9])
        # If a digit is encountered, consider it a selection (if within range)
        if [ $input -lt $(($# + 1)) ]; then
          selected=$(($input - 1))
          break
        fi
        ;;
			up)	((selected--));
					if [ $selected -lt 0 ]; then selected=$(($# - 1)); fi;;
			down)  ((selected++));
					if [ $selected -ge $# ]; then selected=0; fi;;
		esac
	done

    # eraseMenu          # uncommented
    echo ""              # added
	cursor_blink_on

	return $selected
}


### define jumpto function, used to jump from "restore from backup?" directly to renaming the files
# source: https://stackoverflow.com/questions/9639103/is-there-a-goto-statement-in-bash

function jumpto
{
	label=$1
	# shellcheck disable=SC2086
	cmd=$(gsed -n "/$label:/{:a;n;p;ba};" $0 | grep -v ':$')
	eval "$cmd"
	exit
}



## function: single mode
function single_mode() {

    url=""
    username=""
    videoid=""
    output_name=""

    # print an empty line
    echo ""

    # ask the user for the URL
    read -rep $'\033[1;95mEnter URL: \033[0m' url

    # if the input is empty, "q", "quit" or "exit", exit the program
    if [[ $url == "" ]] || [[ $url == "exit" ]] || [[ $url == "quit" ]] || [[ $url == "q" ]]
    then
        echo ""
        exit 0
    fi

    # if the input is "b" or "back", go back to the main menu
    if [[ $url == "b" ]] || [[ $url == "back" ]]
    then
        echo ""
        main_menu
    fi

    # if the URL starts with "https://vm.tiktok.com/" get the redirect URL
        if [[ $url == "https://vm.tiktok.com/"* ]]; then
            url=$(curl -Ls -o /dev/null -w %{url_effective} "$url")
        fi

    # if the URL contains a "?" remove it and everything after it
    if [[ $url == *"?"* ]]; then
        url=$(echo "$url" | cut -d'?' -f1)
    fi

    # strip spaces from the URL
    url=$(echo "$url" | tr -d '[:space:]')

    # from the variable videourl extract the part between "@" and "/" and save it in the variable username
    username=$(echo "$url" | cut -d'@' -f2 | cut -d'/' -f1)

    # print the username
    echo "  Username: $username"

    # from the varable videourl extract the part after the last / and save it in the variable videoid
    videoid=$(echo "$url" | rev | cut -d'/' -f1 | rev)

    # print the videoid
    echo "  Video ID: $videoid"

    # create a new variable output_name with the following pattern: username_videoid.mp4
    output_name="${username}_${videoid}.mp4"


    # print the videoname
    echo "  Output File: $output_name"


    # check if the video already exists
    if [[ -f "$output_folder/$output_name" ]]
    then

        get_file_size=$(wc -c "$output_folder/$output_name" | awk '{print $1}')

        # if file size is less than 30 KB, delete the file and download the video again
        if [[ $get_file_size -lt 30000 ]]
        then

            rm "$output_folder/$output_name"

            echo "  Retry downloading file..."

        else

            # if yes, print a message and skip the video
            echo "  Video already exists. Skipping..."

            # run the function again
            single_mode

        fi
    fi

    # download the video using yt-dlp
    "${ytdlp_path}" -q "$url" -o "$output_folder/$output_name" --add-metadata --embed-subs

    # check if the video was downloaded successfully
        if [[ ! -f "$output_folder/$output_name" ]]
        then 
            # if no, print an error message
            echo -e "\033[1;91m  Download failed.\033[0m"
        fi

    # run the function again
    single_mode

}

## function: batch mode
function batch_mode() {

    file_path=""
    current_video=1
    total_videos=1

    # ask the user to enter the path to the file
    echo -e "\n\033[1;95mEnter the path to a text file with all links:\033[0m"
    read -rep $'\033[1;95m> \033[0m' file_path

    # if the input is empty, "q", "quit" or "exit", exit the program
    if [[ $file_path == "" ]] || [[ $file_path == "exit" ]] || [[ $file_path == "quit" ]] || [[ $file_path == "q" ]]
    then
        echo ""
        exit 0
    fi

    # if the input is "b" or "back", go back to the main menu
    if [[ $file_path == "b" ]] || [[ $file_path == "back" ]]
    then
        echo ""
        main_menu
    fi

    # if the input isn't a txt file, print an error message and restart the function
    if [[ ! $file_path == *.txt ]]
    then
        echo -e "\033[1;91mError: The file must be a .txt file.\033[0m"
        echo ""
        batch_mode
    fi

    # if the input doesn't exist, print an error message and restart the function
    if [[ ! -f "$file_path" ]]
    then
        echo -e "\033[1;91mError: The file doesn't exist.\033[0m"
        echo ""
        batch_mode
    fi

    # get the number of non-empty lines in the file
    total_videos=$(grep -c . "$file_path")

    # for each line in the file
    while IFS= read -r line
    do

        url=""
        username=""
        videoid=""
        output_name=""

        # if the line is empty, skip it
        if [[ $line == "" ]]; then
            continue
        fi

        # if the URL starts with "https://vm.tiktok.com/" get the redirect URL
        if [[ $line == "https://vm.tiktok.com/"* ]]; then
            line=$(curl -Ls -o /dev/null -w %{url_effective} "$line")
        fi

        # if the URL contains a "?" remove it and everything after it
        if [[ $line == *"?"* ]]; then
            url=$(echo "$line" | cut -d'?' -f1)
        else
            url="$line"
        fi

        # print an empty line
        echo ""

        # strip spaces from the URL
        url=$(echo "$url" | tr -d '[:space:]')

        # print the current video number and the total number of videos
        echo "  Video $current_video of $total_videos"

        # from the variable videourl extract the part between "@" and "/" and save it in the variable username
        username=$(echo "$url" | cut -d'@' -f2 | cut -d'/' -f1)

        # print the username
        echo "  Username: $username"

        # from the varable videourl extract the part after the last / and save it in the variable videoid
        videoid=$(echo "$url" | rev | cut -d'/' -f1 | rev)

        # print the videoid
        echo "  Video ID: $videoid"

        # create a new variable output_name with the following pattern: username_videoid.mp4
        output_name="${username}_${videoid}.mp4"

        # print the videoname
        echo "  Output File: $output_name"

        # check if the video already exists
        if [[ -f "$output_folder/$output_name" ]]
        then

            get_file_size=$(wc -c "$output_folder/$output_name" | awk '{print $1}')

            # if file size is less than 30 KB, delete the file and download the video again
            if [[ $get_file_size -lt 30000 ]]
            then

                rm "$output_folder/$output_name"

                echo "  Retry downloading file..."

            else

                # if yes, print a message and skip the video
                echo "  Video already exists. Skipping..."

                # increase the current video number by 1
                current_video=$((current_video+1))

                continue

            fi
        fi

        # download the video using yt-dlp
        "${ytdlp_path}" -q "$url" -o "$output_folder/$output_name" --add-metadata --embed-subs


        # check if the video was downloaded successfully
        if [[ ! -f "$output_folder/$output_name" ]]
        then

            # if no, print an error message
            echo -e "\033[1;91m  Download failed.\033[0m"
        else
            # if yes, print success message
            echo -e "\033[1;92m  Success.\033[0m"
        fi

        # increase the current video number by 1
        current_video=$((current_video+1))

        # when current_video is divisible by 10: wait 3 seconds to prevent rate limiting
        if [[ $((current_video % 10)) == 0 ]]
        then
            sleep 3
        fi


    done < "$file_path"


    # print an empty line
    echo ""
    

    # run the function again
    batch_mode

}

## function: (batch) restore mode
function restore_mode() {

    file_path=""
    current_video=1
    total_videos=1

    # ask the user to enter the path to the file
    echo -e "\n\033[1;95mEnter the path to a text file with all links:\033[0m"
    read -rep $'\033[1;95m> \033[0m' file_path

    # if the input is empty, "q", "quit" or "exit", exit the program
    if [[ $file_path == "" ]] || [[ $file_path == "exit" ]] || [[ $file_path == "quit" ]] || [[ $file_path == "q" ]]
    then
        echo ""
        exit 0
    fi

    # if the input is "b" or "back", go back to the main menu
    if [[ $file_path == "b" ]] || [[ $file_path == "back" ]]
    then
        echo ""
        main_menu
    fi

    # if the input isn't a txt file, print an error message and restart the function
    if [[ ! $file_path == *.txt ]]
    then
        echo -e "\033[1;91mError: The file must be a .txt file.\033[0m"
        echo ""
        batch_mode
    fi

    # if the input doesn't exist, print an error message and restart the function
    if [[ ! -f "$file_path" ]]
    then
        echo -e "\033[1;91mError: The file doesn't exist.\033[0m"
        echo ""
        batch_mode
    fi

    # get the number of non-empty lines in the file
    total_videos=$(grep -c . "$file_path")

    # for each line in the file
    while IFS= read -r line
    do

        url=""
        username=""
        videoid=""
        output_name=""
        error_message=""

        # if the line is empty, skip it
        if [[ $line == "" ]]; then
            # echo "DEBUG: Skipping line '$line'"
            continue
        fi

        # print an empty line
        echo ""


        # if line doesn't end with ".mp4", append ".mp4"
        if [[ ! "${line}" =~ \.mp4$ ]]; then
            line="${line}.mp4"
        fi

        # echo -e "DEBUG: $line"

        # check if the line is in the correct format: <a-z, A-Z, 0-9, .>_<bunch of numbers>.mp4
        if [[ "$line" =~ ^[a-zA-Z0-9.]*_[0-9]*.mp4$ ]]
        then

            # get the username and video id from the line
            username=$(echo "$line" | cut -d'_' -f1)
            videoid=$(echo "$line" | cut -d'_' -f2 | cut -d'.' -f1)

            # create the url
            url="https://www.tiktok.com/@$username/video/$videoid"

            # create the output name (should result in the same as the input)
            output_name="$username"_"$videoid".mp4

        else

            # if the line is in the wrong format, print an error message
            echo -e "\033[1;91mError: The line \"$line\" is in the wrong format.\033[0m"

            continue

        fi


        # print the current video number and the total number of videos
        echo "  Video $current_video of $total_videos"

        # from the variable videourl extract the part between "@" and "/" and save it in the variable username
        username=$(echo "$url" | cut -d'@' -f2 | cut -d'/' -f1)

        # print the username
        echo "  Username: $username"

        # from the varable videourl extract the part after the last / and save it in the variable videoid
        videoid=$(echo "$url" | rev | cut -d'/' -f1 | rev)

        # print the videoid
        echo "  Video ID: $videoid"

        # create a new variable output_name with the following pattern: username_videoid.mp4
        output_name="${username}_${videoid}.mp4"

        # print the videoname
        echo "  Output File: $output_name"


        
        # check if the video already exists
        if [[ -f "$output_folder/$output_name" ]]
        then

            # if overwrite_existing_files_in_restore_mode is true
            if [[ $overwrite_existing_files_in_restore_mode == true ]]
            then

                rm "$output_folder/$output_name"

                echo "  Existing file deleted. Retry downloading file..."

            else

                echo "  File already exists. Skipping..."
                continue

            fi

        fi


        # download the video using yt-dlp, catch the error message and save it in the variable error_message
        error_message=$("${ytdlp_path}" -q "$url" -o "$output_folder/$output_name" --add-metadata --embed-subs 2>&1)

        # check if the error message contains "Unable to find video in feed"
        if [[ $error_message == *"HTTP Error 404"* ]]
        then

            # if yes, print an error message
            echo -e "\033[1;91m  Video is not/no longer available.\033[0m"

        elif [[ $error_message == *"Unable to find video in feed"* ]]
        then

            # if yes, print an error message
            echo -e "\033[1;91m  Download failed. Unable to find video in feed.\033[0m"

        else

            # check if the video was downloaded successfully
            if [[ ! -f "$output_folder/$output_name" ]]
            then

                # if no, print an error message
                echo -e "\033[1;91m  Download failed.\033[0m"
            else
                # if yes, print a success message
                echo -e "\033[1;92m  Success.\033[0m"
            fi

        fi

        # increase the current video number by 1
        current_video=$((current_video+1))

        # when current_video is divisible by 10: wait 3 seconds to prevent rate limiting
        if [[ $((current_video % 10)) == 0 ]]
        then
            sleep 3
        fi


    done < "$file_path"


    # print an empty line
    echo ""
    

    # run the function again
    restore_mode

}

## function: avatar mode
function avatar_mode() {

    username=""
    userurl=""
    avatarurl=""
    output_name=""


    # ask user for TikTok username
    echo -e "\n\033[1;95mEnter TikTok username or profile URL: \033[0m"
    read -rep $'\033[1;95m> \033[0m' username

    # if the input is empty, "q", "quit" or "exit", exit the program
    if [[ $username == "" ]] || [[ $username == "exit" ]] || [[ $username == "quit" ]] || [[ $username == "q" ]]
    then
        echo ""
        exit 0
    fi

    # if the input is "b" or "back", go back to the main menu
    if [[ $username == "b" ]] || [[ $username == "back" ]]
    then
        echo ""
        main_menu
    fi

    # if the username doesn't start with "https://www.tiktok.com/@" prepend it to the username; save it to userurl
    if [[ $username == "https://www.tiktok.com/@"* ]]; then

        # if the username contains a "?" remove it and everything after it
        if [[ $username == *"?"* ]]; then
            userurl=$(echo "$username" | cut -d'?' -f1)
        else
            userurl="$username"
        fi

        # directly pass the input to the destination variable
        userurl="$username"

        # now edit the username variable to only contain the username
        username=${username#"https://www.tiktok.com/@"}

    else

        userurl="https://www.tiktok.com/@$username"

    fi

    # create a temporary file in the current directory
    tempfile=$(mktemp "${BASEDIR}/ttd-ava.XXXXXX")

    # use curl to get the html source code of the user's profile page and save it to the temporary file
    # The user agent is needed, as TkikTok will only show a blank page if curl doesn't pretend to be a browser.
    curl "$userurl" -s -A "${user_agent}" > "$tempfile"

    # in the temporary file, look for the JSON object that contains "avatarLarger" and save that value to avatarurl

    # if "ggrep" is installed, use it, otherwise use "grep"
    if command -v ggrep &> /dev/null
    then
        avatarurl=$(ggrep -oP '(?<="avatarLarger":")[^"]*' "$tempfile")
    else
        avatarurl=$(grep -oP '(?<="avatarLarger":")[^"]*' "$tempfile")
    fi

    # in avatarurl, replace all occurrences of "\u002F" with "/"
    avatarurl=${avatarurl//\\u002F/\/}

    # if the file already exists, add a number to the end of the output name
    if [[ -f "$output_folder/$username.jpg" ]]
    then

        # create a new variable output_name with the following pattern: username_videoid.mp4
        output_name="${username}_$(date +%s).jpg"

        # print a message
        echo "  \033[93m$username.jpg already exists\033[0m"
        echo "  File Name: $output_name"

    else

        # create a new variable output_name with the following pattern: username.jpg
        output_name="${username}.jpg"

        # print a message
        echo "  File Name: $output_name"        

    fi

    # download the avatar image to username.jpg
    curl "$avatarurl" -s -A "${user_agent}" -o "$output_folder/$output_name"

    # check if the image was downloaded successfully
    if [[ ! -f "$output_folder/$output_name" ]]
    then
        # if no, print an error message
        echo -e "\033[1;91mDownload failed.\033[0m"
    else
        # if yes, print success message
        echo -e "\033[1;92m  Success.\033[0m"
    fi

    # delete the temporary file
    rm "$tempfile"

    # print an empty line
    echo ""

    # repeat the function
    avatar_mode


}


## function: live mode
function live_mode() {

    username=""
    liveurl=""
    roomid=""
    jsondata=""
    playlisturl=""
    playlisturl_workaround=""
    flvurl=""
    live_title=""
    description=""
    datetime=""
    output_name=""
    recording_end_time=""
    # ffmpeg_pid=""

    # print an empty line
    echo ""

    # ask user for TikTok username
    echo -e "\n\033[1;95mEnter TikTok username or profile URL: \033[0m"
    read -rep $'\033[1;95m> \033[0m' username

    # if the input is empty, "q", "quit" or "exit", exit the program
    if [[ $username == "" ]] || [[ $username == "exit" ]] || [[ $username == "quit" ]] || [[ $username == "q" ]]
    then
        echo ""
        exit 0
    fi

    # if the input is "b" or "back", go back to the main menu
    if [[ $username == "b" ]] || [[ $username == "back" ]]
    then
        echo ""
        main_menu
    fi

    # if the URL starts with "https://vm.tiktok.com/" get the redirect URL
    if [[ $username == "https://vm.tiktok.com/"* ]]; then
        username=$(curl -Ls -o /dev/null -w %{url_effective} "$username")
    fi

    # if the URL contains a "?" remove it and everything after it
    if [[ $username == *"?"* ]]; then
        username=$(echo "$username" | cut -d'?' -f1)
    fi

    # strip spaces from the URL
    username=$(echo "$username" | tr -d '[:space:]')


    # if the URL starts with "https://www.tiktok.com/@", extract the username
    if [[ $username == "https://www.tiktok.com/@"* ]] || [[ $username == "https://tiktok.com/@"* ]]; then

        username=$(echo "$username" | cut -d'@' -f2 | cut -d'/' -f1)

    fi

    echo ""

    # print the username
    echo "  Username: $username"

    # build the live URL
    liveurl="https://www.tiktok.com/@$username/live"

    # print the videoid
    echo "  Live URL: $liveurl"

    # create a temporary file in the current directory
    tempfile=$(mktemp "${BASEDIR}/ttd-live.XXXXXX")

    # use curl to get the html source code of the live page and save it to the temporary file
    # The user agent is needed, as TkikTok will only show a blank page if curl doesn't pretend to be a browser.
    { curl "$liveurl" -s -A "${user_agent}" > "$tempfile" ; } || { echo -e "\033[1;91mError: Couldn't get Room ID.\033[0m"; echo ""; live_mode; }

    # in the temporary file, look for the JSON object that contains "avatarLarger" and save that value to avatarurl

    # if "ggrep" is installed, use it, otherwise use "grep"
    if command -v ggrep &> /dev/null
    then
        roomid=$(ggrep -oP '(?<="roomId":")[^"]*' "$tempfile")
    else
        roomid=$(grep -oP '(?<="roomId":")[^"]*' "$tempfile")
    fi

    # cut the roomid at the first special character
    #roomid=$(echo "$roomid" | cut -d'?' -f1)

    # cut the roomid before the first space
    #roomid=$(echo "$roomid" | cut -d' ' -f1)

    # the roomid probably contains the variable of interest multiple times, so we only want the first one
    roomid=$(echo "$roomid" | head -n 1)

    # print the room id
    echo "  Room ID: $roomid"

    # status message: getting live infos
    echo -ne "  \033[5mRetrieving live infos...\033[25m\033[0m"

    # write the response of "https://www.tiktok.com/api/live/detail/?aid=1988&roomID=${roomId}" to jsondata
    jsondata=$(curl "https://www.tiktok.com/api/live/detail/?aid=1988&roomID=${roomid}" -s -A "${user_agent}")

    # replace temporary file with jsondata
    echo "$jsondata" > "$tempfile"

    # store the JSON object LiveRoomInfo.liveUrl in playlisturl
    playlisturl=$(echo "$jsondata" | jq -r '.LiveRoomInfo.liveUrl')

    # if the playlisturl is empty, print an error message and exit the function
    if [[ $playlisturl == "" ]]
    then
        echo -e "\033[1;91m\n  Error: Live stream not found.\033[0m"
        echo ""
        live_mode
    fi

    # FIX: I added this workaround because there is no FLV equivalent to playlist.m3u8, but as of now (2022-10-29) you can convert the URL back to the old type.
    #
    # if the playlisturl ends with playlist.m3u8, print a warning "Additional metadata will not be downloaded."
    # if [[ $playlisturl == *"playlist.m3u8" ]]
    # then
    #     # reset status message
    #     echo -ne "\r\033[K"

    #     echo -e "\033[93m  Additional metadata .\033[0m"
    # fi

    # if playlisturl ends with playlist.m3u8
    if [[ $playlisturl == *"playlist.m3u8" ]]
    then

        playlisturl_workaround=$playlisturl

        # replace pull-hls-f1-va01 with pull-hls-f11-va01
        playlisturl_workaround=${playlisturl_workaround/pull-hls-f1-va01/pull-hls-f11-va01}

        # replace or4/playlist.m3u8 with or4.m3u8
        playlisturl_workaround=${playlisturl_workaround/or4\/playlist.m3u8/or4.m3u8}


        # get the flvurl, by replacing "https" with "http" and ".m3u8" with ".flv" in playlisturl
        # source: https://github.com/Pauloo27/tiktok-live/blob/master/index.js
        flvurl=${playlisturl_workaround/https/http}
        flvurl=${flvurl/.m3u8/.flv}

    else

        # get the flvurl, by replacing "https" with "http" and ".m3u8" with ".flv" in playlisturl
        # source: https://github.com/Pauloo27/tiktok-live/blob/master/index.js
        flvurl=${playlisturl/https/http}
        flvurl=${flvurl/.m3u8/.flv}

    fi



    # store the JSON object LiveRoomInfo.title in live_title
    live_title=$(echo "$jsondata" | jq -r '.LiveRoomInfo.title')

    # reset status message
    echo -ne "\r\033[K"

    # if the playlist URL is empty, something went wrong. Abort.
    if [[ $playlisturl == "" ]]
    then

        echo -e "\n\033[1;91mError: Couldn't get playlist URL.\033[0m"
        echo -e "\033[91mThis live might be over, but sometimes TikTok doesn't allow accessing the stream via public API. Try again later. \033[0m"
        echo ""
        live_mode

    else

        # print the playlist URL
        echo "  Playlist URL: $playlisturl"

        # if playlisturl_workaround is set, print it
        if [[ $playlisturl_workaround != "" ]]
        then
            echo "  Playlist URL (workaround): $playlisturl_workaround"
        fi

    fi

    # print the live title
    # if the title is empty, print "No title"
    if [[ $live_title == "" ]]
    then
        echo "  Stream Title: The host has not set a title."
    else
        echo "  Stream Title: $live_title"
    fi

    # get the current date and time in format YYYY-MM-DD_HHMM
    datetime=$(date +"%Y-%m-%d_%H%M")


    # output file extension
    outputext="mp4"             # default is .mp4, source is .ts

    # generate the filename: username_datetime.mp4
    output_name="${username}_${datetime}.${outputext}"

    # print the filename
    echo "  Output File: $output_name"



    echo -ne "\n  Downloading...\n\033[90m  Press ctrl+c to stop.\033[0m"

    # trap ctrl+c and call live_ctrl_c()
    # trap live_ctrl_c INT

    description="User: $username\nRoom ID: $roomid\nLive Title: $live_title"

    # get metadata if get_additional_metadata is true and the playlist URL is in old format (doesn't end with playlist.m3u8)
    if [[ $get_additional_metadata == true ]] && [[ $playlisturl != *"playlist.m3u8" ]]
    then

        start_time=""

        model=""
        platform=""
        os_version=""

        # create a temporary file in the current directory
        metatempfile=$(mktemp "${BASEDIR}/ttd-meta.XXXXXX")

        "${ffmpeg_path}" -y -hide_banner -loglevel quiet -i "$flvurl" -f ffmetadata "$metatempfile"

        # if OS is macOS, use ggrep, otherwise use grep; example: '(?<=model=).+' matches everything after "model="
        if [[ $OSTYPE == "darwin"* ]]
        then
            start_time=$(ggrep -oP '(?<=start_time=).+' "$metatempfile")
            # echo "DEBUG: original start_time: $start_time"
            model=$(ggrep -oP '(?<=model=).+' "$metatempfile")
            platform=$(ggrep -oP '(?<=platform=).+' "$metatempfile")
            os_version=$(ggrep -oP '(?<=os_version=).+' "$metatempfile")
        else
            start_time=$(grep -oP '(?<=start_time=).+' "$metatempfile")
            model=$(grep -oP '(?<=model=).+' "$metatempfile")
            platform=$(grep -oP '(?<=platform=).+' "$metatempfile")
            os_version=$(grep -oP '(?<=os_version=).+' "$metatempfile")
        fi


        # add metadata to description, if it's not empty
        if [[ $start_time != "" ]]
        then

            # divide start_time by 1000
            start_time=$(echo "$start_time" | awk '{print $1/1000}')
            #echo "DEBUG: start_time/1000: $start_time"

            # convert start_time to integer
            start_time=$(printf "%.0f" "$start_time")
            # echo "DEBUG: start_time as integer: $start_time"

            # convert the start time from epoch to human readable format
            start_time=$(date -r $start_time +"%Y-%m-%d %H:%M:%S")
            # echo "DEBUG: start_time human readable: $start_time"

            description="$description\nLive Start Time: $start_time"
        fi

        if [[ $model != "" ]]
        then
            description="$description\n\nDevice Information:\n Model: $model"
        fi

        if [[ $platform != "" ]]
        then
            description="$description\n Platform: $platform"
        fi

        if [[ $os_version != "" ]]
        then
            description="$description\n OS Version: $os_version"
        fi


        # delete the temporary file
        # rm "$metatempfile"

    fi

    beginrecording: &> /dev/null

    # use ffmpeg to download the video
    # if outputext is mp4
    if [[ $outputext == "mp4" ]]
    then
        "${ffmpeg_path}" -y -hide_banner -loglevel quiet -i "$playlisturl" -bsf:a aac_adtstoasc -map_metadata 0 -metadata description="$description" "$output_folder/$output_name"
        # & ffmpeg_pid=$!
        # wait $ffmpeg_pid
    else
        "${ffmpeg_path}" -y -hide_banner -loglevel quiet -i "$playlisturl" -map_metadata 0 -metadata description="$description" "$output_folder/$output_name"
        # & ffmpeg_pid=$!
        # wait $ffmpeg_pid
    fi

    # reset trap
    # trap - INT

    # jump point for ctrl+c
    livestopped: &> /dev/null

    # echo "ffmpeg PID: $!"

    echo ""

    # reset status message
    echo -ne "\r\033[K"

    # write new status message
    # reset status message
    echo -ne "  \033[90mRecording stopped. Checking if download was successful...\033[0m"

    # get current time in HH:MM:SS
    recording_end_time=$(date +"%T")

    



    # delete the temporary file
    rm "$tempfile"


    # check if the video was downloaded successfully
    if [[ ! -f "$output_folder/$output_name" ]]
    then
    
        # reset status message
        echo -ne "\r\033[K"
        echo ""

        # if no, print an error message
        echo -e "\033[1;91m  Download failed. No file was saved.\033[0m"

        # try again with playlisturl_workaround
        if [[ $playlisturl_workaround != "" ]]
        then

            # maybe we have a workaround
            echo -e "\033[93m  Trying again with a workaround...\033[0m"

            # set playlisturl to playlisturl_workaround
            playlisturl="$playlisturl_workaround"

            # clear playlisturl_workaround, so we don't try a third time
            playlisturl_workaround=""

            # jump to beginrecording
            jumpto beginrecording

        fi


    else

        # reset status message
        echo -ne "\r\033[K"
        echo ""

        # print the time when the download ended
        echo -e "  The recording ended at $recording_end_time."

        # if ffprobe is installed, print the duration of the video
        if command -v "${ffprobe_path}" &> /dev/null
        then

            # get the duration of the video
            duration=$("${ffprobe_path}" -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$output_folder/$output_name")

            # convert the duration to integer
            duration=${duration%.*}

            # if OS is macOS, use another command to convert the duration to human readable format
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # run this hell of a command to convert the duration to HH:MM:SS
                duration="$(date -ju -f %s $duration "+%H:%M:%S")"
            else
                # run this other hell of a command to convert the duration to HH:MM:SS
                duration="$(date -d@$duration -u +%H:%M:%S)"
            fi


            echo -e "  \033[92mDuration of recording: $duration\033[0m"

        fi

    fi

    # run the function again
    live_mode

}



## function: avatar mode
function music_mode() {

    musicurl=""
    playurl=""
    title=""
    author=""
    album=""
    duration=""
    coverurl=""
    filename_pattern=""
    m4a_filename=""
    jpg_filename=""


    # ask user for TikTok username
    echo -e "\n\033[1;95mEnter TikTok sound/music URL: \033[0m"
    read -rep $'\033[1;95m> \033[0m' musicurl

    # if the input is empty, "q", "quit" or "exit", exit the program
    if [[ $musicurl == "" ]] || [[ $musicurl == "exit" ]] || [[ $musicurl == "quit" ]] || [[ $musicurl == "q" ]]
    then
        echo ""
        exit 0
    fi

    # if the input is "b" or "back", go back to the main menu
    if [[ $musicurl == "b" ]] || [[ $musicurl == "back" ]]
    then
        echo ""
        main_menu
    fi

    # if the URL starts with "https://vm.tiktok.com/" get the redirect URL
    if [[ $musicurl == "https://vm.tiktok.com/"* ]]; then
        musicurl=$(curl -Ls -o /dev/null -w %{url_effective} "$musicurl")
    fi

    # if the URL doesn't start with "https://www.tiktok.com/music/", tell the user that the URL is invalid and repeat the function
    if [[ $musicurl != "https://www.tiktok.com/music/"* ]]; then
        echo -e "\n\033[1;91mInvalid URL!\033[0m"
        echo -e" \033[91mURL has to start with 'https://www.tiktok.com/music/'\033[0m"
        echo ""
        music_mode
    fi

    # if the musicurl contains a "?" remove it and everything after it
    if [[ $musicurl == *"?"* ]]; then
        userurl=$(echo "$musicurl" | cut -d'?' -f1)
    else
        userurl=$musicurl
    fi

    # create a temporary file in the current directory
    tempfile=$(mktemp "${BASEDIR}/ttd-music.XXXXXX")

    # use curl to get the html source code of the music page and save it to the temporary file
    # The user agent is needed, as TkikTok will only show a blank page if curl doesn't pretend to be a browser.
    curl "$userurl" -s -A "${user_agent}" > "$tempfile"

    
    # if "ggrep" is installed, use it, otherwise use "grep"
    if command -v ggrep &> /dev/null
    then  
        
        # in the temporary file, look for the JSON object MusicModule.musicInfo.music.playUrl and save that value to playurl
        playurl=$(ggrep -oP '(?<="playUrl":")[^"]*' "$tempfile")
        # the result contains the desired vlue multiple times, so we only want the first one
        playurl=$(echo "$playurl" | head -n 1)
        # in playurl, replace all occurrences of "\u002F" with "/"
        playurl=${playurl//\\u002F/\/}


        # if download_music_cover is true
        if [[ $download_music_cover == true ]]
        then

            # in the temporary file, look for the JSON object MusicModule.musicInfo.music.coverLarge and save that value to playurl
            coverurl=$(ggrep -oP '(?<="coverLarge":")[^"]*' "$tempfile")
            # the result contains the desired vlue multiple times, so we only want the first one
            coverurl=$(echo "$coverurl" | head -n 1)
            # in coverurl, replace all occurrences of "\u002F" with "/"
            coverurl=${coverurl//\\u002F/\/}

        fi



        # in the temporary file, look for the JSON object MusicModule.musicInfo.music.title and save that value to title
        title=$(ggrep -oP '(?<="title":")[^"]*' "$tempfile")
        # the result contains the desired vlue multiple times, look for the second one
        title=$(echo "$title" | head -n 2 | tail -n 1)

        # in the temporary file, look for the JSON object MusicModule.musicInfo.music.authorName and save that value to author
        author=$(ggrep -oP '(?<="authorName":")[^"]*' "$tempfile")
        # the result contains the desired vlue multiple times, look for the first one
        author=$(echo "$author" | head -n 1)

        # in the temporary file, look for the JSON object MusicModule.musicInfo.music.album and save that value to album
        album=$(ggrep -oP '(?<="album":")[^"]*' "$tempfile")
        # the result contains the desired vlue multiple times, look for the first one
        album=$(echo "$album" | head -n 1)

        # in the temporary file, look for the JSON object MusicModule.musicInfo.music.duration and save that value to duration, only get numeric characters
        duration=$(ggrep -oP '(?<="duration":)[0-9]*' "$tempfile" | head -n 1)

    else
        
        # in the temporary file, look for the JSON object MusicModule.musicInfo.music.playUrl and save that value to playurl
        playurl=$(grep -oP '(?<="playUrl":")[^"]*' "$tempfile")
        # the result contains the desired vlue multiple times, so we only want the first one
        playurl=$(echo "$playurl" | head -n 1)
        # in playurl, replace all occurrences of "\u002F" with "/"
        playurl=${playurl//\\u002F/\/}

        # if download_music_cover is true
        if [[ $download_music_cover == true ]]
        then

            # in the temporary file, look for the JSON object MusicModule.musicInfo.music.coverLarge and save that value to playurl
            coverurl=$(grep -oP '(?<="coverLarge":")[^"]*' "$tempfile")
            # the result contains the desired vlue multiple times, so we only want the first one
            coverurl=$(echo "$coverurl" | head -n 1)
            # in coverurl, replace all occurrences of "\u002F" with "/"
            coverurl=${coverurl//\\u002F/\/}


        fi

        # in the temporary file, look for the JSON object MusicModule.musicInfo.music.title and save that value to title
        title=$(grep -oP '(?<="title":")[^"]*' "$tempfile")
        # the result contains the desired vlue multiple times, look for the second one
        title=$(echo "$title" | head -n 2 | tail -n 1)

        # in the temporary file, look for the JSON object MusicModule.musicInfo.music.authorName and save that value to author
        author=$(grep -oP '(?<="authorName":")[^"]*' "$tempfile")
        # the result contains the desired vlue multiple times, look for the first one
        author=$(echo "$author" | head -n 1)

        # in the temporary file, look for the JSON object MusicModule.musicInfo.music.album and save that value to album
        album=$(grep -oP '(?<="album":")[^"]*' "$tempfile")
        # the result contains the desired vlue multiple times, look for the first one
        album=$(echo "$album" | head -n 1)

        # in the temporary file, look for the JSON object MusicModule.musicInfo.music.duration and save that value to duration, only get numeric characters
        duration=$(grep -oP '(?<="duration":)[0-9]*' "$tempfile" | head -n 1)

    fi

    # remove the temporary file
    rm "$tempfile"

    # check if the playurl variable is empty, if it is, tell the user that the URL is invalid and repeat the function
    if [[ -z $playurl ]]; then
        echo -e "  \n\033[1;91mError: Couldn't receive music.\033[0m"
        echo ""
        music_mode
    fi

    # check if the title variable is empty, if it is, overwrite it with "Unknown Title"
    if [[ -z $title ]]; then
        title="Unknown Title"
        echo -e "  Title: (Unknown)"
    else
        echo -e "  Title: $title"
    fi

    # check if the author variable is empty, if it is, overwrite it with "Unknown Artist"
    if [[ -z $author ]]; then
        author="Unknown Artist"
        echo -e "  Artist: (Unknown)"
    else
        echo -e "  Artist: $author"
    fi

    # check if the album variable is empty, if it is, overwrite it with "Unknown Album"
    if [[ -z $album ]]; then
        album="Unknown Album"
        echo -e "  Album: (Unknown)"
    else
        echo -e "  Album: $album"
    fi

    # print the duration
    echo -e "  Duration: $duration seconds"
    

    # if download_music_cover is true
    if [[ $download_music_cover == true ]]
    then

        # check if the coverurl variable is empty, if it is, print a message and leave the coverurl variable empty
        if [[ -z $coverurl ]]; then
            echo -e "  Couldn't receive cover art."
        else
            echo "  Cover found."
        fi

    fi


    # generate filename from Title and Author
    filename_pattern="${author} - ${title}"

    # replace all characters that are not allowed in filenames with an underscore, spaces are allowed
    filename_pattern=${filename_pattern//[^a-zA-Z0-9 -_]/_}
    # echo "DEBUG: filename_pattern: $filename_pattern"

    m4a_filename="${filename_pattern}.m4a"
    
    # if the music file already exists, add a number to the end of the output name
    if [[ -f "$output_folder/$filename_pattern.m4a" ]]
    then

        m4a_filename="${filename_pattern}_$(date +%s).m4a"

        # print a message
        echo "  \033[93m$filename_pattern.m4a already exists\033[0m"
        echo "  Music File Name: $m4a_filename"

    else

        m4a_filename="${filename_pattern}.m4a"

        # print a message
        echo "  Music File Name: $m4a_filename"        

    fi


    # if download_music_cover is true
    if [[ $download_music_cover == true ]]
    then

        jpg_filename="${filename_pattern}.jpg"

         # if the cover file already exists, add a number to the end of the output name
        if [[ -f "$output_folder/$filename_pattern.jpg" ]]
        then

            jpg_filename="${filename_pattern}_$(date +%s).jpg"

            # print a message
            echo "  \033[93m$filename_pattern.jpg already exists\033[0m"
            echo "  Cover File Name: $jpg_filename"

        else

            jpg_filename="${filename_pattern}.jpg"

            # print a message
            echo "  Cover File Name: $jpg_filename"        

        fi

        # download the cover image if the coverurl variable is not empty
        if [[ -n $coverurl ]]; then

            # echo "  DEBUG: coverurl: $coverurl"

            curl "$coverurl" -s -A "${user_agent}" -o "$output_folder/$jpg_filename"

            # check if the image was downloaded successfully
            if [[ ! -f "$output_folder/$jpg_filename" ]]
            then
                # if no, print an error message
                echo -e "  \033[1;91mCover download failed.\033[0m"
            fi

        fi

    fi


    # # if jpg_filename is not empty, set the cover art metadata
    # if [[ -f "$output_folder/$jpg_filename" ]]; then

    #     # use ffmpeg to download playurl and save it as m4a_filename, use the cover image as album art, and set the title, album and artist metadata
    #     ffmpeg -i "$playurl" -i "$output_folder/$jpg_filename" -map 0:0 -map 1:0 -c copy -metadata title="$title" -metadata album="$album" -metadata artist="$author" -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (Front)" "$output_folder/$m4a_filename"

    # else

        # use ffmpeg to download playurl and save it as m4a_filename, and set the title, album and artist metadata
        "${ffmpeg_path}" -hide_banner -loglevel quiet -i "$playurl" -c copy -metadata title="$title" -metadata album="$album" -metadata artist="$author" "$output_folder/$m4a_filename"

    # fi


    # check if the music was downloaded successfully
    if [[ ! -f "$output_folder/$m4a_filename" ]]
    then
        # if no, print an error message
        echo -e "  \033[1;91mMusic download failed.\033[0m"
    fi


    # delete the cover image if it was downloaded
    # if [[ -f "$output_folder/$jpg_filename" ]]
    # then
    #     rm "$output_folder/$jpg_filename"
    # fi

    # print an empty line
    echo ""

    # repeat the function
    music_mode


}


function live_ctrl_c() {

    # reset status message
    echo -ne "\r\033[K"

    # write new status message
    # reset status message
    echo -ne "  \033[90mReceived stop signal. Please wait...\033[0m"

    # kill ffmpeg
    # kill -9 $ffmpeg_pid || echo "ffmpeg is not running."

    jumpto livestopped

}


## function: main menu
function main_menu() {

    # if legacy mode is disabled, show the interactive selection menu
    if [[ $legacy_mode == "false" ]]
    then

       # show a selection menu with the options "single mode" "batch mode" and save the user input in the variable mode
        echo -e "\n\033[1;95mWhich mode do you want to use?\033[0m"

        modeoptions=("Single Mode" "Batch Mode" "Live Mode" "Avatar Mode" "Sound Mode" "Restore Mode" "Help" "Exit")
        select_option "${modeoptions[@]}"
        modechoice=$?

        if [[ "${modeoptions[$modechoice]}" == "Single Mode" ]]
        then
            ask_for_output_folder
            single_mode
        elif [[ "${modeoptions[$modechoice]}" == "Batch Mode" ]]
        then
            ask_for_output_folder
            batch_mode
        elif [[ "${modeoptions[$modechoice]}" == "Live Mode" ]]
        then

            # check if ffmpeg is installed
            if ! command -v "${ffmpeg_path}" &> /dev/null
            then
                echo ""
                echo -e "\033[1;91m  ffmpeg is not installed.\033[0m"
                missing_ffmpeg
                echo ""
                main_menu
            fi

            # check if jq is installed
            if ! command -v jq &> /dev/null
            then
                echo ""
                echo -e "\033[1;91m  jq is not installed.\033[0m"
                echo -e "\033[1;91m  Please install jq to use this mode.\033[0m"
                echo ""
                main_menu
            fi

            ask_for_output_folder
            live_mode

        elif [[ "${modeoptions[$modechoice]}" == "Avatar Mode" ]]
        then

            # check if OS is macOS
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # check if ggrep is installed
                if ! command -v ggrep &> /dev/null
                then
                    echo ""
                    echo -e "\033[1;91m  ggrep is not installed.\033[0m"
                    echo -e "\033[1;91m  Please install ggrep to use this mode.\033[0m"
                    echo ""
                    main_menu
                fi
            fi

            ask_for_output_folder
            avatar_mode

        elif [[ "${modeoptions[$modechoice]}" == "Sound Mode" ]]
        then

            # check if OS is macOS
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # check if ggrep is installed
                if ! command -v ggrep &> /dev/null
                then
                    echo ""
                    echo -e "\033[1;91m  ggrep is not installed.\033[0m"
                    echo -e "\033[1;91m  Please install ggrep to use this feature.\033[0m"
                    echo ""
                    main_menu
                fi
            fi

            # check if ffmpeg is installed
            if ! command -v "${ffmpeg_path}" &> /dev/null
            then
                echo ""
                echo -e "\033[1;91m  ffmpeg is not installed.\033[0m"
                missing_ffmpeg
                echo ""
                main_menu
            fi

            ask_for_output_folder
            music_mode


        elif [[ "${modeoptions[$modechoice]}" == "Restore Mode" ]]
        then
            echo -e "\033[95m\nNote: Restore Mode is used to (re)download TikToks based on the file name. Existing files will be overwritten. The input is a text file with entries in the following format: <user name>_<video id>.mp4\n\033[0m"

            ask_for_output_folder
            restore_mode
        elif [[ "${modeoptions[$modechoice]}" == "Help" ]]
        then
            help_screen
        elif [[ "${modeoptions[$modechoice]}" == "Exit" ]]
        then
            exit 0
        fi

    else

        # print a select menu witht he options "Single Mode" "Batch Mode" "Avatar Mode" "Help" "Exit"
        echo -e "\n\033[1;95mWhich mode do you want to use?\033[0m"
        echo -e " \033[95m1) Single Mode\033[0m"
        echo -e " \033[95m2) Batch Mode\033[0m"
        echo -e " \033[95m3) Live Mode\033[0m"
        echo -e " \033[95m4) Avatar Mode\033[0m"
        echo -e " \033[95m5) Sound Mode\033[0m"
        echo -e " \033[95m6) Restore Mode\033[0m"
        echo -e " \033[95m7) Help\033[0m"
        echo -e " \033[95m8) Exit\033[0m\n"

        # read the user input and save it to the variable mode
        read -rep $'\033[1;95m> \033[0m' mode

        # if the input is empty, "q", "quit" or "exit", exit the program
        if [[ $mode == "" ]] || [[ $mode == "exit" ]] || [[ $mode == "quit" ]] || [[ $mode == "q" ]]
        then
            echo ""
            exit 0
        fi

        # if the input is "1", "single mode" or "single", run the single mode function
        if [[ $mode == "1" ]] || [[ $mode == "single mode" ]] || [[ $mode == "single" ]]
        then
            ask_for_output_folder
            single_mode
        fi

        # if the input is "2", "batch mode" or "batch", run the batch mode function
        if [[ $mode == "2" ]] || [[ $mode == "batch mode" ]] || [[ $mode == "batch" ]]
        then
            ask_for_output_folder
            batch_mode
        fi

         # if the input is "3", "live mode" or "live", run the live mode function
        if [[ $mode == "3" ]] || [[ $mode == "live mode" ]] || [[ $mode == "live" ]]
        then

            # check if ffmpeg is installed
            if ! command -v "${ffmpeg_path}" &> /dev/null
            then
                echo ""
                echo -e "\033[1;91m  ffmpeg is not installed.\033[0m"
                missing_ffmpeg
                echo ""
                main_menu
            fi

            ask_for_output_folder
            live_mode

        fi

        # if the input is "4", "avatar mode" or "avatar", run the avatar mode function
        if [[ $mode == "4" ]] || [[ $mode == "avatar mode" ]] || [[ $mode == "avatar" ]]
        then

            # check if OS is macOS
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # check if ggrep is installed
                if ! command -v ggrep &> /dev/null
                then
                    echo ""
                    echo -e "\033[1;91m  ggrep is not installed.\033[0m"
                    echo -e "\033[1;91m  Please install ggrep to use this feature.\033[0m"
                    echo ""
                    main_menu
                fi
            fi

            ask_for_output_folder
            avatar_mode

        fi

        # if the input is "5", "music mode" or "music", run the music mode function
        if [[ $mode == "5" ]] || [[ $mode == "sound mode" ]] || [[ $mode == "sound" ]]
        then

            # check if OS is macOS
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # check if ggrep is installed
                if ! command -v ggrep &> /dev/null
                then
                    echo ""
                    echo -e "\033[1;91m  ggrep is not installed.\033[0m"
                    echo -e "\033[1;91m  Please install ggrep to use this feature.\033[0m"
                    echo ""
                    main_menu
                fi
            fi

            # check if ffmpeg is installed
            if ! command -v "${ffmpeg_path}" &> /dev/null
            then
                echo ""
                echo -e "\033[1;91m  ffmpeg is not installed.\033[0m"
                missing_ffmpeg
                echo ""
                main_menu
            fi

            ask_for_output_folder
            music_mode

        fi

        # if the input is "6", "restore mode" or "restore", run the restore mode function
        if [[ $mode == "6" ]] || [[ $mode == "restore mode" ]] || [[ $mode == "restore" ]]
        then        
            echo -e "\033[95m\nNote: Restore Mode is used to (re)download TikToks based on the file name. Existing files will be overwritten. The input is a text file with entries in the following format: <user name>_<video id>.mp4\n\033[0m"

            ask_for_output_folder
            restore_mode
        fi

        # if the input is "7", "help" or "h", run the help screen function
        if [[ $mode == "7" ]] || [[ $mode == "help" ]] || [[ $mode == "h" ]]
        then
            help_screen
        fi

        # if the input is "8", "exit" or "q", exit the program
        if [[ $mode == "8" ]] || [[ $mode == "exit" ]] || [[ $mode == "q" ]]
        then
            echo ""
            exit 0
        fi


    fi

}


## function: ask_for_output_folder
function ask_for_output_folder() {

    # ask the user to enter an output directory
    echo -e "\n\033[1;95mEnter output directory: \033[0m"


    # if legacy mode is disabled
    if [[ $legacy_mode == "false" ]]
    then

        # if ouptut_folder is empty, suggest default_folder
        # if ouptut_folder is not empty, suggest output_folder
        if [[ $output_folder == "" ]]
        then
            read -rep $'\033[1;95m> \033[0m' -i "$default_folder" output_folder
        else
            read -rep $'\033[1;95m> \033[0m' -i "$output_folder" output_folder
        fi

    else

        read -rep $'\033[1;95m> \033[0m' output_folder

    fi

    # if the input is empty, "q", "quit" or "exit", exit the program
    if [[ $output_folder == "" ]] || [[ $output_folder == "exit" ]] || [[ $output_folder == "quit" ]] || [[ $output_folder == "q" ]]
    then
        exit 0
    fi

    # if the input is "b" or "back", go back to the main menu
    if [[ $output_folder == "b" ]] || [[ $output_folder == "back" ]]
    then
        main_menu
    fi

    # if the input isn't a directory, print an error message and exit the program
    if [[ ! -d $output_folder ]]
    then
        echo -e "\033[1;91mError: The entered path doesn't exist or isn't a directory.\033[0m"
        echo ""
        ask_for_output_folder
    fi

}

## function: help screen
function help_screen() {

    echo -e "\n\033[1mHelp\033[0m"
    echo -e "\033[1m====\033[0m"
    echo ""
    echo -e "\033[1mSingle Mode\033[0m"
    echo -e " In single mode, you can download a single TikTok video by entering the TikTok URL."
    echo -e "\033[1mBatch Mode\033[0m"
    echo -e " In batch mode, you can download multiple TikTok videos by entering the path to a text file containing the TikTok URLs."
    echo -e "\033[1mLive Mode\033[0m"
    echo -e " In live mode, you can download a TikTok livestream by entering the username or profile URL."
    echo -e "\033[1mAvatar Mode\033[0m"
    echo -e " In avatar mode, you can download the profile picture of a TikTok user by entering the TikTok username."
    echo -e "\033[1mMusic Mode\033[0m"
    echo -e " In music mode, you can download a TikTok sound by entering the TikTok music URL."
    echo -e "\033[1mRestore Mode\033[0m"
    echo -e " In restore mode, you can (re)download TikTok videos based on the file name. The input is a text file with entries in the following format: <user name>_<video id>.mp4"
    echo ""

    echo "In all modes you can enter an output directory for the downloaded videos. If you don't enter anything, the default directory will be used (if set)."
    echo ""
    echo "In all prompts you can enter 'q', 'quit' or 'exit' to exit the program. Enter 'b' or 'back' to go back to the main menu."

    echo ""
    echo "See README for further information."

    echo ""
    echo ""
    echo "Debug information (include in issues):"
    # if legacy mode is disabled
    if [[ $legacy_mode == "false" ]]
    then
        echo "  Script version: $version"
    else
        echo "  Script version: $version (running in legacy mode)"
    fi
    echo "  Bash version $BASH_VERSION."

    echo "  yt-dlp version: $("${ytdlp_path}" --version)"

    # if ffmpeg is installed, print the ffmpeg version
    if [[ $(command -v "${ffmpeg_path}") ]]
    then
        echo "  ffmpeg version: $("${ffmpeg_path}" -version | head -n 1 | sed 's/ffmpeg version //' | cut -d " " -f 1)"
    else
        echo "  ffmpeg version: No ffmpeg installation found."
    fi

    # if ffprobe is installed, print the ffprobe version
    if [[ $(command -v "${ffprobe_path}") ]]
    then
        echo "  ffprobe version: $("${ffprobe_path}" -version | head -n 1 | sed 's/ffprobe version //' | cut -d " " -f 1)"
    else
        echo "  ffprobe version: No ffprobe installation found."
    fi

    # check if jq, curl, rev and sed are installed, only print a message if they aren't
    if [[ ! $(command -v jq) ]]
    then
        echo "  jq: No jq installation found."
    fi
    if [[ ! $(command -v curl) ]]
    then
        echo "  curl: No curl installation found."
    fi
    if [[ ! $(command -v rev) ]]
    then
        echo "  rev: No rev installation found."
    fi
    if [[ ! $(command -v sed) ]]
    then
        echo "  sed: No sed installation found."
    fi

    if [[ $OSTYPE != "darwin"* ]]
    then
        if [[ ! $(command -v grep) ]]
        then
            echo "  grep: No grep installation found."
        fi
    fi

    # if OS is Linux, print the Linux distribution
    if [[ $OSTYPE == "linux-gnu" ]]
    then
        echo "  Linux distribution: $(lsb_release -d | sed 's/Description:	//') @ $(uname -prs)"
    fi
    # if OS is macOS, print the macOS version
    if [[ $OSTYPE == "darwin"* ]]
    then
        echo "  macOS version: $(sw_vers -productVersion) @ $(uname -prs)"
        # check if ggrep is installed
        if [[ $(command -v ggrep) ]]
        then
            echo "  ggrep status: installed"
        else
            echo "  ggrep status: not installed"
        fi
    fi

    # if OS is Windows, print the Windows version
    if [[ $OSTYPE == "msys" ]] || [[ $OSTYPE == "cygwin" ]] || [[ $OSTYPE == "win32" ]]
    then
        echo "  Windows environment: $OSTYPE @ $(uname -prs)"
    fi

    # if the script was launched with a parameter, print it
    if [[ $received_error_log != "" ]]
    then
        echo "  Script was originally launched with: $received_error_log"
    fi

    echo ""
    echo "GitHub: https://github.com/anga83/tiktok-downloader"

    echo ""

    # return to main menu
    main_menu

}


## function missing yt-dlp
function missing_ytdlp() {

    # if OS is macOS or Linux print "echo -e "Please install yt-dlp before using this script.". If OS is Windows, print "echo -e "You need to point ytdlp_path to your yt-dlp.exe"
    if [[ $OSTYPE == "darwin"* ]] || [[ $OSTYPE == "linux-gnu" ]]
    then
        echo -e "\033[1;91mPlease install yt-dlp before using this script.\033[0m"
    else
        echo -e "\033[1;91mYou need to point 'ytdlp_path' to your yt-dlp.exe\033[0m"
    fi

}

## function missing ffmpeg
function missing_ffmpeg() {

    if [[ $OSTYPE == "darwin"* ]] || [[ $OSTYPE == "linux-gnu" ]]
    then
        echo -e "\033[1;91mPlease install ffmpeg before using this mode.\033[0m"
    else
        echo -e "\033[1;91mYou need to point 'ffmpeg_path' to your ffmpeg.exe\033[0m"
    fi

}

## function missin ffprobe
function missing_ffprobe() {

    if [[ $OSTYPE == "darwin"* ]] || [[ $OSTYPE == "linux-gnu" ]]
    then
        echo -e "\033[1;91mPlease install ffprobe before using this mode.\033[0m"
    else
        echo -e "\033[1;91mYou need to point 'ffprobe_path' to your ffprobe.exe\033[0m"
    fi

}

### Main code

## perform some checks before starting the main menu

# if disable_shell_rerouting is set to false
if [[ $disable_shell_rerouting == "false" ]]
then

    # if show_warning_when_shell_is_not_bash is enabled, print a warning, otherwise try to suppress any warning and do the trick without the users' notice
    if [[ $show_warning_when_shell_is_not_bash == "true" ]]
    then

        # if $SHELL doesn't contain bash, print a warning and try to fix it
        if [[ $SHELL != *"bash" ]]
        then

            echo -e "\033[1;93mWarning: This script must be run under Bash instead of \033[1;91m$SHELL.\033[0m"
            echo -e "\033[0;93mSee README for more information.\033[0m"
            echo ""
            printf "\033[0;93mTrying to fix this...\033[0m"
            echo ""

            pass_error_log="$SHELL"

           { /usr/bin/env bash "$0" "$pass_error_log"; exit 0; } || { echo -e "\033[1;91mThat didn't work. Make sure you have Bash installed.\033[0m";  exit 1; }
        
        fi

    else

        # if $SHELL doesn't contain bash, try to fix it without the users' notice
        if [[ $SHELL != *"bash" ]]
        then

            pass_error_log="$SHELL"

           { /usr/bin/env bash "$0" "$pass_error_log"; exit 0; } || { echo -e "\033[1;91mThat didn't work. Make sure you have Bash installed.\033[0m";  exit 1; }
        
        fi
    

    fi

    # old code:

    # # check under which shell we are running
    # if [[ $(ps -p $$ -o comm=) != *"bash" ]]; then

    #     # if show_warning_when_shell_is_not_bash is enabled, print a warning, otherwise try to suppress any warning and do the trick without the users' notice
    #     if [[ $show_warning_when_shell_is_not_bash == "true" ]]
    #     then

    #         if [[ ! $(ps -p $$ -o comm=) = *"sh" ]]; then
            
    #             echo -e "\033[1;93mWarning: This script must be run under Bash instead of \033[1;91m$(ps -p $$ -o comm=).\033[0m"
    #             echo -e "\033[0;93mUsage: ./tiktok-downloader.sh\nSee README for more information.\033[0m"
    #             echo ""
    #             echo "\033[0;93mTrying to fix this...\033[0m"
    #             echo ""

    #         else

    #             echo "\033[1;93mWarning: This script must be run under Bash instead of \033[1;91m$(ps -p $$ -o comm=).\033[0m"
    #             printf "\033[0;93mUsage: ./tiktok-downloader.sh\nSee README for more information.\033[0m"
    #             echo ""
    #             printf "\033[0;93mTrying to fix this...\033[0m"
    #             echo ""

    #         fi

    #         pass_error_log="$(ps -p $$ -o comm=)"

    #         { /usr/bin/env bash "$0" "$pass_error_log"; exit 0; } || { echo -e "\033[1;91mThat didn't work. Make sure you have Bash installed.\033[0m";  exit 1; }

    #     else

    #         pass_error_log="$(ps -p $$ -o comm=)"

    #         { /usr/bin/env bash "$0" "$pass_error_log"; exit 0; } || { echo -"TikTok Downloader could't be launched because Bash is not installed.";  exit 1; }

    #     fi

    # fi

fi


# if the script was launched with a parameter, save it in a variable received_error_log
if [[ $1 != "" ]]
then
    received_error_log="$1"
else
    received_error_log=""
fi

# Welcome message
echo -e "\033[1;95mWelcome to the TikTok Downloader.\033[0m"

# check if yt-dlp is installed
if ! command -v "${ytdlp_path}" &> /dev/null
then
    echo -e "\033[1;91mError: yt-dlp is not installed.\033[0m" 
    missing_ytdlp
    echo ""
    exit 1
fi

# check if the Bash version can handle the interactive selection menu
if [[ "${BASH_VERSINFO[0]}" -lt 4 || ( "${BASH_VERSINFO[0]}" -eq 4 && "${BASH_VERSINFO[1]}" -lt 2 ) ]]
then
    legacy_mode="true"
fi


# check if yt-dlp is up to date

# if check_for_yt-dlp_updates is set to "true", check if yt-dlp is up to date
# setting gets overwritten if the Linux distribution is Debian-based, as yt-dlp's self-update mechanism is disabled on Debian, which causes the version check to fail
if [[ $check_for_updates == "true" ]] && [ ! -f /etc/debian_version ]
then

    yt_dlp_version=$("${ytdlp_path}" --update)

    if [[ ! $yt_dlp_version == *"is up to date"* ]]
    then

        if [[ ! $yt_dlp_version == *"self-update mechanism is disabled"* ]]
        then
            echo -e "\033[1;93mYou have an outdated version of yt-dlp installed.\033[0m"
            echo -e "\033[1;93mIf you encounter download errors, update yt-dlp and retry again.\033[0m"
            echo ""
        fi

    fi
fi

# if show_warning_when_ffmpeg_is_not_installed is set to "true", check if ffmpeg is installed
if [[ $show_warning_when_ffmpeg_is_not_installed == "true" ]]
then

    if ! command -v "${ffmpeg_path}" &> /dev/null
    then
        echo -e "\033[1;93mWarning: ffmpeg is not installed.\033[0m"
        echo -e "\033[1;93mLive Mode and Sound Mode won't work, but you can use the other modes.\033[0m"
        echo ""
    fi

fi

# if the OS is macOS, check if ggrep is installed 

if [[ $show_warning_when_ggrep_is_not_installed == "true" ]]
then

    if [[ $OSTYPE == "darwin"* ]]
    then

        if ! command -v ggrep &> /dev/null 
        then

            echo -e "\033[1;93mWarning: GNU grep is not installed.\033[0m"
            echo -e "\033[1;93mAvatar Mode won't work, but you can use the other modes.\033[0m"
            echo ""

        fi
    fi

fi


main_menu


exit 0


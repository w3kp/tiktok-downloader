#!/usr/bin/env bash

# This script allows you to use yt-dlp to download a TikTok video.
# The script has both a mode for downloading a single video and a mode to download all videos passed to the script via a text file.
# In "Avatar Mode" the script downloads the profile picture of a TikTok channel in the highest resolution available.

# Version 1.2 (2022-10-24) - legacy mode for Bash versions < 4.2, check if file already exists before downloading it, check for outdated yt-dlp version
# Version 1.1 (2022-10-23) - added "Avatar Mode"
# Version 1.0 (2022-10-23) - initial version

# Dependencies: yt-dlp (https://github.com/yt-dlp/yt-dlp)
#   on macOS additionally: ggrep (https://formulae.brew.sh/formula/grep)

### Variables:

output_folder=""
default_folder="" # set here your default download folder (optional)

legacy_mode="false" # set to "true" if you can't use the interactive select menu or the script won't run at all in your environment


### Functions

## define select menu function
# source: https://unix.stackexchange.com/questions/146570/arrow-key-enter-menu

# shellcheck disable=SC1087,SC2059,SC2034,SC2162,SC2086,SC2162,SC2155,SC2006,SC2004
function select_option {

    # little helpers for terminal print control and key input
    ESC=$( printf "\033")
    cursor_blink_on()  { printf "$ESC[?25h"; }
    cursor_blink_off() { printf "$ESC[?25l"; }
    cursor_to()        { printf "$ESC[$1;${2:-1}H"; }
    print_option()     { printf "   $1 "; }
    print_selected()   { printf "  $ESC[7m $1 $ESC[27m"; }
    get_cursor_row()   { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
    key_input()        { read -s -n3 key 2>/dev/null >&2
                         if [[ $key = $ESC[A ]]; then echo up;    fi
                         if [[ $key = $ESC[B ]]; then echo down;  fi
                         if [[ $key = ""     ]]; then echo enter; fi; }

    # initially print empty new lines (scroll down if at bottom of screen)
    for opt; do printf "\n"; done

    # determine current screen position for overwriting the options
    
    local lastrow=`get_cursor_row`
    local startrow=$(($lastrow - $#))

    # ensure cursor and input echoing back on upon a ctrl+c during read -s
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    local selected=0
    while true; do
        # print options by overwriting the last lines
        local idx=0
        for opt; do
            cursor_to $(($startrow + $idx))
            if [ $idx -eq $selected ]; then
                print_selected "$opt"
            else
                print_option "$opt"
            fi
            ((idx++))
        done

        # user key control
        case `key_input` in
            enter) break;;
            up)    ((selected--));
                   if [ $selected -lt 0 ]; then selected=$(($# - 1)); fi;;
            down)  ((selected++));
                   if [ $selected -ge $# ]; then selected=0; fi;;
        esac
    done

    # cursor position back to normal
    cursor_to $lastrow
    printf "\n"
    cursor_blink_on

    return $selected
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
    read -rep $'\e[1;35mEnter URL: \e[0m' url

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

    # if the URL contains a "?" remove it and everything after it
    if [[ $url == *"?"* ]]; then
        url=$(echo $url | cut -d'?' -f1)
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
    yt-dlp -q "$url" -o "$output_folder/$output_name"

    # check if the video was downloaded successfully
        if [[ ! -f "$output_folder/$output_name" ]]
        then 
            # if no, print an error message
            echo -e "\e[1;91m  Download failed!\e[0m"
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
    echo -e "\n\e[1;35mEnter the path to a text file with all links:\e[0m"
    read -rep $'\e[1;35m> \e[0m' file_path

    # if the input doesn't exist, print an error message and restart the function
    if [[ ! -f "$file_path" ]]
    then
        echo -e "\e[1;91mError: The file doesn't exist!\e[0m"
        echo ""
        batch_mode
    fi

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
        echo -e "\e[1;91mError: The file must be a .txt file!\e[0m"
        echo ""
        batch_mode
    fi

    # strip spaces from the file path
    file_path=$(echo "$file_path" | tr -d '[:space:]')

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

        # if the URL contains a "?" remove it and everything after it
        if [[ $line == *"?"* ]]; then
            url=$(echo $line | cut -d'?' -f1)
        else
            url=$line
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

        # print the videoname
        echo "  Output File: $output_name"

        # download the video using yt-dlp
        yt-dlp -q "$url" -o "$output_folder/$output_name"


        # check if the video was downloaded successfully
        if [[ ! -f "$output_folder/$output_name" ]]
        then

            # if no, print an error message
            echo -e "\e[1;91m  Download failed!\e[0m"
        fi

        # increase the current video number by 1
        current_video=$((current_video+1))

        # wait 1 second to prevent rate limiting
        sleep 1


    done < "$file_path"


    # print an empty line
    echo ""
    

    # run the function again
    batch_mode

}

## function: avatar mode
function avatar_mode() {

    username=""
    userurl=""
    avatarurl=""


    # ask user for TikTok username
    echo -e "\n\e[1;35mEnter TikTok username or profile URL: \e[0m"
    read -rep $'\e[1;35m> \e[0m' username

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
            userurl=$(echo $username | cut -d'?' -f1)
        else
            userurl=$username
        fi

        # directly pass the input to the destination variable
        userurl=$username

        # now edit the username variable to only contain the username
        username=${username#"https://www.tiktok.com/@"}

    else

        userurl="https://www.tiktok.com/@$username"

    fi

    # create a temporary file in the current directory
    tempfile=$(mktemp)

    # use curl to get the html source code of the user's profile page and save it to the temporary file
    # The user agent is needed, as TkikTok will only show a blank page if curl doesn't pretend to be a browser.
    curl "$userurl" -s -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36" > "$tempfile"

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

    # download the avatar image to username.jpg
    curl "$avatarurl" -s -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36" -o "$output_folder/$username.jpg"

    # check if the image was downloaded successfully
    if [[ ! -f "$output_folder/$username.jpg" ]]
    then
        # if no, print an error message
        echo -e "\e[1;91mDownload failed!\e[0m"
    fi

    # delete the temporary file
    rm "$tempfile"

    # print an empty line
    echo ""

    # repeat the function
    avatar_mode


}


## function: main menu
function main_menu() {

    # if legacy mode is disabled, show the interactive selection menu
    if [[ $legacy_mode == "false" ]]
    then

       # show a selection menu with the options "single mode" "batch mode" and save the user input in the variable mode
        echo -e "\n\e[1;35mWhich mode do you want to use?\e[0m"

        modeoptions=("Single Mode" "Batch Mode" "Avatar Mode" "Help" "Exit")
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
        elif [[ "${modeoptions[$modechoice]}" == "Avatar Mode" ]]
        then
            ask_for_output_folder
            avatar_mode
        elif [[ "${modeoptions[$modechoice]}" == "Help" ]]
        then
            help_screen
        elif [[ "${modeoptions[$modechoice]}" == "Exit" ]]
        then
            exit 0
        fi

    else

        # print a select menu witht he options "Single Mode" "Batch Mode" "Avatar Mode" "Help" "Exit"
        echo -e "\n\e[1;35mWhich mode do you want to use?\e[0m"
        echo -e "\e[1;35m1) Single Mode\e[0m"
        echo -e "\e[1;35m2) Batch Mode\e[0m"
        echo -e "\e[1;35m3) Avatar Mode\e[0m"
        echo -e "\e[1;35m4) Help\e[0m"
        echo -e "\e[1;35m5) Exit\e[0m"

        # read the user input and save it to the variable mode
        read -rep $'\e[1;35m> \e[0m' mode

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

        # if the input is "3", "avatar mode" or "avatar", run the avatar mode function
        if [[ $mode == "3" ]] || [[ $mode == "avatar mode" ]] || [[ $mode == "avatar" ]]
        then
            ask_for_output_folder
            avatar_mode
        fi

        # if the input is "4", "help" or "h", run the help screen function
        if [[ $mode == "4" ]] || [[ $mode == "help" ]] || [[ $mode == "h" ]]
        then
            help_screen
        fi

        # if the input is "5", "exit" or "q", exit the program
        if [[ $mode == "5" ]] || [[ $mode == "exit" ]] || [[ $mode == "q" ]]
        then
            echo ""
            exit 0
        fi


    fi

}


## function: ask_for_output_folder
function ask_for_output_folder() {

    # ask the user to enter an output directory
    echo -e "\n\e[1;35mEnter output directory: \e[0m"
    read -rep $'\e[1;35m> \e[0m' -i "$default_folder" output_folder

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
        echo -e "\e[1;91mError: The entered path doesn't exist or isn't a directory!\e[0m"
        echo ""
        exit 1
    fi

}

## function: help screen
function help_screen() {

    echo -e "\n\e[1mHelp\e[0m"
    echo -e "\e[1m====\e[0m"
    echo ""
    echo -e "\e[1mSingle Mode\e[0m"
    echo -e " In single mode, you can download a single TikTok video by entering the TikTok URL."
    echo -e "\e[1mBatch Mode\e[0m"
    echo -e " In batch mode, you can download multiple TikTok videos by entering the path to a text file containing the TikTok URLs."
    echo -e "\e[1mAvatar Mode\e[0m"
    echo -e " In avatar mode, you can download the profile picture of a TikTok user by entering the TikTok username."
    echo ""

    echo "In all modes you can enter an output directory for the downloaded videos. If you don't enter anything, the default directory will be used (if set)."
    echo ""
    echo "In all prompts you can enter 'q', 'quit' or 'exit' to exit the program. Enter 'b' or 'back' to go back to the main menu."

    echo ""

    echo "https://github.com/anga83/tiktok-downloader"

    echo ""

    # return to main menu
    main_menu

}

### Main code

echo -e "\e[1;35mWelcome to the TikTok Downloader!\e[0m"

# check if yt-dlp is installed
if ! command -v yt-dlp &> /dev/null
then
    echo -e "\e[1;91mError: yt-dlp is not installed!\e[0m"
    echo -e "\e[1;91mPlease install yt-dlp before using this script!\e[0m"
    echo ""
    exit 1
fi

# check if the Bash version can handle the interactive selection menu
if [[ ${BASH_VERSINFO[0]} -lt 4 ]] || [[ ${BASH_VERSINFO[1]} -lt 2 ]]
then
    legacy_mode="true"
fi

# check if yt-dlp is up to date

yt_dlp_version=$(yt-dlp --update)

if [[ ! $yt_dlp_version == *"is up to date"* ]]
then
    echo -e "\e[1;93mYou have an outdated version of yt-dlp installed.\e[0m"
    echo -e "\e[1;93mIf you encounter download errors, update yt-dlp and retry again.\e[0m"
    echo ""
fi

# if the OS is macOS and ggrep is not installed, print a warning
if [[ $OSTYPE == "darwin"* ]]
then

    if ! command -v ggrep &> /dev/null 
    then

        echo -e "\e[1;93mWarning: GNU grep is not installed!\e[0m"
        echo -e "\e[1;93mAvatar Mode won't work, but you can use the other modes.\e[0m"
        echo ""

    fi
fi

main_menu


exit 0




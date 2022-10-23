#!/usr/bin/env bash

# This script allows you to use yt-dlp to download a TikTok video.
# The script has both a mode for downloading a single video and a mode to download all videos passed to the script via a text file.

# Version 1.0 (2022-10-23) - initial version

# Dependencies: yt-dlp

output_folder=""

### You can hardcode a default folder here:
default_folder=""
###

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
        exit 0
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

    # download the video using yt-dlp
    yt-dlp -q "$url" -o "$output_folder/$output_name"

    # check if the video was downloaded successfully and the file is bigger than 50 KB
        if [[ ! -f "$output_folder/$output_name" ]] && [[ $(stat -c%s "$output_folder/$output_name") -lt 50000 ]]
        then 
            # if no, print an error message
            echo -e "\e[1;31m  Download failed!\e[0m"
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
        echo -e "\e[1;31mError: The file doesn't exist!\e[0m"
        echo ""
        batch_mode
    fi

    # if the input isn't a txt file, print an error message and restart the function
    if [[ ! $file_path == *.txt ]]
    then
        echo -e "\e[1;31mError: The file must be a .txt file!\e[0m"
        echo ""
        batch_mode
    fi

    # if the input is empty, "q", "quit" or "exit", exit the program
    if [[ $file_path == "" ]] || [[ $file_path == "exit" ]] || [[ $file_path == "quit" ]] || [[ $file_path == "q" ]]
    then
        exit 0
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

        # print the videoname
        echo "  Output File: $output_name"

        # download the video using yt-dlp
        yt-dlp -q "$url" -o "$output_folder/$output_name"


        # check if the video was downloaded successfully and the file is bigger than 50 KB
        if [[ ! -f "$output_folder/$output_name" ]] && [[ $(stat -c%s "$output_folder/$output_name") -lt 50000 ]]
        then

            # if no, print an error message
            echo -e "\e[1;31m  Download failed!\e[0m"
        fi

        # increase the current video number by 1
        current_video=$((current_video+1))


    done < "$file_path"


    # print an empty line
    echo ""
    

    # run the function again
    batch_mode

}


### Main code

# ask the user to enter an output directory
echo -e "\n\e[1;35mEnter output directory: \e[0m"
read -rep $'\e[1;35m> \e[0m' -i "$default_folder" output_folder

# if the input is empty, "q", "quit" or "exit", exit the program
if [[ $output_folder == "" ]] || [[ $output_folder == "exit" ]] || [[ $output_folder == "quit" ]] || [[ $output_folder == "q" ]]
then
    exit 0
fi

# if the input isn't a directory, print an error message and exit the program
if [[ ! -d $output_folder ]]
then
    echo -e "\e[1;31mError: The path must be a directory!\e[0m"
    echo ""
    exit 1
fi

# show a selection menu with the options "single mode" "batch mode" and save the user input in the variable mode
echo -e "\n\e[1;35mWhich mode do you want to use?\e[0m"

modeoptions=("Single Mode" "Batch Mode" "Exit")
select_option "${modeoptions[@]}"
modechoice=$?

if [[ "${modeoptions[$modechoice]}" == "Single Mode" ]]
then
	single_mode
elif [[ "${modeoptions[$modechoice]}" == "Batch Mode" ]]
then
	batch_mode
elif [[ "${modeoptions[$modechoice]}" == "Exit" ]]
then
    exit 0
fi


exit 0




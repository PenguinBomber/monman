#!/bin/bash

#variable setup
echo $XDG_CONFIG_HOME
if [ ! $XDG_CONFIG_HOME = "" ]
then
	config_dir="$XDG_CONFIG_HOME/monman"
else
	config_dir="$HOME/.config/monman"
fi

if [ "$1" = "-v" ]
then
	verbose=TRUE
fi

#logging function
log () {
	if [ -n $verbose ] 
	then
		echo $1
	fi
}

first_time_setup () {
	log $config_dir
	#create the config directory
	if [ -e $config_dir && ! -d $config_dir ]
	then
		echo "Error Creating Configs. Exiting..."
		exit 1
	else
		log "Setting up base configs"
		mkdir $config_dir
	fi

	#check for a config file, if there is none, make one
	if [ ! -f $config_dir/monitors ]
	then
		xrandr | grep 'nected' | awk '{print $1}' > $config_dir/monitors
	fi
}

#main loop of the script
main () {
	# Run through monitors one by one
	last_monitor=""
	while read monitor_conf
	do
		log "Configuring $monitor_conf"
		
		#grab monitor info from config
		local monitor=`printf "$monitor_conf" | awk '{print $1}'`
		local name=`printf "$monitor_conf" | awk '{print $2}'`
		local option=`printf "$monitor_conf" | awk '{print $3}'`
		
		local status=`xrandr | grep "$monitor " | awk '{print $2}'`
		
		#turn off the monitor if disconnected
		if [ "$status" = "disconnected" ]
		then
			xrandr --output $monitor --off
			bspc monitor $monitor -r
		fi

		#connect the monitors if present
		if [ "$status" = "connected" ]
		then
			#check if the monitor is set as primary and set it accordingly
			if [ "$option" = "primary" ]
			then
				xrandr_opt="--primary"
			fi

			#turn on each monitor and put each new monitor to the right of the last monitor
			if [ "$last_monitor" = "" ]
			then
				log "Connecting $monitor $option"
				xrandr --output $monitor --auto $xrandr_opt
			else
				log "Connecting $monitor $option to the right of $last_monitor"
				xrandr --output $monitor --right-of $last_monitor --auto $xrandr_opt
			fi

			#setup the desktops for each monitor with BSPWM
			bspc monitor $monitor -d "$name 1" "$name 2" "$name 3"
			
			#set the background again so feh fills the new monitors
			feh --bg-fill ~/.config/wallpaper

			last_monitor="$monitor"
		fi
			
	done < "$config_dir/monitors"
	
	#pick up all the windows that got left on disconnected monitors
	bspc wm --adopt-orphans

	#wait for a change in monitor geometry, signifys a monitor has been connected
	bspc subscribe -c 1 monitor_geometry
}

if [ ! -e $config_dir/monitors ]
then
	first_time_setup
fi

while [ 1 = 1 ]
do
	main
done

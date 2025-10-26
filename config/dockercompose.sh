#!/bin/bash

# Function to display the Docker Compose menu
show_docker_menu() {
    clear
    echo "------------------------------------"
    echo "Docker Compose Menu:"
    echo "------------------------------------"
    echo "1: Install Docker Compose"
    echo "2: List Docker Compose Available"
    echo "3: List Docker Container Available"
    echo "4: Uninstall Docker Compose"
    read -p "Enter your choice: " choice
}

# Function to install Docker Compose (same as before)
install_docker_compose() {
    echo "Installing Docker Compose..."
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    echo "Docker Compose installed successfully!"
}

# Function to list and manage Docker Compose services (from previous version)
list_docker_services() {
    while true; do
        clear
        echo "Available Docker Compose Services:"

        # Find all docker-compose.yml files, get their parent directories, and ensure uniqueness
        compose_dirs=$(find /etc/docker -name "docker-compose.yml" -print0 | xargs -0 -I{} dirname "{}" | sort -u)

        # Check if any directories were found
        if [ -z "$compose_dirs" ]; then
            echo "No Docker Compose services found."
            read -p "Press Enter to return to the Docker Compose menu..."
            return
        fi

        # Initialize counter and array
        count=1
        declare -a dir_array

        # Loop through the unique directories
        while IFS= read -r dir; do
            # Construct the full path to the docker-compose.yml file
            compose_file="$dir/docker-compose.yml"

            # Check if the service is running
            if docker compose -f "$compose_file" ps --services 2>/dev/null | grep -q .; then
                status="Running"
            else
                status="Stopped"
            fi

            # Display the directory and status, nicely formatted
            printf "%3d: %-50s (%s)\n" "$count" "$dir" "$status"  # Use printf for formatting

            # Add the directory to the array
            dir_array+=("$dir")

            ((count++))
        done <<< "$compose_dirs"


        read -p "Enter the number to toggle (start/stop), or 0 to return: " service_num

        # Input validation and service toggling
        if [[ "$service_num" =~ ^[0-9]+$ ]] && [ "$service_num" -ge 1 ] && [ "$service_num" -le ${#dir_array[@]} ]; then
            selected_dir="${dir_array[$service_num-1]}"
            selected_file="$selected_dir/docker-compose.yml"  # Use the full path

            cd "$selected_dir" || { echo "Error changing directory"; exit 1; }

            if docker compose -f "$selected_file" ps --services 2>/dev/null | grep -q .; then
                echo "Stopping service in $selected_dir..."
                docker compose -f "$selected_file" down
            else
                echo "Starting service in $selected_dir..."
                docker compose -f "$selected_file" up -d
            fi
            read -p "Press Enter to continue..."

        elif [ "$service_num" -eq 0 ]; then
            return  # Return to the Docker Compose menu
        else
            echo "Invalid input."
            read -p "Press Enter to continue..."
        fi
    done
}


# Function to list and manage individual Docker containers
list_docker_containers() {
    while true; do
        clear
        echo "Available Docker Containers:"

        # Get all container IDs and their status (running or exited)
        containers=$(docker ps -a --format "{{.ID}} {{.Names}} {{.Status}}")

        # Check if any containers were found
        if [ -z "$containers" ]; then
            echo "No Docker containers found."
            read -p "Press Enter to return to the Docker Compose menu..."
            return
        fi

        # Initialize counter and array
        count=1
        declare -a container_array

        # Loop through the containers and display status
        while IFS= read -r line; do
            container_id=$(echo "$line" | awk '{print $1}')
            container_name=$(echo "$line" | awk '{print $2}')
            container_status=$(echo "$line" | awk '{print $3,$4,$5,$6,$7,$8}') #Get more status columns


            printf "%3d: %-20s %-30s (%s)\n" "$count" "$container_id" "$container_name" "$container_status"

            # Add the container ID to the array
            container_array+=("$container_id")

            ((count++))
        done <<< "$containers"

        read -p "Enter container numbers to toggle (comma-separated), or 0 to return: " container_nums

        # Process multiple container selections
        if [[ "$container_nums" =~ ^[0-9,]+$ ]]; then  # Validate input (numbers and commas only)
            IFS=',' read -ra nums <<< "$container_nums"  # Split into an array
            for num in "${nums[@]}"; do
                num=$((num)) # Convert to integer (removes leading zeros)

                if [ "$num" -ge 1 ] && [ "$num" -le ${#container_array[@]} ]; then
                    container_id="${container_array[$num-1]}"

                    # Check current status and toggle
                    if docker inspect --format='{{.State.Running}}' "$container_id" 2>/dev/null | grep -q "true"; then
                        echo "Stopping container $container_id..."
                        docker stop "$container_id"
                    else
                        echo "Starting container $container_id..."
                        docker start "$container_id"
                    fi
                elif [ "$num" -ne 0 ]; then
                   echo "Invalid container number: $num"
                fi
            done
              read -p "Press Enter to continue..."
        elif [ "$container_nums" -eq 0 ]; then
             return
        else
            echo "Invalid input.  Please enter comma-separated numbers or 0."
            read -p "Press Enter to continue..."
        fi
    done
}



# Function to uninstall Docker Compose (same as before)
uninstall_docker_compose() {
    echo "Uninstalling Docker Compose..."

    # Uninstall Docker packages
    sudo apt-get remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-compose

    # Remove Docker-related files (except /etc/docker)
    sudo rm -rf /var/lib/docker
    sudo rm -rf /var/run/docker.sock
    sudo rm -f /etc/apt/keyrings/docker.asc
    sudo rm -f /etc/apt/sources.list.d/docker.list
     sudo apt-get autoremove -y

    echo "Docker Compose and related components uninstalled (except /etc/docker)."
}

# Docker Compose menu loop
while true; do
    show_docker_menu

    case $choice in
        1)
            install_docker_compose
            read -p "Press Enter to return to the Docker Compose menu..."
            ;;
        2)
            list_docker_services
            ;;
        3)
            list_docker_containers
            ;;
        4)
            uninstall_docker_compose
            read -p "Press Enter to return to the Docker Compose menu..."
            ;;
        *)
            echo "Invalid choice. Please try again."
            read -p "Press Enter to continue..."
            ;;
    esac

    if [ "$choice" -eq 5 ]; then # Changed the break out number because one more option added.
        break  # Exit the Docker Compose menu loop
    fi
done

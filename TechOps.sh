#!/bin/bash

# Step 1: Function to read parameters from a xml file
read_from_xml() {
    local file="$1"
    local section="$2"
    local key="$3"
    
    # Use xmllint to extract the value of the given key under the specified section
    xmllint --xpath "string(//serverConfigurations/$section/$key)" "$file"
}

# Path to the XML file containing parameters
PARAM_FILE="credentials.xml"

# Function to extract parameters
extract_parameters() {
    # Extract live configuration
    LIVE_HOST=$(read_from_xml "$PARAM_FILE" "live" "host")
    LIVE_PORT=$(read_from_xml "$PARAM_FILE" "live" "port")
    LIVE_USER=$(read_from_xml "$PARAM_FILE" "live" "user")
    LIVE_URL=$(read_from_xml "$PARAM_FILE" "live" "url")

    # Extract staging configuration
    STAGING_HOST=$(read_from_xml "$PARAM_FILE" "staging" "host")
    STAGING_PORT=$(read_from_xml "$PARAM_FILE" "staging" "port")
    STAGING_USER=$(read_from_xml "$PARAM_FILE" "staging" "user")
    STAGING_URL=$(read_from_xml "$PARAM_FILE" "staging" "url")

    # Export variables to make them globally accessible
    export LIVE_HOST LIVE_PORT LIVE_USER LIVE_URL
    export STAGING_HOST STAGING_PORT STAGING_USER STAGING_URL
}

# Extract SSH credentials and URLs from the XML file
extract_parameters 2>/dev/null

# Step 2: Validate extracted parameters
if [[ -z "$LIVE_HOST" || -z "$STAGING_HOST" || -z "$LIVE_URL" || -z "$STAGING_URL" ]]; then
    echo "Error: Missing required parameters in the xml file."
    exit 1
fi

echo "All parameters read successfully:"
echo "LIVE_HOST=$LIVE_HOST"
echo "STAGING_HOST=$STAGING_HOST"
echo "LIVE_URL=$LIVE_URL"
echo "STAGING_URL=$STAGING_URL"

# Step 3: Log into the staging server first to determine the WP directory
echo "Logging into the staging server ($STAGING_HOST) to find the WordPress directory..."
STAGING_WP_DIR=$(ssh -q  -p "$STAGING_PORT" "$STAGING_USER@$STAGING_HOST" bash -s << "SSH_COMMANDS" 2>/dev/null
    # Function to find the WordPress root directory on the staging server
    find_wordpress_dir() {
        wp_dir=$(find /var/www /home -type d -name "wp-admin" -exec dirname {} \; 2>/dev/null | head -n 1)
        if [[ -d "$wp_dir/wp-content" && -d "$wp_dir/wp-includes" && -f "$wp_dir/wp-config.php" ]]; then
            echo "$wp_dir"
        else
            echo "Error: WordPress root directory not found."
            exit 1
        fi
    }
    WP_DIR=$(find_wordpress_dir)
    if [[ -z "$WP_DIR" ]]; then
        echo "Error: WordPress installation directory not found on the staging server."
        exit 1
    fi
    echo "$WP_DIR"
SSH_COMMANDS
)

# Check if we were able to get the WP directory from the staging server
if [[ -z "$STAGING_WP_DIR" ]]; then
    echo "Error: Could not determine the WordPress directory on the staging server."
    exit 1
fi

echo "Staging WordPress directory is: $STAGING_WP_DIR" 2>/dev/null

# Step 4: Log into the live server using SSH
echo "Logging into the live server ($LIVE_HOST) using SSH..."
ssh -p "$LIVE_PORT" "$LIVE_USER@$LIVE_HOST" bash -s -- "$LIVE_URL" "$STAGING_PORT" "$STAGING_HOST" "$STAGING_USER" "$STAGING_WP_DIR" << "SSH_COMMANDS"
    LIVE_URL="$1"  # Pass LIVE_URL dynamically from the script
    STAGING_PORT="$2"
    STAGING_HOST="$3"
    STAGING_USER="$4"
    STAGING_WP_DIR="$5"

    echo "Logged into the live server successfully."

    # Function to find the WordPress root directory on the live server
    find_wordpress_dir() {
        wp_dir=$(find /var/www /home -type d -name "wp-admin" -exec dirname {} \; 2>/dev/null | head -n 1)
        if [[ -d "$wp_dir/wp-content" && -d "$wp_dir/wp-includes" && -f "$wp_dir/wp-config.php" ]]; then
            echo "$wp_dir"
        else
            echo "Error: WordPress root directory not found."
            exit 1
        fi
    }

    # Find the WordPress directory on live server
    WP_DIR=$(find_wordpress_dir)
    if [[ -z "$WP_DIR" ]]; then
        echo "Error: WordPress installation directory not found on the live server."
        exit 1
    fi

    # Step 5: Change to the live WordPress directory
    cd "$WP_DIR" || { echo "Failed to navigate to WordPress directory: $WP_DIR"; exit 1; }

    # Ensure wp-cli is installed and functional
    if ! command -v wp &> /dev/null || ! wp core is-installed &> /dev/null; then
        echo "Error: wp-cli is not installed or the directory is not a WordPress installation."
        exit 1
    fi

    # # Step 6: Perform WordPress database export on live server (Dry Run)
    # echo "Dry run: Exporting the WordPress database..."
    # TIMESTAMP=$(date +"%Y%m%d%H%M%S")
    # EXPORT_DIR="./db_exports"
    # EXPORT_FILE="${EXPORT_DIR}/live_db_export_${TIMESTAMP}.sql"

    # if [ ! -d "$EXPORT_DIR" ]; then
    #     mkdir -p "$EXPORT_DIR" || { echo "Failed to create export directory: $EXPORT_DIR"; exit 1; }
    # fi
    # if wp db export "$EXPORT_FILE" --dry-run; then
    #     echo "Database export (dry run) completed successfully to: $EXPORT_FILE"
    # else
    #     echo "Database export failed. Exiting."
    #     exit 1
    # fi

    # if [ -z "$STAGING_PORT" ]; then
    #     echo "Error: STAGING_PORT is not set or empty. Please check your credentials.txt file."
    #     exit 1
    # fi

    # Step 7: Rsync the WordPress directory and the export to the staging server (Dry run)

        echo "Dry run: Syncing WordPress files and database export to the staging server..."
        rsync -avn --rsync-path='/usr/bin/sudo /usr/bin/rsync' --exclude='wp-config.php' --exclude='wp-content/cache/' "$WP_DIR/" "$STAGING_USER@$STAGING_HOST:$STAGING_WP_DIR" --dry-run
        RSYNC_STATUS=$?
        echo "Rsync exit status: $RSYNC_STATUS"
        if [[ $RSYNC_STATUS -ne 0 ]]; then
            echo "Error: Rsync failed with exit status $RSYNC_STATUS."
            exit 1
        fi

    # Step 8: Log out of the live server
    echo "Logging out from the live server."
    exit 0
SSH_COMMANDS

# Step 9: Log into the staging server via SSH again to complete remaining tasks
echo "Logging into the staging server ($STAGING_HOST) to perform tasks..."
ssh -p "$STAGING_PORT" "$STAGING_USER@$STAGING_HOST" bash -s -- "$STAGING_URL" << "SSH_COMMANDS"
    STAGING_URL="$1"  # Pass STAGING_URL dynamically from the script

    echo "Logged into the staging server successfully."

    # Function to find the WordPress root directory on the staging server
    find_wordpress_dir() {
        wp_dir=$(find /var/www /home -type d -name "wp-admin" -exec dirname {} \; 2>/dev/null | head -n 1)
        if [[ -d "$wp_dir/wp-content" && -d "$wp_dir/wp-includes" && -f "$wp_dir/wp-config.php" ]]; then
            echo "$wp_dir"
        else
            echo "Error: WordPress root directory not found."
            exit 1
        fi
    }

    # Step 10: Change to the staging WordPress directory
    WP_DIR=$(find_wordpress_dir)
    if [[ -z "$WP_DIR" ]]; then
        echo "Error: WordPress installation directory not found on the staging server."
        exit 1
    fi
    cd "$WP_DIR" || { echo "Failed to navigate to WordPress directory: $WP_DIR"; exit 1; }
    
    # # Step 11: Import the database and perform dry-run search and replace for site URL (excluding config file)
    # TIMESTAMP=$(date +"%Y%m%d%H%M%S")
    # EXPORT_DIR="./db_exports"
    # EXPORT_FILE="${EXPORT_DIR}/live_db_export_${TIMESTAMP}.sql"

    # # Import the database
    # if wp db import "$EXPORT_FILE"; then
    #     echo "Database imported successfully."
    # else
    #     echo "Database import failed. Exiting."
    #     exit 1
    # fi

    # Step 12 (Dry Run): Perform dry-run search and replace for the live URL (no changes will be made to the database)
    echo "Dry run: Performing search and replace for site URL..."
    if wp search-replace "$LIVE_URL" "$STAGING_URL" --skip-columns=guid --dry-run; then
        echo "Dry run search and replace for site URL completed successfully."
    else
        echo "Dry run search and replace failed."
    fi

    # 1a. Check if WooCommerce Follow Up Emails is active and deactivate if necessary
    FOLLOWUP_EMAILS_PLUGIN="woocommerce-follow-up-emails/woocommerce-follow-up-emails.php"
    echo "Checking if WooCommerce Follow Up Emails plugin is active..."
    if wp plugin is-active "$FOLLOWUP_EMAILS_PLUGIN"; then
        echo "Deactivating WooCommerce Follow Up Emails plugin..."
        wp plugin deactivate "$FOLLOWUP_EMAILS_PLUGIN" || handle_error "Failed to deactivate WooCommerce Follow Up Emails plugin"
    else
        echo "WooCommerce Follow Up Emails plugin is not active."
    fi

    # 2. Install required plugins on the staging site
    REQUIRED_PLUGINS=("stop-emails" "email-log")
    for PLUGIN in "${REQUIRED_PLUGINS[@]}"; do
        echo "Checking if plugin '$PLUGIN' is active..."
        if wp plugin is-active "$PLUGIN"; then
            echo "Plugin '$PLUGIN' is already active. Skipping installation."
        else
            echo "Installing and activating plugin '$PLUGIN'..."
            wp plugin install "$PLUGIN" --activate || handle_error "Failed to install and activate plugin '$PLUGIN'"
        fi
    done

    # 3. Append 'wdm' at the end of each user email and user login if they don't already have it
    echo "Appending 'wdm' to user emails and usernames where it doesn't already exist..."
    wp db query "
        UPDATE wp_users
        SET user_email = CONCAT(user_email, 'wdm')
        WHERE user_email NOT LIKE '%wdm';

        UPDATE wp_users
        SET user_login = CONCAT(user_login, 'wdm')
        WHERE user_login NOT LIKE '%wdm';
    " || handle_error "Failed to append 'wdm' to user emails and usernames"

    echo "Successfully appended 'wdm' to user emails and usernames where necessary."

    # Step 13: Dry run update of plugins and themes with exceptions for failed plugins
    echo "Dry run update of all plugins..."
    if wp plugin update --all --dry-run; then
        echo "Plugin update dry run completed successfully."
    else
        echo "Plugin update dry run failed. Skipping some plugins."
    fi

    # Dry run update of themes
    echo "Dry run update of all themes..."
    if wp theme update --all --dry-run; then
        echo "Theme update dry run completed successfully."
    else
        echo "Theme update dry run failed. Skipping some themes."
    fi

    # Step 14: Clear the cache
    echo "Dry run clearing cache..."
    if wp cache flush --dry-run; then
        echo "Cache flush dry run completed successfully."
    else
        echo "Cache flush dry run failed."
    fi

    # Step 15: Log out of the staging server
    echo "Logging out from the staging server."
    exit 0
SSH_COMMANDS


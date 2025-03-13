#!/bin/bash

# Graffiti or Welcome Graphics
cat << "EOF"
================================================================================================
         			WELCOME TO WISDMLABS TECHOPS                     
================================================================================================
 __        ___         _           _          _           _____         _      ___            
 \ \      / (_)___  __| |_ __ ___ | |    __ _| |__  ___  |_   _|__  ___| |__  / _ \ _ __  ___ 
  \ \ /\ / /| / __|/ _` | '_ ` _ \| |   / _` | '_ \/ __|   | |/ _ \/ __| '_ \| | | | '_ \/ __|
   \ V  V / | \__ \ (_| | | | | | | |__| (_| | |_) \__ \   | |  __/ (__| | | | |_| | |_) \__ \
    \_/\_/  |_|___/\__,_|_| |_| |_|_____\__,_|_.__/|___/   |_|\___|\___|_| |_|\___/| .__/|___/
                                                                                   |_|        
================================================================================================
EOF




clone_live() {

# Step 3: Log into the staging server first to determine the WP directory
echo ""
echo "Logging into the staging server ($STAGING_HOST) to find the WordPress directory..."
echo ""
# STAGING_WP_DIR=$(sshpass -p "$STAGING_PASSWORD" ssh -o StrictHostKeyChecking=no -q -p "$STAGING_PORT" "$STAGING_USER@$STAGING_HOST" bash -s << "SSH_COMMANDS" 2>/dev/null
#     # Function to find the WordPress root directory on the staging server
#     find_wordpress_dir() {
# 	wp_dir=$(find /var/www /home -type d -name "wp-admin" -exec dirname {} \; 2>/dev/null | head -n 1)
# 	if [[ -d "$wp_dir/wp-content" && -d "$wp_dir/wp-includes" && -f "$wp_dir/wp-config.php" ]]; then
# 	    echo "$wp_dir"
# 	    echo ""
# 	else
# 	    echo "Error: WordPress root directory not found."
# 	    echo ""
# 	    exit 1
# 	fi
#     }
#     WP_DIR=$(find_wordpress_dir)
#     if [[ -z "$WP_DIR" ]]; then
# 	echo "Error: WordPress installation directory not found on the staging server."
# 	echo ""
# 	exit 1
#     fi
#     echo "$WP_DIR"
#     echo ""
# SSH_COMMANDS
# )

# STAGING_WPDIR

# Check if we were able to get the WP directory from the staging server
if [[ -z "$STAGING_WP_DIR" ]]; then
    echo "Error: Could not determine the WordPress directory on the staging server."
    exit 1
fi

echo "Staging WordPress directory is: $STAGING_WP_DIR" 2>/dev/null
echo ""


# Step 4: Log into the live server using SSH
echo ""
echo "Logging into the live server ($LIVE_HOST) using SSH..."
echo ""

sshpass -p "$LIVE_PASSWORD" ssh -o StrictHostKeyChecking=no -p "$LIVE_PORT" "$LIVE_USER@$LIVE_HOST" bash -s -- "$LIVE_URL" "$LIVE_WP_DIR" "$STAGING_PORT" "$STAGING_HOST" "$STAGING_USER" "$STAGING_WP_DIR" "$LIVE_SSHKEY" << "SSH_COMMANDS"
    LIVE_URL="$1"  # Pass LIVE_URL dynamically from the script
	LIVE_WP_DIR=$2
    STAGING_PORT="$3"
    STAGING_HOST="$4"
    STAGING_USER="$5"
    STAGING_WP_DIR="$6"
	LIVE_SSHKEY="$7"

    echo "Logged into the live server successfully."
    echo ""
    
    # # Function to find the WordPress root directory on the live server
    # find_wordpress_dir() {
	# wp_dir=$(find /var/www /home -type d -name "wp-admin" -exec dirname {} \; 2>/dev/null | head -n 1)
	# if [[ -d "$wp_dir/wp-content" && -d "$wp_dir/wp-includes" && -f "$wp_dir/wp-config.php" ]]; then
	#     echo "$wp_dir"
	#     echo ""
	# else
	#     echo "Error: WordPress root directory not found."
	#     exit 1
	# fi
    # }

    # # Find the WordPress directory on live server
    # WP_DIR=$(find_wordpress_dir)
    if [[ -z "$LIVE_WP_DIR" ]]; then
	echo "Error: WordPress installation directory not found on the live server."
	exit 1
    fi

    # Step 5: Change to the live WordPress directory
    cd "$LIVE_WP_DIR" || { echo "Failed to navigate to WordPress directory: $LIVE_WP_DIR"; exit 1; }

    # Ensure wp-cli is installed and functional
    if ! command -v wp &> /dev/null || ! wp core is-installed &> /dev/null; then
	echo "Error: wp-cli is not installed or the directory is not a WordPress installation."
	exit 1
    fi

    # # Step 6: Perform WordPress database export on live server (Dry Run)
    # echo ""
    # echo "Exporting the WordPress database..."
    # EXPORT_DIR="./wp-content/db_exports"
    # EXPORT_FILE="${EXPORT_DIR}/live_db_export.sql"

    # if [ ! -d "$EXPORT_DIR" ]; then
    #     mkdir -p "$EXPORT_DIR" || { echo "Failed to create export directory: $EXPORT_DIR"; exit 1; }
    # fi
    # if wp db export "$EXPORT_FILE"; then
    #     echo "Database export completed successfully to: $EXPORT_FILE"
    #     echo ""
    # else
    #     echo "Database export failed. Exiting."
    #     exit 1
    # fi


	# Step 6: Perform WordPress database export on live server (Dry Run)
	echo ""
	echo "Exporting the WordPress database..."

	# Define export directory and files
	EXPORT_DIR="./wp-content/db_exports"
	EXPORT_FILE="${EXPORT_DIR}/live_db_export.sql"
	PREFIX_FILE="${EXPORT_DIR}/wp_prefix.txt"

	# Create the export directory if it doesn't exist
	if [ ! -d "$EXPORT_DIR" ]; then
		mkdir -p "$EXPORT_DIR" || { echo "Failed to create export directory: $EXPORT_DIR"; exit 1; }
	fi

	# Retrieve the WordPress table prefix using WP-CLI
	WP_PREFIX=$(wp eval 'global $wpdb; echo $wpdb->prefix;')

	# Export the database
	if wp db export "$EXPORT_FILE"; then
		echo "Database export completed successfully to: $EXPORT_FILE"
		
		# Write the retrieved prefix into a text file
		echo "$WP_PREFIX" > "$PREFIX_FILE"
		echo "WordPress table prefix ($WP_PREFIX) saved to: $PREFIX_FILE"
		echo ""
	else
		echo "Database export failed. Exiting."
		exit 1
	fi



    if [ -z "$STAGING_PORT" ]; then
        echo "Error: STAGING_PORT is not set or empty. Please check your credentials.txt file."
        exit 1
    fi

    # Step 7: Rsync the WordPress directory and the export to the staging server (Dry run)

	echo "Dry run: Syncing WordPress files and database export to the staging server..."
	if rsync -rlzn -e "ssh -i $LIVE_SSHKEY" --exclude='wp-config.php' --exclude='wp-content/cache/' --exclude='updraft/' "$LIVE_WP_DIR/wp-content/" "$STAGING_USER@$STAGING_HOST:$STAGING_WP_DIR/wp-content" --dry-run; then
	    echo "Rsync Dry Run completed successfully"
	    echo ""
	    echo "Performing Rsync"
	    rsync -rlz -e "ssh -i $LIVE_SSHKEY" --exclude='wp-config.php' --exclude='wp-content/cache/' --exclude='updraft/' "$LIVE_WP_DIR/wp-content/" "$STAGING_USER@$STAGING_HOST:$STAGING_WP_DIR/wp-content"
	    echo "Rsync completed successfully"
	else
	    echo "Rsync failed. Exiting."
	    exit 1
	fi

	RSYNC_STATUS=$?
	echo ""
	echo "Rsync exit status: $RSYNC_STATUS"

	if [[ $RSYNC_STATUS -ne 0 ]]; then
	    echo ""
	    echo "Error: Rsync failed with exit status $RSYNC_STATUS."
	    exit 1
	fi

    # Step 8: Log out of the live server
    echo "Logging out from the live server."
    exit 0
SSH_COMMANDS

# Step 9: Log into the staging server via SSH again to complete remaining tasks
echo ""
echo "Logging into the staging server ($STAGING_HOST) to perform tasks..."
echo ""
sshpass -p "$STAGING_PASSWORD" ssh -o StrictHostKeyChecking=no -p "$STAGING_PORT" "$STAGING_USER@$STAGING_HOST" bash -s -- "$STAGING_URL" "$STAGING_WP_DIR" "$LIVE_URL" << "SSH_COMMANDS"
    STAGING_URL="$1"  # Pass STAGING_URL dynamically from the script
	STAGING_WP_DIR="$2"
	LIVE_URL="$3"

    echo "Logged into the staging server successfully."
    echo ""
    # Function to find the WordPress root directory on the staging server
    # find_wordpress_dir() {
	# wp_dir=$(find /var/www /home -type d -name "wp-admin" -exec dirname {} \; 2>/dev/null | head -n 1)
	# if [[ -d "$wp_dir/wp-content" && -d "$wp_dir/wp-includes" && -f "$wp_dir/wp-config.php" ]]; then
	#     echo "$wp_dir"
	#     echo ""
	# else
	#     echo "Error: WordPress root directory not found."
	#     exit 1
	# fi
    # }

    # Step 10: Change to the staging WordPress directory
    # WP_DIR=$(find_wordpress_dir)
    if [[ -z "$STAGING_WP_DIR" ]]; then
	echo "Error: WordPress installation directory not found on the staging server."
	exit 1
    fi
    cd "$STAGING_WP_DIR" || { echo "Failed to navigate to WordPress directory: $STAGING_WP_DIR"; exit 1; }
    
    # Step 11: Import the database and perform dry-run search and replace for site URL (excluding config file)
    # TIMESTAMP=$(date +"%Y%m%d%H%M%S")
    EXPORT_DIR="./wp-content/db_exports"
    EXPORT_FILE="${EXPORT_DIR}/live_db_export.sql"
	PREFIX_FILE="${EXPORT_DIR}/wp_prefix.txt"

	# Read the prefix from the file and update wp-config.php
	if [ -f "$PREFIX_FILE" ]; then
		WP_PREFIX=$(cat "$PREFIX_FILE")
		echo "Setting the table prefix to '$WP_PREFIX' in wp-config.php..."
		wp config set table_prefix "$WP_PREFIX" --type=variable
		echo "Table prefix updated successfully."
	else
		echo "Prefix file ($PREFIX_FILE) not found. Cannot update table prefix."
		exit 1
	fi

    # Import the database
	echo "Importing database from $EXPORT_FILE"
    if wp db import "$EXPORT_FILE"; then
        echo "Database imported successfully."
    else
        echo "Database import failed. Exiting."
        exit 1
    fi

	echo "Updating site"


	wp option update siteurl "$STAGING_URL"
	wp option update home "$STAGING_URL"

	wp cache flush

	wp option get siteurl
	wp option get home


    # Step 12 (Dry Run): Perform dry-run search and replace for the live URL (no changes will be made to the database)
    echo ""
    echo "Dry run: Performing search and replace for site URL..."
    echo ""
    if wp search-replace "$LIVE_URL" "$STAGING_URL" --skip-columns=guid --all-tables --dry-run; then
	echo "Dry run search and replace for site URL completed successfully."
	echo ""
	echo "Performing search replace $LIVE_URL -> $STAGING_URL"
	echo ""
	wp search-replace "$LIVE_URL" "$STAGING_URL" --skip-columns=guid --all-tables
	echo "search and replace for site URL completed successfully."
	wp cache flush
    else
	echo "Dry run search and replace failed."
    fi

	CURRENT_SITEURL=$(wp option get siteurl)
	if [ "$CURRENT_SITEURL" != "$STAGING_URL" ]; then
		wp option update siteurl "$STAGING_URL"
		wp option update home "$STAGING_URL"
	fi
	echo "Updated the URLs."
	wp cache flush
	wp option get siteurl
	wp option get home

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
SSH_COMMANDS

}

perform_techops_on_staging() {

# Step 9: Log into the staging server via SSH again to complete remaining tasks
echo ""
echo "Logging into the staging server ($STAGING_HOST) to perform tasks..."
echo ""
sshpass -p "$STAGING_PASSWORD" ssh -o StrictHostKeyChecking=no -p "$STAGING_PORT" "$STAGING_USER@$STAGING_HOST" bash -s -- "$STAGING_URL" "$STAGING_WP_DIR" "$LIVE_URL" << "SSH_COMMANDS"
    STAGING_URL="$1"  # Pass STAGING_URL dynamically from the script
	STAGING_WP_DIR="$2"
	LIVE_URL="$3"

    echo "Logged into the staging server successfully."
    echo ""
    # Function to find the WordPress root directory on the staging server
    # find_wordpress_dir() {
	# wp_dir=$(find /var/www /home -type d -name "wp-admin" -exec dirname {} \; 2>/dev/null | head -n 1)
	# if [[ -d "$wp_dir/wp-content" && -d "$wp_dir/wp-includes" && -f "$wp_dir/wp-config.php" ]]; then
	#     echo "$wp_dir"
	#     echo ""
	# else
	#     echo "Error: WordPress root directory not found."
	#     exit 1
	# fi
    # }

    # Step 10: Change to the staging WordPress directory
    # WP_DIR=$(find_wordpress_dir)
    if [[ -z "$STAGING_WP_DIR" ]]; then
	echo "Error: WordPress installation directory not found on the staging server."
	exit 1
    fi
    cd "$STAGING_WP_DIR" || { echo "Failed to navigate to WordPress directory: $STAGING_WP_DIR"; exit 1; }
    
    # # Step 11: Import the database and perform dry-run search and replace for site URL (excluding config file)
    # # TIMESTAMP=$(date +"%Y%m%d%H%M%S")
    # EXPORT_DIR="./wp-content/db_exports"
    # EXPORT_FILE="${EXPORT_DIR}/live_db_export.sql"
	# PREFIX_FILE="${EXPORT_DIR}/wp_prefix.txt"

	# # Read the prefix from the file and update wp-config.php
	# if [ -f "$PREFIX_FILE" ]; then
	# 	WP_PREFIX=$(cat "$PREFIX_FILE")
	# 	echo "Setting the table prefix to '$WP_PREFIX' in wp-config.php..."
	# 	wp config set table_prefix "$WP_PREFIX" --type=variable
	# 	echo "Table prefix updated successfully."
	# else
	# 	echo "Prefix file ($PREFIX_FILE) not found. Cannot update table prefix."
	# 	exit 1
	# fi

    # # Import the database
	# echo "Importing database from $EXPORT_FILE"
    # if wp db import "$EXPORT_FILE"; then
    #     echo "Database imported successfully."
    # else
    #     echo "Database import failed. Exiting."
    #     exit 1
    # fi

	# echo "Updating site"


	# wp option update siteurl "$STAGING_URL"
	# wp option update home "$STAGING_URL"

    # # Step 12 (Dry Run): Perform dry-run search and replace for the live URL (no changes will be made to the database)
    # echo ""
    # echo "Dry run: Performing search and replace for site URL..."
    # echo ""
    # if wp search-replace "$LIVE_URL" "$STAGING_URL" --skip-columns=guid --all-tables --dry-run; then
	# echo "Dry run search and replace for site URL completed successfully."
	# echo ""
	# echo "Performing search replace $LIVE_URL -> $STAGING_URL"
	# echo ""
	# wp search-replace "$LIVE_URL" "$STAGING_URL" --skip-columns=guid --all-tables
	# echo "search and replace for site URL completed successfully."
    # else
	# echo "Dry run search and replace failed."
    # fi

	# CURRENT_SITEURL=$(wp option get siteurl)
	# if [ "$CURRENT_SITEURL" != "$STAGING_URL" ]; then
	# 	wp option update siteurl "$STAGING_URL"
	# 	wp option update home "$STAGING_URL"
	# fi
	# echo "Updated the URLs."

    # # 1a. Check if WooCommerce Follow Up Emails is active and deactivate if necessary
    # FOLLOWUP_EMAILS_PLUGIN="woocommerce-follow-up-emails/woocommerce-follow-up-emails.php"
    # echo "Checking if WooCommerce Follow Up Emails plugin is active..."
    # if wp plugin is-active "$FOLLOWUP_EMAILS_PLUGIN"; then
	# echo "Deactivating WooCommerce Follow Up Emails plugin..."
	# wp plugin deactivate "$FOLLOWUP_EMAILS_PLUGIN" || handle_error "Failed to deactivate WooCommerce Follow Up Emails plugin"
    # else
	# echo "WooCommerce Follow Up Emails plugin is not active."
    # fi

    # # 2. Install required plugins on the staging site
    # REQUIRED_PLUGINS=("stop-emails" "email-log")
    # for PLUGIN in "${REQUIRED_PLUGINS[@]}"; do
	# echo "Checking if plugin '$PLUGIN' is active..."
	# if wp plugin is-active "$PLUGIN"; then
	#     echo "Plugin '$PLUGIN' is already active. Skipping installation."
	# else
	#     echo "Installing and activating plugin '$PLUGIN'..."
	#     wp plugin install "$PLUGIN" --activate || handle_error "Failed to install and activate plugin '$PLUGIN'"
	# fi
    # done

    # # 3. Append 'wdm' at the end of each user email and user login if they don't already have it
    # echo "Appending 'wdm' to user emails and usernames where it doesn't already exist..."
    # wp db query "
	# UPDATE wp_users
	# SET user_email = CONCAT(user_email, 'wdm')
	# WHERE user_email NOT LIKE '%wdm';

	# UPDATE wp_users
	# SET user_login = CONCAT(user_login, 'wdm')
	# WHERE user_login NOT LIKE '%wdm';
    # " || handle_error "Failed to append 'wdm' to user emails and usernames"

    # echo "Successfully appended 'wdm' to user emails and usernames where necessary."
    
    # Backup plugins, themes, and database
    echo "Creating a backup of plugins, themes, and database..."
    BACKUP_DIR="$STAGING_WP_DIR/TechOps_Backups"
    mkdir -p "$BACKUP_DIR"
##########################################################

    # Backup plugins
    echo "Backing up plugins..."
    PLUGIN_BACKUP_FILE="$BACKUP_DIR/plugins_backup_$(date +"%Y%m%d%H%M%S").zip"
    zip -r "$PLUGIN_BACKUP_FILE" wp-content/plugins > /dev/null || { echo "Failed to backup plugins."; exit 1; }
    echo "Plugins backup saved to: $PLUGIN_BACKUP_FILE"

    # Backup themes
    echo "Backing up themes..."
    THEME_BACKUP_FILE="$BACKUP_DIR/themes_backup_$(date +"%Y%m%d%H%M%S").zip"
    zip -r "$THEME_BACKUP_FILE" wp-content/themes > /dev/null || { echo "Failed to backup themes."; exit 1; }
    echo "Themes backup saved to: $THEME_BACKUP_FILE"

    # Backup database
    echo "Backing up database..."
    DB_BACKUP_FILE="$BACKUP_DIR/db_backup_$(date +"%Y%m%d%H%M%S").sql"
    if wp db export "$DB_BACKUP_FILE"; then
	echo "Database backup saved to: $DB_BACKUP_FILE"
    else
	echo "Failed to backup database."; exit 1;
    fi

    echo "All backups completed successfully in: $BACKUP_DIR"
    
##########################################################

# Create 'TechOps Reports' directory for reports
    echo "Creating 'TechOps Reports' directory..."
    REPORT_DIR="$STAGING_WP_DIR/TechOps_Reports"
    mkdir -p "$REPORT_DIR"

    # Generate plugin and theme reports before updates
    echo "Generating pre-update plugin and theme report..."
    PLUGIN_REPORT_BEFORE="$REPORT_DIR/plugin_report_before_update_$(date +"%Y%m%d%H%M%S").txt"
    THEME_REPORT_BEFORE="$REPORT_DIR/theme_report_before_update_$(date +"%Y%m%d%H%M%S").txt"

    wp plugin list --fields=name,status,version,update_version --format=table > "$PLUGIN_REPORT_BEFORE" || { echo "Failed to generate plugin report."; exit 1; }
    wp theme list --fields=name,status,version,update_version --format=table > "$THEME_REPORT_BEFORE" || { echo "Failed to generate theme report."; exit 1; }

    echo "Pre-update plugin report saved to: $PLUGIN_REPORT_BEFORE"
    echo "Pre-update theme report saved to: $THEME_REPORT_BEFORE"
    
###############################################################

    # # Step 13: Dry run update of plugins and themes with exceptions for failed plugins
    # echo "Dry run update of all plugins..."
    # if wp plugin update --all --dry-run; then
	# echo "Plugin update dry run completed successfully."
	# echo ""
	# echo "Updating all plugins"
	# echo ""
	# wp plugin update --all
	# echo "Plugin update completed successfully."
    # else
	# echo "Plugin update dry run failed. Skipping some plugins."
    # fi

    # # Dry run update of themes
    # echo "Dry run update of all themes..."
    # if wp theme update --all --dry-run; then
	# echo "Theme update dry run completed successfully."
    # else
	# echo "Theme update dry run failed. Skipping some themes."
    # fi
    
    
echo ""
echo "Fetching initial plugin counts..."

########################################
# Capture initial plugin lists by type
########################################

# Note: "All Plugins" here excludes must-use and dropins by filtering on active and inactive.
initial_active_plugins_list=($(wp plugin list --status=active --field=name --quiet))
initial_all_plugins_list=($(wp plugin list --status=active,inactive --field=name --quiet))
initial_mu_plugins_list=($(wp plugin list --status=must-use --field=name --quiet))
initial_dropins_list=($(wp plugin list --status=dropin --field=name --quiet))

echo ""
echo "Initial Plugin Counts:"
echo "Active plugins - ${#initial_active_plugins_list[@]}"
echo "All Plugins (active & inactive) - ${#initial_all_plugins_list[@]}"
echo "Must Use Plugins - ${#initial_mu_plugins_list[@]}"
echo "Dropins - ${#initial_dropins_list[@]}"
echo ""

########################################
# Update Plugins if Updates Are Available
########################################
echo "Checking for available plugin updates..."
plugins_to_update=($(wp plugin list --update=available --field=name --quiet))
if [ ${#plugins_to_update[@]} -eq 0 ]; then
  echo "No plugin updates available."
else
  echo "Plugins with available updates: ${plugins_to_update[@]}"
  echo "Starting iterative update of plugins..."
  failed_plugins=()
  active_plugins=("${plugins_to_update[@]}")
  
  while true; do
      progress=0
      remaining_plugins=()
      
      for plugin in "${active_plugins[@]}"; do
           echo "Performing dry run for plugin: $plugin"
           if wp plugin update "$plugin" --dry-run --quiet; then
               echo "Dry run successful for $plugin. Attempting update..."
               if wp plugin update "$plugin" --quiet; then
                   echo "Plugin $plugin updated successfully."
                   progress=1
               else
                   echo "Actual update failed for $plugin. It might be waiting on dependent plugins."
                   remaining_plugins+=("$plugin")
               fi
           else
               echo "Dry run failed for $plugin. Likely due to dependency issues."
               remaining_plugins+=("$plugin")
           fi
      done

      if [ ${#remaining_plugins[@]} -eq 0 ]; then
           echo "All plugins updated successfully."
           break
      fi

      if [ $progress -eq 0 ]; then
           echo "No further progress could be made updating the following plugins:"
           printf '  %s\n' "${remaining_plugins[@]}"
           failed_plugins=("${remaining_plugins[@]}")
           break
      fi

      active_plugins=("${remaining_plugins[@]}")
      echo "Retrying updates for remaining plugins..."
      echo ""
  done

  if [[ ${#failed_plugins[@]} -gt 0 ]]; then
      echo "The following plugins could not be updated:"
      printf '  %s\n' "${failed_plugins[@]}"
  fi
fi

########################################
# After updates, capture the final plugin lists by type
########################################

final_active_plugins_list=($(wp plugin list --status=active --field=name --quiet))
final_all_plugins_list=($(wp plugin list --status=active,inactive --field=name --quiet))
final_mu_plugins_list=($(wp plugin list --status=must-use --field=name --quiet))
final_dropins_list=($(wp plugin list --status=dropin --field=name --quiet))

echo ""
echo "Final Plugin Counts:"
echo "Active plugins - ${#final_active_plugins_list[@]}"
echo "All Plugins (active & inactive) - ${#final_all_plugins_list[@]}"
echo "Must Use Plugins - ${#final_mu_plugins_list[@]}"
echo "Dropins - ${#final_dropins_list[@]}"
echo ""

########################################
# Function to compare arrays: returns items in first array not present in second
########################################
function array_diff() {
    local -n arr1=$1
    local -n arr2=$2
    local diff=()
    for item in "${arr1[@]}"; do
        local found=0
        for comp in "${arr2[@]}"; do
            if [[ "$item" == "$comp" ]]; then
                found=1
                break
            fi
        done
        if [ $found -eq 0 ]; then
            diff+=("$item")
        fi
    done
    echo "${diff[@]}"
}

########################################
# Compute deleted plugins for each category
########################################

deleted_active_plugins=($(array_diff initial_active_plugins_list final_active_plugins_list))
deleted_all_plugins=($(array_diff initial_all_plugins_list final_all_plugins_list))
deleted_mu_plugins=($(array_diff initial_mu_plugins_list final_mu_plugins_list))
deleted_dropins=($(array_diff initial_dropins_list final_dropins_list))

########################################
# Print deleted plugins categorized by type
########################################

if [ ${#deleted_active_plugins[@]} -gt 0 ]; then
    echo "Deleted Active Plugins -"
    for plugin in "${deleted_active_plugins[@]}"; do
        echo "$plugin"
    done
fi

if [ ${#deleted_dropins[@]} -gt 0 ]; then
    echo ""
    echo "Deleted Dropin Plugin -"
    for plugin in "${deleted_dropins[@]}"; do
        echo "$plugin"
    done
fi

if [ ${#deleted_mu_plugins[@]} -gt 0 ]; then
    echo ""
    echo "Deleted Must Use Plugin -"
    for plugin in "${deleted_mu_plugins[@]}"; do
        echo "$plugin"
    done
fi

if [ ${#deleted_all_plugins[@]} -gt 0 ]; then
    echo ""
    echo "Deleted All Plugins (active & inactive) -"
    for plugin in "${deleted_all_plugins[@]}"; do
        echo "$plugin"
    done
fi

echo ""
echo "Comparison complete."

########################################
# Update Themes if Updates Are Available
########################################
echo ""
echo "Checking for available theme updates..."
themes_to_update=($(wp theme list --update=available --field=name --quiet))
if [ ${#themes_to_update[@]} -eq 0 ]; then
  echo "No theme updates available."
else
  echo "Themes with available updates: ${themes_to_update[@]}"
  echo "Starting iterative update of themes..."
  failed_themes=()
  active_themes=("${themes_to_update[@]}")
  
  while true; do
      progress=0
      remaining_themes=()
      
      for theme in "${active_themes[@]}"; do
           echo "Performing dry run for theme: $theme"
           if wp theme update "$theme" --dry-run --quiet; then
               echo "Dry run successful for $theme. Attempting update..."
               if wp theme update "$theme" --quiet; then
                   echo "Theme $theme updated successfully."
                   progress=1
               else
                   echo "Actual update failed for $theme. It will be retried."
                   remaining_themes+=("$theme")
               fi
           else
               echo "Dry run failed for $theme."
               remaining_themes+=("$theme")
           fi
      done

      if [ ${#remaining_themes[@]} -eq 0 ]; then
           echo "All themes updated successfully."
           break
      fi

      if [ $progress -eq 0 ]; then
           echo "No further progress could be made updating the following themes:"
           printf '  %s\n' "${remaining_themes[@]}"
           failed_themes=("${remaining_themes[@]}")
           break
      fi

      active_themes=("${remaining_themes[@]}")
      echo "Retrying updates for remaining themes..."
      echo ""
  done

  if [[ ${#failed_themes[@]} -gt 0 ]]; then
      echo "The following themes could not be updated:"
      printf '  %s\n' "${failed_themes[@]}"
  fi
fi

echo ""
echo "Updates completed."

    
################################################################

 # Generate plugin and theme reports after updates
    echo "Generating post-update plugin and theme report..."
    PLUGIN_REPORT_AFTER="$REPORT_DIR/plugin_report_after_update_$(date +"%Y%m%d%H%M%S").txt"
    THEME_REPORT_AFTER="$REPORT_DIR/theme_report_after_update_$(date +"%Y%m%d%H%M%S").txt"

    wp plugin list --fields=name,status,version,update_version --format=table > "$PLUGIN_REPORT_AFTER" || { echo "Failed to generate plugin report."; exit 1; }
    wp theme list --fields=name,status,version,update_version --format=table > "$THEME_REPORT_AFTER" || { echo "Failed to generate theme report."; exit 1; }

    echo "Post-update plugin report saved to: $PLUGIN_REPORT_AFTER"
    echo "Post-update theme report saved to: $THEME_REPORT_AFTER"
    
################################################################

### Logic for comparing plugin and theme version on live site

# Compare reports and apply actions
# echo "Processing plugin and theme version differences..."

# # Process Plugins
# echo "Processing plugins..."
# if [[ -f "$PLUGIN_REPORT_BEFORE" && -f "$PLUGIN_REPORT_AFTER" ]]; then
#     awk -v wp_cli_cmd="wp plugin install" '
#         BEGIN { print "Analyzing plugins..." }
#         NR == FNR && $1 != "name" { before[$1] = $3; next }
#         NR != FNR && $1 != "name" {
#             plugin = $1;
#             before_ver = before[plugin];
#             after_ver = $3;
#             if (after_ver > before_ver) {
#                 print "Upgrading plugin: " plugin " from version " before_ver " to " after_ver;
#                 system(wp_cli_cmd " " plugin " --version=" after_ver " --force")
#             } else if (after_ver < before_ver) {
#                 print "Downgrading plugin: " plugin " from version " before_ver " to " after_ver;
#                 system(wp_cli_cmd " " plugin " --version=" after_ver " --force")
#             } else {
#                 print "No changes needed for plugin: " plugin;
#             }
#         }
#     ' "$PLUGIN_REPORT_BEFORE" "$PLUGIN_REPORT_AFTER"
# else
#     echo "Warning: Plugin reports not found, skipping plugin comparison."
# fi

# # Process Themes
# echo "Processing themes..."
# if [[ -f "$THEME_REPORT_BEFORE" && -f "$THEME_REPORT_AFTER" ]]; then
#     awk -v wp_cli_cmd="wp theme install" '
#         BEGIN { print "Analyzing themes..." }
#         NR == FNR && $1 != "name" { before[$1] = $3; next }
#         NR != FNR && $1 != "name" {
#             theme = $1;
#             before_ver = before[theme];
#             after_ver = $3;
#             if (after_ver > before_ver) {
#                 print "Upgrading theme: " theme " from version " before_ver " to " after_ver;
#                 system(wp_cli_cmd " " theme " --version=" after_ver " --force")
#             } else if (after_ver < before_ver) {
#                 print "Downgrading theme: " theme " from version " before_ver " to " after_ver;
#                 system(wp_cli_cmd " " theme " --version=" after_ver " --force")
#             } else {
#                 print "No changes needed for theme: " theme;
#             }
#         }
#     ' "$THEME_REPORT_BEFORE" "$THEME_REPORT_AFTER"
# else
#     echo "Warning: Theme reports not found, skipping theme comparison."
# fi

# echo "Version comparison and actions completed."


#########################################################################


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

}


visual_regression_reference_run() {
	SERVER_DIR="./backstop-api/"
			cd $SERVER_DIR

			# Open a new GNOME Terminal, change to TESTING_DIR, run the server, and keep the terminal open
			echo "Starting Node server in new GNOME Terminal..."
			# gnome-terminal -- bash -c "cd \"$TESTING_DIR\" && node server.js; exec bash"
			nohup node server.js > server.log 2>&1 &
			SERVER_PID=$!

			echo "$SERVER_PID" > SERVER_PID.txt

			sleep 5

			# Build JSON payload using a heredoc.
# The commented lines are preserved here for reference.
PAYLOAD_KEY="staging_payload"
PAYLOAD=$(jq -c ".${PAYLOAD_KEY}" payload.json)

echo "Sending job creation request to http://localhost:3000/api/visual-regression..."
jobResponse=$(curl -s -X POST "http://localhost:3000/api/visual-regression" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

echo "Job creation response:"
echo "$jobResponse"

# Parse jobId from the response using jq.
jobId=$(echo "$jobResponse" | jq -r '.jobId')
echo "$jobId" > jobid.txt

if [ -z "$jobId" ] || [ "$jobId" == "null" ]; then
    echo "Failed to create job. Exiting."
	kill "$SERVER_PID"
	echo "Node server (PID: $SERVER_PID) has been stopped."
    exit 1
fi

echo "Job created with ID: $jobId"

# Once the job is created (with a pending status), call the reference endpoint
echo "Calling reference endpoint for job ID: $jobId..."
refResponse=$(curl -s -X POST "http://localhost:3000/api/visual-regression/reference/${jobId}" \
  -H "Content-Type: application/json")

echo "Reference endpoint response:"
echo "$refResponse"

echo
echo "=== 3) Polling job status until reference is completed or fails ==="
while true; do
  statusResponse=$(curl -s -X GET "http://localhost:3000/api/visual-regression/$jobId")
  jobStatus=$(echo "$statusResponse" | jq -r '.status')

  echo "Current status: $jobStatus"
  if [ "$jobStatus" == "reference_completed" ]; then
    echo "Reference completed!"
	# kill "$SERVER_PID"
	# echo "Node server (PID: $SERVER_PID) has been stopped."
    # exit 1
	break
  elif [ "$jobStatus" == "failed" ]; then
    echo "Reference failed. Exiting."
	kill "$SERVER_PID"
	echo "Node server (PID: $SERVER_PID) has been stopped."
    exit 1
  fi
  sleep 5  # Poll every 5 seconds
done
}

visual_regression_test_run() {
	# SERVER_DIR="./backstop-api/"
	# 		cd $SERVER_DIR

			# Open a new GNOME Terminal, change to TESTING_DIR, run the server, and keep the terminal open
			# echo "Starting Node server in new GNOME Terminal..."
			# gnome-terminal -- bash -c "cd \"$TESTING_DIR\" && node server.js; exec bash"
			# nohup node server.js > server.log 2>&1 &
			# SERVER_PID=$!

			# sleep 5
SERVER_PID=$(cat SERVER_PID.txt)
jobId=$(cat jobid.txt)
echo
echo "=== 4) Running the test process for job: $jobId ==="
testResponse=$(curl -s -X POST "http://localhost:3000/api/visual-regression/test/$jobId" \
  -H "Content-Type: application/json")

echo "Test start response:"
echo "$testResponse"

echo
echo "=== 5) Polling job status until test is completed or fails ==="
while true; do
  statusResponse=$(curl -s -X GET "http://localhost:3000/api/visual-regression/$jobId")
  jobStatus=$(echo "$statusResponse" | jq -r '.status')

  echo "Current status: $jobStatus"
  if [ "$jobStatus" == "completed" ]; then
    echo "All tests completed successfully!"
    break
  elif [ "$jobStatus" == "failed" ]; then
    echo "Test failed. Exiting."
	kill "$SERVER_PID"
	echo "Node server (PID: $SERVER_PID) has been stopped."
    # exit 0
	break
  fi

  # Poll every 5 seconds
  sleep 5
done

# kill "$SERVER_PID"
# echo "Node server (PID: $SERVER_PID) has been stopped."

REPORT_DIR="./backstop_data/html_report"
INDEX_FILE="$REPORT_DIR/index.html"

if [ -f "$INDEX_FILE" ]; then
    echo "Opening index.html in Google Chrome..."
    google-chrome "$INDEX_FILE"
else
    echo "Error: File not found: $INDEX_FILE"
    exit 1
fi
}


visual_regression_full_run(){
	SERVER_DIR="./backstop-api/"
			cd $SERVER_DIR

			# Open a new GNOME Terminal, change to TESTING_DIR, run the server, and keep the terminal open
			echo "Starting Node server in new GNOME Terminal..."
			# gnome-terminal -- bash -c "cd \"$TESTING_DIR\" && node server.js; exec bash"
			nohup node server.js > server.log 2>&1 &
			SERVER_PID=$!

			echo "$SERVER_PID" > SERVER_PID.txt

			sleep 5

			# Build JSON payload using a heredoc.
# The commented lines are preserved here for reference.
PAYLOAD_KEY="staging_payload"
PAYLOAD=$(jq -c ".${PAYLOAD_KEY}" payload.json)

echo "Sending job creation request to http://localhost:3000/api/visual-regression..."
jobResponse=$(curl -s -X POST "http://localhost:3000/api/visual-regression" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

echo "Job creation response:"
echo "$jobResponse"

# Parse jobId from the response using jq.
jobId=$(echo "$jobResponse" | jq -r '.jobId')
echo "$jobId" > jobid.txt

if [ -z "$jobId" ] || [ "$jobId" == "null" ]; then
    echo "Failed to create job. Exiting."
	kill "$SERVER_PID"
	echo "Node server (PID: $SERVER_PID) has been stopped."
    exit 1
fi

echo "Job created with ID: $jobId"

# Once the job is created (with a pending status), call the reference endpoint
echo "Calling reference endpoint for job ID: $jobId..."
refResponse=$(curl -s -X POST "http://localhost:3000/api/visual-regression/reference/${jobId}" \
  -H "Content-Type: application/json")

echo "Reference endpoint response:"
echo "$refResponse"

echo
echo "=== 3) Polling job status until reference is completed or fails ==="
while true; do
  statusResponse=$(curl -s -X GET "http://localhost:3000/api/visual-regression/$jobId")
  jobStatus=$(echo "$statusResponse" | jq -r '.status')

  echo "Current status: $jobStatus"
  if [ "$jobStatus" == "reference_completed" ]; then
    echo "Reference completed!"
	# kill "$SERVER_PID"
	# echo "Node server (PID: $SERVER_PID) has been stopped."
    # exit 1
	break
  elif [ "$jobStatus" == "failed" ]; then
    echo "Reference failed. Exiting."
	kill "$SERVER_PID"
	echo "Node server (PID: $SERVER_PID) has been stopped."
    exit 1
  fi
  sleep 5  # Poll every 5 seconds
done

echo
echo "=== 4) Running the test process for job: $jobId ==="
testResponse=$(curl -s -X POST "http://localhost:3000/api/visual-regression/test/$jobId" \
  -H "Content-Type: application/json")

echo "Test start response:"
echo "$testResponse"

echo
echo "=== 5) Polling job status until test is completed or fails ==="
while true; do
  statusResponse=$(curl -s -X GET "http://localhost:3000/api/visual-regression/$jobId")
  jobStatus=$(echo "$statusResponse" | jq -r '.status')

  echo "Current status: $jobStatus"
  if [ "$jobStatus" == "completed" ]; then
    echo "All tests completed successfully!"
    break
  elif [ "$jobStatus" == "failed" ]; then
    echo "Test failed. Exiting."
	kill "$SERVER_PID"
	echo "Node server (PID: $SERVER_PID) has been stopped."
    # exit 0
	break
  fi

  # Poll every 5 seconds
  sleep 5
done

# kill "$SERVER_PID"
# echo "Node server (PID: $SERVER_PID) has been stopped."

REPORT_DIR="./backstop_data/html_report"
INDEX_FILE="$REPORT_DIR/index.html"

if [ -f "$INDEX_FILE" ]; then
    echo "Opening index.html in Google Chrome..."
    google-chrome "$INDEX_FILE"
else
    echo "Error: File not found: $INDEX_FILE"
    exit 1
fi

}





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
		    LIVE_PASSWORD=$(read_from_xml "$PARAM_FILE" "live" "password")
			LIVE_WP_DIR=$(read_from_xml "$PARAM_FILE" "live" "wpdir")
			LIVE_SSHKEY=$(read_from_xml "$PARAM_FILE" "live" "sshkeypath")

		    # Extract staging configuration
		    STAGING_HOST=$(read_from_xml "$PARAM_FILE" "staging" "host")
		    STAGING_PORT=$(read_from_xml "$PARAM_FILE" "staging" "port")
		    STAGING_USER=$(read_from_xml "$PARAM_FILE" "staging" "user")
		    STAGING_URL=$(read_from_xml "$PARAM_FILE" "staging" "url")
		    STAGING_PASSWORD=$(read_from_xml "$PARAM_FILE" "staging" "password")
			STAGING_WP_DIR=$(read_from_xml "$PARAM_FILE" "staging" "wpdir")
			STAGING_SSHKEY=$(read_from_xml "$PARAM_FILE" "staging" "sshkeypath")

		    # Export variables to make them globally accessible
		    export LIVE_HOST LIVE_PORT LIVE_USER LIVE_URL LIVE_WP_DIR LIVE_SSHKEY
		    export STAGING_HOST STAGING_PORT STAGING_USER STAGING_URL STAGING_WP_DIR STAGING_SSHKEY
		}

		# Extract SSH credentials and URLs from the XML file
		extract_parameters 2>/dev/null

		# Step 2: Validate extracted parameters
		if [[ -z "$LIVE_HOST" || -z "$STAGING_HOST" || -z "$LIVE_URL" || -z "$STAGING_URL" ]]; then
		    echo "Error: Missing required parameters in the xml file."
		    exit 1
		fi

		# Remove trailing slash if present
		LIVE_URL="${LIVE_URL%/}"
		STAGING_URL="${STAGING_URL%/}"

		echo "All parameters read successfully:"
		echo "LIVE_HOST=$LIVE_HOST"
		echo "STAGING_HOST=$STAGING_HOST"
		echo "LIVE_URL=$LIVE_URL"
		echo "STAGING_URL=$STAGING_URL"
		echo "LIVE_WP_DIR=$LIVE_WP_DIR"
		echo "STAGING_WP_DIR=$STAGING_WP_DIR"
		echo "LIVE_SSHKEY=$LIVE_SSHKEY"
		echo "STAGING_SSHKEY=$STAGING_SSHKEY"

while true; do
	# List of Actions
	echo ""
	echo ""
	echo "Please choose an action by entering a number:"
	# echo "1. Read XML File"
	echo "1. Clone Live to Staging"
	echo "2. Take Staging Backup"
	echo "3. Take Live Backup"
	echo "4. Perform TechOps on Staging"
	echo "5. Perform TechOps on Live"
	echo "6. Visual Regression Reference Run"
	echo "7. Visual Regression Test Run"
	echo "8. Visual Regression Full Run (Imediately after cloning)"
	echo "9. Exit Program"

	# Taking user input for action number
	read -p "Enter a number (1-9): " action_number

# Perform action based on user input
	case $action_number in
        1)
		echo "You selected: Clone Live to Staging"
		# Call the function to clone live to staging (you can add the actual logic)
		clone_live
		;;
	    2)
		echo "You selected: Take Staging Backup -  - This feature is under developement."
		# Call the function to take staging backup (you can add the actual logic)
		;;
	    3)
		echo "You selected: Take Live Backup - This feature is under developement."
		# Call the function to take live backup (you can add the actual logic)
		;;
	    4)
		echo "You selected: Perform TechOps on Staging"
		# Call the function to perform TechOps on Staging (you can add the actual logic)
		perform_techops_on_staging
		;;
	    5)
		echo "You selected: Perform TechOps on Live - This feature is under developement."
		# Call the function to perform TechOps on Live (you can add the actual logic)
		;;
	    6)
		    echo "Performing Reference Run"
			visual_regression_reference_run
		    ;;
		
		7)
		    echo "Performing Test Run"
		    visual_regression_test_run
		    ;;


		8)
		    echo "Perfomring Full Run"
			visual_regression_full_run
		    # exit 0
		    ;;

		9)
		    echo "Exiting the program. Goodbye!"
		    exit 0
		    ;;

	    *)
	    	echo "Invalid selection. Please choose a number between 1 and 7."
	    	;;
	esac
done

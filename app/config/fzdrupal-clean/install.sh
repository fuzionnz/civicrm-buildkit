#!/bin/bash

## install.sh -- Create config files and databases; fill the databases

###############################################################################
## Append the civibuild settings directives to a file
## usage: cvutil_inject_settings <php-file> <settings-dir-name>
## example: cvutil_inject_settings "/var/www/build/drupal/sites/foo/civicrm.settings.php" "civicrm.settings.d"
## example: cvutil_inject_settings "/var/www/build/drupal/sites/foo/settings.php" "drupal.settings.d"
function cvutil_fuzion_inject_settings() {
  local FILE="$1"
  local NAME="$2"
  cvutil_assertvars cvutil_inject_settings PRJDIR SITE_NAME SITE_TYPE SITE_CONFIG_DIR SITE_ID SITE_TOKEN PRIVATE_ROOT FILE NAME CMS_URL

  ## Prepare temp file
  local TMPFILE="${TMPDIR}/${SITE_TYPE}/${SITE_NAME}/${SITE_ID}.settings.tmp"
  cvutil_makeparent "$TMPFILE"

  cat > "$TMPFILE" << EOF
<?php
    #### If deployed via civibuild, include any "pre" scripts
    global \$civibuild;
    \$civibuild['PRJDIR'] = '$PRJDIR';
    \$civibuild['SITE_CONFIG_DIR'] = '$SITE_CONFIG_DIR';
    \$civibuild['SITE_TYPE'] = '$SITE_TYPE';
    \$civibuild['SITE_NAME'] = '$SITE_NAME';
    \$civibuild['SITE_ID'] = '$SITE_ID';
    \$civibuild['SITE_TOKEN'] = '$SITE_TOKEN';
    \$civibuild['PRIVATE_ROOT'] = '$PRIVATE_ROOT';
    \$civibuild['WEB_ROOT'] = '$WEB_ROOT';
    \$civibuild['CMS_ROOT'] = '$CMS_ROOT';
    \$base_url = '$CMS_URL';

    if (file_exists(\$civibuild['PRJDIR'].'/src/civibuild.settings.php')) {
      require_once \$civibuild['PRJDIR'].'/src/civibuild.settings.php';
      _civibuild_settings(__FILE__, '$NAME', \$civibuild, 'pre');
    }

EOF

  # Don't know if FILE has good newlines, so prefix/postfix both have extras
  sed 's/^<?php//' < "$FILE" >> "$TMPFILE"

  cat >> "$TMPFILE" << EOF

    #### If deployed via civibuild, include any "post" scripts
    if (file_exists(\$civibuild['PRJDIR'].'/src/civibuild.settings.php')) {
      require_once \$civibuild['PRJDIR'].'/src/civibuild.settings.php';
      _civibuild_settings(__FILE__, '$NAME', \$civibuild, 'post');
    }
EOF

  ## Replace main file with temp file
  cat < "$TMPFILE" > "$FILE"
}

###############################################################################
## Drupal -- Generate config files and setup database
## usage: drupal_install <extra-drush-args>
## To use an "install profile", simply pass it as part of <extra-drush-args>
function drupal_fuzion_install() {
  cvutil_assertvars drupal7_install CMS_ROOT SITE_ID CMS_TITLE CMS_DB_USER CMS_DB_PASS CMS_DB_HOST CMS_DB_NAME ADMIN_USER ADMIN_PASS CMS_URL
  DRUPAL_SITE_DIR=$(_drupal_multisite_dir "$CMS_URL" "$SITE_ID")
  CMS_DB_HOSTPORT=$(cvutil_build_hostport "$CMS_DB_HOST" "$CMS_DB_PORT")
  pushd "$CMS_ROOT" >> /dev/null
    [ -f "sites/$DRUPAL_SITE_DIR/settings.php" ] && rm -f "sites/$DRUPAL_SITE_DIR/settings.php"

    drush site-install fuzion -y "$@" \
      --db-url="mysql://${CMS_DB_USER}:${CMS_DB_PASS}@${CMS_DB_HOSTPORT}/${CMS_DB_NAME}" \
      --account-name="$ADMIN_USER" \
      --account-pass="$ADMIN_PASS" \
      --account-mail="$ADMIN_EMAIL" \
      --site-name="$CMS_TITLE" \
      --sites-subdir="$DRUPAL_SITE_DIR"
    chmod u+w "sites/$DRUPAL_SITE_DIR"
    chmod u+w "sites/$DRUPAL_SITE_DIR/settings.php"
    ls -lAF "sites/$DRUPAL_SITE_DIR/settings.php"
    cvutil_fuzion_inject_settings "$CMS_ROOT/sites/$DRUPAL_SITE_DIR/settings.php" "drupal.settings.d"
    chmod u-w "sites/$DRUPAL_SITE_DIR/settings.php"
    ## Setup extra directories
    amp datadir "sites/${DRUPAL_SITE_DIR}/files" "${PRIVATE_ROOT}/${DRUPAL_SITE_DIR}"
    cvutil_mkdir "sites/${DRUPAL_SITE_DIR}/modules"
    drush vset --yes file_private_path "${PRIVATE_ROOT}/${DRUPAL_SITE_DIR}"
    [ -n "$APACHE_VHOST_ALIAS" ] && cvutil_ed .htaccess '# RewriteBase /$' 's;# RewriteBase /$;RewriteBase /;'
  popd >> /dev/null
}

###############################################################################
## Create virtual-host and databases

amp_install

###############################################################################
## Setup Drupal (config files, database tables)
###############################################################################
## Drupal -- Generate config files and setup database
## usage: drupal_install <extra-drush-args>
## To use an "install profile", simply pass it as part of <extra-drush-args>
function drupal_fuzion_install() {
  cvutil_assertvars drupal7_install CMS_ROOT SITE_ID CMS_TITLE CMS_DB_USER CMS_DB_PASS CMS_DB_HOST CMS_DB_NAME ADMIN_USER ADMIN_PASS CMS_URL
  DRUPAL_SITE_DIR=$(_drupal_multisite_dir "$CMS_URL" "$SITE_ID")
  CMS_DB_HOSTPORT=$(cvutil_build_hostport "$CMS_DB_HOST" "$CMS_DB_PORT")
  pushd "$CMS_ROOT" >> /dev/null
    [ -f "sites/$DRUPAL_SITE_DIR/settings.php" ] && rm -f "sites/$DRUPAL_SITE_DIR/settings.php"

    drush site-install fuzion -y "$@" \
      --db-url="mysql://${CMS_DB_USER}:${CMS_DB_PASS}@${CMS_DB_HOSTPORT}/${CMS_DB_NAME}" \
      --account-name="$ADMIN_USER" \
      --account-pass="$ADMIN_PASS" \
      --account-mail="$ADMIN_EMAIL" \
      --site-name="$CMS_TITLE" \
      --sites-subdir="$DRUPAL_SITE_DIR"
    chmod u+w "sites/$DRUPAL_SITE_DIR"
    chmod u+w "sites/$DRUPAL_SITE_DIR/settings.php"
    ls -lAF "sites/$DRUPAL_SITE_DIR/settings.php"
    cvutil_inject_settings "$CMS_ROOT/sites/$DRUPAL_SITE_DIR/settings.php" "drupal.settings.d"
    chmod u-w "sites/$DRUPAL_SITE_DIR/settings.php"
    ## Setup extra directories
    amp datadir "sites/${DRUPAL_SITE_DIR}/files" "${PRIVATE_ROOT}/${DRUPAL_SITE_DIR}"
    cvutil_mkdir "sites/${DRUPAL_SITE_DIR}/modules"
    drush vset --yes file_private_path "${PRIVATE_ROOT}/${DRUPAL_SITE_DIR}"
    [ -n "$APACHE_VHOST_ALIAS" ] && cvutil_ed .htaccess '# RewriteBase /$' 's;# RewriteBase /$;RewriteBase /;'
  popd >> /dev/null
}

drupal_fuzion_install

###############################################################################
## Setup CiviCRM (config files, database tables)

DRUPAL_SITE_DIR=$(_drupal_multisite_dir "$CMS_URL" "$SITE_ID")
CIVI_DOMAIN_NAME="Demonstrators Anonymous"
CIVI_DOMAIN_EMAIL="\"Demonstrators Anonymous\" <info@example.org>"
CIVI_CORE="${WEB_ROOT}/sites/all/modules/civicrm"
CIVI_SETTINGS="${WEB_ROOT}/sites/${DRUPAL_SITE_DIR}/civicrm.settings.php"
CIVI_FILES="${WEB_ROOT}/sites/${DRUPAL_SITE_DIR}/files/civicrm"
CIVI_TEMPLATEC="${CIVI_FILES}/templates_c"
CIVI_UF="Drupal"

## civicrm-core v4.7+ sets default ext dir; for older versions, we'll set our own.
if [[ "$CIVI_VERSION" =~ ^4.[0123456](\.([0-9]|alpha|beta)+)?$ ]] ; then
  CIVI_EXT_DIR="${WEB_ROOT}/sites/${DRUPAL_SITE_DIR}/ext"
  CIVI_EXT_URL="${CMS_URL}/sites/${DRUPAL_SITE_DIR}/ext"
fi

civicrm_install

###############################################################################
## Extra configuration
pushd "${WEB_ROOT}/sites/${DRUPAL_SITE_DIR}" >> /dev/null

  drush -y updatedb
  drush -y en admin_menu admin_menu_toolbar civicrm locale garland login_destination userprotect
  ## disable annoying/unneeded modules
  drush -y dis overlay toolbar

  ## Setup theme
  #above# drush -y en garland
  export SITE_CONFIG_DIR
  drush -y -u "$ADMIN_USER" scr "$SITE_CONFIG_DIR/install-theme.php"

  ## Based on the block info, CRM_Core_Block::CREATE_NEW and CRM_Core_Block::ADD should be enabled by default, but they aren't.
  ## "drush -y cc all" and "drush -y cc block" do *NOT* solve the problem. But this does:
  drush php-eval -u "$ADMIN_USER" 'module_load_include("inc","block","block.admin"); block_admin_display();'

  ## Setup demo user
  drush -y en civicrm_webtest
  drush -y user-create --password="$DEMO_PASS" --mail="$DEMO_EMAIL" "$DEMO_USER"
  drush -y user-add-role civicrm_webtest_user "$DEMO_USER"
  # We've activated more components than typical web-test baseline, so grant rights to those components.
  #for perm in 'access toolbar'
  #do
  #  drush -y role-add-perm civicrm_webtest_user "$perm"
  #done

popd >> /dev/null

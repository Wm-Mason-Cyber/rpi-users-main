#!/usr/bin/env bash
set -euo pipefail

# quick script to create two users and a limited sudo group
# Usage: sudo ./setup.sh {Teacher user name} {Teacher password} {Student Username} {Student Password} {Fake Admin Group Name}

# Help Clause
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "Usage: sudo ./setup.sh [-t teacher_username] [-T teacher_password] [-s student_username] [-S student_password] [-g group]"
  exit 0
fi

# Sudo Error Clause
if [ "$(id -u)" -ne 0 ]; then
  echo "error: Use sudo dude." >&2
  exit 1
fi


# assign variables and use defaults if not arguments

USER_ADMIN="teacher"
PASS_ADMIN="letmein"
USER_STUDENT="student"
PASS_STUDENT="studentpass"
GROUP="fake_admin"
SUDOERS_FILE="/etc/sudoers.d/${GROUP}"


while getopts ":t:T:s:S:g:" opt; do
  case $opt in
    t)
      USER_ADMIN="$OPTARG"
      ;;
    T)
      PASS_ADMIN="$OPTARG"
      ;;
    s)
      USER_STUDENT="$OPTARG"
      ;;
    S)
      PASS_STUDENT="$OPTARG"
      ;;
    g)
      GROUP="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG"
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument."
      exit 1
      ;;
  esac
done


#Print out the variables
echo "Admin user: $USER_ADMIN"
echo "Student user: $USER_STUDENT"
echo "Group: $GROUP"


# Update + git
apt-get update
apt-get install -y git
apt upgrade -y
apt-get autoremove -y
apt-get clean

# Create group if missing
if ! getent group "${GROUP}" >/dev/null; then
  groupadd "${GROUP}"
  echo "Created group ${GROUP}"
else
  echo "Group ${GROUP} already exists"
fi

# Create or update admin user and add to group
if ! id "${USER_ADMIN}" >/dev/null 2>&1; then
  useradd -m -s /bin/bash -G "${GROUP}" -c "Limited admin account" "${USER_ADMIN}"
  echo "Created user ${USER_ADMIN}"
else
  usermod -aG "${GROUP}" "${USER_ADMIN}"
  echo "User ${USER_ADMIN} already exists — added to ${GROUP}"
fi

# Make admin password
echo "${USER_ADMIN}:${PASS_ADMIN}" | chpasswd

# Create student user (not a sudoer)
if ! id "${USER_STUDENT}" >/dev/null 2>&1; then
  useradd -m -s /bin/bash -c "Student account" "${USER_STUDENT}"
  echo "${USER_STUDENT}:${PASS_STUDENT}" | chpasswd
  echo "Created user ${USER_STUDENT}"
else
  echo "User ${USER_STUDENT} already exists"
fi

# Create sudo perms for fake admin
cat > "${SUDOERS_FILE}" <<EOF
# limit sudo for ${GROUP} group

Cmnd_Alias APT_CMDS = /usr/bin/apt, /usr/bin/apt-get, /usr/bin/apt-cache, /usr/bin/dpkg
Cmnd_Alias REBOOT_CMDS = /sbin/reboot, /usr/sbin/reboot, /bin/reboot, /usr/bin/systemctl reboot

# To add more available commands:
# add another Cmnd_Alias above with the path to the bin or sbin
# then, add it to the end of the %${GROUP} list 

%${GROUP} ALL=(ALL) APT_CMDS, REBOOT_CMDS
EOF


chmod 0440 "${SUDOERS_FILE}"
if visudo -c -f "${SUDOERS_FILE}"; then
  echo "Sudoers file ${SUDOERS_FILE} created and validated."
else
  echo "ERROR: sudoers validation failed. Removing ${SUDOERS_FILE}." >&2
  rm -f "${SUDOERS_FILE}"
  exit 1
fi

#clones github reporsity into correct apachii directory

mkdir -p /var/www/html
sudo git clone https://github.com/Wm-Mason-Cyber/rpi-users-main /var/www/html

echo "Done!"

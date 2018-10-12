# Save a backup of the original file
if [[ ! -e /etc/apt/sources.list.original ]]; then
  mv /etc/apt/sources.list /etc/apt/sources.list.original
fi

# Set the environment variables
DISTRO_MIRROR="http://mirror.rackspace.com/ubuntu"
DISTRO_COMPONENTS="main,universe"

# Get the distribution name
if [[ -e /etc/lsb-release ]]; then
  source /etc/lsb-release
  DISTRO_RELEASE=${DISTRIB_CODENAME}
elif [[ -e /etc/os-release ]]; then
  source /etc/os-release
  DISTRO_RELEASE=${UBUNTU_CODENAME}
else
  echo "Unable to determine distribution due to missing lsb/os-release files."
  exit 1
fi

# Rewrite the apt sources file
cat << EOF >/etc/apt/sources.list
deb ${DISTRO_MIRROR} ${DISTRO_RELEASE} ${DISTRO_COMPONENTS//,/ }
deb ${DISTRO_MIRROR} ${DISTRO_RELEASE}-updates ${DISTRO_COMPONENTS//,/ }
deb ${DISTRO_MIRROR} ${DISTRO_RELEASE}-backports ${DISTRO_COMPONENTS//,/ }
deb ${DISTRO_MIRROR} ${DISTRO_RELEASE}-security ${DISTRO_COMPONENTS//,/ }
EOF

# Add apt debug configuration
echo 'Debug::Acquire::http "true";' > /etc/apt/apt.conf.d/99debug

# Ensure package installs are in headless mode
export DEBIAN_FRONTEND=noninteractive

# Update the apt cache
apt-get update

# Install pre-requisites
pkgs_to_install=""
dpkg-query --list | grep python-minimal &>/dev/null || pkgs_to_install+="python-minimal "
dpkg-query --list | grep python-yaml &>/dev/null || pkgs_to_install+="python-yaml "
if [ "${pkgs_to_install}" != "" ]; then
  apt-get install -y ${pkgs_to_install}
fi

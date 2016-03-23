#!/bin/bash -x

env > buildenv

#fix sudoers because jenkins jcloud plugin stamps on it.
sudo tee -a /etc/sudoers <<ESUDOERS
%admin ALL=(ALL) ALL

# Allow members of group sudo to execute any command
%sudo   ALL=(ALL:ALL) ALL

# See sudoers(5) for more information on "#include" directives:

#includedir /etc/sudoers.d
ESUDOERS

UPGRADE="yes"
UPGRADE_FROM_REF="origin/kilo"
UPGRADE_FROM_NEAREST_TAG="yes"

if [ "$UPGRADE_FROM_NEAREST_TAG" == "yes" ]
  then
    COMMITISH=$(git describe --tags --abbrev=0 $UPGRADE_FROM_REF)
else
    COMMITISH=$UPGRADE_FROM_REF
fi
if [ "$UPGRADE" == "yes" ]
  then
    git fetch
    git checkout $COMMITISH || {
      echo "Checkout failed, quitting"
      exit 1
    }
    git submodule update --init
else
    echo "Rebasing ${sha1} on ${ghprbTargetBranch}"
    git rebase origin/${ghprbTargetBranch} || {
      echo "Rebase failed, quitting"
      exit 1
    }
fi

# git plugin checks out repo to root of workspace
# but deploy script expects checkout in /opt/rpc-openstack
sudo ln -s $PWD /opt/rpc-openstack


## Add MAAS credentials
uev=/opt/rpc-openstack/rpcd/etc/openstack_deploy/user_extras_variables.yml
echo "Removing placeholder creds from user_extras_variables"

# Remove placeholder lines
sudo sed -i '/rackspace_cloud_\(auth_url\|tenant_id\|username\|password\|api_key\):/d' $uev

echo "Adding MAAS creds to user_extras_variables"
#set +x to avoid leaking creds to the log.
set +x
sudo tee -a $uev &>/dev/null <<EOVARS
rackspace_cloud_auth_url: ${rackspace_cloud_auth_url}
rackspace_cloud_tenant_id: ${rackspace_cloud_tenant_id}
rackspace_cloud_username: ${rackspace_cloud_username}
rackspace_cloud_password: ${rackspace_cloud_password}
rackspace_cloud_api_key: ${rackspace_cloud_api_key}
EOVARS
set -x


# Set ubuntu repo to supplied value. Effects Host bootstrap, and container default repo.
export BOOTSTRAP_OPTS="${BOOTSTRAP_OPTS} bootstrap_host_ubuntu_repo=${UBUNTU_REPO}"
export BOOTSTRAP_OPTS="${BOOTSTRAP_OPTS} bootstrap_host_ubuntu_security_repo=${UBUNTU_REPO}"

# Add any additional vars specified in jenkins job params
echo "$USER_VARS" | tee -a $uev

echo "********************** Run RPC Deploy Script ***********************"

sudo \
  DEPLOY_AIO=yes \
  DEPLOY_HAPROXY=yes \
  DEPLOY_TEMPEST=yes \
  DEPLOY_CEPH=${DEPLOY_CEPH} \
  DEPLOY_SWIFT=${DEPLOY_SWIFT} \
  DEPLOY_MAAS=yes \
  ANSIBLE_GIT_RELEASE=ssh_retry \
  ANSIBLE_GIT_REPO="https://github.com/hughsaunders/ansible" \
  ADD_NEUTRON_AGENT_CHECKSUM_RULE=yes \
  BOOTSTRAP_OPTS=$BOOTSTRAP_OPTS \
  scripts/deploy.sh

DEPLOY_RC=$?

echo "********************** Run Tempest ***********************"

# jenkins user does not have the necessary permissions to run lxc commands
# serial needed to ensure all tests
sudo lxc-attach -n $(sudo lxc-ls |grep utility) -- /bin/bash -c "RUN_TEMPEST_OPTS='--serial' /opt/openstack_tempest_gate.sh ${TEMPEST_TESTS}"

TEMPEST_RC=$?

[ $DEPLOY_RC == 0 -a $TEMPEST_RC == 0 ]
OVERALL_RESULT=$?

if [ "$UPGRADE" == "yes" ] && [ "$OVERALL_RESULT" -eq 0 ];
  then
    echo "Pre-upgrade Deployment Ansible Result: $DEPLOY_RC"
    echo "Pre-upgrade Deployment Tempest Result: $TEMPEST_RC"
    echo "Pre-upgrade Deployment Overall Result: $OVERALL_RESULT"

    git stash
    git checkout master
    echo "Rebasing ${sha1} on ${ghprbTargetBranch}"
    git rebase origin/${ghprbTargetBranch} || {
      echo "Rebase failed, quitting"
      exit 1
    }
    git submodule update --init

    echo "********************** Run RPC Deploy Script ***********************"

    sudo \
      TERM=linux \
      DEPLOY_AIO=no \
      DEPLOY_HAPROXY=yes \
      DEPLOY_TEMPEST=yes \
      DEPLOY_CEPH=${DEPLOY_CEPH} \
      DEPLOY_SWIFT=${DEPLOY_SWIFT} \
      DEPLOY_MAAS=yes \
      ANSIBLE_GIT_RELEASE=ssh_retry \
      ANSIBLE_GIT_REPO="https://github.com/hughsaunders/ansible" \
      ADD_NEUTRON_AGENT_CHECKSUM_RULE=yes \
      BOOTSTRAP_OPTS=$BOOTSTRAP_OPTS \
      scripts/upgrade.sh

    DEPLOY_RC=$?

    echo "********************** Run Tempest ***********************"

    # jenkins user does not have the necessary permissions to run lxc commands
    # serial needed to ensure all tests
    sudo lxc-attach -n $(sudo lxc-ls |grep utility) -- /bin/bash -c "RUN_TEMPEST_OPTS='--serial' /opt/openstack_tempest_gate.sh ${TEMPEST_TESTS}"

    TEMPEST_RC=$?

    [ $DEPLOY_RC == 0 -a $TEMPEST_RC == 0 ]
    OVERALL_RESULT=$?

fi
echo "Ansible Result: $DEPLOY_RC"
echo "Tempest Result: $TEMPEST_RC"
echo "Overall Result: $OVERALL_RESULT"
exit $OVERALL_RESULT

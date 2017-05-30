Ansible rpc_f5 role
###################

Role for generating bigip F5 commands for an RPC reference architecture

Example playbook:
.. code-block:: yaml

  - name: Generate F5 configuration
    hosts: localhost
    user: root
    roles:
      - { role: "rpc_f5" }

Services and options
~~~~~~~~~~~~~~~~~~~~

The services that will have respective F5 configurations are listed in defaults/main.yml.

This list can be overridden, but keep in mind that it must be overridden as a whole, so services cannot be
overridden individually.

Take the following snippit from the ``services`` list as an example:

.. code-block:: yaml

    - name: "nova_spice"
      proto: 'http'
      port: "{{ nova_spice_html5proxy_base_port }}"
      backend_port: "{{ nova_spice_html5proxy_base_port }}"
      make_public: true
      ssl_impossible: true
      persist: true
      group: "nova_console"
      mon_options:
        - "defaults-from http"
        - "destination '*:{{ nova_spice_html5proxy_base_port }}'"
        - "recv '200 OK'"
        - "send 'HEAD /spice_auto.html HTTP/1.1\\r\\nHost: rpc\\r\\n\\r\\n'"
      condition: "{{ nova_console_type == 'spice' and groups['nova_console'] | length > 0 | bool }}"

* name - The name of the service. This value will be used to build out virtual server names and monitors if applicable
* proto - The protocol to on the monitor for that service (if applicable)
* port - The frontend port of the service
* backend_port - The backend port of the service
* make_public - If make_public is true, then this role will create a virtual server for this service using the external_lb_vip_address
* ssl_impossible - Only used when make_public is true. If ssl_impossible is true, then the virtual server for this service will not be configured with an SSL profile
* persist - If persist is true, then the virtual server for this service will be configured with connection persistance
* mon_options - If it's required to create a custom monitor for this service, then options for that monitor can be specified here. Otherwise the service will use a generic external monitor
* condition - The F5 networking configurations for this service will only be printed if this condition is true

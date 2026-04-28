Role Name
=========

This Ansible role automates the installation and configuration of the
`brscan-skey` utility for Brother scanners.

This tool is essential for enabling
the physical "Scan" button on your Brother device to trigger a scan operation
on a Linux host. The role also includes a customizable script (scantofile.sh)
to handle the scanned images, with an example for scanning directly to a
CIFS/SMB network share.

Requirements
------------

- Designed for Deiban-based systems
- Internet access to download packages from the Brother website
- Internet access to install packages via apt


Role Variables
--------------

The following variables must be defined:
  - brscan_scanner_name: Brother_MFC-L2710DW_series         # The full scanner name as it appears in the network discovery
  - brscan_scanner_model: MFC-L2710DW                       # the specific model
  - brscan_scanner_ip: 192.168.8.239                        # the static IP of the scanner. Hostnames would need a modification in the role - see Brother documentation.

The provided script 'scantofile.sh' mounts a CIFS share. For this operation, it
requires a username and a password that must be provided as ansible variables.
It is highly recommended to store these variables in an Ansible vault for security.

The variables are:

    # group_vars/vault.yml
    # Role brscan: credentials for the "scan" user for SMB share
    - brscan_username: scan
    - brscan_password: 'transpire1TLYah%ample.uNHOOK'


Dependencies
------------

none

Example Playbook
----------------

Here's an example playbook:

    - name: Setup Brother brscan and ImageMagick tools
      hosts: t-docker01
      become: true
      become_method: sudo
      gather_facts: true

      vars_files:
      - group_vars/vault.yml    # encrypted credentials for the SMB share

      vars:
        brscan_scanner_name: Brother_MFC-L2710DW_series
        brscan_scanner_model: MFC-L2710DW
        brscan_scanner_ip: 192.168.8.239

      # Run Roles
      roles:
        - role: brscan
          tags: brscan

License
-------

BSD

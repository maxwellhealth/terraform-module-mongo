# terraform-module-mongo

A terraform module for creating a mongo replica set that is kind of self healing. If an individual member dies, the auto scale group should relaunch it and it should rejoin automagically.

## Requirements
* base ami (ubuntu, untested with anything else)
  * mongodb installed and configured
  * EBS volume available at /dev/xvdg
  * name prefixed with `mongo-`

## Initial Setup
# `terraform apply`
# log into created mongo hosts via ssh
# stop mongo (probably not running properly, because an admin user doesn't exist yet)
# create mongo admin user
# restart mongo on all hosts
# on a single host, create a replica set, using the DNS name created in route53 instead of the hostname of the box
# add the other instances to the replica set using the DNS names
# your replica set should be up

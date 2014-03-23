#!/usr/bin/env python
#
# rollout.py
#

"""
Generates a new release image from the latest Git versions.
"""

import boto.ec2
from boto.ec2.autoscale import AutoScaleConnection
from boto.ec2.autoscale.launchconfig import LaunchConfiguration
from boto.ec2.blockdevicemapping import BlockDeviceType, BlockDeviceMapping

import logging, time, subprocess, time, traceback, random, datetime

logging.basicConfig(level = logging.INFO,
  format = "%(asctime)-15s %(levelname)-5s %(message)s")

def main():
    logging.info("Starting rollout.")
    
    conn_ec2 = boto.ec2.connect_to_region("us-east-1")
    conn_ec2_as = AutoScaleConnection()
    
    logging.info("Searching for existing images...")
    existing_images = conn_ec2.get_all_images(owners = ["self"])
    
    ami_id = None
    for image in existing_images:
        if "Latest" in image.name and image.state == "available":
            ami_id = image.id
            break
    
    if ami_id is None:
        ami_id = 'ami-59a4a230' # Clean Ubuntu 12.04.
        logging.info("Using base image {0}".format(ami_id))
    else:
        logging.info("Using existing image {0}".format(ami_id))
    
    reservation = conn_ec2.run_instances(
        image_id = ami_id,
        key_name = 'jeremy-aws-key',
        instance_type = 't1.micro',
        security_groups = ['Worker Nodes'],
    )
    
    try:
        instance = reservation.instances[0]
        logging.info("Waiting for instance {} to start...".format(instance.id))
        
        instance.update()
        while instance.ip_address is None:
            logging.info("Not ready. Retrying in 10 seconds...")
            time.sleep(10)
            instance.update()
        
        while True:
            result = subprocess.call(["ssh", "-o",
              "UserKnownHostsFile=/dev/null", "-o", "StrictHostKeyChecking=no",
              "ubuntu@{}".format(instance.ip_address), "uname -r"])
            if result != 0:
                logging.info("Not ready for SSH. Retrying in 10 seconds...")
                time.sleep(10)
            else:
                break
        
        logging.info("Instance has started; running setup script.")
        logging.info("(IP address is {})".format(instance.ip_address))
        
        subprocess.check_call(["ssh", "-o", "UserKnownHostsFile=/dev/null",
          "-o", "StrictHostKeyChecking=no",
          "ubuntu@{}".format(instance.ip_address),
          "curl -O https://raw.github.com/fatlotus/lsda-infrastructure/"
          "master/servers/worker.sh && grep -v start <./worker.sh | sudo bash"])
        
        logging.info("Creating AMI from existing image.")
        new_image = instance.create_image(
            name = ('Latest-{:%Y-%m-%d--%H-%M-%S}'.
              format(datetime.datetime.now())),
            description = "(automatically generated)"
        )
        
        time.sleep(10)
        
        image_object = conn_ec2.get_image(new_image)
        
        while image_object.state == "pending":
            logging.info("State is still pending. Retrying in 10 seconds.")
            time.sleep(10)
            image_object.update()
        
    finally:
        logging.warn("Stopping all nodes.")
        for node in reservation.instances:
            node.terminate()
    
    logging.info("Creating new LaunchConfiguration.")
    
    mapping = BlockDeviceMapping()
    mapping["/dev/sdb"] = BlockDeviceType(ephemeral_name = "ephemeral0")
    
    new_launch_config = LaunchConfiguration(
        conn_ec2_as,
        name = ('$0.06d / Small / Latest-{:%Y-%m-%d--%H-%M-%S}'.
          format(datetime.datetime.now())),
        image_id = new_image,
        security_groups = ['sg-f9a08492'],
        instance_type = 'm1.small',
        block_device_mappings = [mapping],
        instance_profile_name = ("arn:aws:iam::470084502640:instance-profile"
          "/dal-access")
    )
    conn_ec2_as.create_launch_configuration(new_launch_config)
    
    logging.info("Setting launch configuration in existing ASG.")
    group = conn_ec2_as.get_all_groups(['LSDA Worker Pool'])[0]
    group.launch_config_name = new_launch_config.name
    group.update()
    
    logging.info("Cleaning up old launch configurations.")
    for config in conn_ec2_as.get_all_launch_configurations(names=["Latest"]):
        print(config.name)
        if config.image_id != new_launch_config.image_id:
            config.delete()
    
    logging.info("Cleaning up old images.")
    for image in conn_ec2.get_all_images(filters={"name":["LatestImage"]}):
        if image.id != new_image:
            conn_ec2.deregister_image(image.id, True)
    
    logging.info("Rollout complete. New image is {}.".format(new_image))

if __name__ == '__main__':
    main()

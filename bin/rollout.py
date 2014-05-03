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

import logging, time, subprocess, time, traceback, random, datetime, argparse

logging.basicConfig(level = logging.INFO,
  format = "%(asctime)-15s %(levelname)-5s %(message)s")

def main():
    parser = argparse.ArgumentParser(
      description = "triggers a full LSDA rollout")
    
    parser.add_argument("--inspect", action = "store_true",
      help = "pause before baking AMI", default = False)
    parser.add_argument("--clean", action = "store_true",
      help = "reset from clean Ubuntu 12.04 image", default = False)
    parser.add_argument("--no-restart", action = "store_true",
      dest = "no_restart", help = "don't restart all nodes in ASG",
      default = False)
    
    options = parser.parse_args()
    
    logging.info("Starting rollout.")
    
    conn_ec2 = boto.ec2.connect_to_region("us-east-1")
    conn_ec2_as = AutoScaleConnection()
    
    if not options.clean:
        logging.info("Searching for existing images...")
        
        group = conn_ec2_as.get_all_groups(['LSDA Worker Pool'])[0]
        launch_config = conn_ec2_as.get_all_launch_configurations(
          names=[group.launch_config_name])[0]
        
        existing_images = conn_ec2.get_all_images(owners = ["self"])[0]
        
        ami_id = launch_config.image_id
        logging.info("Using existing image {0}".format(ami_id))
    
    else:
        ami_id = 'ami-59a4a230' # Clean Ubuntu 12.04.
        logging.info("Using base image {0}".format(ami_id))
    
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
          "sudo stop lsda; sleep 20; sudo rm worker.sh;"
          "wget https://raw.github.com/fatlotus/lsda-infrastructure/"
          "master/servers/worker.sh; sudo bash worker.sh"])
        
        if options.inspect:
            logging.info("Connect to ubuntu@{} to inspect the image."
              .format(instance.ip_address))
            logging.info("When you're done, press CTRL-C.")
            
            try:
                while True:
                    time.sleep(3600)
            except KeyboardInterrupt:
                pass
        
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
    mapping["/dev/sdc"] = BlockDeviceType(ephemeral_name = "ephemeral1")
    
    new_launch_config = LaunchConfiguration(
        conn_ec2_as,
        name = ('$0.06d / C3Large / Latest-{:%Y-%m-%d--%H-%M-%S}'.
          format(datetime.datetime.now())),
        image_id = new_image,
        security_groups = ['sg-f9a08492'],
        instance_type = 'c3.large',
        block_device_mappings = [mapping],
        instance_profile_name = ("arn:aws:iam::470084502640:instance-profile"
          "/dal-access")
    )
    conn_ec2_as.create_launch_configuration(new_launch_config)
    
    logging.info("Setting launch configuration in existing ASG.")
    group.launch_config_name = new_launch_config.name
    group.update()
    
    logging.info("Cleaning up old launch configurations.")
    for config in conn_ec2_as.get_all_launch_configurations():
        if config.image_id != new_launch_config.image_id:
            conn_ec2_as.delete_launch_configuration(config.name)
    
    logging.info("Cleaning up old images.")
    for image in conn_ec2.get_all_images(filters={"name":["LatestImage"]}):
        if image.id != new_image:
            conn_ec2.deregister_image(image.id, True)
    
    logging.info("Rollout complete. New image is {}.".format(new_image))
    
    if not options.no_restart:
        logging.info("Triggering reload of all nodes in ASG.")
        for instance in group.instances:
            for reservation in conn_ec2.get_all_instances(instance.instance_id):
                reservation.stop_all()

if __name__ == '__main__':
    main()

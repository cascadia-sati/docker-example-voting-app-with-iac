# Example Voting App on Docker Swarm

This is a simple project that uses Terraform and Ansible to deploy [Docker's Example Voting App](https://github.com/dockersamples/example-voting-app) to a Docker Swarm running on EC2 instances.

The Terraform configuration supports provisioning an arbitrary number of Swarm manager and worker nodes (default of three each) and will auto-generate an inventory file for use with the Ansible playbooks, which in turn will install Docker on all nodes, create the Docker Swarm, and deploy the Example Voting App.

## Instructions

### Deploying the App

Follow these steps to provision the necessary AWS resources, create the Docker Swarm cluster, and deploy the Example Voting App:

1. Ensure AWS config and credentials are properly configured in _~/.aws/config_ and _~/.aws/credentials_ by running:  
   `$ aws configure`
1. Make sure you have SSH keys available. If not, generate them with the command below. Unless you set the `SSH_PRV_KEY` and `SSH_PUB_KEY` env vars, these keys will be assumed to be in _~/.ssh/id_rsa[.pub]_.  
   `$ ssh-keygen`
1. Optionally set the following env vars so you can directly copy and paste the commands in the remaining steps:
   - `$SSH_PRV_KEY`: The path to your private SSH key
   - `$SSH_PUB_KEY`: The path to your public SSH key
   - `$SSH_MGR_CNT`: How many Docker Swarm manager nodes to deploy  
     _(Note: Docker recommends using 3, 5, or 7 manager nodes)_
   - `$SSH_WRK_CNT`: How many Docker Swarm worker nodes to deploy
1. Deploy the necessary AWS Resources by running the following commands from the _./terraform_ directory:
   - `$ terraform init`
   - `$ terraform plan`  
     (Verify that the expected number of EC2 instances will be deployed)
   - `$ terraform apply \`  
     `-var="swarm_ssh_public_key_file=$SSH_PUB_KEY" \`  
     `-var="swarm_manager_count=$SWRM_MGR_CNT" \`  
     `-var="swarm_worker_count=$SWRM_WKR_CNT"`  
     (Verify that the Ansible inventory config was properly generated in _./ansible/hosts.cfg_)
1. Deploy the Example Voting App by running the following command in the _./ansible_ directory:  
   `$ ansible-playbook -i hosts.cfg --private-key $SSH_PRV_KEY deploy_example_voting_app.yml`
1. To verify the app is working, pick any of the worker node IPs in the _./ansible/hosts.cfg_ file and visit the following URLs in a web browser:
   - Voting page: `http://<worker-ip>:5000`
   - Results page: `http://<worker-ip>:5001`
   - You should be able to cast a vote on the voting page and see the results change on the results page.

### Deleting the App

These steps will destroy the Example Voting App, the Docker Swarm cluster, as well as the AWS resources:

1. Run the following command from the _./ansible_ directory:  
   `$ ansible-playbook -i hosts.cfg --private-key $SSH_PRV_KEY destroy_example_voting_app.yml`
1. Run the following command from the _./terraform_ directory:  
   `$ terraform destroy`

_Note: It's important to destroy any AWS resources that you're not actively using to conserve costs._

## Assumptions

The following assumptions about the configurations in this project must hold for the deployment instructions above to work:

- Ansible playbooks assume the inventory file places the Swarm manager nodes in a group called `swarm_managers` and the worker nodes in a group called `swarm_workers`. In Terraform this is done in the inventory template file _./terraform/templates/hosts.tftpl_ and for Ansible in the variables file _./ansible/vars.yml_.

## Future Enhancements

- Add TLS security to the app

- Save Terraform state in a remote backend

- Add an AWS Elastic Load Balancer (ELB) in front of the Docker Swarm workers

## Lessons Learned

- As stated on Terraform's [security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) documentation page (search "NOTE on Egress rules"), the normal default allow-all egress rule isn't created when Terraform creates security groups. This has to be explicitly added so that the instances can access the public Internet, which is necessary for them to install the Docker YUM and PIP packages. The default ingress rule that allows traffic between instances within security group also isn't created. It either needs to be created, or per-port rules must be added. The latter was chosen for better security.

- To create ingress or egress rules that reference the security group that they're atttached to, you can either use the `self = true` keyword in the rule or use separate `aws_security_group_rule` resources. The latter is useful to reduce redundancy when using the same rule across multiple security groups, but be careful to know which security groups are effected when changing such rules.

- The project provides a good example of how Terraform can generate an Ansible hosts files from the EC2 instances it deployed. It does so by passing in the lists of hostnames and public IP addresses, iterating over the hostnames, and then using the iteration index to access the public IP corresponding to each hostname.

- Ansible reuses SSH sessions between tasks, which means that the logged-in user will not be in any Unix groups that the user was added to during that session. For group changes to take effect, the `meta: reset_connection` task is used to force Ansible to create new SSH sessions.

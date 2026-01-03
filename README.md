# Flymetothemoon

This is a trial project to see if I can manage and host an application on a server that I manage. 

The overall goals of this are:

1. Demonstrate easy setup with a local setup_script
1. Provision a server on Hetzner using OpenTofu
1. Set up a straightforward CI/CD pipeline with GH actions, to 

Stretch Goals

1. Automatic backups
1. Automated or Semi-Automated Upgrades of Elixir/Erlang
1. Playbooks for increasing or decreasing resources on Hetzner with minimal downtime.
1. Automatic DNS setup.

## Motivation

I got fed up with trying to understand what the hell was going on with various
PaaS providers. At the end of the day, with Coding Agents drastically reducing the
barrier to IaC and deploy scripts, the use of these platforms, _specifically for
side-projects_ tend to become a bit of a nightmare after 3-4 years.
When you set and forget, the PaaS keeps moving. 
While I am obviously trading off the complexity of a specific service, for that of
running things on a server that I manage and maintain, I believe it is a worthwhile
tradeoff, as the skills developed here are more transferable than a specific provider.

vagrant-hackdinium
==================

A Vagrant environment for your [Hackdinium](https://github.com/mcrumm/vindinium-hacklang) project.

### Requirements

- [Vagrant](http://vagrantup.com)
- [VirtualBox](http://virtualbox.com)
- [vagrant-librarian-puppet](https://github.com/mhahn/vagrant-librarian-puppet), or install the [required modules](puppet/Puppetfile) manually.

### Installation

1. Clone this repository.
2. Copy `config.yaml.dist` to `config.yaml` and modify to suit your development environment.
3. Run `vagrant up`.
4. Access your project files from `/vagrant` within the virtual machine.
4. Fight!

*If you have any questions on how to get the Virtual Environment up and running, create an issue and I will update the documentation accordingly.*

project_path = File.dirname(__FILE__)
project_name = project_path.split('/').last
install_path = `grep -r install_path #{project_path}/config/projects | tr -s ' ' | cut -d' ' -f2`

$script = <<SCRIPT
mkdir -p #{project_name}
mkdir -p #{install_path}
chown vagrant:vagrant #{install_path}
SCRIPT

Vagrant.configure("2") do |c|
  c.vm.box = "forty9ten-omnibus-centos-6.5"
  c.vm.box_url = "https://dl.dropboxusercontent.com/s/yyhxj65ezgijfq0/forty9ten-omnibus-300-default-centos-65.box"
  c.vm.hostname = "default-centos-65.vagrantup.com"
  c.vm.synced_folder ".", "/vagrant", disabled: true
  c.vm.synced_folder ".", "/home/vagrant/#{project_name}"
  c.vm.provision "shell", inline: $script
  c.vm.provider :virtualbox do |p|
    p.customize ["modifyvm", :id, "--cpus", "2"]
    p.customize ["modifyvm", :id, "--memory", "2048"]
  end
end

## Omnibus Installer Tutorial

### Intro

Often, there is a bit of confusion around what [Omnibus](https://github.com/opscode/omnibus-ruby) does. Omnibus is a fantastic tool for creating "full-stack" or "vendor-everything" installers for multiple platforms (including Windows). It's what [Opscode/Chef](http://www.getchef.com/) uses to package [Chef](http://www.getchef.com/chef/) itself, but you don't need to be using Chef to take advantage of Omnibus.

There are many use cases for an Omnibus installer. In general, it simplifies the installation of any software by including all of the dependencies for that piece of software. This allows it to be installed on a target system regardless of whether its dependencies are in place. The work of resolving dependencies is done at installing build time. This means that once the installer has been built, it can be installed in a consistent manner across platforms.

### About this tutorial

In this tutorial we will be using the Omnibus installer to package a simple Ruby application with some Gem dependencies.

Typically, an Omnibus project is created using the Omnibus project code generator:

```
$ bin/omnibus project foo
```

For this tutorial, I have simplified the process by providing a project template. We will also be using [Vagrant](http://www.vagrantup.com/) to startup the virtual machine, so you will need to install it before getting started.

If you have any questions or run into any problems, feel free to drop me an email: <aaron@forty9ten.com>
or hit me up on Twitter [@aaronfeng] (http://twitter.com/aaronfeng).

**Note**: I created this Vagrant template because Omnibus 3.0.0+ requires additional tools (such as Test Kitchen and Berkshelf). These tools are intended to make Omnibus better, but they also increase the barrier to entry for Omnibus if you are not already familiar with them.

### Setup the template

First, we need to clone the project template.  Make sure you clone the repository into a directory named after your project. Notice that I have prefixed by project's name (`awesome`) with `omnibus`. This is a an Omnibus project convention:

```
$ git clone https://github.com/forty9ten/omnibus-skeleton.git omnibus-awesome
```

### Setup the virtual machine

Now we need to start the CentOS virtual machine and setup our Omnibus environment. It will take a few minutes to download the base virtual machine (depending on your internet connection), but this is a one time thing:

```
$ vagrant up
$ vagrant ssh
```

*From this point forward we will be executing commands inside the virtual machine.*

Now, after you SSH into the virtual machine, move into previously cloned directory:

```
$ cd omnibus-awesome
````

Next, we will need to change all the project files and references to match the project name.  `setup_project.sh` will handle it all for you.  This script is not part of Omnibus, but is a convenient script and it only needs to be run once.

```
$ ./bin/setup_project.sh awesome
```

Now we need to install Omnibus dependencies:

```
$ bundle install --binstubs
```

Before we go any further, let's do a test build to make sure we have everything setup correctly.

```
bin/omnibus build project awesome
```

An RPM will be generated inside the `pkg` directory (because we're on CentOS).  If the build finished successfully can continue.

### Working with Omnibus

Use your editor to open `config/projects/awesome.rb`.  Notice that the project file is the same name that you named the project from the step above.

First, update the `maintainer` and `homepage` attributes.  You can also change the `install_path` to another directory. This is the directory where the installer will install the software on the target machine.

**Note**: If you decide to change the `install_path`, you will need to run `./bin/setup_project awesome` again in order to setup the new path with the correct permissions.  For this tutorial you can just leave it as `/opt/awesome` for now.

The Omnibus installer will build everything inside the value of `install_path` and then create an RPM mirroring that directory.  Technically, this isn't exactly how it works behind the scenes, but you can think of it this way.

Around line `15` you will see `dependency 'awesome'`.  This tells the Omnibus installer to depend on the software definition file inside `config/software` directory (without the `.rb` extension).

Now let's edit `config/software/awesome.rb` in order to provide installation instructions. The content of the file should look something like below:

```ruby
name "awesome"
default_version "1.0.0"

# remove these if you don't need ruby
dependency "ruby"
dependency "rubygems"

build do
end
```

We will need to keep the `ruby` and `rubygems` dependencies since we are deploying a Ruby application. You might be wondering where the dependency definition is coming from.  By default it will look inside `config/software` directory. However, if it can't find it, then it will look in the [omnibus-software](https://github.com/opscode/omnibus-software/tree/master/config/software) repository.

It doesn't actually go out to the Internet to retrieve those files during the build. That repository got cloned onto your virtual machine when you did `bundle install`.  If you look inside the `Gemfile` you will see it points to the `omnibus-software` repo on GitHub:

```ruby
# Install omnibus software
gem 'omnibus', '~> 3.0'
gem 'omnibus-software', github: 'opscode/omnibus-software'
```

If you want to see the contents of those files on your machine, the location can be retrieved by using `bundle show omnibus-software`.

Those definitions are written by Opscode/Chef.  You can include anything in that list for free.  In addition, looking through these files is a quick way to learn the different things Omnibus can do.

Inside the `build` block is where we need to provide instructions on how to build our installer.  Below is the demo application we will be including inside this installer:

```
https://github.com/forty9ten/omnibus-example-ruby-app
```

The application is trivial, but it demonstrates how to package up all its dependencies (Gems) inside the installer.  Remember, we want to bundle all the program's dependencies into the installer so the application can run without needing to pull down any additional dependencies.

Below is a completed version of `config/software/awesome.rb`:

```ruby
name "awesome"
default_version "master"

dependency "ruby"
dependency "rubygems"
dependency "bundler"

source :git => "https://github.com/forty9ten/omnibus-example-ruby-app"

build do
  # vendor the gems required by the app
  bundle "install --path vendor/bundle"

  # setup a script to start the app using correct ruby and bundler
  command "cat << EOF > #{install_dir}/bin/run.sh
cd #{install_dir}/app
  #{install_dir}/embedded/bin/bundle exec \
  #{install_dir}/embedded/bin/ruby \
  #{install_dir}/app/money.rb
cd -
EOF"

  # make it executable
  command "chmod +x #{install_dir}/bin/run.sh"

  # move built app into install_dir
  command "cp -r #{project_dir} #{install_dir}/app"
end
```

The `default_version` is the version of the application.  It can be any string.  In this case, it goes hand-in-hand with `source`.  `source` is a way to tell Omnibus where the application lives.  When `source` sees the `:git` symbol, it will clone the code from git.  Since we set the `default_version` to `master`, it will clone the master branch of the code.  The directory of the cloned code will match the `name` attribute (`awesome`).  This is usually not important, but useful to know for debugging.  If you want to checkout a specific version, tag name can be used as value of `default_version`.  There are other valid sources such as `:url` and `:path`.

The `bundler` dependency is included because we use it to vendor all the application's Gems at build time.  Internally Omnibus knows how to execute Bundler, which is why the `bundle` command is available.  `--path vendor/bundle` tells bundler to download all the Gems specified by the Gemfile into `vender/bundle` of the cloned Git repository.

Another thing that might seem magical is where `bundle` command is executed from.  The application directory specified by the `source` is totally managed by Omnibus.  The `bundle` command is executed within the context of source.  This is nice because we are free to change the installer name without worry about adjusting paths to align everything.

Next we will create a convenience script to run our application.  Inside the project (`config/projects/awesome.rb`) file we specified the `install_path` (`/opt/awesome`) which points to the same location as `install_dir`.  The `bin` directory will be provided by Omnibus, so we don't need to create it ahead of time.  The script uses the `bundle` and `ruby` command packaged by the installer.

`project_dir` is where our application is cloned to (managed by `source`), it actually lives in an Omnibus cached directory inside `/var/cache/omnibus/src/awesome`.  We need to `cp` it to the `install_dir` in order to be packaged with our installer.  We will just copy to a directory named `app` inside `install_dir`.

Now, let's build our installer:

```
$ bin/omnibus build project awesome
```

The Omnibus installer takes a while to build the first time, but it is smart enough to cache files in between builds.  Subsequent builds should take less time.

If everything is setup correctly, you should see the new RPM inside `pkg` directory.  Notice the RPM name `awesome-0.0.0+20140508200804-1.el6.x86_64.rpm`  Omnibus uses `git tag` to version the RPM.  It defaults to `0.0.0` if no tag is found for the Omnibus project.

In case you are wondering what `install_dir` looks like after a successful build:

```
#>  tree -L 3 /opt/awesome

/opt/awesome/
├── app
├── bin
│   └── run.sh
├── embedded
│   ├── bin
│   ├── include
│   ├── lib
│   ├── man
│   ├── share
│   └── ssl
└── version-manifest.txt
```

The output above only shows 3 levels deep, so most of the files are not displayed.  Everything under `/opt/awesome` will be mirrored into the RPM.

The last step is to test out the RPM.  Before we do that, we need to delete the contents of `/opt/awesome/` shown above because we want to make sure the RPM has all the necessary files.  If we don't delete it, the RPM will just install on top of it.

Luckily, Omnibus has a command to do just that:

```
$ ./bin/omnibus clean awesome --purge
```

During Omnibus build process intermediate files are cached to speed up the builds.  The `clean` command will remove all the cached files.  `--purge` will remove contents of `install_dir`.

Install the RPM:

```
$ sudo rpm -ivh pkg/awesome-0.0.0....-1.el6.x86_64.rpm
```

Fill in the `...` with your actual build timestamp.  Once it has been installed, we need to verify that the program is still working:

```
$ /opt/awesome/bin/run.sh
```

The output should look something like this:

```
hello, how much money do I have? 10.00
going to sleep for 5
hello, how much money do I have? 10.00
going to sleep for 5
```

Yay!  You have successfully created a full-stack installer with everything included.  This application can be deployed without needing an internet connection or any extra external dependencies from the installed system.

Retrace the previous steps if you didn't get a working RPM.  You need to make sure you uninstall the RPM before reinstalling again by using the command below:

```
$ sudo rpm -e awesome
```

## Troubleshooting

You might encounter this error during your build process:

```
[fetcher:net::cacerts] Invalid MD5 for cacerts
```

This just means that the MD5 checksum for the Certificate Authority has changed compared to the locally cached version.  Most likely this problem will go away if you just delete the `Gemfile.lock` and rerun `bundle install` again.

If that doesn't fix your problem, you can override the `cacerts.rb` MD5 checksum in your project.  Create `config/software/cacerts.rb` with the content of below:

```
https://raw.githubusercontent.com/opscode/omnibus-software/master/config/software/cacerts.rb
```

 Update the MD5 value to what it is expecting, which should be shown below the error.  This is not the recommended way of fixing the problem, but it might be needed if the upstream repository has not been corrected.  This also shows that you can override any files in `omnibus-software` by creating a file with the same name inside your project.

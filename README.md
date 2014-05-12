## Omnibus Installer Tutorial

### Intro

Omnibus is a fantastic tool to create a "full-stack" or "vendor-everything" installer for  multiple platforms (including Windows).  It is what OpsCode (or Chef) uses to package Chef itself.  There is some confusion around what Omnibus really is.  Often people think Omnibus is only good for creating Chef installers, but in reality it is a general installer technology.

There are many use cases for Omnibus installer, but in general, it greatly simplifies the installation of any software.  It "vendor-everything", which means it will include all of the dependencies reguardless of what's installed on the target system.  The burden isn't placed on the end users to figure out how to fulfill the dependencies.  It is up to the publisher of the software to figure all the details out ahead of time.  This means once the installer has been built, it can be installed in a very consistent manner.  Since all the dependencies are built into the installer, no Internet connection is needed during the install, which greatly speeds up the installation process.  This is also useful in restricted environments that have limited or no Internet access at all.

### About this Tutorial

In this tutorial we will be using the Omnibus installer to package a simple Ruby application with some Gem dependencies.  This is a step-by-step tutorial so please pay attention to the details.

Typically an Omnibus project is created using the Omnibus project code generator.

`bin/omnibus project foo`

For this tutorial I have simplified the process so you can focus your attention on the creation of the installer.  A project template with a CentOS 6.5 VM has been specifically created for this tutorial in order to achieve the simplicity.  We will be using Vagrant to start up the VM so you will need to install it before getting started.

The reason I created this template is because Omnibus 3.0.0 requires additional tools and knowledge, such as Test Kitchen and Berkshelf.  These tools are intended to make Omnibus better, but it also increases the barrier to learn Omnibus if you are not already familiar with them.

This tutorial is designed to be very verbose because I want to make it as clear as possible.  If you have any questions or run into any problems, feel free to drop me an email: <aaron@forty9ten.com>.

### Setup the Template

Before we start we need to clone the project template.  Make sure you clone the directory into the name you want to call the project (as shown below).  Notice that I preserved the omnibus prefix before the project name.  This is a typical convention for an Omnibus installer project.  If you are going through the tutorial for the first time, it might be best to execute all commands. I have shown exactly to avoid any errors.

`git clone https://github.com/forty9ten/omnibus-skeleton.git omnibus-awesome`

### Setup the VM

Now we need to start up the CentOS VM and setup our Omnibus environment.  It will take sometime to download the VM, but this is a one time penalty.  Make sure you have fast Internet connection before proceeding.

`vagrant up && vagrant ssh`

From this point forward we are going to strictly work within the Vagrant VM.

Move into previously cloned directory.

`cd omnibus-awesome`

Next, we will need to change all the project files and references to match the project name.  `setup_project.sh` will handle it all for you.  This script is not part of Omnibus, but is a convenient script and it only needs to be run just this once.

`./bin/setup_project.sh awesome`

Install Omnibus dependepcies.

`bundle install --binstubs`

Before we go any further, let's do a test build to make sure we have everything setup correctly.

`bin/omnibus build project awesome`

The resulting RPM will appear inside the `pkg` directory.  If the build finished successfully we can start to do some real work.

Since we haven't provided any instructions on how to build the RPM yet, the resulting RPM doesn't contain anything useful.  No point to install it.  Let's add a simple Ruby script as part of the application we plan to deploy.

### Working with Omnibus

Use your favorite editor to edit `config/projects/awesome.rb`.  Notice that the project file is the same name that you named the project from the step above.

Change the `maintainer` and `homepage` to the desired values.  The `install_path` can also be changed to another directory.  This is the directory where the installer will install the final software on to the target machine.  If you decide to change the `install_path`, you will need to run `./bin/setup_project awesome` again in order to setup the new path with the correct permissions.  For this tutorial you can just leave it as `/opt/awesome` for now.

The way Omnibus installer works is that it will build everything inside the value of `install_path` then create an RPM that mirrors that directory.  This is an important concept to remember.  Technically speaking, this isn't exactly how it works behind the scenes, but you can think of it this way.

Around line 15 you will see `dependency 'awesome'`.  This tells the Omnibus installer to depend on the software definition file inside `config/software` directory (without the .rb extension).

Now let's edit `config/software/awesome.rb` in order to provide installation instructions.
The content of the file should look something like below:

```ruby
name "awesome"
default_version "1.0.0"

# remove these if you don't need ruby
dependency "ruby"
dependency "rubygems"

build do
end
```

We will need to keep `ruby` and `rubygems` dependencies since we are deploying a Ruby application.  This will instruct the Omnibus installer to include those dependencies into our application.
You might be wondering where the dependency definition is coming from.  By default it will look inside `config/software` directory. However, if it can't find it, then it will look at the `omnibus-software` repository which is located here:

`https://github.com/opscode/omnibus-software/tree/master/config/software`

It doesn't actually go out to the Internet to retrieve those files during the build.  It has cloned that repository onto your VM when you did `bundle install`.  If you look inside the `Gemfile` you will see it points to the omnibus-software repo on Github:

```ruby
# Install omnibus software
gem 'omnibus', '~> 3.0'
gem 'omnibus-software', github: 'opscode/omnibus-software'
```

If you want to see the implementation of those file on your machine the location can be retrieved by using `bundle show omnibus-software`.

Those are written by OpsCode (or Chef) for Chef.  You can include anything in that list for free.  Looking at these files can be a quick way to learn what Omnibus can do.

Inside the `build` block is where we need to provide instructions on how to build our installer.  Below is the demo application we will be including inside this installer:

`https://github.com/forty9ten/omnibus-example-ruby-app`

The application is trivial but it will demonstrate how to package up all its dependencies (Gems) inside the installer.  Remember, we want to bundle all the program's dependencies into the installer so the application can run without downloading anything from the Internet.

Below is a completed version of `config/software/awesome.rb`:

```ruby
name "awesome"
default_version "master"

dependency "ruby"
dependency "rubygems"
dependency "bundler"

source :git => "https://github.com/forty9ten/omnibus-example-ruby-app"

build do
  # vender the gems required by the app
  bundle "install --path vender/bundle"

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

The `default_version` is the version of the application.  It can be any string.  In this case, it goes hand-in-hand with `source`.  `source` is a way to tell Omnibus where the application lives that we want to be included.  When `source` sees `:git` symbol it will clone the code from git.  Since we set the `default_version` to `master`, it will clone the master branch of the code.  The directory of the cloned code will match the `name` attribute (awesome).  This is usually not important, but useful to know for debugging.  If you want to checkout a specific version, tag name can be used as value of `default_version`.  There are other valid sources such as `:url` and `:path`.

`bundler` dependency is included because we will use it to vendor all the application's Gems during the build time.  Internally Omnibus knows how to execute bundler, which is why the `bundle` command is available.  `--path vender/bundle` tells bundler to download all the Gems specified by the Gemfile into `vender/bundle` of the cloned git repository.  Another thing that might seem magical is where `bundle` command is executed from.  The application directory specified by the `source` is totally managed by Omnibus.  The `bundle` command is executed within the context of source.  This is nice because we are free to change the installer name without worry about adjusting paths to align everything.

Next we will create a convenience script to run our application.  Inside the project (`config/projects/awesome.rb`) file we specified the `install_path` (`/opt/awesome`) which points to the same location as `install_dir`.  The `bin` directory will be provided by Omnibus, so we don't need to create it ahead of time.  The script uses the `bundle` and `ruby` command packaged by the installer.

`project_dir` is where our application is cloned to (managed by `source`), it actually lives in an Omnibus cached directory inside `/var/cache/omnibus/src/awesome`.  We need to cp it to the `install_dir` in order to be packaged with our installer.  We will just copy to a directory named `app` inside `install_dir`.

Let's build our installer:

`bin/omnibus build project awesome`

Omnibus installer takes a while to build the first time, but it is smart enough to cache files in between builds.  Subsequent builds should be much faster.

If everything is setup correctly, you should see the new rpm inside `pkg` directory.  Notice the RPM name `awesome-0.0.0+20140508200804-1.el6.x86_64.rpm`  Omnibus uses `git tag` to version the RPM.  It defaults to `0.0.0` if no tag is found for the Omnibus project.

In case you are wondering what `install_dir` looked like after a successful build:

```
#>  tree -L 3 /opt/awesome

/opt/awesome/
├── app
├── bin
│   └── run.sh
├── embedded
│   ├── bin
│   ├── include
│   ├── lib
│   ├── man
│   ├── share
│   └── ssl
└── version-manifest.txt
```

The output above only shows 3 levels deep, so most of the files are not displayed.  Everything under `/opt/awesome` will be mirrored into the RPM.

Last step is to test out the RPM.  Before we do that, we need to delete the contents of `/opt/awesome/` shown above because we want to make sure the RPM does have all the necessary files.  If we don't delete it, the RPM will install on top of it which means we will have no idea if the RPM is missing any files.  Omnibus has a command to do just that:

`./bin/omnibus clean awesome --purge`

During Omnibus build process intermediate files are cached to speed up the builds.  `clean` command will remove all the cached files.  `--purage` will remove contents of `install_dir`.

Install the RPM.

`sudo rpm -ivh pkg/awesome-0.0.0....-1.el6.x86_64.rpm`

Fill in the `...` with your actual build timestamp.  Once it has been installed, we need to verify that the program is still working:

`/opt/awesome/bin/run.sh`

The output should look something like below:

```
hello, how much money do I have? 10.00
going to sleep for 5
hello, how much money do I have? 10.00
going to sleep for 5
```
Yay!  You have successfully created a full-stack installer that has everything included.  This application can be deployed without needing Internet connection or any extra external dependencies from the installed system.

Retrace previous steps if you didn't get a working RPM.  You need to make sure you uninstall the RPM before reinstalling again by using the command below:

`sudo rpm -e awesome`

### MD5 Error

You might encounter this error during your build process:

`[fetcher:net::cacerts] Invalid MD5 for cacerts`

This just means that the MD5 checksum for the Certificate Authority has changed compared to the locally cached version.  Most likely this problem will go away if you just delete the `Gemfile.lock` and rerun `bundle install` again.

If that doesn't fix your problem, you can override the `cacerts.rb` MD5 checksum in your project.  Create `config/software/cacerts.rb` with the content of below:

 `https://raw.githubusercontent.com/opscode/omnibus-software/master/config/software/cacerts.rb`

 Update the MD5 value to what it is expecting, which should be shown below the error.  This is not the recommended way of fixing the problem, but it might be needed is the upstream repository has not been corrected.  This also illustrates that you can override any files in `omnibus-software` by creating a file with the same name inside your project.

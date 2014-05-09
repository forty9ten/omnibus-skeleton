
name 'skeleton'
maintainer 'CHANGE ME'
homepage 'CHANGEME.com'

replaces        'skeleton'
install_path    '/opt/skeleton'
build_version   Omnibus::BuildVersion.new.semver
build_iteration 1

# creates required build directories
dependency 'preparation'

# skeleton dependencies/components
# dependency 'somedep'

# version manifest file
dependency 'version-manifest'

exclude '\.git*'
exclude 'bundler\/git'

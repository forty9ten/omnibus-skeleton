#!/bin/bash

if [ "$#" -ne 1 ]; then
  echo "please pass in a project name.  single word, no spaces"
fi

if [[ `uname` == 'Darwin' ]]; then
  echo "sed argument might not be compatible with Darwin."
  echo "it is designed to run on linux."
  echo "exiting..."
  exit 1
fi

# export is required because mv happens in a child shell
export NEW_PROJECT_NAME="$1"
export DEFAULT_PROJECT_NAME="skeleton"

# get full path of where this script is no matter where it was invoked
pushd `dirname $0` > /dev/null
SCRIPTPATH=`pwd`
popd > /dev/null

cd "$SCRIPTPATH/.."
  # avoid this error:
  # sed: RE error: illegal byte sequence
  export LC_CTYPE=C
  export LANG=C

  find . -type f -not -path "*/\.*"   \
                 -not -path "*/bin/*" \
                 -not -path "*/pkg/*" \
                 -exec sed -i "s/$DEFAULT_PROJECT_NAME/$NEW_PROJECT_NAME/g" {} \;

  find .  -name "$DEFAULT_PROJECT_NAME*"    \
          -not -path "*/\.*"   \
          -not -path "*/bin/*" \
          -not -path "*/pkg/*" \
          -exec sh -c 'git mv "$0" "${0/$DEFAULT_PROJECT_NAME/$NEW_PROJECT_NAME}"' {} \; \
          > /dev/null 2>&1

  sed -i "s/# dependency 'somedep'/dependency '$NEW_PROJECT_NAME'/g" \
      config/projects/$NEW_PROJECT_NAME.rb

cd - > /dev/null


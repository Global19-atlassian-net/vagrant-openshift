#--
# Copyright 2013 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#++

module Vagrant
  module Openshift
    module Action
      class BuildOrigin
        include CommandHelper

        def initialize(app, env, options)
          @app = app
          @env = env
          @options = options
        end

        def call(env)
          if @options[:images]
            # Migrate the local epel repo to the host machine
            ssh_user = @env[:machine].ssh_info[:username]
            destination="/home/#{ssh_user}/"
            @env[:machine].communicate.upload(File.join(__dir__,"/../resources"), destination)
            home="#{destination}/resources"
          
            sudo(@env[:machine], "#{home}/install_local_epel_repos.sh")
            
            cmd = %{
echo "Performing origin release build with images..."
set -e
OS_BUILD_IMAGE_ARGS='--mount /etc/yum.repos.d/local_epel.repo:/etc/yum.repos.d/local_epel.repo' make release
}
          else
            cmd = %{
echo "Performing origin release build..."
set -e
make release-binaries
}
          end
          cmd += %{

if [ ! -d _output/etcd ]
then
  hack/install-etcd.sh
fi
}
          if @options[:force]
            build_cmd = cmd
            cmd = %{
pushd /data/src/github.com/openshift/origin
#{build_cmd}
popd
}
          else
            cmd = sync_bash_command('origin', cmd)
          end
          do_execute(env[:machine], cmd)
          @app.call(env)
        end
      end
    end
  end
end
